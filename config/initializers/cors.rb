# Executa antes de autenticação, redirecionamentos SSL e tratamento de erros,
# incluindo o preflight OPTIONS enviado pelo navegador antes do POST /login.
local_origins = %w[http://localhost:8081 http://127.0.0.1:8081]
default_origins = Rails.env.production? ? local_origins.join(',') : '*'
configured = ENV['CORS_ORIGINS'].presence || default_origins
allowed_origins = configured.split(',').map { |origin| origin.strip.sub(%r{/+\z}, '') }.reject(&:blank?).uniq

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)
    resource '*',
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: false,
      max_age: 600
  end
end
