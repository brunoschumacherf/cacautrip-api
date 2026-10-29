class TrailReservationsController < ApplicationController
  before_action :authenticate_user!

  def create
    departure = TrailDeparture.where(trail_id: Trail.visible.select(:id)).find(params[:departure_id])
    trail = departure.trail
    return render_error('Você não pode reservar sua própria trilha') if trail.guide_profile.user_id == @current_user.id
    return render_error('Confirme a leitura dos requisitos e condições') unless ActiveModel::Type::Boolean.new.cast(params[:requirements_accepted])
    people = params[:people].to_i
    return render_error('Informe entre uma e 100 pessoas') unless people.between?(1, 100)
    route = params[:route_id].present? ? @current_user.routes.find(params[:route_id]) : nil
    result = nil
    departure.with_lock do
      return render_error('Esta saída não está mais disponível') unless departure.status == 'scheduled' && departure.starts_at > Time.current
      existing = departure.occupying_bookings.find_by(user_id: @current_user.id)
      return render json: { booking: existing.details } if existing
      return render_error('Não há vagas suficientes nesta saída', :conflict) if people > departure.available_seats
      total = departure.unit_price * (trail.price_mode == 'per_person' ? people : 1)
      snapshot = trail.attributes.except('created_at', 'updated_at').merge(
        'stops' => trail.stops.as_json, 'guide_name' => trail.guide_profile.user.name,
        'starts_at' => departure.starts_at.iso8601, 'meeting_point' => departure.meeting_point,
        'unit_price' => departure.unit_price.to_f, 'total_amount' => total.to_f, 'departure_notes' => departure.notes)
      result = @current_user.bookings.create!(service_type: 'Guia', service_id: trail.guide_profile_id,
        trail_departure: departure, route: route, trail_snapshot: snapshot,
        people: people, total_amount: total, status: 'approved_waiting_payment', payment_status: 'pending',
        date: departure.starts_at.in_time_zone('America/Bahia').strftime('%Y-%m-%d %H:%M'),
        meeting_point: departure.meeting_point, dropoff_point: trail.stops.last&.address,
        conditions: nil, offer_by_id: trail.guide_profile.user_id, hold_expires_at: 30.minutes.from_now)
    end
    render json: { booking: result.details }, status: :created
  end
end
