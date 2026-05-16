module RedmineAssistant
  class ProjectExporter
    SENSITIVE_PATTERNS = [
      /(password|passwd|pwd)\s*[:=]\s*\S+/i,
      /(api[_-]?key|token|secret)\s*[:=]\s*\S+/i,
      /(authorization:\s*bearer)\s+\S+/i
    ].freeze

    def initialize(project, user = User.current)
      @project = project
      @user = user
    end

    def chunks
      result = []
      result << ['project-info.txt', project_info_text]
      result.concat(issue_chunks) if allowed?(:view_issues)
      wiki_text = wiki_pages_text
      result << ['wiki.txt', wiki_text] if wiki_text.present?
      news_text = news_text_content
      result << ['news.txt', news_text] if news_text.present?
      result
    end

    def to_text
      chunks.map { |filename, content| "FILE: #{filename}\n\n#{content}" }.join("\n\n")
    end

    private

    def project_info_text
      lines = []
      lines << 'PROJECT:'
      lines << "Name: #{clean(@project.name)}"
      lines << "Identifier: #{clean(@project.identifier)}"
      lines << "Description: #{clean(@project.description)}"
      lines << "Homepage: #{clean(@project.homepage)}" if @project.respond_to?(:homepage) && @project.homepage.present?
      lines << "Created: #{format_time(@project.created_on)}" if @project.respond_to?(:created_on)
      lines << "Updated: #{format_time(@project.updated_on)}" if @project.respond_to?(:updated_on)
      lines.join("\n")
    end

    def issue_chunks
      issues = @project.issues.visible(@user).includes(:status, :priority, :tracker, :author, :assigned_to, :journals => :user).order('issues.id ASC')
      chunks = []
      index = 0
      issues.find_in_batches(:batch_size => RedmineAssistant.issue_chunk_size) do |batch|
        first_id = batch.first.id
        last_id = batch.last.id
        filename = "issues-#{first_id}-#{last_id}.txt"
        chunks << [filename, batch.map { |issue| issue_text(issue) }.join("\n\n")]
        index += 1
      end
      chunks
    end

    def issue_text(issue)
      lines = []
      lines << 'ISSUE:'
      lines << "ID: #{issue.id}"
      lines << "Subject: #{clean(issue.subject)}"
      lines << "Status: #{clean(issue.status && issue.status.name)}"
      lines << "Priority: #{clean(issue.priority && issue.priority.name)}"
      lines << "Tracker: #{clean(issue.tracker && issue.tracker.name)}"
      lines << "Author: #{clean(issue.author && issue.author.name)}"
      lines << "Assigned To: #{clean(issue.assigned_to && issue.assigned_to.name)}"
      lines << "Created: #{format_time(issue.created_on)}"
      lines << "Updated: #{format_time(issue.updated_on)}"
      lines << "Description:"
      lines << clean(issue.description)
      notes = visible_journals(issue).map { |journal| journal_text(journal) }.reject(&:blank?)
      if notes.any?
        lines << 'Journals/Notes:'
        lines.concat(notes)
      end
      lines.join("\n")
    end

    def journal_text(journal)
      return '' if journal.notes.blank?
      "Note by #{clean(journal.user && journal.user.name)} at #{format_time(journal.created_on)}:\n#{clean(journal.notes)}"
    end

    def visible_journals(issue)
      if issue.respond_to?(:visible_journals)
        issue.visible_journals
      else
        issue.journals.select { |journal| journal.notes.present? }
      end
    end

    def wiki_pages_text
      return '' unless allowed?(:view_wiki_pages) && @project.wiki

      pages = @project.wiki.pages.includes(:content).order('wiki_pages.title ASC')
      pages.map do |page|
        content = page.content
        next if content.nil?
        lines = []
        lines << 'WIKI:'
        lines << "Title: #{clean(page.title)}"
        lines << "Version: #{content.version}" if content.respond_to?(:version)
        lines << "Author: #{clean(content.author && content.author.name)}" if content.respond_to?(:author)
        lines << "Updated: #{format_time(content.updated_on)}" if content.respond_to?(:updated_on)
        lines << 'Content:'
        lines << clean(content.text)
        lines.join("\n")
      end.compact.join("\n\n")
    rescue => e
      Rails.logger.warn("[redmine_assistant] wiki export skipped project_id=#{@project.id}: #{e.class}: #{e.message}")
      ''
    end

    def news_text_content
      return '' unless allowed?(:view_news)

      news_items = @project.news.includes(:author).order('created_on ASC')
      news_items.map do |item|
        lines = []
        lines << 'NEWS:'
        lines << "Title: #{clean(item.title)}"
        lines << "Author: #{clean(item.author && item.author.name)}"
        lines << "Created: #{format_time(item.created_on)}"
        lines << "Summary: #{clean(item.summary)}" if item.respond_to?(:summary)
        lines << 'Description:'
        lines << clean(item.description)
        if item.respond_to?(:comments)
          comments = item.comments.map { |comment| news_comment_text(comment) }.reject(&:blank?)
          if comments.any?
            lines << 'Comments:'
            lines.concat(comments)
          end
        end
        lines.join("\n")
      end.join("\n\n")
    rescue => e
      Rails.logger.warn("[redmine_assistant] news export skipped project_id=#{@project.id}: #{e.class}: #{e.message}")
      ''
    end

    def news_comment_text(comment)
      text = comment.respond_to?(:comments) ? comment.comments : comment.to_s
      return '' if text.blank?
      author = comment.respond_to?(:author) ? comment.author : nil
      created = comment.respond_to?(:created_on) ? comment.created_on : nil
      "Comment by #{clean(author && author.name)} at #{format_time(created)}:\n#{clean(text)}"
    end

    def allowed?(permission)
      @user.allowed_to?(permission, @project)
    end

    def clean(value)
      text = value.to_s.dup
      SENSITIVE_PATTERNS.each { |pattern| text.gsub!(pattern, '\1 [FILTERED]') }
      text.gsub(/\r\n?/, "\n").strip
    end

    def format_time(value)
      return '' if value.blank?
      return value.to_fs(:db) if value.respond_to?(:to_fs)
      return value.to_formatted_s(:db) if value.respond_to?(:to_formatted_s)

      value.strftime('%Y-%m-%d %H:%M:%S')
    end
  end
end
