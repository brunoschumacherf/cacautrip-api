# Registro técnico sem parâmetros, mensagens de usuários, IP ou texto da exceção.
class SystemErrorReporter
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue StandardError => error
    begin
      if ActiveRecord::Base.connection.data_source_exists?('system_incidents')
        controller = env['action_controller.instance']
        trace = Array(error.backtrace).select { |line| line.start_with?(Rails.root.to_s) }.first(8).join("\n").delete_prefix(Rails.root.to_s)
        SystemIncident.create!(error_class: error.class.name, location: controller ? "#{controller.controller_path}##{controller.action_name}" : 'rack',
          request_id: env['action_dispatch.request_id'], trace: trace)
      end
    rescue StandardError
      Rails.logger.error('Não foi possível registrar incidente do backoffice')
    end
    raise error
  end
end
