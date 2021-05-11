require "./helper"

require "placeos-driver/storage"
require "placeos-driver/subscriptions"
require "placeos-driver/proxy/subscriptions"
require "placeos-driver/proxy/remote_driver"

module PlaceOS::Triggers
  # Trigger state for the system
  mappings = Mapping.new

  # Start watching trigger table
  trigger_loader = Loader::Trigger.new(mappings)

  # Start watching trigger instance table
  instance_loader = Loader::TriggerInstance.new(mappings)

  Spec.after_suite do
    store = ::PlaceOS::Driver::RedisStorage.new("mod-1234")
    store.clear
  end

  describe "e2e" do
    it "creates a trigger, updates it and checks that exec works" do
      trigger = Model::Generator.trigger
      compare = Model::Trigger::Conditions::Comparison.new(
        left: true,
        operator: "and",
        right: {
          mod:    "Test_1",
          status: "state",
          keys:   ["on"],
        }
      )
      trigger.conditions.try &.comparisons = [compare]
      trigger.valid?.should be_true
      trigger.save!

      trigger_loader.process_resource(:created, trigger).success?.should be_true

      inst = Model::Generator.trigger_instance(trigger).save!

      instance_loader.process_resource(:created, inst)

      # create the status lookup structure
      sys_id = inst.control_system_id.not_nil!
      storage = PlaceOS::Driver::RedisStorage.new(sys_id, "system")
      storage["Test/1"] = "mod-1234"

      PlaceOS::Driver::Subscriptions.new_redis.publish "lookup-change", sys_id

      sleep 0.1

      # signal a change in lookup state
      redis = PlaceOS::Driver::RedisStorage.new_redis_client

      # Ensure the trigger hasn't fired
      state = mappings.with_instances &.[inst.id]
      state.triggered.should be_false

      store = PlaceOS::Driver::RedisStorage.new("mod-1234")
      store[:state] = {on: true}.to_json

      sleep 0.1

      # ensure the trigger has fired
      state.triggered.should be_true

      compare2 = Model::Trigger::Conditions::Comparison.new(
        left: "hello",
        operator: "equal",
        right: {
          mod:    "Test_1",
          status: "greeting",
          keys:   [] of String,
        }
      )

      trigger.conditions.try &.comparisons = [compare, compare2]
      trigger.conditions_will_change!
      trigger.save!

      trigger_loader.process_resource(:updated, trigger)

      sleep 0.1

      # The state is replaced with a new state on update
      state = mappings.with_instances &.[inst.id]
      state.triggered.should be_false
      store[:greeting] = "hello".to_json

      sleep 0.1

      state.triggered.should be_true

      func = Model::Trigger::Actions::Function.new(
        mod: "Test_1",
        method: "start"
      )

      # ensure module metadata exists
      meta = PlaceOS::Driver::DriverModel::Metadata.new({
        "start" => {} of String => Array(JSON::Any),
      }, ["Functoids"])
      redis.set("interface/mod-1234", meta.to_json)

      # mock out the exec request
      WebMock.stub(:post, "http://127.0.0.1:9001/api/core/v1/command/mod-1234/execute")
        .with(body: "{\"__exec__\":\"start\",\"start\":{}}")
        .to_return(body: "null")

      trigger.actions.try &.functions = [func]
      trigger.actions_will_change!
      trigger.save!

      trigger_loader.process_resource(:created, trigger).success?.should be_true

      # Check the state in redis
      inst_store = PlaceOS::Driver::RedisStorage.new(inst.id.not_nil!)
      status = JSON.parse(inst_store["state"])
      status["triggered"].as_bool.should be_true
      status["trigger_count"].as_i.should eq(1)
      status["action_errors"].as_i.should eq(0)
      status["comparison_errors"].as_i.should eq(0)
    end # it

    it "creates two triggers, updates them and checks they works" do
      system = Model::Generator.control_system.save!

      trigger = Model::Generator.trigger
      compare = Model::Trigger::Conditions::Comparison.new(
        left: true,
        operator: "and",
        right: {
          mod:    "Test_1",
          status: "state",
          keys:   ["on"],
        }
      )
      trigger.conditions.try &.comparisons = [compare]
      trigger.valid?.should be_true
      trigger.save!

      trigger_loader.process_resource(:created, trigger).success?.should be_true

      inst = Model::Generator.trigger_instance(trigger, control_system: system).save!
      inst2 = Model::Generator.trigger_instance(trigger, control_system: system).save!

      instance_loader.process_resource(:created, inst).success?.should be_true
      instance_loader.process_resource(:created, inst2).success?.should be_true

      # create the status lookup structure
      sys_id = system.id.not_nil!
      storage = PlaceOS::Driver::RedisStorage.new(sys_id, "system")
      storage["Test/1"] = "mod-1235"

      PlaceOS::Driver::Subscriptions.new_redis.publish "lookup-change", sys_id

      sleep 0.1

      # signal a change in lookup state
      redis = PlaceOS::Driver::RedisStorage.new_redis_client
      # Ensure the trigger hasn't fired
      state = mappings.with_instances &.[inst.id]
      state.triggered.should be_false

      state2 = mappings.with_instances &.[inst2.id]
      state2.triggered.should be_false

      store = PlaceOS::Driver::RedisStorage.new("mod-1235")
      store[:state] = {on: true}.to_json

      sleep 0.1

      # ensure the trigger has fired
      state.triggered.should be_true
      state2.triggered.should be_true

      compare2 = Model::Trigger::Conditions::Comparison.new(
        left: "hello",
        operator: "equal",
        right: {
          mod:    "Test_1",
          status: "greeting",
          keys:   [] of String,
        }
      )

      trigger.conditions.try &.comparisons = [compare, compare2]
      trigger.conditions_will_change!
      trigger.save!

      trigger_loader.process_resource(:updated, trigger).success?.should be_true

      sleep 0.1

      # The state is replaced with a new state on update
      state = mappings.with_instances &.[inst.id]
      state.triggered.should be_false

      state2 = mappings.with_instances &.[inst2.id]
      state2.triggered.should be_false
      store[:greeting] = "hello".to_json

      sleep 0.1

      state.triggered.should be_true
      state2.triggered.should be_true

      func = Model::Trigger::Actions::Function.new(
        mod: "Test_1",
        method: "start"
      )

      # ensure module metadata exists
      meta = PlaceOS::Driver::DriverModel::Metadata.new({
        "start" => {} of String => Array(JSON::Any),
      }, ["Functoids"])
      redis.set("interface/mod-1235", meta.to_json)

      # mock out the exec request
      WebMock.stub(:post, "http://127.0.0.1:9001/api/core/v1/command/mod-1235/execute")
        .with(body: "{\"__exec__\":\"start\",\"start\":{}}")
        .to_return(body: "null")

      trigger.actions.try &.functions = [func]
      trigger.actions_will_change!

      trigger_loader.process_resource(:updated, trigger).success?.should be_true

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
    end # it
  end   # describe
end     # module
