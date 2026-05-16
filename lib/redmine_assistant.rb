module RedmineAssistant
  PLUGIN_ID = 'redmine_ai_assistant'.freeze
  LEGACY_PLUGIN_ID = 'redmine_assistant'.freeze
  DEFAULT_ISSUE_SUMMARY_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an AI assistant for Redmine issue management.

    Your task is to generate a professional and meaningful summary
    of a Redmine ticket for project teams, managers, and developers.

    Rules:
    - Understand the actual problem, bug, feature request, or task.
    - Analyze journals, notes, and comments carefully.
    - Identify progress, blockers, fixes attempted, and current state.
    - Ignore duplicate or noisy comments.
    - Keep the summary concise but informative.
    - Use professional language.
    - Highlight important technical details when relevant.
    - Mention pending actions if any.
    - Mention blockers or risks if present.
    - Mention completed work clearly.
    - Do not hallucinate missing information.
    - If information is insufficient, explicitly mention it.

    Return the response in the following format:

    Ticket Summary:
    <meaningful summary>

    Current Status:
    <short status>

    Key Points:
    - point 1
    - point 2
    - point 3

    Pending Actions:
    - action 1
    - action 2

    Risks / Blockers:
    - blocker 1
    - blocker 2
  PROMPT

  DEFAULT_ISSUE_SUMMARY_USER_PROMPT = <<~PROMPT.freeze
    Please summarize the following Redmine ticket.

    {{issue_content}}
  PROMPT

  DEFAULT_SETTINGS = {
    'enabled' => '1',
    'openwebui_base_url' => 'https://example.com/openui',
    'openwebui_api_key' => '',
    'default_chat_model' => 'qwen2.5-coder:7b',
    'embedding_model' => 'mxbai-embed-large',
    'chat_provider' => 'openwebui',
    'ollama_base_url' => 'http://localhost:11434',
    'issue_summary_enabled' => '1',
    'issue_summary_system_prompt' => DEFAULT_ISSUE_SUMMARY_SYSTEM_PROMPT,
    'issue_summary_user_prompt' => DEFAULT_ISSUE_SUMMARY_USER_PROMPT,
    'run_in_background' => '0',
    'issue_chunk_size' => '100'
  }.freeze

  def self.settings
    current = plugin_settings(PLUGIN_ID)
    legacy = plugin_settings(LEGACY_PLUGIN_ID)
    DEFAULT_SETTINGS.merge(legacy).merge(current)
  end

  def self.plugin_settings(plugin_id)
    if Setting.respond_to?("plugin_#{plugin_id}")
      Setting.send("plugin_#{plugin_id}") || {}
    else
      setting = Setting.where(:name => "plugin_#{plugin_id}").first
      deserialize_plugin_settings(setting)
    end
  end

  def self.deserialize_plugin_settings(setting)
    return {} unless setting

    raw_value = setting.read_attribute(:value)
    return raw_value if raw_value.is_a?(Hash)
    return {} unless raw_value.is_a?(String) && raw_value.present?

    value = YAML.safe_load(
      raw_value,
      :permitted_classes => Rails.configuration.active_record.yaml_column_permitted_classes,
      :aliases => true
    )
    value.is_a?(Hash) ? value : {}
  rescue => e
    Rails.logger.warn("[redmine_ai_assistant] could not read legacy plugin settings: #{e.class}: #{e.message}")
    {}
  end

  def self.project_enabled?(project)
    project &&
      (project.module_enabled?(:redmine_ai_assistant) ||
       project.module_enabled?(:redmine_assistant))
  end

  def self.enabled?
    settings['enabled'].to_s == '1'
  end

  def self.run_in_background?
    settings['run_in_background'].to_s == '1'
  end

  def self.issue_summary_enabled?
    settings['issue_summary_enabled'].to_s == '1'
  end

  def self.issue_chunk_size
    size = settings['issue_chunk_size'].to_i
    size > 0 ? size : 100
  end

  def self.apply_patches
    require_dependency 'projects_helper'
    require_dependency 'settings_controller'
    require_dependency 'redmine_assistant/patches/projects_helper_patch'
    require_dependency 'redmine_assistant/patches/settings_controller_patch'

    unless ProjectsHelper.ancestors.include?(RedmineAssistant::Patches::ProjectsHelperPatch)
      ProjectsHelper.send(:prepend, RedmineAssistant::Patches::ProjectsHelperPatch)
    end

    unless SettingsController.ancestors.include?(RedmineAssistant::Patches::SettingsControllerPatch)
      SettingsController.send(:prepend, RedmineAssistant::Patches::SettingsControllerPatch)
    end
  end
end

if defined?(Rails.configuration.to_prepare)
  Rails.configuration.to_prepare do
    RedmineAssistant.apply_patches
  end
else
  ActionDispatch::Callbacks.to_prepare do
    RedmineAssistant.apply_patches
  end
end

Rails.application.config.after_initialize do
  RedmineAssistant.apply_patches
end
