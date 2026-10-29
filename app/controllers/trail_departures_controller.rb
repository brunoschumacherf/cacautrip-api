class TrailDeparturesController < ApplicationController
  before_action :authenticate_user!

  def create
    trail = owned_trails.find(params[:trail_id])
    starts = Array(params[:starts_at_list].presence || departure_params[:starts_at])
    return render_error('Informe entre uma e 60 datas de saída') unless starts.length.between?(1, 60)
    parsed_dates = starts.map { |value| Time.zone.parse(value.to_s) rescue nil }
    return render_error('Escolha datas futuras para as novas saídas') unless parsed_dates.all? { |date| date && date > Time.current }
    result = []
    trail.guide_profile.user.with_lock do
      parsed_dates.each do |date|
        attributes = departure_params.merge(starts_at: date)
        result << trail.departures.create!(attributes)
      end
    end
    render json: result.map(&:serialize), status: :created
  end

  def update
    departure = owned_departures.find(params[:id])
    departure.with_lock { departure.update!(departure_params) }
    render json: departure.serialize
  end

  def cancel
    departure = owned_departures.find(params[:id])
    if departure.bookings.where(status: 'completed').exists?
      return render_error('Não é possível cancelar uma saída que já possui serviços concluídos')
    end
    departure.with_lock do
      if departure.bookings.where(status: 'completed').exists?
        departure.errors.add(:base, 'Esta saída possui serviços concluídos e não pode ser cancelada')
        raise ActiveRecord::RecordInvalid, departure
      end
      departure.bookings.where.not(status: ['cancelled', 'rejected']).order(:id).each do |booking|
        booking.with_lock do
          booking.wallet_entries.where(kind: 'earning').update_all(status: 'cancelled')
          booking.update!(status: 'cancelled', payment_status: booking.payment_status == 'approved' ? 'refunded' : 'cancelled')
        end
      end
      departure.update!(status: 'cancelled')
    end
    render json: departure.serialize
  end

  def participants
    departure = owned_departures.find(params[:id])
    render json: { departure: departure.serialize,
      participants: departure.occupying_bookings.includes(:user).map { |booking| { booking_id: booking.id, name: booking.user.name, people: booking.people, status: booking.status, payment_status: booking.payment_status } } }
  end

  private

  def owned_trails
    Trail.joins(:guide_profile).where(guide_profiles: { user_id: @current_user.id })
  end

  def owned_departures
    TrailDeparture.where(trail_id: owned_trails.select(:id))
  end

  def departure_params
    params.require(:departure).permit(:starts_at, :capacity, :price_override, :meeting_point, :notes)
  end
end
