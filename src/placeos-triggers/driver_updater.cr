require "git-repository"
require "placeos-models"
require "tasker"

module PlaceOS::Triggers
  class DriverUpdate
    Log = ::Log.for(self)

    class_getter repository_dir : String = File.expand_path("./repositories")

    def initialize(@repeat_interval : Time::Span)
    end

    def self.new(interval : String)
      matches = interval.downcase.match(/^(\dh)?(\dm)?(\ds)?$/)
      raise "Invalid interval '#{interval}' value. Interval need to be in format 'xh:xm:xs' where 'x' represents number. e.g. '2h' or '5m30s' or '3s' etc" unless matches
      values = matches.captures.map(&.try &.sub(/h|m|s/, "")).map(&.try &.to_i)
      duration = Time::Span.new(hours: values[0] || 0, minutes: values[1] || 0, seconds: values[2] || 0)
      new(duration)
    end

    def start
      Tasker.every(@repeat_interval) do
        installed_drivers = PlaceOS::Model::Driver.all.reload
        Log.info { "Finding if updates are available for #{installed_drivers.size} installed drivers" }
        installed_drivers.each do |driver|
          Log.debug { {message: "Looking for driver updates", driver: driver.id, commit: driver.commit} }
          begin
            folder = fetch_repo(driver.repository.not_nil!)
            info = last_commit(folder, driver.file_name)
            Log.debug { {message: "Retrieved latest commit for driver", driver: driver.id, previous_commit: driver.commit, latest_commit: info.commit} }
            driver.process_update_info(info)
          rescue ex
            Log.error(exception: ex) { "Exception received" }
          end
        end
      end
    end

    private def last_commit(folder, filename)
      git = GitRepository::Commands.new(folder)
      last = git.commits(filename, 1).first
      Model::Driver::UpdateInfo.new(last.commit, last.subject, last.author, last.date)
    end

    private def fetch_repo(current_repo)
      folder = Path.new(self.class.repository_dir, current_repo.id.as(String), current_repo.folder_name)
      downloaded = Dir.exists?(folder)
      Dir.mkdir_p(folder) unless downloaded
      password = current_repo.decrypt_password if current_repo.password.presence
      repo = GitRepository.new(current_repo.uri, current_repo.username, password)
      git = GitRepository::Commands.new(folder.to_s)
      unless downloaded
        git.init
        git.add_origin repo.repository
      end
      git.run_git("fetch", {"--all"})
      git.checkout current_repo.branch rescue git.checkout repo.default_branch

      folder.to_s
    end
  end
end
