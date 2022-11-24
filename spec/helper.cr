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
  # Triggers code
  Log.setup "*", :info, PlaceOS::LogBackend.log_backend
  # We are creating them here for specs only. In normal cases, these
  # model tables should have been created by init container or some other mechanism
  PgORM::Database.connection do |db|
    db.exec <<-SQL
      DROP TABLE IF EXISTS "trigger"
    SQL
    db.exec <<-SQL
      DROP TABLE IF EXISTS "sys"
    SQL
    db.exec <<-SQL
      DROP TABLE IF EXISTS "trig"
    SQL

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS "trigger"(
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        actions JSONB NOT NULL,
        conditions JSONB NOT NULL,
        debounce_period INTEGER NOT NULL,
        important BOOLEAN NOT NULL,
        enable_webhook BOOLEAN NOT NULL,
        supported_methods TEXT[] NOT NULL,
        control_system_id TEXT,
        id TEXT NOT NULL PRIMARY KEY
      );
    SQL
    db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS "sys"(
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      features TEXT[] NOT NULL,
      email JSONB,
      bookable BOOLEAN NOT NULL,
      display_name TEXT,
      code TEXT,
      type TEXT,
      capacity INTEGER NOT NULL,
      map_id TEXT,
      images TEXT[] NOT NULL,
      timezone TEXT,
      support_url TEXT NOT NULL,
      version INTEGER NOT NULL,
      installed_ui_devices INTEGER NOT NULL,
      zones TEXT[] NOT NULL,
      modules TEXT[] NOT NULL,
      id TEXT NOT NULL PRIMARY KEY
    );
    SQL
    db.exec <<-SQL
    CREATE TABLE IF NOT EXISTS "trig"(
      created_at TIMESTAMPTZ NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      enabled BOOLEAN NOT NULL,
      triggered BOOLEAN NOT NULL,
      important BOOLEAN NOT NULL,
      exec_enabled BOOLEAN NOT NULL,
      webhook_secret TEXT NOT NULL,
      trigger_count INTEGER NOT NULL,
      control_system_id TEXT,
      trigger_id TEXT,
      zone_id TEXT,
      id TEXT NOT NULL PRIMARY KEY
    );
    SQL
  end
end

Spec.before_each &->WebMock.reset

# Clear test tables on exit
Spec.after_suite do
  PgORM::Database.connection do |db|
    db.exec <<-SQL
      DROP TABLE IF EXISTS "trigger"
    SQL
    db.exec <<-SQL
      DROP TABLE IF EXISTS "sys"
    SQL
    db.exec <<-SQL
      DROP TABLE IF EXISTS "trig"
    SQL
  end
end

def listen_for_changes(changefeed, mapping)
  spawn do
    changefeed.each do |change|
      model = change.value
      case change.event
      in .created? then mapping.add(model)
      in .deleted? then mapping.remove(model)
      in .updated? then mapping.update(model)
      end
    end
  end
end

module PlaceOS::Api::SpecClient
  # Can't use ivars at top level, hence this hack
  private CLIENT = ActionController::SpecHelper.client

  def client
    CLIENT
  end
end

include PlaceOS::Api::SpecClient
