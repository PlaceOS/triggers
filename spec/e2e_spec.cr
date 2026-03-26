require "./helper"

require "placeos-driver/storage"
require "placeos-driver/subscriptions"
require "placeos-driver/proxy/subscriptions"
require "placeos-driver/proxy/remote_driver"

module PlaceOS::Triggers
  class_getter! module_id : String
  class_getter! store : Driver::RedisStorage

  Spec.before_each do
    @@module_id = "mod-#{Random::DEFAULT.hex(8)}"
    @@store = ::PlaceOS::Driver::RedisStorage.new(module_id)
  end

  Spec.after_each do
    store.clear
  end

  describe "e2e" do
    it "creates a trigger, updates it and checks that exec works" do
      # Trigger state for the system
      mappings = PlaceOS::Triggers.mapping

      trig_cf = Triggers.trigger_resource
      trigi_cf = Triggers.trigger_instance_resource
      mappings.clear
      clear_tables
      trig_cf.start
      trigi_cf.start

      sleep 100.milliseconds

      trigger = Model::Generator.trigger

      compare = Model::Trigger::Conditions::Comparison.new(
        left: true,
        operator: :and,
        right: Model::Trigger::Conditions::Comparison::StatusVariable.new(
          mod: "Test_1",
          status: "state",
          keys: ["on"],
        )
      )
      trigger.conditions.try &.comparisons = [compare]
      trigger.valid?.should be_true
      trigger.save!

      inst = Model::Generator.trigger_instance(trigger).save!

      # create the status lookup structure
      sys_id = inst.control_system_id.not_nil!
      storage = PlaceOS::Driver::RedisStorage.new(sys_id, "system")
      storage["Test/1"] = module_id

      PlaceOS::Driver::Subscriptions.new_redis.publish "lookup-change", sys_id

      # signal a change in lookup state
      redis = PlaceOS::Driver::RedisStorage.new_redis_client

      # Wait for state to be tracked
      wait_for { mappings.state_for?(inst) != nil }

      # Ensure the trigger hasn't fired
      state = mappings.state_for?(inst).not_nil!
      state.triggered?.should be_false

      store[:state] = {on: true}.to_json

      # ensure the trigger has fired
      wait_for { state.triggered? }

      compare2 = Model::Trigger::Conditions::Comparison.new(
        left: "hello",
        operator: :equal,
        right: Model::Trigger::Conditions::Comparison::StatusVariable.new(
          mod: "Test_1",
          status: "greeting",
          keys: [] of String,
        )
      )

      # Set greeting value before trigger update so new state picks it up
      # via current_value fetch (direct Redis read, not dependent on pub/sub)
      store[:greeting] = "hello".to_json

      trigger.conditions.try &.comparisons = [compare, compare2]
      trigger.conditions_will_change!
      trigger.update

      # Wait for the state to be replaced and both conditions to be met.
      # Re-signal values to handle pub/sub reconnection gaps.
      wait_for { mappings.state_for?(inst) != state }
      state = mappings.state_for?(inst).not_nil!

      wait_for do
        unless state.triggered?
          store.signal_status("state")
          store.signal_status("greeting")
        end
        state.triggered?
      end

      func = Model::Trigger::Actions::Function.new(
        mod: "Test_1",
        method: "start"
      )

      # ensure module metadata exists
      meta = PlaceOS::Driver::DriverModel::Metadata.new({
        "start" => {} of String => JSON::Any,
      }, ["Functoids"])
      redis.set("interface/#{module_id}", meta.to_json)

      # mock out the exec request
      WebMock.stub(:post, "http://127.0.0.1:9001/api/core/v1/command/#{module_id}/execute")
        .with(body: "{\"__exec__\":\"start\",\"start\":{}}")
        .to_return(body: "null")

      trigger.actions.try &.functions = [func]
      trigger.actions_will_change!
      trigger.update

      # Check the state in redis
      inst_store = PlaceOS::Driver::RedisStorage.new(inst.id.not_nil!)
      status = JSON.parse(inst_store["state"])
      status["triggered"].as_bool.should be_true
      status["trigger_count"].as_i.should eq(1)
      status["action_errors"].as_i.should eq(0)
      status["comparison_errors"].as_i.should eq(0)

      trig_cf.stop
      trigi_cf.stop
    end

    it "creates two triggers, updates them and checks they work" do
      # Trigger state for the system
      mappings = PlaceOS::Triggers.mapping
      trig_cf = Triggers.trigger_resource
      trigi_cf = Triggers.trigger_instance_resource
      mappings.clear
      clear_tables
      trig_cf.start
      trigi_cf.start

      sleep 100.milliseconds

      system = Model::Generator.control_system.save!

      trigger = Model::Generator.trigger
      compare = Model::Trigger::Conditions::Comparison.new(
        left: true,
        operator: :equal,
        right: Model::Trigger::Conditions::Comparison::StatusVariable.new(
          mod: "Test_1",
          status: "state",
          keys: ["on"],
        )
      )

      trigger.conditions.try &.comparisons = [compare]
      trigger.valid?.should be_true
      trigger.save!

      inst = Model::Generator.trigger_instance(trigger, control_system: system).save!
      inst2 = Model::Generator.trigger_instance(trigger, control_system: system).save!

      # create the status lookup structure
      sys_id = system.id.not_nil!
      storage = PlaceOS::Driver::RedisStorage.new(sys_id, "system")
      storage["Test/1"] = module_id

      PlaceOS::Driver::Subscriptions.new_redis.publish "lookup-change", sys_id

      # signal a change in lookup state
      redis = PlaceOS::Driver::RedisStorage.new_redis_client

      # Wait for states to be tracked
      wait_for { mappings.state_for?(inst) != nil && mappings.state_for?(inst2) != nil }

      # Ensure the trigger hasn't fired
      state = mappings.state_for?(inst).not_nil!
      state.triggered?.should be_false

      state2 = mappings.state_for?(inst2).not_nil!
      state2.triggered?.should be_false

      store[:state] = {on: true}.to_json

      # ensure the trigger has fired, re-signal to handle pub/sub gaps
      wait_for do
        store.signal_status("state") unless state.triggered? && state2.triggered?
        state.triggered? && state2.triggered?
      end

      compare2 = Model::Trigger::Conditions::Comparison.new(
        left: "hello",
        operator: :equal,
        right: Model::Trigger::Conditions::Comparison::StatusVariable.new(
          mod: "Test_1",
          status: "greeting",
          keys: [] of String,
        )
      )

      # Set greeting value before trigger update so new states pick it up
      # via current_value fetch (direct Redis read, not dependent on pub/sub)
      store[:greeting] = "hello".to_json

      trigger.conditions.try &.comparisons = [compare, compare2]
      trigger.conditions_will_change!
      trigger.update

      # Wait for the states to be replaced and both conditions to be met.
      # Re-signal values to handle pub/sub reconnection gaps.
      wait_for { mappings.state_for?(inst) != state && mappings.state_for?(inst2) != state2 }
      state = mappings.state_for?(inst).not_nil!
      state2 = mappings.state_for?(inst2).not_nil!

      wait_for do
        unless state.triggered? && state2.triggered?
          store.signal_status("state")
          store.signal_status("greeting")
        end
        state.triggered? && state2.triggered?
      end

      func = Model::Trigger::Actions::Function.new(
        mod: "Test_1",
        method: "start"
      )

      # ensure module metadata exists
      meta = PlaceOS::Driver::DriverModel::Metadata.new({
        "start" => {} of String => JSON::Any,
      }, ["Functoids"])
      redis.set("interface/#{module_id}", meta.to_json)

      # mock out the exec request
      WebMock.stub(:post, "http://127.0.0.1:9001/api/core/v1/command/#{module_id}/execute")
        .with(body: "{\"__exec__\":\"start\",\"start\":{}}")
        .to_return(body: "null")

      trigger.actions.try &.functions = [func]
      trigger.actions_will_change!

      sleep 100.milliseconds

      # Check the state in redis
      inst_store = PlaceOS::Driver::RedisStorage.new(inst.id.not_nil!)
      status = JSON.parse(inst_store["state"])

      status["triggered"].as_bool.should be_true
      status["trigger_count"].as_i.should eq(1)
      status["action_errors"].as_i.should eq(0)
      status["comparison_errors"].as_i.should eq(0)

      inst_store = PlaceOS::Driver::RedisStorage.new(inst2.id.not_nil!)

      status = JSON.parse(inst_store["state"])
      status["triggered"].as_bool.should be_true
      status["trigger_count"].as_i.should eq(1)
      status["action_errors"].as_i.should eq(0)
      status["comparison_errors"].as_i.should eq(0)

      trig_cf.stop
      trigi_cf.stop
    end

    it "does not fire disabled trigger instances" do
      # Trigger state for the system
      mappings = PlaceOS::Triggers.mapping

      trig_cf = Triggers.trigger_resource
      trigi_cf = Triggers.trigger_instance_resource
      mappings.clear
      clear_tables
      trig_cf.start
      trigi_cf.start

      sleep 100.milliseconds

      trigger = Model::Generator.trigger

      compare = Model::Trigger::Conditions::Comparison.new(
        left: true,
        operator: :and,
        right: Model::Trigger::Conditions::Comparison::StatusVariable.new(
          mod: "Test_1",
          status: "state",
          keys: ["on"],
        )
      )
      trigger.conditions.try &.comparisons = [compare]
      trigger.valid?.should be_true
      trigger.save!

      # Create a disabled trigger instance
      inst = Model::Generator.trigger_instance(trigger)
      inst.enabled = false
      inst.save!

      # create the status lookup structure
      sys_id = inst.control_system_id.not_nil!
      storage = PlaceOS::Driver::RedisStorage.new(sys_id, "system")
      storage["Test/1"] = module_id

      PlaceOS::Driver::Subscriptions.new_redis.publish "lookup-change", sys_id

      sleep 100.milliseconds

      # Disabled trigger instance should not be tracked
      state = mappings.state_for?(inst)
      state.should be_nil

      # Set the condition that would normally trigger
      store[:state] = {on: true}.to_json

      sleep 100.milliseconds

      # Should still not be tracked (no state object created)
      mappings.state_for?(inst).should be_nil

      # Now enable the trigger instance
      inst.enabled = true
      inst.save!

      # Now it should be tracked and triggered
      wait_for do
        s = mappings.state_for?(inst)
        s != nil && s.not_nil!.triggered?
      end
      mappings.state_for?(inst).should_not be_nil

      # Disable it again
      inst.enabled = false
      inst.save!

      # Should be removed from tracking
      wait_for { mappings.state_for?(inst) == nil }

      trig_cf.stop
      trigi_cf.stop
    end
  end
end
