require Rails.root.join('lib/system_error_reporter')
Rails.application.config.middleware.insert_after ActionDispatch::DebugExceptions, SystemErrorReporter
