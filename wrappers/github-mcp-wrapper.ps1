# GitHub MCP Server Wrapper Script for Zed (Windows PowerShell)
#
# Cross-platform PowerShell wrapper that provides automatic GitHub authentication
# for the GitHub MCP (Model Context Protocol) server, bypassing Zed's WASM
# sandbox limitations to enable seamless integration with GitHub CLI and
# environment variables.
#
# Features:
# - Automatic token detection via GitHub CLI (`gh auth token`)
# - Fallback to environment variables (GITHUB_TOKEN, etc.)
# - Token file support (~/.config/gh/hosts.yml, ~/.github_token)
# - Silent authentication verification
# - Support for GitHub's official Go-based MCP server
# - Comprehensive error handling and validation
# - Auto-detection by Zed extension (no manual path configuration needed)
#
# Usage:
#   Automatic: Set `use_wrapper_script: true` in Zed settings
#   Manual: .\github-mcp-wrapper.ps1 [OPTIONS]
#
# Examples:
#   .\github-mcp-wrapper.ps1 -Validate
#   .\github-mcp-wrapper.ps1 -Port 3001
#   $env:LOG_LEVEL="debug"; .\github-mcp-wrapper.ps1
#
# Part of the Zed GitHub MCP Extension
# Repository: https://github.com/LoamStudios/zed-mcp-server-github
#
# @author Jeffrey Guenther <guenther.jeffrey@gmail.com>
# @author James Inman <james@jamesinman.co.uk>
# @version 0.0.5
# @license MIT

param(
    [string]$Port = $env:GITHUB_MCP_PORT ?? "3000",
    [string]$Server = $env:MCP_SERVER_PATH ?? "",
    [string]$Token = "",
    [switch]$Validate,
    [switch]$Help,
    [string[]]$ServerArgs = @()
)

# Configuration
$LogLevel = $env:LOG_LEVEL ?? "info"

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Write-Host "[$timestamp] $Message" -ForegroundColor Blue
}

