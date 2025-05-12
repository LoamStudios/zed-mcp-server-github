# GitHub MCP Server Extension for Zed

This extension integrates [GitHub MCP Server](https://github.com/github/github-mcp-server) as a context server for
[Zed's](https://zed.dev) [Agent Panel.](https://zed.dev/docs/ai/overview)

To install navigate to: **Zed** > **Extensions**. Or use the command palette ([macOS](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-macos.json#L581), [Linux](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-linux.json#L459)) to search `extensions`.

You'll need to [create](https://github.com/settings/tokens) a PAT with `repo` permissions.

```json
"context_servers": {
  "mcp-server-github": {
      "settings": {
      "github_personal_access_token": "<GITHUB_PERSONAL_ACCESS_TOKEN>"
    }
  }
},
```
