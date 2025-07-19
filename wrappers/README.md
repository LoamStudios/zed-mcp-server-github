# GitHub MCP Wrapper Scripts

This directory contains cross-platform wrapper scripts that enable automatic GitHub authentication for the GitHub MCP Extension in Zed.

## Overview

Zed extensions run in a WebAssembly (WASM) sandbox that cannot access environment variables or execute system commands. These wrapper scripts run outside the sandbox to bridge this gap, providing seamless GitHub authentication.

## Scripts

### `github-mcp-wrapper.sh`

**Platform**: Unix, Linux, macOS
**Runtime**: Bash shell (universally available)
**Purpose**: Primary wrapper for Unix-like systems

**Features**:

- GitHub CLI integration (`gh auth token`)
- Environment variable fallbacks
- Token file support (including GitHub CLI config)
- HTTP token validation using curl/wget
- Comprehensive error handling and logging
- Signal handling for clean shutdown

### `github-mcp-wrapper.ps1`

**Platform**: Windows
**Runtime**: PowerShell (built into Windows)
**Purpose**: Native Windows wrapper

**Features**:

- PowerShell-native implementation
- Same authentication methods as Bash version
- Token validation using `Invoke-RestMethod`
- Windows-specific file paths and commands
- Process management with `Start-Process`

### `github-mcp-wrapper.js`

**Platform**: Cross-platform
**Runtime**: Node.js
**Purpose**: Backwards compatibility fallback

**Features**:

- Original Node.js implementation
- Maintained for backwards compatibility
- Full feature parity with shell versions
- Comprehensive error handling

## Usage

These scripts are automatically detected and used by the Zed extension when `use_wrapper_script: true` is configured. The extension selects the appropriate script based on the detected platform.

### Manual Testing

```bash
# Unix/Linux/macOS
./github-mcp-wrapper.sh --validate

# Windows
.\github-mcp-wrapper.ps1 -Validate

# Node.js (any platform)
node github-mcp-wrapper.js --validate
```

### Command Line Options

#### Bash Script (`github-mcp-wrapper.sh`)

```bash
./github-mcp-wrapper.sh [OPTIONS] [-- SERVER_ARGS...]

OPTIONS:
    -p, --port PORT     Port for MCP server (default: 3000)
    -s, --server PATH   Path to MCP server executable
    -t, --token TOKEN   Use specific GitHub token
    -v, --validate      Validate token before starting server
    -h, --help         Show help message
```

#### PowerShell Script (`github-mcp-wrapper.ps1`)

```powershell
.\github-mcp-wrapper.ps1 [OPTIONS]

OPTIONS:
    -Port PORT          Port for MCP server (default: 3000)
    -Server PATH        Path to MCP server executable
    -Token TOKEN        Use specific GitHub token
    -Validate           Validate token before starting server
    -Help              Show help message
```

#### Node.js Script (`github-mcp-wrapper.js`)

```bash
node github-mcp-wrapper.js [OPTIONS] [-- SERVER_ARGS...]

OPTIONS:
    -p, --port PORT     Port for MCP server (default: 3000)
    -s, --server PATH   Path to MCP server executable
    -t, --token TOKEN   Use specific GitHub token
    -v, --validate      Validate token before starting server
    -h, --help         Show help message
```

## Authentication Methods

All scripts try authentication methods in this priority order:

1. **GitHub CLI**: `gh auth token` (if available and authenticated)
2. **Environment Variables**: `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN`
3. **Token Files**:
   - `~/.config/gh/hosts.yml` (GitHub CLI config)
   - `~/.github_token`
   - `~/.config/github/token`

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub personal access token | - |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | Alternative token variable | - |
| `GH_TOKEN` | Another token variable | - |
| `MCP_SERVER_PATH` | Custom MCP server path | auto-detect |
| `GITHUB_MCP_PORT` | Server port | 3000 |
| `LOG_LEVEL` | Logging verbosity (debug, info, warn, error) | info |

## Examples

### Basic Usage

```bash
# Auto-detect authentication and start server
./github-mcp-wrapper.sh

# Validate authentication setup
./github-mcp-wrapper.sh --validate

# Custom port
./github-mcp-wrapper.sh --port 3001

# Debug mode
LOG_LEVEL=debug ./github-mcp-wrapper.sh --validate
```

### With Specific Token

```bash
# Use specific token
./github-mcp-wrapper.sh --token ghp_your_token_here

# Validate specific token
./github-mcp-wrapper.sh --token ghp_your_token_here --validate
```

### Windows Examples

```powershell
# Basic usage
.\github-mcp-wrapper.ps1

# Validate authentication
.\github-mcp-wrapper.ps1 -Validate

# Custom port
.\github-mcp-wrapper.ps1 -Port 3001

# Debug mode
$env:LOG_LEVEL="debug"; .\github-mcp-wrapper.ps1 -Validate
```

## Troubleshooting

### Common Issues

**"No GitHub token found"**

```bash
# Setup GitHub CLI (recommended)
gh auth login

# Or set environment variable
export GITHUB_TOKEN="ghp_your_token_here"
```

**"Permission denied"** (Unix/Linux/macOS)

```bash
chmod +x github-mcp-wrapper.sh
```

**"MCP server not found"**

```bash
# Install Go for GitHub's official MCP server
brew install go  # macOS
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Bash/Unix
LOG_LEVEL=debug ./github-mcp-wrapper.sh --validate

# PowerShell/Windows
$env:LOG_LEVEL="debug"; .\github-mcp-wrapper.ps1 -Validate

# Node.js
LOG_LEVEL=debug node github-mcp-wrapper.js --validate
```

## Development

### Adding New Authentication Methods

To add new authentication methods, update the `get_github_token()` function in each script. Maintain the same priority order across all implementations.

### Testing

```bash
# Test script syntax
bash -n github-mcp-wrapper.sh  # Bash syntax check

# Test authentication
./github-mcp-wrapper.sh --validate

# Test with debug logging
LOG_LEVEL=debug ./github-mcp-wrapper.sh --validate
```

### Cross-Platform Considerations

- **File paths**: Use platform-appropriate separators
- **Commands**: Test availability before use (`command -v`, `Get-Command`)
- **HTTP clients**: Bash uses curl/wget, PowerShell uses `Invoke-RestMethod`
- **Process management**: Different signal handling per platform

## Security Notes

- Scripts validate tokens against GitHub API before use
- Tokens are passed via environment variables to child processes
- No tokens are logged or stored permanently
- Scripts support secure token file locations used by GitHub CLI

## Contributing

When modifying wrapper scripts:

1. Maintain feature parity across all platforms
2. Test on target platforms
3. Update this README with any new features
4. Follow existing error handling patterns
5. Maintain backwards compatibility where possible
