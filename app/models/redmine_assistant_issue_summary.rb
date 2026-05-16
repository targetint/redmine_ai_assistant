class RedmineAssistantIssueSummary < ActiveRecord::Base
  self.ignored_columns = ['model_name'] if respond_to?(:ignored_columns=)

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

  def self.enqueue_for(issue, user = User.current)
    latest = latest_for(issue)
    return latest if latest

    create!(
      :issue_id => issue.id,
      :version => 1,
      :status => 'queued',
      :generated_by_id => user && user.id,
      :generated_at => Time.now
    )
  end
end
