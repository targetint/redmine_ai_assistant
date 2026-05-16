module RedmineAssistant
  class SyncService
    def initialize(client = nil, exporter_class = RedmineAssistant::ProjectExporter)
      @client = client || RedmineAssistant::OpenwebuiClient.new
      @exporter_class = exporter_class
    end

    def sync(project)
      mapping = RedmineAssistantProject.where(:project_id => project.id).first_or_initialize
      knowledge_name = knowledge_base_name(project)
      mapping.sync_status = 'running'
      mapping.sync_message = 'Sync started'
      mapping.save!

      knowledge = find_or_create_knowledge(project, knowledge_name)
      knowledge_id = knowledge_value(knowledge, 'id')
      raise 'OpenWebUI knowledgebase response did not include an id' if knowledge_id.blank?

      mapping.openwebui_knowledge_id = knowledge_id
      mapping.openwebui_knowledge_name = knowledge_name
      mapping.save!

      Rails.logger.info("[redmine_assistant] uploading project_id=#{project.id} knowledge_id=#{knowledge_id}")
      @exporter_class.new(project).chunks.each do |filename, content|
        next if content.blank?
        @client.upload_document_to_knowledge_base(knowledge_id, timestamped_filename(project, filename), content)
        Rails.logger.info("[redmine_assistant] uploaded project_id=#{project.id} filename=#{filename}")
      end

      mapping.last_synced_at = Time.now
      mapping.sync_status = 'success'
      mapping.sync_message = 'Knowledge base synced successfully'
      mapping.save!
      mapping
    rescue => e
      mapping ||= RedmineAssistantProject.where(:project_id => project.id).first_or_initialize
      mapping.sync_status = 'failed'
      mapping.sync_message = e.message.to_s.truncate(1000)
      mapping.save! if mapping.project_id.present?
      Rails.logger.error("[redmine_assistant] sync failed project_id=#{project && project.id}: #{e.class}: #{e.message}")
      raise e
    end

    private

    def find_or_create_knowledge(project, knowledge_name)
      knowledge = @client.find_knowledge_base_by_name(knowledge_name)
      if knowledge
        Rails.logger.info("[redmine_assistant] reusing knowledgebase project_id=#{project.id} name=#{knowledge_name}")
        knowledge
      else
        Rails.logger.info("[redmine_assistant] creating knowledgebase project_id=#{project.id} name=#{knowledge_name}")
        @client.create_knowledge_base(knowledge_name, "Redmine project knowledgebase for #{project.name} (#{project.identifier})")
      end
    end

    def knowledge_base_name(project)
      identifier = project.identifier.to_s.strip
      return project.name if identifier.blank?

      "#{project.name} #{identifier}"
    end

    def timestamped_filename(project, filename)
      safe_identifier = project.identifier.to_s.gsub(/[^a-zA-Z0-9_-]/, '-')
      "redmine-project-#{safe_identifier}-#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{filename}"
    end

    def knowledge_value(knowledge, key)
      knowledge[key] || knowledge[key.to_sym]
    end
  end
end
