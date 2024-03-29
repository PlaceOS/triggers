require "./logging"
require "opentelemetry-instrumentation/src/opentelemetry/instrumentation/instrument"
require "placeos-log-backend/telemetry"

module PlaceOS::Triggers
  PlaceOS::LogBackend.configure_opentelemetry(
    service_name: APP_NAME,
    service_version: VERSION,
  )
end
