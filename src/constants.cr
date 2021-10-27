require "secrets-env"
require "hound-dog"

module PlaceOS::Triggers
  APP_NAME = "triggers"
  VERSION  = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

  Log         = ::Log.for(self)
  ENVIRONMENT = ENV["SG_ENV"]?.presence || "development"

  BUILD_TIME   = {{ system("date -u").stringify.chomp }}
  BUILD_COMMIT = {{ env("PLACE_COMMIT") || "DEV" }}

  DEFAULT_PORT          = (ENV["SG_SERVER_PORT"]? || 3000).to_i
  DEFAULT_HOST          = ENV["SG_SERVER_HOST"]? || "127.0.0.1"
  DEFAULT_PROCESS_COUNT = (ENV["SG_PROCESS_COUNT"]? || 1).to_i

  SMTP_SERVER = ENV["SMTP_SERVER"]? || "smtp.example.com"
  SMTP_PORT   = (ENV["SMTP_PORT"]? || 25).to_i
  SMTP_USER   = ENV["SMTP_USER"]? || ""
  SMTP_PASS   = ENV["SMTP_PASS"]? || ""
  SMTP_SECURE = ENV["SMTP_SECURE"]? || ""

  PULSE_ENABLED              = self.boolean_environment("PLACE_PULSE_ENABLED")
  PLACE_DOMAIN               = ENV["PLACE_DOMAIN"]?.presence
  PLACE_PULSE_INSTANCE_EMAIL = ENV["PLACE_PULSE_INSTANCE_EMAIL"]?.presence

  # HoundDog Configuration.
  # ----------------------------------
  # ETCD_HOST (default: "127.0.0.1")
  # ETCD_PORT (default: 2379)
  # ETCD_TTL  (default: 15)

  CORE_NAMESPACE = "core"

  class_getter discovery : HoundDog::Discovery { HoundDog::Discovery.new(CORE_NAMESPACE) }
  class_getter? production : Bool = ENVIRONMENT.downcase == "production"
  class_getter? pulse_enabled : Bool = PULSE_ENABLED
  class_getter? smtp_authenticated : Bool = !SMTP_USER.empty?

  def self.boolean_environment(key) : Bool
    !!ENV[key]?.presence.try(&.downcase.in?("1", "true"))
  end
end
