class SupportChat
  class Unavailable < StandardError; end

  def self.send_message(ticket, content, initial: false)
    text = content.to_s.strip
    raise Unavailable, 'Escreva uma mensagem de até 4000 caracteres.' if text.blank? || text.length > 4000
    request_id = nil
    ticket.with_lock do
      raise Unavailable, 'Este atendimento foi encerrado. Inicie uma nova conversa.' if ticket.status == 'closed'
      if ticket.ai_request_id.present? && ticket.ai_started_at && ticket.ai_started_at > 90.seconds.ago
        raise Unavailable, 'O assistente está respondendo. Aguarde um instante.'
      end
      ticket.support_messages.create!(role: 'user', content: text) unless initial
      if ticket.status == 'ai'
        request_id = SecureRandom.uuid
        ticket.update!(ai_request_id: request_id, ai_started_at: Time.current)
      else
        ticket.update!(status: 'open')
      end
    end
    if request_id
      history = ticket.support_messages.where.not(role: 'system').order(id: :desc).limit(13).to_a.reverse
      answer = SupportResponder.call(text, history: history[0...-1].map { |message| { role: message.role == 'user' ? 'user' : 'assistant', content: message.content } })
      ticket.with_lock do
        # Uma transferência humana invalida qualquer resposta de IA em andamento.
        if ticket.status == 'ai' && ticket.ai_request_id == request_id
          ticket.support_messages.create!(role: 'assistant', sender_name: 'Assistente virtual', content: answer.fetch(:reply))
          ticket.update!(ai_request_id: nil, ai_started_at: nil)
        end
      end
    end
    ticket.reload
  ensure
    if request_id
      SupportTicket.where(id: ticket.id, ai_request_id: request_id).update_all(ai_request_id: nil, ai_started_at: nil)
    end
  end

  def self.request_human(ticket)
    ticket.with_lock do
      raise Unavailable, 'Este atendimento foi encerrado. Inicie uma nova conversa.' if ticket.status == 'closed'
      return ticket unless ticket.status == 'ai'
      ticket.update!(status: 'open', human_requested_at: Time.current, ai_request_id: nil, ai_started_at: nil)
      ticket.support_messages.create!(role: 'system', content: 'Atendimento humano solicitado. A equipe recebeu sua conversa e responderá por aqui.')
    end
    ticket
  end

  def self.staff_reply(ticket, staff, text)
    text = text.to_s.strip
    raise Unavailable, 'Escreva uma resposta de até 4000 caracteres.' if text.blank? || text.length > 4000
    ticket.with_lock do
      raise Unavailable, 'Este chamado não está disponível para resposta humana.' unless %w[open answered].include?(ticket.status)
      ticket.support_messages.create!(role: 'staff', admin_user: staff, sender_name: staff.name, content: text)
      ticket.update!(reply: text, status: 'answered', assigned_staff: staff)
      Notification.create!(user: ticket.user, title: 'Nova mensagem do suporte', body: text.truncate(180), kind: 'support', target: 'suporte')
    end
  end

  def self.close(ticket, staff)
    ticket.with_lock do
      raise Unavailable, 'Este atendimento já foi encerrado ou ainda está com o assistente.' unless %w[open answered].include?(ticket.status)
      ticket.update!(status: 'closed', assigned_staff: ticket.assigned_staff || staff, ai_request_id: nil, ai_started_at: nil)
      ticket.support_messages.create!(role: 'system', content: 'Atendimento encerrado pela equipe. Caso precise, inicie uma nova conversa.')
      Notification.create!(user: ticket.user, title: 'Atendimento encerrado', body: "O chamado ##{ticket.id} foi encerrado. Seu histórico continua disponível no suporte.", kind: 'support', target: 'suporte')
    end
  end
end
