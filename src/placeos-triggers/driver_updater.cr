require "git-repository"
require "placeos-models"
require "tasker"

module PlaceOS::Triggers
  class DriverUpdate
    Log = ::Log.for(self)

    def initialize(@repeat_interval : Time::Span)
    end

    def self.new(interval : String)
      new(Triggers.extract_time_span(interval))
    end

    def start
      Tasker.every(@repeat_interval) do
        installed_drivers = PlaceOS::Model::Driver.all.reload
        Log.info { "Finding if updates are available for #{installed_drivers.size} installed drivers" }
        installed_drivers.group_by(&.repository_id).each_value do |drivers|
          repo = nil
          begin
            current_repo = drivers.first.repository.not_nil!
            password = current_repo.decrypt_password if current_repo.password.presence
            # providing the branch caches the repository history in a temp folder
            # for the lifetime of this object
            repo = GitRepository.new(current_repo.uri, current_repo.username, password, branch: current_repo.branch)

            drivers.each do |driver|
              Log.debug { {message: "Looking for driver updates", driver: driver.id, commit: driver.commit} }
              begin
                last = repo.commits(current_repo.branch, driver.file_name, depth: 1).first
                info = Model::Driver::UpdateInfo.new(last.commit, last.subject, last.author, last.date)
                Log.debug { {message: "Retrieved latest commit for driver", driver: driver.id, previous_commit: driver.commit, latest_commit: info.commit} }
                driver.process_update_info(info)
              rescue ex
                Log.error(exception: ex) { "failed to check for updates: #{driver.id}" }
              end
            end
          rescue ex
            Log.error(exception: ex) { "failed to obtain repository details: #{drivers.first.repository_id}" }
          ensure
            # remove the cached history now, rather than waiting for the GC to finalize
            repo.try { |cached| cached.cleanup(cached.cache_path) }
          end
        end
      end
    end
  end
end
