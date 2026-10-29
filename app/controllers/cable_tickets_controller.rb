class CableTicketsController < ApplicationController
  before_action :authenticate_user!

  def create
    ticket = Rails.application.message_verifier('cable').generate(@current_user.id, purpose: 'chat', expires_in: 1.minute)
    render json: { ticket: ticket }
  end
end
