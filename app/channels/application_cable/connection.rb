module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      id = Rails.application.message_verifier('cable').verified(request.params[:ticket].to_s, purpose: 'chat')
      self.current_user = User.find_by(id: id, suspended: false)
      reject_unauthorized_connection unless current_user
    end
  end
end
