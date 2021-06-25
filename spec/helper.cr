require "secrets-env"
require "spec"
require "base64"
require "random"
require "webmock"
require "rethinkdb-orm"

require "placeos-models/spec/generator"
require "../lib/action-controller/spec/curl_context"
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

# Configure DB
db_name = "test"

Spec.before_suite do
  # Triggers code
  Log.setup "*", :trace, PlaceOS::LogBackend.log_backend

  RethinkORM.configure do |settings|
    settings.db = db_name
  end
end

# Clear test tables on exit
Spec.after_suite do
  RethinkORM::Connection.raw do |q|
    q.db(db_name).table_list.for_each do |t|
      q.db(db_name).table(t).delete
    end
  end
end
