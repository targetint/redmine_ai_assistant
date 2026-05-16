# Redmine AI Assistant

Redmine AI Assistant adds AI assistant features to Redmine. The first module syncs each Redmine project into an OpenWebUI Knowledgebase.

## Compatibility

Designed for Redmine 4.x, 5.x, and 6.x and their Rails versions. The migration uses Rails 4.2 migration syntax and the code avoids Rails 7-only APIs.

## Features

- Per-project **Sync AI Knowledgebase** button.
- Project overview box and project settings tab.
- Exports project info, issues, issue descriptions, journal notes, wiki pages, news, and news comments when available.
- Reuses an existing OpenWebUI Knowledgebase with the same project name, or creates one.
- Stores the OpenWebUI Knowledgebase mapping in Redmine.
- Splits large projects into multiple uploaded text files.
- Optional ActiveJob background sync with direct sync fallback.
- Collapsible issue-page Ticket Summary generated from issue updates and public journal notes using Ollama.

## Installation

1. Place the plugin at:

   ```sh
   plugins/redmine_ai_assistant
   ```

2. Run migrations:

   ```sh
   bundle exec rake redmine:plugins:migrate NAME=redmine_ai_assistant RAILS_ENV=production
   ```

3. Restart Redmine.

4. Enable the **Redmine AI Assistant** project module for projects that should sync.

5. Grant the `Sync AI Knowledgebase` permission to the desired roles, normally Manager.

## Uninstall

1. Disable the **Redmine AI Assistant** module in projects that use it.

2. Roll back the plugin migrations:

   ```sh
   bundle exec rake redmine:plugins:migrate NAME=redmine_ai_assistant VERSION=0 RAILS_ENV=production
   ```

   This removes the plugin database tables and stored sync/summary records.

3. Remove the plugin directory:

   ```sh
   rm -rf plugins/redmine_ai_assistant
   ```

4. Restart Redmine.

If this plugin was previously installed under the old folder/name `redmine_ai_assistant`, make sure that old directory is also removed before restarting Redmine.

## Settings

Open **Administration -> Plugins -> Redmine AI Assistant -> Configure**.

- **OpenWebUI base URL**: `https://example.com/openui`
- **OpenWebUI API key**: API key generated in OpenWebUI.
- **Default chat model**: recommended `qwen2.5-coder:7b` or `llama3.1:8b`.
- **Embedding model**: recommended `mxbai-embed-large` or `nomic-embed-text`.
- **Ticket summary chat provider**: use `OpenWebUI` when your OpenWebUI URL/API key are already configured; use `Direct Ollama` only when Redmine can reach Ollama's native API.
- **Ollama base URL**: default `http://localhost:11434`.
- **Enable ticket summaries**: creates a new versioned summary after issue updates.
- **Enable AI Knowledgebase sync**: master enable/disable switch.
- **Run sync in background**: uses ActiveJob when queue workers are configured.
- **Issue chunk size**: number of issues per uploaded text file.

The Ruby namespace and database tables intentionally remain `RedmineAssistant` / `redmine_ai_assistant_*` for compatibility with existing data.

## OpenWebUI API Key

Create an API key in Open WebUI, then paste it into the plugin settings. The key is stored in Redmine plugin settings and is never logged by this plugin.

1. Log in to Open WebUI as the user Redmine should act as.

2. Open **Settings -> Account**.

3. Find the **API Keys** section.

4. Create a new key. Use a clear name such as:

   ```text
   Redmine AI Assistant
   ```

5. Copy the key immediately and store it in Redmine:

   ```text
   Administration -> Plugins -> Redmine AI Assistant -> Configure -> OpenWebUI API key
   ```

6. Set **OpenWebUI base URL** to the browser-accessible root URL, for example:

   ```text
   https://example.com/openui
   ```

7. Save the plugin settings.

Open WebUI API keys are personal access tokens and inherit the permissions of the user that created them. If the API key section is not visible, an Open WebUI admin may need to enable API keys under **Admin Panel -> Settings -> General -> Enable API Keys**, and non-admin users may need the API Keys feature permission.

You can verify the key from the Redmine server with:

```sh
curl -H "Authorization: Bearer YOUR_OPENWEBUI_API_KEY" \
  https://example.com/openui/api/models
```

Expected result: a JSON response listing available models. If you get `401 Unauthorized`, check that the key was copied correctly, has not been deleted, and is allowed to access the endpoint.

Open WebUI does not show API keys again after creation. If you lose the key, delete it and create a new one.

## OpenWebUI Endpoint Notes

OpenWebUI API endpoints can vary by version. The paths are centralized in:

```ruby
RedmineAssistant::OpenwebuiClient
```

Current defaults:

- `GET /api/v1/knowledge/`
- `POST /api/v1/knowledge/create`
- `POST /api/v1/files/`
- `POST /api/v1/knowledge/:id/file/add`

If your OpenWebUI version uses different paths, update the constants in `app/services/redmine_ai_assistant/openwebui_client.rb`.

## Security

- Users must have `:sync_redmine_ai_assistant` on the project.
- Export respects normal Redmine project permissions for issues, wiki, and news.
- API keys, tokens, secrets, and password-like values are filtered from exported text where they match common patterns.
- The plugin logs project IDs, Knowledgebase names/IDs, upload filenames, and errors. It does not log API keys or full exported content.

## Troubleshooting

- **Button not visible**: enable the project module and grant the role permission.
- **Disabled message**: enable sync in plugin settings.
- **401/403 from OpenWebUI**: check the API key and user permissions in OpenWebUI.
- **404 from OpenWebUI**: your OpenWebUI version may use different API paths; adjust the constants in `OpenwebuiClient`.
- **Background sync does not run**: disable background sync or configure an ActiveJob queue worker for your Redmine deployment.
- **Large projects time out**: reduce issue chunk size or enable background sync.
