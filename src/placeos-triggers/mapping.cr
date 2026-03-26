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

    # Terminate all tracked states and clear all caches
    def clear : Nil
      mapping_lock.synchronize do
        trigger_instance_state.each_value(&.terminate!)
        trigger_instance_state.clear
        trigger_state.clear
        trigger_cache.clear
      end
    end

    {% for verb in %w(add update remove) %}
      def {{ verb.id }}(model : Model::Trigger)
        mapping_lock.synchronize { {{ verb.id }}_trigger(model) }
      end

      def {{ verb.id }}(model : Model::TriggerInstance)
        mapping_lock.synchronize { {{ verb.id }}_instance(model) }
      end
    {% end %}

    # TriggerInstances
    ###############################################################################################

    protected def add_instance(instance : Model::TriggerInstance)
      trigger_id = instance.trigger_id.as(String)
      trigger = trigger_cache[trigger_id]?

      if trigger.nil?
        trigger = trigger_cache[trigger_id] = instance.trigger.not_nil!
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

    # Reconcile loaded trigger instances against the database.
    # Any enabled instances missing from the mapping are loaded.
    def reconcile : Nil
      mapping_lock.synchronize do
        expected_ids = Model::TriggerInstance.where(enabled: true).ids.map(&.as(String)).to_set
        loaded_ids = trigger_instance_state.keys.to_set

        missing = expected_ids - loaded_ids
        extra = loaded_ids - expected_ids

        if missing.empty? && extra.empty?
          Log.info { "startup reconciliation: all #{expected_ids.size} enabled trigger instances loaded" }
          return
        end

        Log.warn { "startup reconciliation: #{missing.size} missing, #{extra.size} extra instances detected" }

        # Remove instances that are no longer enabled
        extra.each do |id|
          Log.info { "reconciliation removing extra instance #{id}" }
          trigger_instance_state.delete(id).try do |state|
            trigger_state[state.instance.trigger_id]?.try &.delete(state)
            state.terminate!
          end
        end

        # Load missing instances
        missing.each do |id|
          begin
            instance = Model::TriggerInstance.find!(id)
            next unless instance.enabled
            Log.info { "reconciliation loading missing instance #{id}" }
            add_instance(instance)
          rescue error
            Log.error(exception: error) { "reconciliation failed to load instance #{id}" }
          end
        end

        Log.info { "startup reconciliation complete: #{trigger_instance_state.size} instances now loaded" }
      end
    end
  end
end
