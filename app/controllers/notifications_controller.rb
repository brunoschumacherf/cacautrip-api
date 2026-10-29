class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Lembretes são derivados das reservas atuais, sem agendamento externo.
    @current_user.bookings.where(status: 'confirmed').find_each do |booking|
      date = Time.zone.parse(booking.date) rescue nil
      next unless date && date.between?(Time.current, 1.day.from_now)
      @current_user.notifications.find_or_create_by!(kind: 'reminder', target: "booking:#{booking.id}") do |notification|
        notification.title = 'Seu passeio está chegando'
        notification.body = "#{booking.date} • #{booking.meeting_point}"
      end
    end
    render json: @current_user.notifications.order(created_at: :desc).limit(100)
  end

  def update
    notification = @current_user.notifications.find(params[:id])
    notification.update!(read_at: Time.current)
    render json: notification
  end
end
