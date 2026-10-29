class BookingsController < ApplicationController
  # POST /bookings (Criar solicitação de acordo/reserva pelo turista)
  def create
    booking = Booking.new(booking_params)
    booking.status = 'pending_approval'
    booking.payment_status = 'pending'

    if booking.save
      render json: { message: "Proposta de acordo enviada com sucesso!", booking: booking }, status: :created
    else
      render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /bookings/professional/:id (Listar solicitações recebidas pelo Guia ou Motorista)
  def professional_requests
    service_type = params[:service_type] # 'Guia' ou 'Motorista'
    service_id = params[:professional_id]

    bookings = Booking.where(service_type: service_type, service_id: service_id)
    render json: bookings, status: :ok
  end

  # PATCH /bookings/:id/respond (Profissional aceita ou recusa a proposta)
  def respond_booking
    booking = Booking.find_by(id: params[:id])
    return render json: { error: "Reserva não encontrada" }, status: :not_found unless booking

    action = params[:action_type] # 'accept' ou 'reject'

    if action == 'accept'
      booking.update(status: 'approved_waiting_payment')
      render json: { message: "Acordo aceito com sucesso!", booking: booking }, status: :ok
    elsif action == 'reject'
      booking.update(status: 'rejected')
      render json: { message: "Acordo recusado.", booking: booking }, status: :ok
    else
      render json: { error: "Ação inválida" }, status: :bad_request
    end
  end

  private

  def booking_params
    params.require(:booking).permit(:user_id, :service_type, :service_id, :total_amount, :date, :meeting_point)
  end
end