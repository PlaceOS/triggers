require "secrets-env"
require "spec"
require "base64"
require "random"
require "webmock"
require "pg-orm"

require "action-controller/spec_helper"

require "placeos-models/spec/generator"
require "../src/constants.cr"
require "placeos-models/version"

# Prepare for node discovery
WebMock.stub(:post, "http://127.0.0.1:2379/v3beta/kv/range")
  .with(body: "{\"key\":\"c2VydmljZS9jb3JlLw==\",\"range_end\":\"c2VydmljZS9jb3JlMA==\"}", headers: {"Content-Type" => "application/json"})
  .to_return(body: {
    count: "1",
    kvs:   [{
      key:   "c2VydmljZS9jb3JlLw==",
      value: Base64.strict_encode("http://127.0.0.1:9001"),
    }],
  }.to_json)

# We'll let the watch request hang
WebMock.stub(:post, "http://127.0.0.1:2379/v3beta/watch")
  .with(body: "{\"create_request\":{\"key\":\"c2VydmljZS9jb3Jl\",\"range_end\":\"c2VydmljZS9jb3Jm\"}}", headers: {"Content-Type" => "application/json"})
  .to_return(body_io: IO::Stapled.new(*IO.pipe))

require "../src/config"

Spec.before_suite do
  PgORM::Database.configure { |_| }
  Log.setup "*", :info, PlaceOS::LogBackend.log_backend
  clear_tables
end

Spec.before_each &->WebMock.reset

Spec.after_suite { clear_tables }

def clear_tables
  {% begin %}
    Promise.all(
      {% for t in {
                    PlaceOS::Model::ControlSystem,
                    PlaceOS::Model::Trigger,
                    PlaceOS::Model::TriggerInstance,
                  } %}
        Promise.defer { {{t.id}}.clear },
      {% end %}
    ).get
  {% end %}
end

module PlaceOS::Api::SpecClient
  # Can't use ivars at top level, hence this hack
  private CLIENT = ActionController::SpecHelper.client

  def client
    CLIENT
  end
end

include PlaceOS::Api::SpecClient
