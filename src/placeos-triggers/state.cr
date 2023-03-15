require "hound-dog"
require "json"
require "tasker"

require "placeos-models"
require "placeos-driver/proxy/remote_driver"
require "placeos-driver/proxy/subscriptions"
require "placeos-driver/storage"
require "placeos-driver/subscriptions"

# NOTE: Webhooks should allow drivers to process and provide responses

module PlaceOS::Triggers
  class State
    Log = ::Log.for(self)

    @@subscriber = PlaceOS::Driver::Subscriptions.new

    @terminated : Bool = false
    @comparison_errors : Int64 = 0_i64
    @action_errors : Int64 = 0_i64

    getter count : Int64 = 0_i64
    getter triggered : Bool = false

    getter trigger : Model::Trigger
    getter instance : Model::TriggerInstance
    getter trigger_id : String { trigger.id }
    getter instance_id : String { instance.id.not_nil! }

    private getter debounce_period : Time::Span do
      trigger.debounce_period ? trigger.debounce_period.milliseconds : 59.seconds
    end

    private getter conditions_met = {} of String => Bool
    private getter condition_timers = [] of Tasker::Task
    private getter debounce_timers = {} of String => Tasker::Task
    private getter comparisons = [] of Comparison

    private getter subscriptions : Driver::Proxy::Subscriptions { PlaceOS::Driver::Proxy::Subscriptions.new(@@subscriber) }

    private getter storage : Driver::RedisStorage do
      # Fresh state for the trigger instance
      PlaceOS::Driver::RedisStorage.new(instance_id).tap &.clear
    end

    def initialize(@trigger : Model::Trigger, @instance : Model::TriggerInstance)
      conditions_met["webhook"] = false if trigger.enable_webhook

      # Set the initial state of the trigger instance
      publish_state

      # New thread!
      spawn { monitor! }
    end

    def terminate!
      @terminated = true

      # Cancel timers
      condition_timers.each(&.cancel)
      debounce_timers.each_value(&.cancel)
      condition_timers.clear
      debounce_timers.clear

      # Cancel subscriptions
      subscriptions.terminate
    end

    def monitor!
      return if @terminated

      # Build the time triggers
      trigger.conditions.time_dependents.each_with_index do |time, index|
        condition_key = "time_#{index}"
        conditions_met[condition_key] = false

        case time.type
        in .at?   then time_at(condition_key, time.time)
        in .cron? then time_cron(condition_key, time.cron, time.timezone)
        end
      end

      # Monitor status values to track conditions
      system_id = instance.control_system_id.not_nil!
      trigger.conditions.comparisons.each_with_index do |comparison, index|
        condition_key = "comparison_#{index}"
        conditions_met[condition_key] = false

        self.comparisons << Comparison.new(
          self,
          condition_key,
          system_id,
          comparison.left,
          comparison.operator,
          comparison.right
        )
      end

      self.comparisons.each(&.bind!(subscriptions))
    rescue error
      Log.error(exception: error) { {
        system_id: instance.control_system_id,
        trigger:   instance.trigger_id,
        instance:  instance.id,
        message:   "failed to initialize trigger instance '#{trigger.name}'",
      } }
    end

    def set_condition(key : String, state : Bool)
      conditions_met[key] = state
      check_trigger!
    end

    def check_trigger!
      update_state !conditions_met.values.includes?(false)
    end

    def increment_action_error
      begin
        @action_errors += 1
      rescue OverflowError
        @action_errors = 1
      end
      publish_state
    end

    def increment_comparison_error
      begin
        @comparison_errors += 1
      rescue OverflowError
        @comparison_errors = 1
      end
      publish_state
    end

    def publish_state
      state = {
        triggered:         triggered,
        trigger_count:     count,
        action_errors:     @action_errors,
        comparison_errors: @comparison_errors,
        conditions:        conditions_met,
      }

      Log.debug { state.merge(message: "publishing trigger instance state", trigger_instance_id: instance_id) }

      storage["state"] = state.to_json
    end

    def update_state(triggered : Bool)
      # Check if there was change
      return if triggered == @triggered

      if triggered
        begin
          @count += 1
        rescue OverflowError
          @count = 0_i64
        end
      end

      @triggered = triggered

      publish_state

      Log.info { {
        system_id: instance.control_system_id,
        trigger:   instance.trigger_id,
        instance:  instance.id,
        message:   "state changed to #{triggered}",
      } }

      # Check if we should run the actions
      return unless triggered

      system_id = instance.control_system_id.not_nil!

      # Perform actions
      trigger.actions.functions.each_with_index do |action, function_index|
        modname, index = PlaceOS::Driver::Proxy::RemoteDriver.get_parts(action.mod)
        request_id = "action_#{function_index}_#{Time.utc.to_unix_ms}"

        Log.debug { {
          system_id:  system_id,
          module:     modname,
          index:      index.to_s,
          method:     action.method,
          request_id: request_id,
          trigger:    instance.trigger_id,
          instance:   instance.id,
          message:    "performing exec for trigger '#{trigger.name}'",
        } }

        begin
          PlaceOS::Driver::Proxy::RemoteDriver.new(
            system_id,
            modname,
            index,
            PlaceOS::Triggers.discovery
          ) { |module_id|
            Model::Module.find!(module_id).edge_id.as(String)
          }.exec(
            PlaceOS::Driver::Proxy::RemoteDriver::Clearance::Admin,
            action.method,
            named_args: action.args,
            request_id: request_id
          )
        rescue error
          Log.error(exception: error) { {
            system_id:  system_id,
            module:     modname,
            index:      index,
            method:     action.method,
            request_id: request_id,
            trigger:    instance.trigger_id,
            instance:   instance.id,
            message:    "exec failed for trigger '#{trigger.name}'",
          } }
          increment_action_error
        end
      end

      unless trigger.actions.mailers.empty?
        Log.debug { {
          system_id: instance.control_system_id,
          trigger:   instance.trigger_id,
          instance:  instance.id,
          message:   "sending email for trigger '#{trigger.name}'",
        } }

        begin
          # Create SMTP client object
          client = EMail::Client.new(::SMTP_CONFIG)
          client.start do
            trigger.actions.mailers.each do |mail|
              mail.emails.each do |address|
                # TODO:: Complete subject and from addresses
                email = EMail::Message.new
                email.from "triggers@example.com"
                email.to address
                email.subject "triggered"
                email.message mail.content

                send(email)
              end
            end
          end
        rescue error
          Log.error(exception: error) { {
            system_id: instance.control_system_id,
            trigger:   instance.trigger_id,
            instance:  instance.id,
            message:   "email send failed for trigger '#{trigger.name}'",
          } }
          increment_action_error
        end
      end
    end

    def time_at(key, time)
      condition_timers << Tasker.at(time.not_nil!) { temporary_condition_met(key) }
    end

    def time_cron(key, cron, timezone)
      location = timezone ? Time::Location.load(timezone) : Time::Location.local
      condition_timers << Tasker.cron(cron.not_nil!, location) { temporary_condition_met(key) }
    end

    def temporary_condition_met(key : String)
      # Cancel old debounce timer
      debounce_timers.delete(key).try &.cancel

      # Revert the status of this condition
      debounce_timers[key] = Tasker.in(debounce_period) do
        debounce_timers.delete key
        conditions_met[key] = false
        update_state(false)
      end

      # Update status of this condition
      conditions_met[key] = true

      check_trigger!
    end
  end
end

require "./state/comparison"
