class SupportController < ApplicationController
  before_action :authenticate_user!
  before_action :load_ticket, only: [:show, :message, :human]
  rescue_from SupportChat::Unavailable do |error|
    render_error(error.message, :conflict)
  end

  def index
    render json: @current_user.support_tickets.includes(:assigned_staff).order(updated_at: :desc).limit(100).map(&:summary)
  end

  def show
    scope = @ticket.support_messages
    if params[:after_id].present?
      messages = scope.where('id > ?', params[:after_id].to_i).order(:id).limit(100)
    else
      scope = scope.where('id < ?', params[:before_id].to_i) if params[:before_id].present?
      messages = scope.order(id: :desc).limit(100).to_a.reverse
    end
    oldest = messages.first&.id
    render json: @ticket.summary.merge(messages: messages.map(&:public_message),
      has_older: oldest.present? && @ticket.support_messages.where('id < ?', oldest).exists?)
  end

  def create
    text = params[:message].to_s.strip
    return render_error('Escreva uma dúvida de até 4000 caracteres.') if text.blank? || text.length > 4000
    return render_error('Aguarde antes de iniciar outra conversa.', :too_many_requests) unless AuthenticationThrottle.allow?("support:#{@current_user.id}")
    ticket = @current_user.support_tickets.create!(message: text, status: 'ai')
    SupportChat.send_message(ticket, text, initial: true)
    render json: ticket.summary, status: :created
  end

  def message
    return render_error('Aguarde antes de enviar outra mensagem.', :too_many_requests) unless AuthenticationThrottle.allow?("support:#{@current_user.id}")
    SupportChat.send_message(@ticket, params[:message])
    render json: @ticket.summary
  end

  def human
    SupportChat.request_human(@ticket)
    render json: @ticket.summary
  end

  # Compatibilidade com versões antigas do aplicativo; agora cria histórico.
  def ask
    create
  end

  private

  def load_ticket
    @ticket = @current_user.support_tickets.find(params[:id])
  end
end
