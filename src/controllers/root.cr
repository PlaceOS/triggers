require "placeos-models/version"

module PlaceOS::Triggers
  class Admin < Application
    base "/api/triggers/v2/"

    get "/", :root do
      head :ok
    end

    get "/version", :version do
      render :ok, json: PlaceOS::Model::Version.new(
        version: VERSION,
        build_time: BUILD_TIME,
        commit: BUILD_COMMIT,
        service: APP_NAME
      )
    end
  end
end
