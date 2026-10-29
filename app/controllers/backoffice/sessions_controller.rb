module Backoffice
  class SessionsController < BaseController
    skip_before_action :require_staff!, only: [:new, :create]

    def new
      redirect_to backoffice_root_path if current_admin_user
    end

    def create
      unless AuthenticationThrottle.allow?(request.remote_ip)
        flash.now[:alert] = 'Muitas tentativas. Aguarde um minuto.'
        return render :new, status: :too_many_requests
      end
      user = AdminUser.find_by(email: params[:email].to_s.strip.downcase, active: true)
      unless user && user.authenticate(params[:password].to_s)
        flash.now[:alert] = 'E-mail ou senha inválidos.'
        return render :new, status: :unprocessable_entity
      end
      reset_session
      session[:admin_user_id] = user.id
      session[:admin_session_version] = user.session_version
      session[:staff_seen_at] = Time.current.to_i
      session[:staff_signed_at] = Time.current.to_i
      user.update!(last_sign_in_at: Time.current)
      @current_admin_user = user
      audit!('session.login')
      redirect_to (user.collection_operator? ? backoffice_eco_codes_path : backoffice_root_path), notice: 'Bem-vindo ao painel.'
    end

    def destroy
      audit!('session.logout')
      reset_session
      redirect_to backoffice_login_path, notice: 'Sessão encerrada.', status: :see_other
    end
  end
end
