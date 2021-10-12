require "placeos-pulse"

require "./constants"
require "./placeos-triggers/*"

module PlaceOS::Triggers
  class_getter mapping = Mapping.new

  class_getter pulse : Pulse::Client do
    Pulse.from_environment
  end

  def self.start_pulse : Nil
    if pulse_enabled?
      pulse.start
    else
      Log.info { "pulse is not enabled for this instance" }
    end
  end
end
