require "placeos-models/trigger"
require "placeos-resource"

module PlaceOS::Triggers::Loader
  class Trigger < Resource(Model::Trigger)
    getter mapping : Mapping

    def initialize(@mapping, **args)
      super(**args)
    end

    def process_resource(action : Resource::Action, resource trigger : Model::Trigger) : Resource::Result
      trigger_id = trigger.id.as(String)
      case action
      in .deleted?
        mapping.delete_trigger(trigger_id)
      in .created?
        mapping.with_cache do |cache|
          cache[trigger_id] = trigger
        end
      in .updated?
        mapping.update_trigger(trigger)
      end

      Resource::Result::Success
    end
  end
end
