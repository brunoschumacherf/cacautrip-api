class GoogleAuthenticationController < ApplicationController
  class Conflict < StandardError; end

  def start
    return render_error('O acesso com Google ainda não foi configurado.', :service_unavailable) unless configured?
    return render_error('Muitas tentativas. Aguarde um minuto.', :too_many_requests) unless AuthenticationThrottle.allow?(request.remote_ip)
    target = params[:redirect_uri].to_s
    allowed = ENV.fetch('GOOGLE_APP_REDIRECT_URIS', '').split(',').map(&:strip)
    return render_error('Endereço de retorno não autorizado') unless allowed.include?(target)
    link_user = nil
    if request.headers['Authorization'].present?
      authenticate_user!
      return if performed?
      link_user = @current_user
    end
    state, secret = SecureRandom.urlsafe_base64(32), SecureRandom.urlsafe_base64(32)
    flow = GoogleAuthFlow.create!(state_digest: GoogleAuthFlow.digest(state), exchange_digest: GoogleAuthFlow.digest(secret),
      nonce: SecureRandom.urlsafe_base64(32), redirect_uri: target, link_user: link_user, expires_at: 10.minutes.from_now)
    query = URI.encode_www_form(client_id: ENV.fetch('GOOGLE_CLIENT_ID'), redirect_uri: ENV.fetch('GOOGLE_CALLBACK_URL'),
      response_type: 'code', scope: 'openid email profile', state: state, nonce: flow.nonce, prompt: 'select_account')
    render json: { authorization_url: "https://accounts.google.com/o/oauth2/v2/auth?#{query}", exchange_secret: secret, flow_id: flow.id }
  end

  def callback
    flow = GoogleAuthFlow.find_by(state_digest: GoogleAuthFlow.digest(params[:state]))
    return render_error('Solicitação de login inválida ou expirada.', :unauthorized) unless flow
    ticket = nil
    flow.with_lock do
      return render_error('Solicitação de login expirada.', :unauthorized) unless flow.status == 'pending' && flow.expires_at.future?
      if params[:error].present?
        flow.update!(status: 'cancelled')
      else
        claims = GoogleIdentity.exchange(params[:code].to_s, nonce: flow.nonce)
        user = resolve_user(claims, flow.link_user)
        ticket = SecureRandom.urlsafe_base64(32)
        flow.update!(status: 'authorized', authenticated_user: user, ticket_digest: GoogleAuthFlow.digest(ticket), expires_at: 2.minutes.from_now)
      end
    end
    redirect_to app_redirect(flow, ticket ? { code: ticket, flow: flow.id } : { error: 'cancelled' }), allow_other_host: true
  rescue Conflict
    redirect_to app_redirect(flow, error: 'account_exists'), allow_other_host: true
  rescue GoogleIdentity::Invalid, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to app_redirect(flow, error: 'invalid_identity'), allow_other_host: true
  end

  def finish
    flow = GoogleAuthFlow.find_by(id: params[:flow_id], ticket_digest: GoogleAuthFlow.digest(params[:code]))
    return render_error('Login expirado. Tente entrar novamente.', :unauthorized) unless flow
    secret_matches = ActiveSupport::SecurityUtils.secure_compare(flow.exchange_digest, GoogleAuthFlow.digest(params[:exchange_secret]))
    return render_error('Não foi possível confirmar esta sessão.', :unauthorized) unless secret_matches
    user = nil
    flow.with_lock do
      return render_error('Este login já foi usado ou expirou.', :unauthorized) unless flow.status == 'authorized' && flow.expires_at.future?
      user = flow.authenticated_user
      return render_error('Conta indisponível.', :forbidden) unless user && !user.suspended?
      flow.update!(status: 'consumed', ticket_digest: nil)
    end
    token = Rails.application.message_verifier('session').generate(user.id, purpose: 'login', expires_in: 7.days)
    render json: { token: token, user: user.public_profile }
  end

  private

  def configured?
    %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_CALLBACK_URL GOOGLE_APP_REDIRECT_URIS].all? { |key| ENV[key].present? }
  end

  def resolve_user(claims, linking)
    email = claims.fetch('email').strip.downcase
    identity = User.find_by(google_uid: claims.fetch('sub'))
    if linking
      raise Conflict if linking.email != email || (identity && identity.id != linking.id) || (linking.google_uid.present? && linking.google_uid != claims['sub']) || linking.suspended?
      linking.update!(google_uid: claims['sub'])
      return linking
    end
    return identity if identity
    # Nunca unir uma conta local a uma identidade externa apenas pelo e-mail.
    raise Conflict if User.exists?(email: email)
    User.create!(email: email, name: claims['name'].to_s.presence || email.split('@').first,
      google_uid: claims['sub'], password: SecureRandom.urlsafe_base64(40), gov_verified: false, active_role: 'tourist', admin: false)
  end

  def app_redirect(flow, values)
    "#{flow.redirect_uri}?#{URI.encode_www_form(values)}"
  end
end
