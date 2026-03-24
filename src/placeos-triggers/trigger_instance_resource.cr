require "placeos-resource"
require "placeos-models"

class PlaceOS::Triggers::TriggerInstanceResource < PlaceOS::Resource(PlaceOS::Model::TriggerInstance)
  def process_resource(action : Action, resource instance : Model::TriggerInstance) : Result
    mapping = PlaceOS::Triggers.mapping

    Log.info { "Instance Change: #{action} => #{instance.id}" }

    case action
    in .created?
      # Only add enabled instances
      mapping.add(instance) if instance.enabled
    in .deleted?
      mapping.remove(instance)
    in .updated?
      if instance.enabled
        # If enabled, update or add if not already tracked
        mapping.update(instance)
      else
        # If disabled, remove from tracking
        mapping.remove(instance)
      end
    end

    Result::Success
  end
end
