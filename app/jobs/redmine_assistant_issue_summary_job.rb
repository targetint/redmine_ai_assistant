class RedmineAssistantIssueSummaryJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id, user_id = nil, summary_id = nil)
    issue = Issue.find(issue_id)
    User.current = User.find_by_id(user_id) || User.anonymous
    summary_record = summary_id ? RedmineAssistantIssueSummary.find_by_id(summary_id) : nil
    summary = RedmineAssistant::IssueSummarizer.new.summarize(issue, User.current, :summary_record => summary_record)
    retry_summary(issue, User.current, summary) if summary && summary.retryable?
  ensure
    User.current = nil if defined?(User)
  end

  private

  def retry_summary(issue, user, summary)
    Rails.logger.warn("[redmine_assistant] retrying ticket summary issue_id=#{issue.id} summary_id=#{summary.id} retry_count=#{summary.retry_count_value}")
    summary.update!(:status => 'queued')
    self.class.set(:wait => summary.next_retry_delay.seconds).perform_later(issue.id, user.id, summary.id)
  end
end