function Write-Error-Log {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warn-Log {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Success-Log {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Check GitHub CLI authentication silently
function Test-GitHubCliAuth {
    if (-not (Test-Command "gh")) {
        Write-Warn-Log "GitHub CLI not found - will try other authentication methods"
        return $false
    }

    try {
        & gh auth status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "GitHub CLI authentication verified"
            return $true
        }
        else {
            Write-Warn-Log "GitHub CLI is installed but not authenticated"
            Write-Warn-Log "Consider running 'gh auth login' for seamless authentication"
            return $false
        }
    }
    catch {
        Write-Warn-Log "GitHub CLI authentication check failed"
        return $false
    }
}

# Get GitHub token using various methods
function Get-GitHubToken {
    # Method 1: Try gh auth token command
    if (Test-Command "gh") {
        Write-Log "Attempting to get token from GitHub CLI..."
        try {
            $token = & gh auth token 2>$null
            if ($LASTEXITCODE -eq 0 -and $token -and $token -ne "null" -and $token.Length -gt 0) {
                Write-Log "Successfully retrieved token from GitHub CLI"
                return $token.Trim()
            }
        }
        catch {
            Write-Warn-Log "GitHub CLI is installed but no valid token found"
        }
    }

    # Method 2: Try environment variables
    Write-Log "Checking environment variables..."
    $envTokens = @("GITHUB_TOKEN", "GITHUB_PERSONAL_ACCESS_TOKEN", "GH_TOKEN")

    foreach ($envVar in $envTokens) {
        $envValue = [System.Environment]::GetEnvironmentVariable($envVar)
        if ($envValue) {
            Write-Log "Found $envVar environment variable"
            return $envValue
        }
    }

    # Method 3: Try reading from common token files
    $tokenFiles = @(
        "$env:USERPROFILE\.config\gh\hosts.yml",
        "$env:USERPROFILE\.github_token",
        "$env:USERPROFILE\.config\github\token"
    )

    foreach ($tokenFile in $tokenFiles) {
        if (Test-Path $tokenFile) {
            Write-Log "Checking token file: $tokenFile"
            try {
                $content = Get-Content $tokenFile -Raw

                if ($tokenFile -like "*hosts.yml") {
                    # Parse GitHub CLI config file (simple YAML parsing)
                    $lines = $content -split "`n"
                    $inGitHubSection = $false

                    foreach ($line in $lines) {
                        if ($line -match "github\.com:") {
                            $inGitHubSection = $true
                            continue
                        }
                        if ($inGitHubSection -and $line -match "oauth_token:\s*(.+)") {
                            $token = $matches[1].Trim().Trim('"')
                            if ($token) {
                                Write-Log "Successfully retrieved token from $tokenFile"
                                return $token
                            }
                        }
                    }
                }
                else {
                    # Read plain token files
                    $token = $content.Trim()
                    if ($token) {
                        Write-Log "Successfully retrieved token from $tokenFile"
                        return $token
                    }
                }
            }
            catch {
                Write-Warn-Log "Failed to read ${tokenFile}: $($_.Exception.Message)"
            }
        }
    }

    throw "No GitHub token found"
}

# Validate GitHub token
function Test-GitHubToken {
    param([string]$Token)

    Write-Log "Validating GitHub token..."

    if ($Token.Length -lt 20) {
        throw "Token appears to be too short (less than 20 characters)"
    }

    try {
        $headers = @{
            "Authorization" = "token $Token"
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "GitHub-MCP-Wrapper/1.0.0"
        }

        $response = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -TimeoutSec 10

        if ($response.login) {
            Write-Success-Log "Token validation successful"
            return $true
        }
        else {
            throw "Token validation failed - no login field in response"
        }
    }
    catch {
        throw "Token validation failed: $($_.Exception.Message)"
    }
}

# Find MCP server executable
function Find-McpServer {
    $possiblePaths = @()

    # Add configured path
    if ($Server) {
        $possiblePaths += $Server
    }

    # Add Go-based server if Go is available
    if (Test-Command "go") {
        $possiblePaths += "github.com/github/github-mcp-server/cmd/github-mcp-server@latest"
    }

    # Try which command for legacy servers
    if (Test-Command "where") {
        try {
            $wherePath = & where mcp-server-github 2>$null
            if ($LASTEXITCODE -eq 0 -and $wherePath) {
                $possiblePaths += $wherePath
            }
        }
        catch {
            # Ignore errors
        }
    }

    # Try npm global if npm exists
    if (Test-Command "npm") {
        try {
            $npmRoot = & npm root -g 2>$null
            if ($LASTEXITCODE -eq 0 -and $npmRoot) {
                $possiblePaths += @(
                    "$npmRoot\@modelcontextprotocol\server-github\dist\index.js",
                    "$npmRoot\mcp-server-github\dist\index.js"
                )
            }
        }
        catch {
            # Ignore errors
        }
    }

    # Add more common locations
    $possiblePaths += @(
        "$env:USERPROFILE\.local\bin\mcp-server-github.exe",
        "$env:USERPROFILE\.npm-global\bin\mcp-server-github.exe",
        ".\node_modules\.bin\mcp-server-github.exe"
    )

    foreach ($serverPath in $possiblePaths) {
        if ($serverPath) {
            # Special handling for Go-based server
            if ($serverPath -like "*github.com/github/github-mcp-server*") {
                Write-Log "Found GitHub's official Go-based MCP server"
                return $serverPath
            }
            # Check if file exists for other paths
            if (Test-Path $serverPath) {
                Write-Log "Found MCP server at: $serverPath"
                return $serverPath
            }
        }
    }

    throw "MCP server not found. Please install Go or mcp-server-github, or set MCP_SERVER_PATH"
}

# Start MCP server with token
function Start-McpServer {
    param(
        [string]$Token,
        [string]$ServerPath,
        [string]$Port,
        [string[]]$ServerArgs
    )

    Write-Log "Starting GitHub MCP server..."
    Write-Log "Server path: $ServerPath"
    Write-Log "Port: $Port"

    # Set environment variables for the MCP server
    $env:GITHUB_TOKEN = $Token
    $env:GITHUB_PERSONAL_ACCESS_TOKEN = $Token
    $env:PORT = $Port
    $env:LOG_LEVEL = $LogLevel

    $command = ""
    $args = @()

    # Handle GitHub's official Go-based MCP server
    if ($ServerPath -like "*github.com/github/github-mcp-server*") {
        Write-Log "Starting GitHub's official Go-based MCP server..."
        $command = "go"
        $args = @("run", $ServerPath, "stdio") + $ServerArgs
    }
    elseif ($ServerPath -like "*.js") {
        Write-Log "Starting Node.js MCP server..."
        if (-not (Test-Command "node")) {
            throw "Node.js required for .js server but not found"
        }
        $command = "node"
        $args = @($ServerPath) + $ServerArgs
    }
    elseif (Test-Path $ServerPath) {
        Write-Log "Starting executable MCP server..."
        $command = $ServerPath
        $args = $ServerArgs
    }
    else {
        throw "Unknown server type or server not executable: $ServerPath"
    }

    # Start the server process
    try {
        $process = Start-Process -FilePath $command -ArgumentList $args -NoNewWindow -PassThru -Wait
        $exitCode = $process.ExitCode
        Write-Log "MCP server exited with code $exitCode"
        exit $exitCode
    }
    catch {
        Write-Error-Log "Failed to start MCP server: $($_.Exception.Message)"
        exit 1
    }
}

# Show usage information
function Show-Usage {
    Write-Host @"

GitHub MCP Server Wrapper (PowerShell)

USAGE:
    .\$(Split-Path -Leaf $MyInvocation.ScriptName) [OPTIONS]

OPTIONS:
    -Port PORT              Port for MCP server (default: $($env:GITHUB_MCP_PORT ?? "3000"))
    -Server PATH            Path to MCP server executable
    -Token TOKEN            Use specific GitHub token
    -Validate               Validate token before starting server
    -Help                   Show this help message

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN           GitHub personal access token
    GITHUB_PERSONAL_ACCESS_TOKEN  Alternative GitHub token variable
    GH_TOKEN              Another GitHub token variable
    MCP_SERVER_PATH       Path to MCP server executable
    GITHUB_MCP_PORT       Default port for MCP server
    LOG_LEVEL             Logging level (default: info)

EXAMPLES:
    .\$(Split-Path -Leaf $MyInvocation.ScriptName)                    # Auto-detect token and start server
    .\$(Split-Path -Leaf $MyInvocation.ScriptName) -Port 3001        # Start on custom port
    .\$(Split-Path -Leaf $MyInvocation.ScriptName) -Token ghp_xxxxx  # Use specific token
    .\$(Split-Path -Leaf $MyInvocation.ScriptName) -Validate         # Validate token before starting

"@
}

# Main execution function
function Main {
    Write-Log "GitHub MCP Server Wrapper starting..."

    # Show help if requested
    if ($Help) {
        Show-Usage
        exit 0
    }

    # Check GitHub CLI authentication silently first
    Test-GitHubCliAuth | Out-Null

    # Get GitHub token
    $gitHubToken = $Token
    if (-not $gitHubToken) {
        try {
            $gitHubToken = Get-GitHubToken
        }
        catch {
            Write-Error-Log "Failed to obtain GitHub token"
            Write-Host ""
            Write-Host "Please ensure one of the following:"
            Write-Host "  1. GitHub CLI is installed and authenticated (gh auth login)"
            Write-Host "  2. Set GITHUB_TOKEN environment variable"
            Write-Host "  3. Set GITHUB_PERSONAL_ACCESS_TOKEN environment variable"
            Write-Host "  4. Use -Token parameter to provide token directly"
            exit 1
        }
    }

    # Validate token if requested
    if ($Validate) {
        try {
            Test-GitHubToken $gitHubToken
            Write-Success-Log "All validation checks passed - wrapper is ready!"
            exit 0
        }
        catch {
            Write-Error-Log "Token validation failed: $($_.Exception.Message)"
            exit 1
        }
    }

    # Find MCP server
    $serverPath = $Server
    if (-not $serverPath) {
        try {
            $serverPath = Find-McpServer
        }
        catch {
            Write-Error-Log $_.Exception.Message
            exit 1
        }
    }
    elseif (-not (Test-Path $serverPath)) {
        Write-Error-Log "Specified server path does not exist: $serverPath"
        exit 1
    }

    # Start MCP server
    try {
        Start-McpServer $gitHubToken $serverPath $Port $ServerArgs
    }
    catch {
        Write-Error-Log "Failed to start server: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function if this script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
