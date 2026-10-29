class BookingsController < ApplicationController
  before_action :authenticate_user!
  rescue_from EcoCheckout::Invalid do |error|
    render_error(error.message)
  end
  around_action :lock_trail_departure, only: [:pay, :payment_status, :cancel, :complete]

  def index
    render json: @current_user.bookings.order(created_at: :desc).map(&:details)
  end

  def show
    render json: accessible_bookings.find(params[:id]).details
  end

  def conversation
    booking = accessible_bookings.find(params[:id])
    return render_error('Chat disponível para guias e motoristas') unless ['Guia', 'Motorista'].include?(booking.service_type) && booking.provider
    attributes = { booking_id: booking.id, tourist_id: booking.user_id,
      guide_id: booking.service_type == 'Guia' ? booking.provider.id : nil,
      driver_id: booking.service_type == 'Motorista' ? booking.provider.id : nil }
    chat = Conversation.find_or_create_by!(attributes)
    render json: { id: chat.id }
  end

  def create
    attributes = params.require(:booking).permit(:service_type, :service_id, :date, :meeting_point, :people, :dropoff_point, :route_id, :conditions, :total_amount, :pickup_latitude, :pickup_longitude, :dropoff_latitude, :dropoff_longitude)
    return render_error('Escolha uma trilha e uma data no perfil do guia para reservar') if attributes[:service_type] == 'Guia'
    booking = @current_user.bookings.new(attributes)
    profile = booking.professional_profile
    allowed = if profile.is_a?(Destination)
      profile.active?
    else
      profile && profile.user.gov_verified? && !profile.user.suspended? && profile.available? && profile.moderation_status == 'published'
    end
    return render_error('Serviço indisponível') unless allowed && booking.provider&.id != @current_user.id
    return render_error('Roteiro inválido') if booking.route_id && !@current_user.routes.exists?(booking.route_id)
    return render_error('Capacidade insuficiente') if profile.is_a?(DriverProfile) && booking.people.to_i > profile.capacity
    if !profile.is_a?(Destination) && profile.availability.present? && !profile.availability.include?(booking.date)
      return render_error('Escolha uma das datas e horários informados pelo profissional')
    end
    booking.total_amount = profile.price if profile.is_a?(GuideProfile)
    booking.total_amount = profile.price * booking.people if profile.is_a?(Destination)
    booking.offer_by_id = @current_user.id
    booking.offer_history = [{ user_id: @current_user.id, amount: booking.total_amount.to_s, at: Time.current.iso8601 }]
    booking.status = booking.provider ? 'pending_approval' : 'approved_waiting_payment'
    booking.save!
    render json: { booking: booking.details }, status: :created
  end

  def professional_requests
    render json: professional_bookings.order(created_at: :desc).map(&:details)
  end

  def respond_booking
    return accept_offer if params[:action_type] == 'accept'
    booking = professional_bookings.find(params[:id])
    @current_user.with_lock do
      booking.with_lock do
        return render_error('Proposta já respondida', :conflict) unless ['pending_approval', 'counteroffer'].include?(booking.status)
        status = { 'accept' => 'approved_waiting_payment', 'reject' => 'rejected' }[params[:action_type]]
        return render_error('Ação inválida') unless status
        if params[:action_type] == 'accept' && professional_bookings.where(date: booking.date, status: ['approved_waiting_payment', 'confirmed']).where.not(id: booking.id).exists?
          return render_error('Você já possui um atendimento aceito neste horário', :conflict)
        end
        booking.update!(status: status)
      end
    end
    render json: { booking: booking.details }
  end

  def counteroffer
    booking = accessible_bookings.find(params[:id])
    return render_error('Guias trabalham com preço fixo') unless booking.service_type == 'Motorista'
    amount = BigDecimal(params[:amount].to_s.tr(',', '.')) rescue nil
    return render_error('Informe um valor maior que zero') unless amount && amount.positive? && amount <= 99999999
    booking.with_lock do
      return render_error('Esta negociação já foi encerrada', :conflict) unless ['pending_approval', 'counteroffer'].include?(booking.status)
      return render_error('Aguarde a resposta à sua proposta', :conflict) if booking.offer_by_id == @current_user.id
      booking.update!(total_amount: amount, offer_by_id: @current_user.id, status: 'counteroffer',
        offer_history: booking.offer_history + [{ user_id: @current_user.id, amount: amount.to_s, at: Time.current.iso8601 }])
    end
    render json: { booking: booking.details }
  end

  def accept_offer
    booking = accessible_bookings.find(params[:id])
    provider = booking.provider
    return render_error('Profissional indisponível') unless provider
    provider.with_lock do
      booking.with_lock do
        return render_error('Proposta já respondida', :conflict) unless ['pending_approval', 'counteroffer'].include?(booking.status)
        author = booking.offer_by_id || booking.user_id
        return render_error('A outra parte deve aceitar sua proposta', :forbidden) if author == @current_user.id
        provider_bookings = Booking.where(service_type: 'Motorista', service_id: provider.driver_profile&.id)
          .or(Booking.where(service_type: 'Guia', service_id: provider.guide_profile&.id))
        if provider_bookings.where(date: booking.date, status: ['approved_waiting_payment', 'confirmed']).where.not(id: booking.id).exists?
          return render_error('O profissional já tem um serviço neste horário', :conflict)
        end
        booking.update!(status: 'approved_waiting_payment')
      end
    end
    render json: { booking: booking.details }
  end

  def cancel
    booking = @current_user.bookings.find(params[:id])
    booking.with_lock do
      return render_error('Reserva não pode ser cancelada', :conflict) if ['completed', 'cancelled', 'rejected'].include?(booking.status)
      booking.wallet_entries.where(kind: 'earning').update_all(status: 'cancelled')
      EcoCheckout.release!(booking)
      booking.update!(status: 'cancelled', payment_status: booking.payment_status == 'approved' ? 'refunded' : 'cancelled')
    end
    render json: { booking: booking.details, message: 'Reserva cancelada.' }
  end

  def complete
    booking = professional_bookings.or(@current_user.bookings.where(service_type: ['Passeio', 'Parceiro'])).find(params[:id])
    return render_error('Somente o prestador pode concluir este serviço', :forbidden) if booking.provider && booking.provider.id != @current_user.id
    return render_error('Esta saída ainda não começou') if booking.trail_departure && booking.trail_departure.starts_at > Time.current
    booking.with_lock do
      return render_error('Somente reservas pagas podem ser concluídas', :conflict) unless booking.status == 'confirmed' && booking.payment_status == 'approved'
      booking.update!(status: 'completed', completed_at: Time.current)
      booking.wallet_entries.where(kind: 'earning', status: 'pending').update_all(status: 'available')
    end
    render json: { booking: booking.details }
  end

  def pay
    booking = @current_user.bookings.find(params[:id])
    booking.with_lock do
      return render json: { booking: booking.details } if booking.payment_status == 'approved'
      return render_error('O prazo da reserva expirou. Selecione novamente a saída.', :gone) if booking.trail_hold_expired?
      return render_error('Esta saída foi cancelada', :conflict) if booking.trail_departure && booking.trail_departure.status != 'scheduled'
      return render_error('Aguarde o aceite da proposta', :conflict) unless booking.status == 'approved_waiting_payment'
      method = params[:payment_method]
      return render_error('Escolha Pix ou cartão') unless ['pix', 'credit_card'].include?(method)
      discount_changed = false
      if params.key?(:redemption_id)
        previous_discount = [booking.discount_amount, booking.eco_discount['redemption_id']]
        EcoCheckout.apply!(booking, params[:redemption_id])
        discount_changed = previous_discount != [booking.discount_amount, booking.eco_discount['redemption_id']]
      end
      unless booking.payment_method == method && method == 'pix' && !discount_changed
        booking.update!(payment_method: method, payment_polls: 0)
      end
      booking.approve_payment! if method == 'credit_card' || booking.amount_due.zero?
    end
    render json: { booking: booking.details, pix_code: "PIX-MOCK-CACAUTRIP-#{booking.id}" }
  end

  def payment_status
    booking = @current_user.bookings.find(params[:id])
    booking.with_lock do
      return render_error('O prazo da reserva expirou. Selecione novamente a saída.', :gone) if booking.trail_hold_expired?
      if booking.status == 'approved_waiting_payment' && booking.payment_method == 'pix' && booking.payment_status == 'pending'
        booking.update!(payment_polls: booking.payment_polls + 1)
        booking.approve_payment! if booking.payment_polls >= 4
      end
    end
    render json: { booking: booking.details }
  end

  private

  def lock_trail_departure
    booking = accessible_bookings.find(params[:id])
    if booking.trail_departure
      booking.trail_departure.with_lock { yield }
    else
      yield
    end
  end

  def accessible_bookings
    @current_user.bookings.or(professional_bookings)
  end

  def professional_bookings
    guides = Booking.where(service_type: 'Guia', service_id: GuideProfile.where(user_id: @current_user.id).select(:id))
    drivers = Booking.where(service_type: 'Motorista', service_id: DriverProfile.where(user_id: @current_user.id).select(:id))
    partners = Booking.where(service_type: ['Passeio', 'Parceiro'], service_id: Destination.where(provider_id: @current_user.id).select(:id))
    guides.or(drivers).or(partners)
  end
end
