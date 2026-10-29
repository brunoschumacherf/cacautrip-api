class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find_by(id: params[:conversation_id])
    return reject unless conversation && conversation.participant?(current_user)
    stream_for conversation
  end
end
