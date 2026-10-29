class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: 'Registro não encontrado' }, status: :not_found
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
  rescue_from ActionController::ParameterMissing do |error|
    render json: { error: error.message }, status: :bad_request
  end
  rescue_from ActiveRecord::RecordNotUnique do
    render json: { error: 'Este registro já foi criado. Atualize a tela.' }, status: :conflict
  end

  private

  def authenticate_user!
    token = request.headers['Authorization'].to_s.delete_prefix('Bearer ')
    id = Rails.application.message_verifier('session').verified(token, purpose: 'login')
    @current_user = User.find_by(id: id)
    render json: { error: 'Faça login novamente' }, status: :unauthorized unless @current_user && !@current_user.suspended?
  end

  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end

  def require_admin!
    render_error('Acesso restrito à administração', :forbidden) unless @current_user&.admin?
  end
end
