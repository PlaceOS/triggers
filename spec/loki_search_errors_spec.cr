require "./helper"

module PlaceOS::Triggers
  describe LokiSearchForErrors do
    it "performs bulk update using UNNEST with array parameters" do
      # Create test modules
      mod1 = PlaceOS::Model::Generator.module.save!
      mod1.running = true
      mod1.save!

      mod2 = PlaceOS::Model::Generator.module.save!
      mod2.running = true
      mod2.save!

      mod3 = PlaceOS::Model::Generator.module.save!
      mod3.running = true
      mod3.save!

      # Prepare test data
      mod_ids = [mod1.id.as(String), mod2.id.as(String), mod3.id.as(String)]
      timestamps = [
        Time.utc - 1.hour,
        Time.utc - 30.minutes,
        Time.utc - 15.minutes,
      ]

      # Execute the bulk update SQL directly (same as in the actual code)
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

      result = PgORM::Database.connection do |dbc|
        dbc.exec(sql, mod_ids, timestamps)
      end

      # Verify the update was successful
      result.rows_affected.should eq(3)

      # Verify the modules were updated correctly
      mod1.reload!
      mod2.reload!
      mod3.reload!

      mod1.has_runtime_error.should be_true
      mod2.has_runtime_error.should be_true
      mod3.has_runtime_error.should be_true

      # PostgreSQL truncates to microsecond precision, so compare with tolerance
      mod1.error_timestamp.not_nil!.to_unix.should eq(timestamps[0].to_unix)
      mod2.error_timestamp.not_nil!.to_unix.should eq(timestamps[1].to_unix)
      mod3.error_timestamp.not_nil!.to_unix.should eq(timestamps[2].to_unix)
    end

    it "only updates running modules" do
      # Create test modules - some running, some not
      running_mod = PlaceOS::Model::Generator.module.save!
      running_mod.running = true
      running_mod.save!

      stopped_mod = PlaceOS::Model::Generator.module.save!
      stopped_mod.running = false
      stopped_mod.save!

      # Try to update both
      mod_ids = [running_mod.id.as(String), stopped_mod.id.as(String)]
      timestamps = [Time.utc - 1.hour, Time.utc - 30.minutes]

      # Get only running module IDs (simulating the actual code logic)
      running_module_ids = PlaceOS::Model::Module.where(running: true).pluck(:id).to_set

      # Filter updates to only running modules
      updates = Hash.zip(mod_ids, timestamps).select { |mod_id, _| running_module_ids.includes?(mod_id) }

      # Execute bulk update only for running modules
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

      result = PgORM::Database.connection do |dbc|
        dbc.exec(sql, updates.keys, updates.values)
      end

      # Should only update 1 module (the running one)
      result.rows_affected.should eq(1)

      # Verify only the running module was updated
      running_mod.reload!
      stopped_mod.reload!

      running_mod.has_runtime_error.should be_true
      stopped_mod.has_runtime_error.should be_false
    end

    it "handles empty updates gracefully" do
      # Execute with empty arrays
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

      result = PgORM::Database.connection do |db|
        db.exec(sql, [] of String, [] of Time)
      end

      # Should affect 0 rows
      result.rows_affected.should eq(0)
    end

    it "validates pg-orm DSL query for running modules" do
      # Create a mix of running and stopped modules
      running_mod1 = PlaceOS::Model::Generator.module.save!
      running_mod1.running = true
      running_mod1.save!

      running_mod2 = PlaceOS::Model::Generator.module.save!
      running_mod2.running = true
      running_mod2.save!

      stopped_mod1 = PlaceOS::Model::Generator.module.save!
      stopped_mod1.running = false
      stopped_mod1.save!

      stopped_mod2 = PlaceOS::Model::Generator.module.save!
      stopped_mod2.running = false
      stopped_mod2.save!

      # Test the exact DSL query used in the implementation
      running_module_ids = PlaceOS::Model::Module.where(running: true).pluck(:id).to_set

      # Verify it returns only running module IDs
      running_module_ids.should contain(running_mod1.id)
      running_module_ids.should contain(running_mod2.id)
      running_module_ids.should_not contain(stopped_mod1.id)
      running_module_ids.should_not contain(stopped_mod2.id)

      # Verify the count is correct
      running_module_ids.size.should be >= 2 # At least our 2 running modules

      # Verify the DSL query works correctly for filtering (the key functionality)
      test_module_ids = [running_mod1.id.as(String), stopped_mod1.id.as(String)]
      filtered = test_module_ids.select { |id| running_module_ids.includes?(id) }
      filtered.should eq([running_mod1.id])

      # Verify it supports O(1) lookups (Set behavior)
      running_module_ids.includes?(running_mod1.id).should be_true
      running_module_ids.includes?(stopped_mod1.id).should be_false
    end

    it "handles large batch updates efficiently" do
      # Create 100 test modules
      modules = Array.new(100) do
        mod = PlaceOS::Model::Generator.module.save!
        mod.running = true
        mod.save!
        mod
      end

      mod_ids = modules.map(&.id.as(String))
      timestamps = Array.new(100) { |i| Time.utc - i.minutes }

      # Execute bulk update
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

      result = PgORM::Database.connection do |db|
        db.exec(sql, mod_ids, timestamps)
      end

      # Should update all 100 modules in a single query
      result.rows_affected.should eq(100)

      # Spot check a few modules
      modules[0].reload!
      modules[50].reload!
      modules[99].reload!

      modules[0].has_runtime_error.should be_true
      modules[50].has_runtime_error.should be_true
      modules[99].has_runtime_error.should be_true
    end

    it "uses configurable search window with flexible duration format" do
      # Test that it uses the LOKI_SEARCH_WINDOW constant and parses it correctly
      searcher = LokiSearchForErrors.new(1.minute)
      expected_window = PlaceOS::Triggers.extract_time_span(PlaceOS::Triggers::LOKI_SEARCH_WINDOW)
      searcher.@search_window.should eq(expected_window)

      # Default should be 24 hours
      searcher.@search_window.should eq(24.hours)
    end

    it "validates duration parsing supports various formats" do
      # Test the extract_time_span method with different formats
      PlaceOS::Triggers.extract_time_span("5m").should eq(5.minutes)
      PlaceOS::Triggers.extract_time_span("1h20m").should eq(1.hour + 20.minutes)
      PlaceOS::Triggers.extract_time_span("5h").should eq(5.hours)
      PlaceOS::Triggers.extract_time_span("30s").should eq(30.seconds)
      PlaceOS::Triggers.extract_time_span("2h30m45s").should eq(2.hours + 30.minutes + 45.seconds)
    end

    it "handles edge cases in duration parsing" do
      # Test what happens with just a number (no postfix)
      PlaceOS::Triggers.extract_time_span("5").should eq(Time::Span.zero)

      # Test empty string
      PlaceOS::Triggers.extract_time_span("").should eq(Time::Span.zero)

      # Test invalid formats - also return zero duration (regex matches but captures nothing)
      PlaceOS::Triggers.extract_time_span("invalid").should eq(Time::Span.zero)
      PlaceOS::Triggers.extract_time_span("5x").should eq(Time::Span.zero)
    end
  end
end
