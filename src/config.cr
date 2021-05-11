require "./logging"

# PlaceOS::Triggerslication dependencies
require "email"
require "active-model"
require "action-controller"

# Required to convince Crystal this file is not a module
abstract class PlaceOS::Driver; end

class PlaceOS::Driver::Protocol; end

# PlaceOS::Trigger application code
require "./constants"
require "./controllers/application"
require "./controllers/*"
require "./placeos-triggers"

# Server required after application controllers
require "action-controller/server"

# Filter out sensitive params that shouldn't be logged
filter_params = ["password", "bearer_token"]
keeps_headers = ["X-Request-ID"]

# Add handlers that should run before your application
ActionController::Server.before(
  ActionController::ErrorHandler.new(PlaceOS::Triggers.production?, keeps_headers),
  Raven::ActionController::ErrorHandler.new,
  ActionController::LogHandler.new(filter_params, ms: true),
)

# Set SMTP client configuration
SMTP_CONFIG = EMail::Client::Config.new(
  PlaceOS::Triggers::SMTP_SERVER,
  PlaceOS::Triggers::SMTP_PORT
)

SMTP_CONFIG.use_auth(PlaceOS::Triggers::SMTP_USER, PlaceOS::Triggers::SMTP_PASS) if PlaceOS::Triggers.smtp_authenticated?

case PlaceOS::Triggers::SMTP_SECURE
when "SMTPS"
  SMTP_CONFIG.use_tls(EMail::Client::TLSMode::SMTPS)
  SMTP_CONFIG.tls_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
when "STARTTLS"
  SMTP_CONFIG.use_tls(EMail::Client::TLSMode::STARTTLS)
  SMTP_CONFIG.tls_context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
when ""
else
  raise "unknown SMTP_SECURE setting: #{PlaceOS::Triggers::SMTP_SECURE.inspect}"
end
