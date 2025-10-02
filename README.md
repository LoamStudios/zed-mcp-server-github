# GitHub MCP Extension for Zed

A Zed extension that provides GitHub integration through the Model Context Protocol (MCP), enabling AI-powered GitHub operations directly within your editor.

## 🚀 Quick Start

1. **Install Extension**: Search "GitHub MCP Server" in Zed Extensions
2. **Configure Authentication**: Choose your preferred method below
3. **Start Using**: Ask AI about GitHub operations in natural language

## ⚙️ Authentication Setup

### 🔧 Automatic Setup (Recommended) ⭐

**Just 2 steps:**

1. **Authenticate with GitHub**: `gh auth login`
2. **Configure Zed**:

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

Done! Extension automatically uses your GitHub CLI credentials.

### 📋 Manual Token Setup

If you prefer direct token configuration:

```json
{
  "context_servers": {
    "mcp-server-github": {
      "source": "extension",
      "settings": {
        "github_personal_access_token": "your_token_here"
      }
    }
  }
}
```

Get token: `gh auth token` or [github.com/settings/tokens](https://github.com/settings/tokens)

## 📖 Usage Examples

Once configured, you can use natural language commands in Zed's AI chat:

### Repository Operations

- "Show me my GitHub repositories"
- "List files in the src directory of my main project"
- "Create a new repository called 'my-awesome-project'"

### File Management

- "Create a README.md with installation instructions"
- "Update the version in package.json to 2.0.0"
- "Show me the contents of the main.rs file"

### Issue & PR Management

- "Create an issue about the login bug I found"
- "Show me all open pull requests waiting for review"
- "List issues labeled 'bug' in my repository"

### Code Search & Analysis

- "Find all functions containing 'authenticate' in this repo"
- "Show me security vulnerabilities in my projects"
- "Search for React components in public repositories"

### CI/CD & Workflows

- "Check the status of my latest GitHub Actions run"
- "Why did my last build fail?"
- "Create a new release for version 1.5.0"

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/LoamStudios/zed-mcp-server-github.git
cd zed-mcp-server-github
cargo build --release
chmod +x wrappers/github-mcp-wrapper.sh  # macOS/Linux
./wrappers/github-mcp-wrapper.sh --validate  # Test setup
```
