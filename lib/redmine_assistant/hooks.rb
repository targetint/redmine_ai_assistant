module RedmineAssistant
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_projects_show_right,
              :partial => 'redmine_ai_assistant/project_sync_box'

    render_on :view_issues_show_details_bottom,
              :partial => 'issues/redmine_assistant_ticket_summary'

    def controller_issues_edit_after_save(context = {})
      issue = context[:issue]
      return unless issue
      return unless RedmineAssistant.issue_summary_enabled?
      return unless RedmineAssistant.project_enabled?(issue.project)

      summary = RedmineAssistantIssueSummary.create!(
        :issue_id => issue.id,
        :version => RedmineAssistantIssueSummary.where(:issue_id => issue.id).maximum(:version).to_i + 1,
        :status => 'queued',
        :generated_by_id => User.current.id,
        :generated_at => Time.now
      )
      RedmineAssistantIssueSummaryJob.perform_later(issue.id, User.current.id, summary.id)
    rescue => e
      Rails.logger.error("[redmine_assistant] ticket summary enqueue failed issue_id=#{issue && issue.id}: #{e.class}: #{e.message}")
    end
  end
end
