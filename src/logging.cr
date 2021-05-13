require "placeos-log-backend"
require "raven"
require "raven/integrations/action-controller"

require "./constants"

# Logging configuration
module PlaceOS::Triggers::Logging
  standard_sentry = Raven::LogBackend.new
  comprehensive_sentry = Raven::LogBackend.new(capture_all: true)

  # Logging configuration
  log_backend = PlaceOS::LogBackend.log_backend
  log_level = Triggers.production? ? ::Log::Severity::Info : ::Log::Severity::Debug
  namespaces = ["action-controller.*", "place_os.*", "e_mail.*"]

  ::Log.setup do |config|
    config.bind "*", :warn, log_backend

    namespaces.each do |namespace|
      config.bind namespace, log_level, log_backend

      # Bind raven's backend
      config.bind namespace, :warn, standard_sentry
      config.bind namespace, :error, comprehensive_sentry
    end
  end

  # Configure Sentry
  Raven.configure &.async=(true)

  PlaceOS::LogBackend.register_severity_switch_signals(
    production: Triggers.production?,
    namespaces: namespaces,
    backend: log_backend,
  )
end
