class RedmineAssistantSyncJob < ActiveJob::Base
  queue_as :default

  def perform(project_id, user_id = nil)
    project = Project.find(project_id)
    User.current = User.find_by_id(user_id) || User.anonymous
    RedmineAssistant::SyncService.new.sync(project)
  ensure
    User.current = nil if defined?(User)
  end
end

