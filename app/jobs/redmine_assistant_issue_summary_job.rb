class RedmineAssistantIssueSummaryJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, user_id = nil, summary_id = nil)
    issue = Issue.find(issue_id)
    User.current = User.find_by_id(user_id) || User.anonymous
    summary_record = summary_id ? RedmineAssistantIssueSummary.find_by_id(summary_id) : nil
    RedmineAssistant::IssueSummarizer.new.summarize(issue, User.current, :summary_record => summary_record)
  ensure
    User.current = nil if defined?(User)
  end
end
