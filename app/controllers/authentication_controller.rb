class AuthenticationController < ApplicationController
  def signup
    user = User.new(user_params)
    if user.save
      render json: { message: "Usuário criado com sucesso", user: { id: user.id, name: user.name, email: user.email } }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    email = params[:email] || params.dig(:authentication, :email)
    password = params[:password] || params.dig(:authentication, :password)

    user = User.find_by(email: email)
    if user && user.authenticate(password)
      render json: { 
        message: "Login realizado com sucesso", 
        user: { id: user.id, name: user.name, email: user.email, gov_verified: user.gov_verified } 
      }, status: :ok
    else
      render json: { error: "E-mail ou senha inválidos" }, status: :unauthorized
    end
  end

  private

  def user_params
    params.require(:authentication).permit(:name, :email, :password, :password_confirmation)
  rescue ActionController::ParameterMissing
    params.permit(:name, :email, :password, :password_confirmation)
  end
end