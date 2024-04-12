require "placeos-models"
require "tasker"

module PlaceOS::Triggers
  class GraphSecretExpiryFinder
    Log = ::Log.for(self)

    def initialize(@repeat_interval : Time::Span)
    end

    def self.new(interval : String)
      new(Triggers.extract_time_span(interval))
    end

    def start
      Tasker.every(@repeat_interval) do
        Log.debug { "Finding list of tenants which are using office365 graph" }
        PlaceOS::Model::Tenant.where(platform: "office365", delegated: false, secret_expiry: nil).each do |tenant|
          Log.debug { {message: "Trying to retrieve graph secret expiry for tenant", tenant: tenant.name, domain: tenant.domain} }
          begin
            client = tenant.place_calendar_client
            if office = client.as?(::PlaceCalendar::Office365)
              expiry = office.client.secret_expiry
              if exp = expiry
                Log.debug { {message: "Secret expiry information retrieved.", expiry: exp.to_unix} }
                tenant.update(secret_expiry: exp)
              end
            else
              Log.warn { {message: "Returned calendar client is not an Office365 client", domain: tenant.domain, place_calendar_client: client.class.to_s} }
            end
          rescue ex
            Log.error(exception: ex) { "Exception received" }
          end
        end
      end
    end
  end
end
