require "./state"

module PlaceOS::Triggers
  class Mapping
    private getter mapping_lock = Mutex.new(protection: :reentrant)

    private getter trigger_cache = {} of String => Model::Trigger
    private getter trigger_state = Hash(String, Array(State)).new { |hash, key| hash[key] = [] of State }
    private getter trigger_instance_state = {} of String => State

    def state_for?(trigger_instance : Model::TriggerInstance)
      trigger_instance_state[trigger_instance.id.as(String)]?
    end

    # Instances
    ###############################################################################################

    def new_instance(instance : Model::TriggerInstance)
      mapping_lock.synchronize do
        trigger_id = instance.trigger_id.as(String)
        trigger = trigger_cache[trigger_id]?

        if trigger.nil?
          trigger = instance.trigger.not_nil!
          trigger_cache[trigger_id] = trigger
        end

        new_instance(trigger, instance)
      end
    end

    def new_instance(trigger : Model::Trigger, instance : Model::TriggerInstance)
      mapping_lock.synchronize do
        State.new(trigger, instance).tap do |state|
          self.trigger_instance_state[instance.id.as(String)] = state
          self.trigger_state[trigger.id.as(String)] << state
        end
      end
    end

    def update_instance(instance : Model::TriggerInstance)
      mapping_lock.synchronize do
        remove_instance(instance)
        new_instance(instance)
      end
    end

    def remove_instance(instance : Model::TriggerInstance)
      mapping_lock.synchronize do
        trigger_instance_state.delete(instance.id).try do |state|
          self.trigger_state[instance.trigger_id]?.try &.delete(state)
          state.terminate!
        end
      end
    end

    # Triggers
    ###############################################################################################

    def new_trigger(trigger : Model::Trigger)
      mapping_lock.synchronize do
        trigger_cache[trigger.id.as(String)] = trigger
      end
    end

    def update_trigger(trigger : Model::Trigger)
      trigger_id = trigger.id.as(String)
      mapping_lock.synchronize do
        self.trigger_cache[trigger_id] = trigger
        self.trigger_state.delete(trigger_id).try &.each do |state|
          instance = state.instance
          self.trigger_instance_state.delete(instance.id)
          state.terminate!

          new_instance(trigger, instance)
        end
      end
    end

    def remove_trigger(trigger : Model::Trigger)
      trigger_id = trigger.id.as(String)
      mapping_lock.synchronize do
        self.trigger_cache.delete trigger_id
        self.trigger_state.delete(trigger_id).try &.each do |state|
          self.trigger_instance_state.delete state.instance_id
          state.terminate!
        end
      end
    end
  end
end
