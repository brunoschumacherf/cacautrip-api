Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    configured = ENV.fetch('CORS_ORIGINS', '').split(',').map(&:strip).reject(&:blank?)
    if Rails.env.production?
      origins(*configured) if configured.any?
    else
      origins(*(configured.presence || ['*']))
    end
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
