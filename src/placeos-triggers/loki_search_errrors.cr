require "time"
require "placeos-models"
require "tasker"
require "loki-client"

module PlaceOS::Triggers
  class LokiSearchForErrors
    Log = ::Log.for(self)

    def initialize(@repeat_interval : Time::Span)
      @client = Loki::Client.from_env
    end

    def self.new(interval : String)
      new(Triggers.extract_time_span(interval))
    end

    def start
      labels = @client.list_labels.data
      stream = labels.try &.includes?("container") ? "container" : "app"
      query = %({#{stream}="core"} |~ "mod-*" |~ "(?i)exception" | level =~ "ERROR|[E]")

      Tasker.every(@repeat_interval) do
        Log.debug { "Searching Loki for runtime error logs of all running modules" }
        PlaceOS::Model::Module.where(running: true).each do |mod|
          Log.debug { {message: "Searching Loki for module errors", module: mod.id, driver: mod.driver_id} }
          begin
            errors = Array(Tuple(String, String)).new
            result = @client.query_range(query, 1000, Time.utc - 24.hour, Time.utc, Loki::Direction::Backward)
            result.response_data.result.as(Loki::Model::Streams).each do |resp_stream|
              map = resp_stream.labels.map
              errors << {map["source"], map["time"]}
            end
            if errors.empty?
              Log.info { "No module runtime errors found. Skipping..." }
              next
            end

            errors = errors.uniq { |v| v[0] }
            errors.each do |mod_id, time|
              err_time = Time::Format::RFC_3339.parse(time)
              PlaceOS::Model::Module.update(mod_id, {has_runtime_error: true, error_timestamp: err_time})
            rescue ex
              Log.error(exception: ex) { {message: "Exception received when updating module", module: mod_id, timestamp: time} }
            end
          rescue ex
            Log.error(exception: ex) { "Exception received" }
          end
        end
      end
    end
  end
end
