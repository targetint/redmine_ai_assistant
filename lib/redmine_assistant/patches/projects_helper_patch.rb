module RedmineAssistant
  module Patches
    module ProjectsHelperPatch
      def project_settings_tabs
        tabs = super

        if redmine_assistant_project_tab_visible?
          tabs << {
            :name => 'redmine_ai_assistant',
            :action => :edit_project,
            :partial => 'projects/settings/redmine_ai_assistant',
            :label => :label_redmine_assistant
          }
        end

        tabs
      end

      private

      def redmine_assistant_project_tab_visible?
        @project &&
          RedmineAssistant.enabled? &&
          RedmineAssistant.project_enabled?(@project) &&
          (User.current.admin? || User.current.allowed_to?(:sync_redmine_assistant, @project) || User.current.allowed_to?(:edit_project, @project))
      end
    end
  end
end
