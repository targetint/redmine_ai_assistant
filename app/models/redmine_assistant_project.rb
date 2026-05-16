class RedmineAssistantProject < ActiveRecord::Base
  belongs_to :project

  validates :project_id, :presence => true, :uniqueness => true
  validates :sync_status, :inclusion => { :in => %w[running success failed], :allow_blank => true }

  def status_label
    return 'not_synced' if sync_status.blank?
    sync_status
  end
end

