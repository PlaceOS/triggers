require "placeos-resource"
require "placeos-models"

class PlaceOS::Triggers::TriggerResource < PlaceOS::Resource(PlaceOS::Model::Trigger)
  def process_resource(action : Action, resource trigger : Model::Trigger) : Result
    mapping = PlaceOS::Triggers.mapping

    Log.info { "Trigger Change: #{action} => #{trigger.id}" }

    case action
    in .created? then mapping.add(trigger)
    in .deleted? then mapping.remove(trigger)
    in .updated? then mapping.update(trigger)
    end

    Result::Success
  end
end
