require "simple_retry"
require "placeos-pulse"
require "placeos-models/api_key"

require "./constants"
require "./placeos-triggers/*"

module PlaceOS::Triggers
  class_getter mapping = Mapping.new
  class_getter trigger_resource = TriggerResource.new
  class_getter trigger_instance_resource = TriggerInstanceResource.new

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

    instance_api_key = if Pulse.saas?
                         begin
                           Model::ApiKey.saas_api_key(
                             instance_domain: domain,
                             instance_email: email,
                           )
                         rescue error : Model::Error::InvalidSaasKey
                           Log.error(exception: error) { "failed to fetch the saas key for the instance" }
                           raise error
                         end
                       else
                         nil
                       end

    # Generate pulse client
    Pulse.from_environment(instance_api_key)
  end

  def self.start_pulse : Nil
    if client = pulse
      spawn do
        SimpleRetry.try_to(
          retry_on: PlaceOS::Pulse::Error,
          base_interval: 5.minutes,
          max_interval: 1.hour
        ) do |run_count, last_error|
          if last_error
            Log.warn(exception: last_error) { "error starting pulse client. Retry no.#{run_count}" }
          end
          client.start
        end
      end
    else
      Log.info { "pulse telemetry is not enabled for this instance" }
    end
  end
end
