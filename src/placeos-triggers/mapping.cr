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

    {% for verb in %w(add update remove) %}
      def {{ verb.id }}(model : Model::TriggerInstance | Model::Trigger)
        mapping_lock.synchronize do
          case model
          in Model::TriggerInstance then {{ verb.id }}_instance(model)
          in Model::Trigger         then {{ verb.id }}_trigger(model)
          end
        end
      end
    {% end %}

    # TriggerInstances
    ###############################################################################################

    protected def add_instance(instance : Model::TriggerInstance)
      trigger_id = instance.trigger_id.as(String)
      trigger = trigger_cache[trigger_id]?

      if trigger.nil?
        trigger = trigger_cache[trigger_id] = instance.trigger
      end

      add_instance(trigger, instance)
    end

    protected def add_instance(trigger : Model::Trigger, instance : Model::TriggerInstance)
      State.new(trigger, instance).tap do |state|
        self.trigger_instance_state[instance.id.as(String)] = state
        self.trigger_state[trigger.id.as(String)] << state
      end
    end

    protected def update_instance(instance : Model::TriggerInstance)
      remove_instance(instance)
      add_instance(instance)
    end

    protected def remove_instance(instance : Model::TriggerInstance)
      trigger_instance_state.delete(instance.id).try do |state|
        self.trigger_state[instance.trigger_id]?.try &.delete(state)
        state.terminate!
      end
    end

    # Triggers
    ###############################################################################################

    protected def add_trigger(trigger : Model::Trigger)
      trigger_cache[trigger.id.as(String)] = trigger
    end

    protected def update_trigger(trigger : Model::Trigger)
      trigger_id = trigger.id.as(String)
      self.trigger_cache[trigger_id] = trigger
      self.trigger_state.delete(trigger_id).try &.each do |state|
        instance = state.instance
        self.trigger_instance_state.delete(instance.id)
        state.terminate!

        add_instance(trigger, instance)
      end
    end

    protected def remove_trigger(trigger : Model::Trigger)
      trigger_id = trigger.id.as(String)
      self.trigger_cache.delete trigger_id
      self.trigger_state.delete(trigger_id).try &.each do |state|
        self.trigger_instance_state.delete state.instance_id
        state.terminate!
      end
    end
  end
end
