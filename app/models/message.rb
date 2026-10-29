class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: 'User'
  validates :content, presence: true, length: { maximum: 4000 }
  validate :protect_contacts
  after_create_commit :broadcast_message
  after_update_commit :broadcast_message

  def public_payload
    as_json.merge('content' => hidden? ? 'Mensagem removida pela moderação.' : content)
  end

  private

  def protect_contacts
    errors.add(:content, 'não pode conter telefone, e-mail, redes sociais ou links. Continue a conversa pelo aplicativo.') if (new_record? || will_save_change_to_content?) && ContactPolicy.blocked?(content)
    errors.add(:sender, 'não participa desta conversa') unless conversation && sender && conversation.participant?(sender)
  end

  def broadcast_message
    ConversationChannel.broadcast_to(conversation, public_payload)
  end
end
