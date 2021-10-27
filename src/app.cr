require "http/client"
require "option_parser"

require "./constants"

# Server defaults
port = PlaceOS::Triggers::DEFAULT_PORT
host = PlaceOS::Triggers::DEFAULT_HOST
process_count = PlaceOS::Triggers::DEFAULT_PROCESS_COUNT

# Command line options
OptionParser.parse(ARGV.dup) do |parser|
  parser.banner = "Usage: #{PlaceOS::Triggers::APP_NAME} [arguments]"

  parser.on("-b HOST", "--bind=HOST", "Specifies the server host") { |h| host = h }
  parser.on("-p PORT", "--port=PORT", "Specifies the server port") { |p| port = p.to_i }

  parser.on("-w COUNT", "--workers=COUNT", "Specifies the number of processes to handle requests") do |w|
    process_count = w.to_i
  end

  parser.on("-r", "--routes", "List the application routes") do
    ActionController::Server.print_routes
    exit 0
  end

  parser.on("-v", "--version", "Display the application version") do
    puts "#{PlaceOS::Triggers::APP_NAME} v#{PlaceOS::Triggers::VERSION}"
    exit 0
  end

  parser.on("-c URL", "--curl=URL", "Perform a basic health check by requesting the URL") do |url|
    begin
      response = HTTP::Client.get url
      exit 0 if (200..499).includes? response.status_code
      puts "health check failed, received response code #{response.status_code}"
      exit 1
    rescue error
      error.inspect_with_backtrace(STDOUT)
      exit 2
    end
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

# Load the routes
require "./config"

module PlaceOS::Triggers
  Log.info { "launching #{APP_NAME} v#{VERSION}" }

  server = ActionController::Server.new(port, host)

  # Start clustering
  server.cluster(process_count, "-w", "--workers") if process_count != 1

  terminate = Proc(Signal, Nil).new do |signal|
    puts " > terminating gracefully"
    spawn(same_thread: true) { server.close }
    signal.ignore
  end

  # Detect ctr-c to shutdown gracefully
  # Docker containers use the term signal
  Signal::INT.trap &terminate
  Signal::TERM.trap &terminate

  # Start watching trigger table
  trigger_loader = Loader::Trigger.new(self.mapping).start

  # Start watching trigger instance table
  trigger_instance_loader = Loader::TriggerInstance.new(self.mapping).start

  # Start telemetry
  PlaceOS::Triggers.start_pulse

  # Start the server
  server.run do
    Log.info { "listening on #{server.print_addresses}" }
  end

  # Shutdown message
  Log.info { "#{APP_NAME} leaps through the veldt" }
end
