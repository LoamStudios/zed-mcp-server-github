# GitHub MCP Server Extension for Zed

This extension integrates [GitHub MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/github) as a context server for
Zed's Assistant.


You'll need to [create](https://github.com/settings/tokens) a PAT with `repo` permissions.

```
"context_servers": {
    "mcp-server-github": {
      "settings": {
        "github_personal_access_token": "<GITHUB_PERSONAL_ACCESS_TOKEN>"
      }
    }
  },
```
