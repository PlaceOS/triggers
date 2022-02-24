require "placeos-pulse"
require "placeos-models/api_key"

require "./constants"
require "./placeos-triggers/*"

module PlaceOS::Triggers
  class_getter mapping = Mapping.new

  class_getter pulse : Pulse::Client? do
    unless pulse_enabled?
      Log.info { "telemetry disabled as PLACE_PULSE_ENABLED is not enabled in environment" }
      return
    end

    unless domain = PLACE_DOMAIN
      Log.info { "telemetry disabled as PLACE_DOMAIN is not in environment" }
      return
    end

    unless email = PLACE_PULSE_INSTANCE_EMAIL
      Log.info { "telemetry disabled as PLACE_PULSE_INSTANCE_EMAIL is not in environment" }
      return
    end

    if Pulse.saas?
      instance_api_key = begin
        Model::ApiKey.saas_api_key(
          instance_domain: domain,
          instance_email: email,
        )
      rescue error : Model::Error::InvalidSaasKey
        Log.error(exception: error) { "failed to fetch the saas key for the instance" }
        raise error
      end
    else
      instance_api_key = nil
    end

    # Generate pulse client
    Pulse.from_environment(
      instance_api_key,
    )
  end

  def self.start_pulse : Nil
    if client = pulse
      client.start
    else
      Log.info { "pulse telemetry is not enabled for this instance" }
    end
  end
end
