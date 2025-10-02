# GitHub MCP Extension Configuration

## Quick Start (Recommended) ⭐

1. **Install GitHub CLI**: `brew install gh`
2. **Authenticate**: `gh auth login`
3. **Configure Zed**:

```json
{
  "context_servers": {
    "mcp-server-github": {
      "source": "extension",
      "settings": {
        "use_wrapper_script": true
      }
    }
  }
}
```

That's it! The extension automatically handles authentication using your GitHub CLI credentials.

## Alternative: Direct Token

If you prefer not to use GitHub CLI:

1. **Get token**: `gh auth token` or create at [github.com/settings/tokens](https://github.com/settings/tokens)
2. **Configure Zed**:

```json
{
  "context_servers": {
    "mcp-server-github": {
      "source": "extension",
      "settings": {
        "github_personal_access_token": "ghp_your_token_here"
      }
    }
  }
}
```

## Benefits of GitHub CLI Approach

✅ **No hardcoded tokens** in settings
✅ **Automatic token refresh**
✅ **Zero dependencies** - uses system shell
✅ **Cross-platform** - works on macOS, Linux, Windows
✅ **Secure** - tokens managed by GitHub CLI

## Authentication Methods

The wrapper tries these in order:

1. **GitHub CLI**: `gh auth token`
2. **Environment variables**: `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`
3. **Token files**: `~/.config/gh/hosts.yml`, `~/.github_token`

## Troubleshooting

**"No GitHub token found"**
```bash
gh auth login
```

**"Wrapper script not found"**
- Ensure `use_wrapper_script: true` is set
- Extension auto-detects wrapper scripts in `wrappers/` folder

**Need to validate setup?**
```bash
./wrappers/github-mcp-wrapper.sh --validate  # macOS/Linux
.\wrappers\github-mcp-wrapper.ps1 -Validate  # Windows
```

## Cross-Platform Support

- **macOS/Linux**: Uses Bash (`wrappers/github-mcp-wrapper.sh`)
- **Windows**: Uses PowerShell (`wrappers/github-mcp-wrapper.ps1`)
- **Fallback**: Node.js (`wrappers/github-mcp-wrapper.js`)

Choose the method that works best for you!
