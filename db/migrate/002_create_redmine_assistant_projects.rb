class CreateRedmineAssistantProjects < ActiveRecord::Migration[4.2]
  def change
    return if table_exists?(:redmine_assistant_projects)

    create_table :redmine_assistant_projects do |t|
      t.integer :project_id, :null => false
      t.string :openwebui_knowledge_id
      t.string :openwebui_knowledge_name
      t.datetime :last_synced_at
      t.string :sync_status
      t.text :sync_message
      t.timestamps :null => false
    end

    add_index :redmine_assistant_projects, :project_id, :unique => true
    add_index :redmine_assistant_projects, :openwebui_knowledge_id
  end
end
