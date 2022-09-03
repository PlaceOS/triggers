require "placeos-models/version"

module PlaceOS::Triggers
  class Root < Application
    base "/api/triggers/v2/"

    # used to check service is responding
    @[AC::Route::GET("/")]
    def healthcheck : Nil
    end

    # returns the service commit level and build time
    @[AC::Route::GET("/version")]
    def version : PlaceOS::Model::Version
      PlaceOS::Model::Version.new(
        version: VERSION,
        build_time: BUILD_TIME,
        commit: BUILD_COMMIT,
        service: APP_NAME
      )
    end
  end
end
