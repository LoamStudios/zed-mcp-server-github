# GitHub MCP Server Extension for Zed

This extension integrates [GitHub MCP Server](https://github.com/github/github-mcp-server) as a context server for
(Zed's)[https://zed.dev] [Assistant.](https://zed.dev/docs/assistant/assistant)

This extension integrates [GitHub MCP Server](https://github.com/github/github-mcp-server) as a context server for [Zed's](https://zed.dev) [Assistant](https://zed.dev/docs/assistant/assistant).

## 🚀 Installation

1. Navigate to: **Zed** > **Extensions**
   - Or use the command palette ([macOS](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-macos.json#L581), [Linux](https://github.com/zed-industries/zed/blob/main/assets/keymaps/default-linux.json#L459)) to search `extensions`

2. [Create a GitHub Personal Access Token](https://github.com/settings/tokens) with `repo` permissions

3. Add the following configuration to your root level settings:

```json
"context_servers": {
    "mcp-server-github": {
      "settings": {
        "github_personal_access_token": "<GITHUB_PERSONAL_ACCESS_TOKEN>"
      }
    }
}
```

4. Enable and configure the GitHub profile using Zed's tools panel

## 🛠️ Available Tools

This extension uses [GitHub MCP Server](https://github.com/github/github-mcp-server) under the hood. Below is a quick reference of available tools:

| Tool Name | Description |
|-----------|-------------|
| get_me | Get details of the authenticated user |
| get_issue | Get details of a specific issue |
| create_issue | Create a new issue |
| list_issues | List repository issues |
| get_pull_request | Get PR details |
| create_pull_request | Create a new PR |
| merge_pull_request | Merge a PR |
| search_code | Search code across repositories |
| create_branch | Create a new branch |
| push_files | Push multiple files in a commit |
| list_commits | Get branch commits |

For complete documentation of all available tools and their parameters, please refer to the [GitHub MCP Server Documentation](https://github.com/github/github-mcp-server#tools).

## 📝 License

[MIT](LICENSE)
