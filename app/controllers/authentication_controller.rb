class AuthenticationController < ApplicationController
  before_action :authenticate_user!, only: [:me, :verify_gov, :update_profile]

  def me
    render json: @current_user.public_profile
  end

  def update_profile
    attributes = params.permit(:name, :email, :active_role, preferences: [:interests, :accessible, :region, :notifications])
    if ['guide', 'driver'].include?(attributes[:active_role]) && !@current_user.public_send("#{attributes[:active_role]}_profile")
      return render_error('Cadastre primeiro este perfil profissional')
    end
    @current_user.update!(attributes)
    render json: @current_user.public_profile
  end

  def verify_gov
    @current_user.update!(gov_verified: true)
    render json: { user: @current_user.as_json(only: [:id, :name, :email, :gov_verified]), message: 'Conta autenticada no Gov.br (simulação)' }
  end

  def signup
    return render_error('Muitas tentativas. Aguarde um minuto.', :too_many_requests) unless AuthenticationThrottle.allow?(request.remote_ip)
    user = User.new(user_params)
    if user.save
      render json: { message: "Usuário criado com sucesso", token: session_token(user), user: { id: user.id, name: user.name, email: user.email, gov_verified: user.gov_verified } }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    return render_error('Muitas tentativas. Aguarde um minuto.', :too_many_requests) unless AuthenticationThrottle.allow?(request.remote_ip)
    email = params[:email] || params.dig(:authentication, :email)
    password = params[:password] || params.dig(:authentication, :password)

    user = User.find_by(email: email.to_s.strip.downcase)
    if user && !user.suspended? && user.authenticate(password)
      render json: { 
        message: "Login realizado com sucesso", 
        token: session_token(user),
        user: { id: user.id, name: user.name, email: user.email, gov_verified: user.gov_verified } 
      }, status: :ok
    else
      render json: { error: "E-mail ou senha inválidos" }, status: :unauthorized
    end
  end

  private

  def session_token(user)
    Rails.application.message_verifier('session').generate(user.id, purpose: 'login', expires_in: 7.days)
  end

  def user_params
    params.require(:authentication).permit(:name, :email, :password, :password_confirmation)
  rescue ActionController::ParameterMissing
    params.permit(:name, :email, :password, :password_confirmation)
  end
end
