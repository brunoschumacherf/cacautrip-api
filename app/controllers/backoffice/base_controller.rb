module Backoffice
  class BaseController < ActionController::Base
    layout 'backoffice'
    helper Backoffice::DisplayHelper
    helper Backoffice::NavigationHelper
    protect_from_forgery with: :exception
    before_action :require_staff!
    before_action :restrict_collection_operator!
    helper_method :current_admin_user, :can_read?, :can_write?

    rescue_from ActiveRecord::RecordNotFound do
      render plain: 'Registro não encontrado.', status: :not_found
    end

    private

    def current_admin_user
      return @current_admin_user if defined?(@current_admin_user)
      user = AdminUser.find_by(id: session[:admin_user_id], active: true)
      @current_admin_user = user if user && user.session_version == session[:admin_session_version] && session[:staff_seen_at].to_i > 1.hour.ago.to_i && session[:staff_signed_at].to_i > 8.hours.ago.to_i
    end

    def require_staff!
      unless current_admin_user
        reset_session
        redirect_to backoffice_login_path, alert: 'Entre com sua conta de administração ou suporte.'
        return
      end
      session[:staff_seen_at] = Time.current.to_i
      response.headers['Cache-Control'] = 'no-store, private'
      response.headers['X-Frame-Options'] = 'DENY'
      response.headers['Referrer-Policy'] = 'same-origin'
    end

    def can_read?(resource)
      current_admin_user&.admin? || (current_admin_user&.suporte? && Backoffice::Registry::SUPPORT_READ.include?(resource.to_s))
    end

    def can_write?(resource)
      current_admin_user&.admin? || (current_admin_user&.suporte? && Backoffice::Registry::SUPPORT_WRITE.include?(resource.to_s))
    end

    def restrict_collection_operator!
      return unless current_admin_user&.collection_operator?
      return if %w[eco_codes sessions].include?(controller_name)
      request.get? ? redirect_to(backoffice_eco_codes_path) : head(:forbidden)
    end

    def require_administrator!
      render plain: 'Esta ação é restrita a administradores.', status: :forbidden unless current_admin_user&.admin?
    end

    def audit!(action, record = nil, metadata = {})
      AdminAudit.create!(admin_user: current_admin_user, action: action, record_type: record&.class&.name,
        record_id: record&.id, metadata: metadata, request_id: request.request_id)
    end
  end
end
