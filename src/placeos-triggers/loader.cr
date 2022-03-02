require "placeos-resource"
require "placeos-models/trigger"
require "placeos-models/trigger_instance"

require "./mapping"

module PlaceOS::Triggers
  class Loader(T) < Resource(T)
    getter mapping : Mapping

    def initialize(@mapping : Mapping, **args)
      super(**args)
    end

    def process_resource(action : Resource::Action, resource model : T) : Resource::Result
      case action
      in .created? then mapping.add(model)
      in .deleted? then mapping.remove(model)
      in .updated? then mapping.update(model)
      end

      Resource::Result::Success
    end

    class TriggerInstance < Loader(Model::TriggerInstance)
    end

    class Trigger < Loader(Model::Trigger)
    end
  end
end
