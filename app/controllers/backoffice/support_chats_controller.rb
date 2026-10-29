module Backoffice
  class SupportChatsController < BaseController
    before_action :require_support_access!
    before_action :load_ticket, except: :index
    rescue_from SupportChat::Unavailable do |error|
      redirect_to backoffice_support_chat_path(@ticket), alert: error.message, status: :see_other
    end

    def index
      scope = SupportTicket.human_queue.includes(:user, :assigned_staff)
      @status = %w[open answered closed all].include?(params[:status]) ? params[:status] : 'open'
      scope = scope.where(status: @status) unless @status == 'all'
      if params[:q].present?
        query = "%#{SupportTicket.sanitize_sql_like(params[:q].to_s.truncate(100))}%"
        scope = scope.joins(:user).where('users.name ILIKE :q OR users.email ILIKE :q OR support_tickets.message ILIKE :q', q: query)
      end
      @waiting = SupportTicket.human_queue.where(status: 'open').count
      @ongoing = SupportTicket.human_queue.where(status: 'answered').count
      @page = [params[:page].to_i, 1].max
      @tickets = scope.order(updated_at: :desc).offset((@page - 1) * 30).limit(31).to_a
      @more = @tickets.length > 30
      @tickets = @tickets.first(30)
    end

    def show
      audit!('support.view', @ticket)
      scope = @ticket.support_messages
      scope = scope.where('id < ?', params[:before_id].to_i) if params[:before_id].present?
      @messages = scope.order(id: :desc).limit(100).to_a.reverse
      @has_older = @messages.any? && @ticket.support_messages.where('id < ?', @messages.first.id).exists?
    end

    def messages
      messages = @ticket.support_messages.where('id > ?', params[:after_id].to_i).order(:id).limit(100)
      render json: { html: render_to_string(partial: 'messages', formats: [:html], locals: { messages: messages }),
        last_id: messages.last&.id, status: @ticket.status }
    end

    def reply
      SupportTicket.transaction do
        SupportChat.staff_reply(@ticket, current_admin_user, params[:content])
        audit!('support.reply', @ticket)
      end
      redirect_to backoffice_support_chat_path(@ticket, anchor: 'responder'), notice: 'Resposta enviada.', status: :see_other
    rescue SupportChat::Unavailable => error
      @draft = params[:content].to_s.first(4000)
      @messages = @ticket.support_messages.order(id: :desc).limit(100).to_a.reverse
      @has_older = @messages.any? && @ticket.support_messages.where('id < ?', @messages.first.id).exists?
      flash.now[:alert] = error.message
      render :show, status: :unprocessable_entity
    end

    def close
      SupportTicket.transaction do
        SupportChat.close(@ticket, current_admin_user)
        audit!('support.close', @ticket)
      end
      redirect_to backoffice_support_chat_path(@ticket), notice: 'Atendimento encerrado.', status: :see_other
    end

    private

    def require_support_access!
      head :forbidden unless current_admin_user&.admin? || current_admin_user&.suporte?
    end

    def load_ticket
      @ticket = SupportTicket.human_queue.find(params[:id])
    end
  end
end
