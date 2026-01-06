require "time"
require "placeos-models"
require "tasker"
require "loki-client"

module PlaceOS::Triggers
  class LokiSearchForErrors
    Log = ::Log.for(self)

    def initialize(@repeat_interval : Time::Span)
      @client = Loki::Client.from_env
      @search_window = Triggers.extract_time_span(LOKI_SEARCH_WINDOW)
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

        begin
          # Query Loki once for all modules
          result = @client.query_range(query, 1000, Time.utc - @search_window, Time.utc, Loki::Direction::Backward)

          # Build a map of module_id => latest error timestamp
          module_errors = Hash(String, Time).new
          result.response_data.result.as(Loki::Model::Streams).each do |resp_stream|
            map = resp_stream.labels.map

            # Extract module ID from stream labels
            mod_id = map["source"]?
            next unless mod_id

            # Iterate through entries to find the latest error timestamp
            resp_stream.entries.each do |entry|
              if err_time = entry.timestamp
                # Keep only the latest error per module
                if !module_errors.has_key?(mod_id) || err_time > module_errors[mod_id]
                  module_errors[mod_id] = err_time
                end
              end
            end
          end

          if module_errors.empty?
            Log.info { "No module runtime errors found. Skipping..." }
            next
          end

          Log.debug { {message: "Found errors for modules", count: module_errors.size} }

          # Get all running module IDs for validation
          running_module_ids = PlaceOS::Model::Module.where(running: true).pluck(:id).to_set

          # Filter to only running modules
          updates = module_errors.select { |mod_id, _| running_module_ids.includes?(mod_id) }

          if updates.empty?
            Log.info { "No running modules with errors to update. Skipping..." }
            next
          end

          # Bulk update using UNNEST - single database query
          mod_ids = updates.keys
          timestamps = updates.values

          sql = <<-SQL
            UPDATE #{PlaceOS::Model::Module.table_name}
            SET has_runtime_error = true,
                error_timestamp = data.timestamp
            FROM (
              SELECT UNNEST($1::text[]) AS id,
                     UNNEST($2::timestamptz[]) AS timestamp
            ) AS data
            WHERE #{PlaceOS::Model::Module.table_name}.id = data.id
          SQL

          PgORM::Database.connection do |db|
            db.exec(sql, mod_ids, timestamps)
          end
          Log.info { {message: "Bulk updated modules with runtime errors", count: updates.size} }
        rescue ex
          Log.error(exception: ex) { "Exception received while searching Loki" }
        end
      end
    end
  end
end
