require "placeos-models/trigger"
require "placeos-resource"

module PlaceOS::Triggers::Loader
  class Trigger < Resource(Model::Trigger)
    getter mapping : Mapping

    def initialize(@mapping, **args)
      super(**args)
    end

    def process_resource(action : Resource::Action, resource trigger : Model::Trigger) : Resource::Result
      case action
      in .created? then mapping.new_trigger(trigger)
      in .deleted? then mapping.remove_trigger(trigger)
      in .updated? then mapping.update_trigger(trigger)
      end

      Resource::Result::Success
    end
  end
end
