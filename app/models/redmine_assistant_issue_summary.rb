class RedmineAssistantIssueSummary < ActiveRecord::Base
  self.ignored_columns = ['model_name'] if respond_to?(:ignored_columns=)
  MAX_RETRY_COUNT = 5
  RETRY_DELAY_SECONDS = 60

  belongs_to :issue
  belongs_to :generated_by, :class_name => 'User'

  validates :issue_id, :presence => true
  validates :version, :presence => true, :numericality => { :only_integer => true, :greater_than => 0 }
  validates :status, :inclusion => { :in => %w[queued running success failed], :allow_blank => true }

  scope :latest_first, lambda { order('version DESC') }

  def self.latest_for(issue)
    where(:issue_id => issue.id).latest_first.first
  end

  def self.latest_success_for(issue)
    where(:issue_id => issue.id, :status => 'success').latest_first.first
  end

  def self.ai_model_name_column?
    column_names.include?('ai_model_name')
  end

  def self.retry_count_column?
    column_names.include?('retry_count')
  end

  def self.enqueue_for(issue, user = User.current)
    latest = latest_for(issue)
    return latest if latest

    enqueue_new_version_for(issue, user)
  end

  def self.enqueue_new_version_for(issue, user = User.current)
    transaction do
      issue.lock!
      version = where(:issue_id => issue.id).maximum(:version).to_i + 1

      create!(
        :issue_id => issue.id,
        :version => version,
        :status => 'queued',
        :generated_by_id => user && user.id,
        :generated_at => Time.now
      )
    end
  end

  def self.enqueue_failed_retry_for(issue, user = User.current)
    latest = latest_for(issue)
    return nil unless latest && latest.retryable?

    latest.update!(
      :status => 'queued',
      :generated_by_id => user && user.id,
      :generated_at => Time.now
    )
    latest
  end

  def retry_count_value
    self.class.retry_count_column? ? retry_count.to_i : 0
  end

  def retryable?
    self.class.retry_count_column? && status == 'failed' && retry_count_value < MAX_RETRY_COUNT
  end

  def next_retry_delay
    RETRY_DELAY_SECONDS * (retry_count_value + 1)
  end
end
