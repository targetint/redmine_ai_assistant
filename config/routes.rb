post 'projects/:project_id/redmine_ai_assistant/sync',
     :to => 'redmine_assistant#sync',
     :as => 'project_redmine_ai_assistant_sync'

get 'projects/:project_id/redmine_ai_assistant/status',
    :to => 'redmine_assistant#status',
    :as => 'project_redmine_ai_assistant_status'

post 'issues/:issue_id/redmine_ai_assistant/summary',
     :to => 'redmine_assistant#generate_issue_summary',
     :as => 'issue_redmine_ai_assistant_summary'
