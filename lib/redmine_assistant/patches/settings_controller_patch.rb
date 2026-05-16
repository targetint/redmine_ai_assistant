module RedmineAssistant
  module Patches
    module SettingsControllerPatch
      def plugin
        preserve_redmine_assistant_api_key
        super
      end

      private

      def preserve_redmine_assistant_api_key
        return unless request.post?
        return unless [RedmineAssistant::PLUGIN_ID, RedmineAssistant::LEGACY_PLUGIN_ID].include?(params[:id].to_s)
        return unless params[:settings].present?
        return unless params[:settings][:openwebui_api_key].to_s.blank?

        existing = RedmineAssistant.settings
        params[:settings][:openwebui_api_key] = existing['openwebui_api_key'].to_s
      end
    end
  end
end
