class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: scope.includes(:tourist, :guide, :driver).order(updated_at: :desc).map { |chat| serialize(chat) }
  end

  def create
    type = params[:professional_type]
    klass = { 'Guia' => GuideProfile, 'Motorista' => DriverProfile }[type]
    return head :unprocessable_entity unless klass
    profile = klass.find(params[:professional_id])
    return render_error('Profissional indisponível') unless profile.user.gov_verified? && !profile.user.suspended?
    return head :unprocessable_entity if profile.user_id == @current_user.id
    attributes = { tourist_id: @current_user.id, guide_id: nil, driver_id: nil }
    attributes[type == 'Guia' ? :guide_id : :driver_id] = profile.user_id
    if params[:booking_id].present?
      booking = @current_user.bookings.find(params[:booking_id])
      return render_error('Reserva não corresponde ao profissional') unless booking.provider&.id == profile.user_id
      attributes[:booking_id] = booking.id
    end
    existing = if attributes[:booking_id].blank?
      scope.where(booking_id: nil).detect { |item| [item.tourist_id, item.guide_id, item.driver_id].compact.sort == [@current_user.id, profile.user_id].sort }
    end
    chat = existing || Conversation.find_or_create_by!(attributes)
    render json: serialize(chat)
  end

  def messages
    chat = scope.find(params[:id])
    render json: chat.messages.order(:created_at, :id).map { |message| message.as_json.merge('content' => message.hidden? ? 'Mensagem removida pela moderação.' : message.content) }
  end

  def send_message
    chat = scope.find(params[:id])
    message = chat.messages.new(content: params[:content].to_s.strip, sender: @current_user)
    if message.save
      chat.touch
      receiver_id = ([chat.tourist_id, chat.guide_id, chat.driver_id].compact - [@current_user.id]).first
      Notification.create!(user_id: receiver_id, title: "Mensagem de #{@current_user.name}", body: message.content.truncate(120), kind: 'message', target: 'chat')
      render json: message, status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def scope
    Conversation.where(tourist_id: @current_user.id).or(Conversation.where(guide_id: @current_user.id)).or(Conversation.where(driver_id: @current_user.id))
  end

  def serialize(chat)
    other = chat.tourist_id == @current_user.id ? (chat.guide || chat.driver) : chat.tourist
    chat.as_json.merge(name: other.name)
  end
end
