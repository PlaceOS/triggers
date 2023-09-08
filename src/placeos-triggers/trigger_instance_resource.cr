require "placeos-resource"
require "placeos-models"

class PlaceOS::Triggers::TriggerInstanceResource < PlaceOS::Resource(PlaceOS::Model::TriggerInstance)
  def process_resource(action : Action, resource instance : Model::TriggerInstance) : Result
    mapping = PlaceOS::Triggers.mapping

    Log.info { "Instance Change: #{action} => #{instance.id}" }

    case action
    in .created? then mapping.add(instance)
    in .deleted? then mapping.remove(instance)
    in .updated? then mapping.update(instance)
    end

    Result::Success
  end
end
