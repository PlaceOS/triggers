require "placeos-resource"
require "placeos-models/trigger_instance"

require "../mapping"

module PlaceOS::Triggers::Loader
  class TriggerInstance < Resource(Model::TriggerInstance)
    getter mapping : Mapping

    def initialize(@mapping : Mapping, **args)
      super(**args)
    end

    def process_resource(action : Resource::Action, resource trigger_instance : Model::TriggerInstance) : Resource::Result
      case action
      in .deleted?
        mapping.remove_instance(trigger_instance)
      in .created?
        mapping.new_instance(trigger_instance)
      in .updated?
        mapping.remove_instance(trigger_instance)
        mapping.new_instance(trigger_instance)
      end

      Resource::Result::Success
    end
  end
end
