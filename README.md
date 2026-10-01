# GitHub MCP Server Extension for Zed

This extension integrates [GitHub MCP Server](https://github.com/github/github-mcp-server) as a context server for
[Zed's](https://zed.dev) [Agent Panel.](https://zed.dev/docs/ai/overview)

To install navigate to: **Zed** > **Extensions**. Or use the command palette ([macOS](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-macos.json#L581), [Linux](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-linux.json#L459)) to search `extensions`.

## Authentication

**OAuth (default).** On github.com no setup is needed. On the first tool call, the server opens your browser to log in. The token is kept in memory only, so you'll log in again after Zed restarts. If you take longer than Zed's request timeout (`context_server_timeout`, 60 seconds by default) to approve, the first request fails; retry it once you've approved.

**Personal access token.** [Create a fine-grained token](https://github.com/settings/personal-access-tokens/new) (or a [classic token with `repo` scope](https://github.com/settings/tokens/new?description=zed-mcp-server-github&scopes=repo)). A token is required for GitHub Enterprise Server and ghe.com. Either export it from your shell profile, which keeps it out of Zed's settings:

```sh
export GITHUB_PERSONAL_ACCESS_TOKEN="<GITHUB_PERSONAL_ACCESS_TOKEN>"
```

Zed loads your login shell's environment at startup and passes it to the server, so restart Zed after changing it. `GITHUB_HOST`, `GITHUB_READ_ONLY`, and `GITHUB_TOOLSETS` work the same way. Values in Zed's settings take precedence over the environment.

Or add it to your settings:

```json
"context_servers": {
  "mcp-server-github": {
    "settings": {
      "github_personal_access_token": "<GITHUB_PERSONAL_ACCESS_TOKEN>"
    }
  }
},
```

## Settings

All settings are optional.

| Setting | Description |
| --- | --- |
| `github_personal_access_token` | Token to use instead of OAuth. |
| `github_host` | GitHub Enterprise Server or ghe.com host, e.g. `https://github.example.com`. |
| `read_only` | `true` to only expose read-only tools. |
| `toolsets` | Toolsets to enable, e.g. `["repos", "issues", "pull_requests"]`. See the [list of toolsets](https://github.com/github/github-mcp-server#available-toolsets). |
