# 🔐 How It Works

Zed extensions run in a secure **WebAssembly sandbox** that cannot access environment variables or execute commands. The wrapper script runs **outside** the sandbox to bridge this gap:

```text
Zed Extension (WASM) → Wrapper Script (Bash/PowerShell) → MCP Server (Go)
                           ↓
                    GitHub CLI / Environment Variables
```

**Benefits:**

- ✅ **Zero dependencies** - uses system shell
- ✅ **Cross-platform** - Bash (Unix/Linux/macOS) + PowerShell (Windows)
- ✅ **Secure** - no hardcoded tokens
- ✅ **Automatic** - GitHub CLI integration with smart fallbacks
- ✅ **Simple** - just enable `use_wrapper_script: true`

## 🛠️ Advanced Setup

### Prerequisites

- **GitHub CLI** (optional): `brew install gh && gh auth login`
- **Go** (for MCP server): `brew install go`

### Authentication Methods

The wrapper tries these in order:

1. **GitHub CLI**: `gh auth token` (if available)
2. **Environment variables**: `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN`
3. **Token files**: `~/.config/gh/hosts.yml`, `~/.github_token`

## Testing Authentication

```bash
# macOS/Linux
./wrappers/github-mcp-wrapper.sh --validate

# Windows
.\wrappers\github-mcp-wrapper.ps1 -Validate

# Check GitHub CLI
gh auth status
```

## 🔍 Troubleshooting

**"No GitHub token found"**

```bash
gh auth login                           # Recommended
export GITHUB_TOKEN="your_token_here"   # Alternative
```

**"MCP server not found"**

```bash
brew install go  # Required for GitHub's MCP server
```

**"Permission denied"** (macOS/Linux)

```bash
chmod +x wrappers/github-mcp-wrapper.sh
```

<old_text line=164>
```bash
LOG_LEVEL=debug ./github-mcp-wrapper.sh --validate
```

**Debug mode:**

```bash
LOG_LEVEL=debug ./wrappers/github-mcp-wrapper.sh --validate
```

**Fallback to direct token:**

```json
{
  "context_servers": {
    "mcp-server-github": {
      "source": "extension",
      "settings": {
        "github_personal_access_token": "ghp_your_token_here",
        "use_wrapper_script": false
      }
    }
  }
}
```

### Cross-Platform Support

The wrapper automatically detects your platform and uses the appropriate script:

- **Unix/Linux/macOS**: Uses Bash shell script (`wrappers/github-mcp-wrapper.sh`)
- **Windows**: Uses PowerShell script (`wrappers/github-mcp-wrapper.ps1`)
- **Fallback**: Node.js script (`wrappers/github-mcp-wrapper.js`) for backwards compatibility

**Note**: You only need ONE authentication method. GitHub CLI is recommended but not required.

Choose the method that best fits your workflow!
