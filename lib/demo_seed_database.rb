require 'uri'

# O acesso remoto só é aceito nesta base de apresentação explicitamente indicada.
# O fluxo padrão continua restrito ao desenvolvimento local.
module DemoSeedDatabase
  REMOTE_HOST = 'dpg-dbhk60e7bikc73ercmgg-a.oregon-postgres.render.com'.freeze

  def self.expected_database
    ENV['ALLOW_REMOTE_DEMO_RESET'] == 'cacautrip' ? 'cacautrip' : 'cacautrip_development'
  end

  def self.allowed?
    return false unless Rails.env.development?
    connection = ActiveRecord::Base.connection
    return false unless connection.current_database == expected_database
    return true if expected_database == 'cacautrip_development'

    url = URI.parse(ENV.fetch('DATABASE_URL', ''))
    url.host == REMOTE_HOST && url.path == '/cacautrip' &&
      ActiveRecord::Base.connection_db_config.configuration_hash[:host] == REMOTE_HOST
  rescue URI::InvalidURIError
    false
  end
end
