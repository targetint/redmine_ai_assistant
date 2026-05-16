class AddRetryCountToIssueSummaries < ActiveRecord::Migration[4.2]
  def change
    return unless table_exists?(:redmine_assistant_issue_summaries)
    return if column_exists?(:redmine_assistant_issue_summaries, :retry_count)

    add_column :redmine_assistant_issue_summaries, :retry_count, :integer, :null => false, :default => 0
  end
end

