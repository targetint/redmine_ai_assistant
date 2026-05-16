class RenameIssueSummaryModelName < ActiveRecord::Migration[4.2]
  def up
    if column_exists?(:redmine_assistant_issue_summaries, :model_name) &&
       !column_exists?(:redmine_assistant_issue_summaries, :ai_model_name)
      rename_column :redmine_assistant_issue_summaries, :model_name, :ai_model_name
    end
  end

  def down
    if column_exists?(:redmine_assistant_issue_summaries, :ai_model_name) &&
       !column_exists?(:redmine_assistant_issue_summaries, :model_name)
      rename_column :redmine_assistant_issue_summaries, :ai_model_name, :model_name
    end
  end
end

