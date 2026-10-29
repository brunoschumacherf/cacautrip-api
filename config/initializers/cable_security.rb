Rails.application.config.action_cable.allowed_request_origins = if Rails.env.production?
  (ENV['CABLE_ORIGINS'].presence || ENV['CORS_ORIGINS'].presence || 'http://localhost:8081,http://127.0.0.1:8081').split(',').map { |origin| origin.strip.sub(%r{/+\z}, '') }.reject(&:blank?)
else
  [nil, /\Ahttp:\/\/localhost(?::\d+)?\z/, /\Ahttp:\/\/127\.0\.0\.1(?::\d+)?\z/, /\Ahttp:\/\/192\.168\.\d+\.\d+(?::\d+)?\z/, /\Ahttp:\/\/10\.\d+\.\d+\.\d+(?::\d+)?\z/]
end
Rails.application.config.filter_parameters += [:ticket, :pix_key, :account, :agency]
