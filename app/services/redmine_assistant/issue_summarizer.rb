module RedmineAssistant
  class IssueSummarizer
    MAX_TEXT_LENGTH = 12000

    def initialize(client = nil)
      @client = client || default_client
    end

    def summarize(issue, user = User.current, options = {})
      ai_model_name = RedmineAssistant.settings['default_chat_model'].to_s
      summary_record = options[:summary_record]
      mark_running(summary_record, ai_model_name) if summary_record
      content = issue_content(issue, user)
      Rails.logger.info("[redmine_assistant] starting ticket summary issue_id=#{issue && issue.id}")
      summary_text = @client.chat(messages_for(content), ai_model_name)
      save_summary(issue, user, ai_model_name, summary_text, 'success', nil, summary_record)
    rescue => e
      failed_summary = save_summary(issue, user, ai_model_name, nil, 'failed', e.message, summary_record)
      Rails.logger.error("[redmine_assistant] ticket summary failed issue_id=#{issue && issue.id}: #{e.class}: #{e.message}")
      raise e if options[:raise_errors]

      failed_summary
    end

    private

    def default_client
      if RedmineAssistant.settings['chat_provider'].to_s == 'ollama'
        RedmineAssistant::OllamaClient.new
      else
        RedmineAssistant::OpenwebuiClient.new
      end
    end

    def messages_for(content)
      [
        {
          :role => 'system',
          :content => configured_system_prompt
        },
        {
          :role => 'user',
          :content => configured_user_prompt(content)
        }
      ]
    end

    def configured_system_prompt
      prompt = RedmineAssistant.settings['issue_summary_system_prompt'].to_s
      prompt.present? ? prompt : RedmineAssistant::DEFAULT_ISSUE_SUMMARY_SYSTEM_PROMPT
    end

    def configured_user_prompt(issue_content)
      prompt = RedmineAssistant.settings['issue_summary_user_prompt'].to_s
      prompt = RedmineAssistant::DEFAULT_ISSUE_SUMMARY_USER_PROMPT if prompt.blank?

      if prompt.include?('{{issue_content}}')
        prompt.gsub('{{issue_content}}', issue_content.to_s)
      else
        "#{prompt}\n\n#{issue_content}"
      end
    end

    def issue_content(issue, user)
      lines = []
      lines << "ISSUE ##{issue.id}"
      lines << "Subject: #{clean(issue.subject)}"
      lines << "Project: #{clean(issue.project && issue.project.name)}"
      lines << "Tracker: #{clean(issue.tracker && issue.tracker.name)}"
      lines << "Status: #{clean(issue.status && issue.status.name)}"
      lines << "Priority: #{clean(issue.priority && issue.priority.name)}"
      lines << "Author: #{clean(issue.author && issue.author.name)}"
      lines << "Assigned To: #{clean(issue.assigned_to && issue.assigned_to.name)}"
      lines << "Created: #{format_time(issue.created_on)}"
      lines << "Updated: #{format_time(issue.updated_on)}"
      lines << ''
      lines << 'Description:'
      lines << clean(issue.description)
      lines << ''
      lines << 'Public Journals:'
      visible_public_journals(issue, user).each do |journal|
        lines << "Note by #{clean(journal.user && journal.user.name)} at #{format_time(journal.created_on)}:"
        lines << clean(journal.notes)
        lines << ''
      end
      truncate_text(lines.join("\n"))
    end

    def visible_public_journals(issue, user)
      # journals =
      #   if issue.respond_to?(:visible_journals)
      #     issue.visible_journals
      #   else
      #     issue.journals
      #   end

      # journals.select do |journal|
      #   journal.notes.present? && (!journal.respond_to?(:private_notes) || !journal.private_notes?)
      # end
      issue.journals
    end

    def mark_running(summary_record, ai_model_name)
      attributes = {
        :status => 'running',
        :error_message => nil,
        :generated_at => Time.now
      }
      attributes[:ai_model_name] = ai_model_name if RedmineAssistantIssueSummary.ai_model_name_column?
      summary_record.update!(attributes)
    end

    def save_summary(issue, user, ai_model_name, summary_text, status, error_message, summary_record = nil)
      if summary_record
        attributes = {
          :summary => summary_text,
          :status => status,
          :error_message => error_message,
          :generated_by_id => user && user.id,
          :generated_at => Time.now
        }
        attributes[:ai_model_name] = ai_model_name if RedmineAssistantIssueSummary.ai_model_name_column?
        if RedmineAssistantIssueSummary.retry_count_column?
          attributes[:retry_count] = status == 'failed' ? summary_record.retry_count_value + 1 : 0
        end
        summary_record.update!(attributes)
        return summary_record
      end

      RedmineAssistantIssueSummary.transaction do
        issue.lock!
        version = RedmineAssistantIssueSummary.where(:issue_id => issue.id).maximum(:version).to_i + 1
        attributes = {
          :issue_id => issue.id,
          :version => version,
          :summary => summary_text,
          :status => status,
          :error_message => error_message,
          :retry_count => status == 'failed' ? 1 : 0,
          :generated_by_id => user && user.id,
          :generated_at => Time.now
        }
        attributes.delete(:retry_count) unless RedmineAssistantIssueSummary.retry_count_column?
        attributes[:ai_model_name] = ai_model_name if RedmineAssistantIssueSummary.ai_model_name_column?

        RedmineAssistantIssueSummary.create!(attributes)
      end
    end

    def clean(value)
      value.to_s.gsub(/\r\n?/, "\n").strip
    end

    def truncate_text(text)
      return text if text.length <= MAX_TEXT_LENGTH

      "#{text[0, MAX_TEXT_LENGTH]}\n\n[Content truncated before summarization]"
    end

    def format_time(value)
      return '' if value.blank?
      return value.to_fs(:db) if value.respond_to?(:to_fs)
      return value.to_formatted_s(:db) if value.respond_to?(:to_formatted_s)

      value.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
