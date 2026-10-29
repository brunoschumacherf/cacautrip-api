class SupportController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: @current_user.support_tickets.order(created_at: :desc)
  end

  def ask
    message = params[:message].to_s.strip
    return render_error('Escreva uma dúvida de até 4000 caracteres') if message.blank? || message.length > 4000
    render json: SupportResponder.call(message)
  end

  def create
    ticket = @current_user.support_tickets.create!(message: params[:message])
    render json: ticket, status: :created
  end
end
