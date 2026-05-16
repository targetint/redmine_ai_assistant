class CreateRedmineAssistantIssueSummaries < ActiveRecord::Migration[4.2]
  def change
    return if table_exists?(:redmine_assistant_issue_summaries)

    create_table :redmine_assistant_issue_summaries do |t|
      t.integer :issue_id, :null => false
      t.integer :version, :null => false
      t.string :ai_model_name
      t.text :summary
      t.string :status
      t.text :error_message
      t.integer :generated_by_id
      t.datetime :generated_at
      t.timestamps :null => false
    end

    add_index :redmine_assistant_issue_summaries, [:issue_id, :version], :unique => true
    add_index :redmine_assistant_issue_summaries, :issue_id
    add_index :redmine_assistant_issue_summaries, :generated_by_id
  end
end
