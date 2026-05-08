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

    def loaded_count
      mapping_lock.synchronize { trigger_instance_state.size }
    end

    RECONCILE_BATCH_SIZE = 200

    # Reconcile loaded trigger instances against the database.
    # Any enabled instances missing from the mapping are loaded; any loaded
    # instances no longer enabled are removed.
    #
    # Walks the enabled set in created_at order one batch at a time so the
    # set of loaded ids we hold in memory is the only working set, and it
    # only ever shrinks: ids the DB confirms as enabled are removed as we
    # see them, ids missing from the mapping are loaded inline, and anything
    # left at the end is stale and torn down.
    def reconcile : Nil
      mapping_lock.synchronize do
        expected = Model::TriggerInstance.where(enabled: true).count
        loaded = trigger_instance_state.size
        return if expected == loaded

        loaded_ids = trigger_instance_state.keys.to_set
        initial_loaded = loaded_ids.size
        missing_count = 0

        last_created_at = nil.as(Time?)
        last_id = nil.as(String?)

        loop do
          query = Model::TriggerInstance.where(enabled: true)
          if last_created_at && last_id
            # composite cursor (created_at, id) keeps pagination stable when
            # multiple records share a created_at value
            query = query.where(
              "(created_at, id) > (?, ?)",
              last_created_at, last_id
            )
          end

          page = query.order(:created_at, :id).limit(RECONCILE_BATCH_SIZE).to_a
          page.each do |instance|
            id = instance.id.as(String)
            last_created_at = instance.created_at
            last_id = id

            # if it's already loaded, drop it from the working set; if not,
            # load it now using the record we just fetched
            unless loaded_ids.delete(id)
              begin
                Log.info { "reconciliation loading missing instance #{id}" }
                add_instance(instance)
                missing_count += 1
              rescue error
                Log.error(exception: error) { "reconciliation failed to load instance #{id}" }
              end
            end
          end

          break if page.size < RECONCILE_BATCH_SIZE
        end

        # Anything still in loaded_ids was not in the enabled set: stale
        extra_count = loaded_ids.size
        loaded_ids.each do |id|
          Log.info { "reconciliation removing extra instance #{id}" }
          trigger_instance_state.delete(id).try do |state|
            trigger_state[state.instance.trigger_id]?.try &.delete(state)
            state.terminate!
          end
        end

        if missing_count > 0 || extra_count > 0
          Log.warn { "reconciliation: loaded #{missing_count} missing, removed #{extra_count} extra (was #{initial_loaded}, now #{trigger_instance_state.size})" }
        else
          Log.info { "reconciliation: no changes (#{initial_loaded} instances loaded)" }
        end
      end
    rescue error
      Log.error(exception: error) { "failed to reconcile loaded triggers" }
    end
  end
end
