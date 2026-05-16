$LOAD_PATH.unshift File.expand_path('lib', __dir__)

require 'redmine_assistant'
require 'redmine_assistant/hooks'

Rails.application.config.eager_load_paths += Dir.glob("#{Rails.application.config.root}/plugins/redmine_ai_assistant/{lib,app/models,app/controllers,app/services,app/jobs}")
ActiveSupport::Dependencies.autoload_paths += Dir.glob("#{Rails.application.config.root}/plugins/redmine_ai_assistant/{lib,app/models,app/controllers,app/services,app/jobs}") if defined?(ActiveSupport::Dependencies)

Redmine::Plugin.register :redmine_ai_assistant do
  name 'Redmine AI Assistant'
  author 'Target Integration'
  description 'AI assistant features for Redmine, starting with OpenWebUI knowledgebase sync.'
  version '0.1.0'
  url 'https://targetintegration.com'
  author_url 'https://targetintegration.com'

  requires_redmine :version_or_higher => '4.0.0'

  settings(
    :default => RedmineAssistant::DEFAULT_SETTINGS,
    :partial => 'settings/redmine_ai_assistant_settings'
  )

  project_module :redmine_ai_assistant do
    permission :sync_redmine_assistant,
               { :redmine_assistant => [:sync, :status] },
               :require => :member
  end
end
