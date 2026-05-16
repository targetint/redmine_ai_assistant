class RedmineAssistantController < ApplicationController
  before_action :find_project, :only => [:sync, :status]
  before_action :find_issue, :only => [:generate_issue_summary]
  before_action :authorize_sync, :only => [:sync, :status]
  before_action :authorize_issue_summary, :only => [:generate_issue_summary]

  accept_api_auth :status

  def sync
    unless RedmineAssistant.enabled?
      return respond_with_error(l(:error_redmine_assistant_disabled))
    end

    if RedmineAssistant.run_in_background? && defined?(RedmineAssistantSyncJob)
      mapping = RedmineAssistantProject.where(:project_id => @project.id).first_or_initialize
      mapping.sync_status = 'running'
      mapping.sync_message = l(:notice_redmine_assistant_sync_queued)
      mapping.save!
      RedmineAssistantSyncJob.perform_later(@project.id, User.current.id)
      respond_with_success(mapping, l(:notice_redmine_assistant_sync_queued))
    else
      mapping = RedmineAssistant::SyncService.new.sync(@project)
      respond_with_success(mapping, l(:notice_redmine_assistant_sync_success))
    end
  rescue => e
    Rails.logger.error("[redmine_assistant] sync failed project_id=#{@project && @project.id}: #{e.class}: #{e.message}")
    respond_with_error(e.message)
  end

  def status
    mapping = RedmineAssistantProject.where(:project_id => @project.id).first
    respond_to do |format|
      format.json do
        render :json => status_payload(mapping)
      end
      format.html do
        redirect_to :controller => 'projects', :action => 'settings', :id => @project, :tab => 'redmine_ai_assistant'
      end
    end
  end

  def generate_issue_summary
    unless RedmineAssistant.issue_summary_enabled?
      return respond_with_issue_summary_error(l(:error_redmine_assistant_summary_disabled))
    end

    if RedmineAssistant.run_in_background? && defined?(RedmineAssistantIssueSummaryJob)
      RedmineAssistantIssueSummaryJob.perform_later(@issue.id, User.current.id)
      respond_with_issue_summary_success(l(:notice_redmine_assistant_summary_queued))
    else
      summary = RedmineAssistant::IssueSummarizer.new.summarize(@issue, User.current)
      if summary && summary.status == 'failed'
        respond_with_issue_summary_error(summary.error_message)
      else
        respond_with_issue_summary_success(l(:notice_redmine_assistant_summary_generated))
      end
    end
  rescue => e
    Rails.logger.error("[redmine_assistant] manual ticket summary failed issue_id=#{@issue && @issue.id}: #{e.class}: #{e.message}")
    respond_with_issue_summary_error(e.message)
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_sync
    deny_access unless User.current.allowed_to?(:sync_redmine_assistant, @project)
  end

  def find_issue
    @issue = Issue.visible.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_issue_summary
    deny_access unless @project &&
                       RedmineAssistant.project_enabled?(@project) &&
                       User.current.allowed_to?(:view_issues, @project)
  end

  def respond_with_success(mapping, message)
    respond_to do |format|
      format.json { render :json => status_payload(mapping).merge(:success => true, :message => message) }
      format.html do
        flash[:notice] = message
        redirect_back_or_default :controller => 'projects', :action => 'show', :id => @project
      end
    end
  end

  def respond_with_error(message)
    respond_to do |format|
      format.json { render :json => { :success => false, :error => message }, :status => 422 }
      format.html do
        flash[:error] = message
        redirect_back_or_default :controller => 'projects', :action => 'show', :id => @project
      end
    end
  end

  def respond_with_issue_summary_success(message)
    respond_to do |format|
      format.json { render :json => { :success => true, :message => message } }
      format.html do
        flash[:notice] = message
        redirect_to issue_path(@issue)
      end
    end
  end

  def respond_with_issue_summary_error(message)
    respond_to do |format|
      format.json { render :json => { :success => false, :error => message }, :status => 422 }
      format.html do
        flash[:error] = message
        redirect_to issue_path(@issue)
      end
    end
  end

  def status_payload(mapping)
    {
      :project_id => @project.id,
      :status => mapping ? mapping.status_label : 'not_synced',
      :knowledge_id => mapping && mapping.openwebui_knowledge_id,
      :knowledge_name => mapping && mapping.openwebui_knowledge_name,
      :last_synced_at => mapping && mapping.last_synced_at,
      :message => mapping && mapping.sync_message
    }
  end
end
