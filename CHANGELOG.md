# Changelog

All notable changes to the GitHub MCP Extension for Zed will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.4] - 2025-01-19

### Added

- **Cross-Platform Wrapper Scripts**: Added `github-mcp-wrapper.sh` (Bash) and `github-mcp-wrapper.ps1` (PowerShell)
- **Zero Dependencies**: Eliminated Node.js requirement - uses system shell (Bash/PowerShell)
- **Auto-Detection**: Extension automatically finds and uses appropriate wrapper script for platform
- **Wrapper Mode Setting**: New `use_wrapper_script` boolean setting to enable automatic authentication
- **GitHub CLI Integration**: Automatic token detection via `gh auth token` command
- **Environment Variable Support**: Fallback authentication using `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN`
- **Token File Support**: Reads tokens from `~/.config/gh/hosts.yml`, `~/.github_token`, and other common locations
- **Token Validation**: Optional token validation against GitHub API before starting server
- **Debug Mode**: Verbose logging support via `LOG_LEVEL=debug`

### Enhanced

- **Cross-Platform Compatibility**: Native support for Unix/Linux/macOS (Bash) and Windows (PowerShell)
- **Documentation**: Updated README and installation instructions to reflect dependency removal
- **Security**: No hardcoded tokens required in configuration files
- **Performance**: Reduced overhead by eliminating Node.js runtime dependency

### Technical Details

- **Platform Detection**: Automatically selects Bash or PowerShell wrapper based on OS
- **Backwards Compatibility**: Node.js wrapper (`github-mcp-wrapper.js`) maintained as fallback
- **Authentication Priority**: CLI tokens → Environment variables → Token files
- **WASM Sandbox Bypass**: Wrapper scripts run outside Zed's WASM sandbox to access system resources

### Breaking Changes

- None - all existing configurations remain functional

### Dependencies

- **Removed**: Node.js requirement (was previously required for wrapper script)
- GitHub CLI (optional, recommended for automatic authentication)
- Go (for GitHub's official MCP server)

### Configuration Examples

#### Traditional Method (Unchanged)

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

#### Wrapper Method (Recommended - Zero Dependencies)

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

### Benefits

- ✅ **Zero additional dependencies** - uses system shell
- ✅ **Cross-platform ready** - supports Unix/Linux/macOS and Windows
- ✅ No hardcoded tokens in Zed settings
- ✅ Automatic token refresh via GitHub CLI
- ✅ Auto-detection of wrapper script path
- ✅ Better security practices
- ✅ Seamless GitHub CLI integration

### Files Added

- `wrappers/github-mcp-wrapper.sh` - Bash wrapper script for Unix/Linux/macOS
- `wrappers/github-mcp-wrapper.ps1` - PowerShell wrapper script for Windows
- `wrappers/github-mcp-wrapper.js` - Node.js wrapper script (backwards compatibility)
- `DEPENDENCY_REMOVAL_SUMMARY.md` - Technical details of dependency removal

### Files Modified

- `src/mcp_server_github.rs` - Platform-aware wrapper detection with wrappers/ subfolder support
- `README.md` - Updated for cross-platform support and organized file structure
- `docs/configuration.md` - Removed Node.js requirement and updated paths
- `docs/default_settings.jsonc` - Updated prerequisite comments

## [0.0.3] - Previous Release

### Added

- Initial GitHub MCP server integration
- Basic token authentication
- Core GitHub API operations

---

**Migration Guide**: No migration required. Existing configurations continue to work. New wrapper approach is optional but recommended for better security and automation.
