#!/bin/bash

# GitHub MCP Server Wrapper Script for Zed (Unix/Linux/macOS)
#
# Cross-platform shell wrapper that provides automatic GitHub authentication
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
#   Manual: ./github-mcp-wrapper.sh [OPTIONS]
#
# Examples:
#   ./github-mcp-wrapper.sh --validate
#   ./github-mcp-wrapper.sh --port 3001
#   LOG_LEVEL=debug ./github-mcp-wrapper.sh
#
# Part of the Zed GitHub MCP Extension
# Repository: https://github.com/LoamStudios/zed-mcp-server-github
#
# @author Jeffrey Guenther <guenther.jeffrey@gmail.com>
# @author James Inman <james@jamesinman.co.uk>
# @version 0.0.5
# @license MIT

set -euo pipefail

# Configuration
MCP_SERVER_PATH="${MCP_SERVER_PATH:-}"
GITHUB_MCP_PORT="${GITHUB_MCP_PORT:-3000}"
LOG_LEVEL="${LOG_LEVEL:-info}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo -e "${BLUE}[${timestamp}] $1${NC}" >&2
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check GitHub CLI authentication silently
check_github_cli_auth() {
    if ! command_exists gh; then
        warn "GitHub CLI not found - will try other authentication methods"
        return 1
    fi

    if gh auth status >/dev/null 2>&1; then
        log "GitHub CLI authentication verified"
        return 0
    else
        warn "GitHub CLI is installed but not authenticated"
        warn "Consider running 'gh auth login' for seamless authentication"
        return 1
    fi
}

# Get GitHub token using various methods
get_github_token() {
    local token=""

    # Method 1: Try gh auth token command
    if command_exists gh; then
        log "Attempting to get token from GitHub CLI..."
        if token=$(gh auth token 2>/dev/null) && [ -n "$token" ] && [ "$token" != "null" ]; then
            log "Successfully retrieved token from GitHub CLI"
            echo "$token"
            return 0
        fi
        warn "GitHub CLI is installed but no valid token found"
    fi

    # Method 2: Try environment variables
    log "Checking environment variables..."
    for env_var in GITHUB_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN GH_TOKEN; do
        if [ -n "${!env_var:-}" ]; then
            log "Found $env_var environment variable"
            echo "${!env_var}"
            return 0
        fi
    done

    # Method 3: Try reading from common token files
    local token_files=(
        "$HOME/.config/gh/hosts.yml"
        "$HOME/.github_token"
        "$HOME/.config/github/token"
    )

    for token_file in "${token_files[@]}"; do
        if [ -f "$token_file" ]; then
            log "Checking token file: $token_file"

            if [[ "$token_file" == *"hosts.yml" ]]; then
                # Parse GitHub CLI config file (simple YAML parsing)
                if command_exists grep && command_exists sed; then
                    token=$(grep -A 10 "github.com:" "$token_file" 2>/dev/null | grep "oauth_token:" | sed 's/.*oauth_token: *//g' | tr -d '"' | head -n1)
                    if [ -n "$token" ]; then
                        log "Successfully retrieved token from $token_file"
                        echo "$token"
                        return 0
                    fi
                fi
            else
                # Read plain token files
                token=$(cat "$token_file" 2>/dev/null | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [ -n "$token" ]; then
                    log "Successfully retrieved token from $token_file"
                    echo "$token"
                    return 0
                fi
            fi
        fi
    done

    error "No GitHub token found"
    return 1
}

# Validate GitHub token
validate_token() {
    local token="$1"
    log "Validating GitHub token..."

    if [ ${#token} -lt 20 ]; then
        error "Token appears to be too short (less than 20 characters)"
        return 1
    fi

    # Use curl if available, fallback to wget
    local http_code=""
    local exit_code=0

    if command_exists curl; then
        # Get just the HTTP status code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $token" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "User-Agent: GitHub-MCP-Wrapper/1.0.0" \
            "https://api.github.com/user" 2>/dev/null || echo "000")
        exit_code=$?
    elif command_exists wget; then
        local temp_file=$(mktemp)
        # Get HTTP status code from wget
        http_code=$(wget -q -O "$temp_file" \
            --header="Authorization: token $token" \
            --header="Accept: application/vnd.github.v3+json" \
            --header="User-Agent: GitHub-MCP-Wrapper/1.0.0" \
            --server-response "https://api.github.com/user" 2>&1 | \
            grep "HTTP/" | tail -1 | sed 's/.*HTTP\/[0-9.]*[[:space:]]*\([0-9]*\).*/\1/' || echo "000")
        exit_code=$?
        rm -f "$temp_file"
    else
        error "Neither curl nor wget available for token validation"
        return 1
    fi

    if [ $exit_code -eq 0 ] && [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        success "Token validation successful"
        return 0
    else
        error "Token validation failed (HTTP status: $http_code)"
        return 1
    fi
}

# Find MCP server executable
find_mcp_server() {
    local possible_paths=(
        "$MCP_SERVER_PATH"
    )

    # Add Go-based server if Go is available
    if command_exists go; then
        possible_paths+=("github.com/github/github-mcp-server/cmd/github-mcp-server@latest")
    fi

    # Add other common locations
    if command_exists which; then
        local which_result=$(which mcp-server-github 2>/dev/null || echo "")
        if [ -n "$which_result" ]; then
            possible_paths+=("$which_result")
        fi
    fi

    # Try npm global if npm exists
    if command_exists npm; then
        local npm_root=$(npm root -g 2>/dev/null || echo "")
        if [ -n "$npm_root" ]; then
            possible_paths+=(
                "$npm_root/@modelcontextprotocol/server-github/dist/index.js"
                "$npm_root/mcp-server-github/dist/index.js"
            )
        fi
    fi

    # Add more common locations
    possible_paths+=(
        "$HOME/.local/bin/mcp-server-github"
        "$HOME/.npm-global/bin/mcp-server-github"
        "./node_modules/.bin/mcp-server-github"
    )

    for server_path in "${possible_paths[@]}"; do
        if [ -n "$server_path" ]; then
            # Special handling for Go-based server
            if [[ "$server_path" == *"github.com/github/github-mcp-server"* ]]; then
                log "Found GitHub's official Go-based MCP server"
                echo "$server_path"
                return 0
            fi
            # Check if file exists for other paths
            if [ -f "$server_path" ]; then
                log "Found MCP server at: $server_path"
                echo "$server_path"
                return 0
            fi
        fi
    done

    error "MCP server not found. Please install Go or mcp-server-github, or set MCP_SERVER_PATH"
    return 1
}

# Start MCP server with token
start_mcp_server() {
    local token="$1"
    local server_path="$2"
    local port="$3"
    shift 3
    local server_args=("$@")

    log "Starting GitHub MCP server..."
    log "Server path: $server_path"
    log "Port: $port"

    # Set environment variables for the MCP server
    export GITHUB_TOKEN="$token"
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    export PORT="$port"
    export LOG_LEVEL="$LOG_LEVEL"

    local command=""
    local args=()

    # Handle GitHub's official Go-based MCP server
    if [[ "$server_path" == *"github.com/github/github-mcp-server"* ]]; then
        log "Starting GitHub's official Go-based MCP server..."
        command="go"
        args=("run" "$server_path" "stdio" "${server_args[@]}")
    elif [[ "$server_path" == *.js ]]; then
        log "Starting Node.js MCP server..."
        if ! command_exists node; then
            error "Node.js required for .js server but not found"
            return 1
        fi
        command="node"
        args=("$server_path" "${server_args[@]}")
    elif [ -x "$server_path" ]; then
        log "Starting executable MCP server..."
        command="$server_path"
        args=("${server_args[@]}")
    else
        error "Unknown server type or server not executable: $server_path"
        return 1
    fi

    # Handle cleanup on signals
    cleanup() {
        log "Received signal, shutting down..."
        if [ -n "${child_pid:-}" ]; then
            kill -TERM "$child_pid" 2>/dev/null || true
            wait "$child_pid" 2>/dev/null || true
        fi
        exit 0
    }

    trap cleanup SIGTERM SIGINT

    # Start the server
    "$command" "${args[@]}" &
    child_pid=$!

    # Wait for the child process
    wait "$child_pid"
    local exit_code=$?

    log "MCP server exited with code $exit_code"
    exit $exit_code
}

# Show usage information
show_usage() {
    cat << EOF

GitHub MCP Server Wrapper (Shell Script)

USAGE:
    $(basename "$0") [OPTIONS] [-- SERVER_ARGS...]

OPTIONS:
    -p, --port PORT         Port for MCP server (default: $GITHUB_MCP_PORT)
    -s, --server PATH       Path to MCP server executable
    -t, --token TOKEN       Use specific GitHub token
    -v, --validate          Validate token before starting server
    -h, --help             Show this help message

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN           GitHub personal access token
    GITHUB_PERSONAL_ACCESS_TOKEN  Alternative GitHub token variable
    GH_TOKEN              Another GitHub token variable
    MCP_SERVER_PATH       Path to MCP server executable
    GITHUB_MCP_PORT       Default port for MCP server
    LOG_LEVEL             Logging level (default: info)

EXAMPLES:
    $(basename "$0")                              # Auto-detect token and start server
    $(basename "$0") --port 3001                  # Start on custom port
    $(basename "$0") --token ghp_xxxxx            # Use specific token
    $(basename "$0") --validate                   # Validate token before starting
    $(basename "$0") -- --additional-server-args  # Pass args to MCP server

EOF
}

# Parse command line arguments
parse_args() {
    local validate_token=false
    local validation_only=false
    local custom_token=""
    local custom_port="$GITHUB_MCP_PORT"
    local custom_server_path="$MCP_SERVER_PATH"
    local server_args=()
    local show_help=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help=true
                shift
                ;;
            -p|--port)
                if [ -z "${2:-}" ]; then
                    error "$1 requires a value"
                    return 1
                fi
                custom_port="$2"
                if ! [[ "$custom_port" =~ ^[0-9]+$ ]]; then
                    error "Invalid port number: $custom_port"
                    return 1
                fi
                shift 2
                ;;
            -s|--server)
                if [ -z "${2:-}" ]; then
                    error "$1 requires a value"
                    return 1
                fi
                custom_server_path="$2"
                shift 2
                ;;
            -t|--token)
                if [ -z "${2:-}" ]; then
                    error "$1 requires a value"
                    return 1
                fi
                custom_token="$2"
                shift 2
                ;;
            -v|--validate)
                validate_token=true
                validation_only=true
                shift
                ;;
            --)
                shift
                server_args=("$@")
                break
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Export parsed values for use in main
    export PARSED_VALIDATE_TOKEN="$validate_token"
    export PARSED_VALIDATION_ONLY="$validation_only"
    export PARSED_CUSTOM_TOKEN="$custom_token"
    export PARSED_CUSTOM_PORT="$custom_port"
    export PARSED_CUSTOM_SERVER_PATH="$custom_server_path"
    export PARSED_SHOW_HELP="$show_help"

    # Handle server args array
    if [ ${#server_args[@]} -gt 0 ]; then
        # Save server args to a temporary file for main to read
        printf '%s\n' "${server_args[@]}" > /tmp/github_mcp_wrapper_args.$$
    fi

    return 0
}

# Main execution function
main() {
    log "GitHub MCP Server Wrapper starting..."

    # Check GitHub CLI authentication silently first
    check_github_cli_auth || true

    # Parse command line arguments
    if ! parse_args "$@"; then
        show_usage
        exit 1
    fi

    if [ "$PARSED_SHOW_HELP" = "true" ]; then
        show_usage
        exit 0
    fi

    # Get GitHub token
    local token="$PARSED_CUSTOM_TOKEN"
    if [ -z "$token" ]; then
        if ! token=$(get_github_token); then
            error "Failed to obtain GitHub token"
            echo "" >&2
            echo "Please ensure one of the following:" >&2
            echo "  1. GitHub CLI is installed and authenticated (gh auth login)" >&2
            echo "  2. Set GITHUB_TOKEN environment variable" >&2
            echo "  3. Set GITHUB_PERSONAL_ACCESS_TOKEN environment variable" >&2
            echo "  4. Use --token flag to provide token directly" >&2
            exit 1
        fi
    fi

    # Validate token if requested
    if [ "$PARSED_VALIDATE_TOKEN" = "true" ]; then
        if ! validate_token "$token"; then
            error "Token validation failed"
            exit 1
        fi
    fi

    # If validation-only mode, exit after successful validation
    if [ "$PARSED_VALIDATION_ONLY" = "true" ]; then
        success "All validation checks passed - wrapper is ready!"
        exit 0
    fi

    # Find MCP server
    local server_path="$PARSED_CUSTOM_SERVER_PATH"
    if [ -z "$server_path" ]; then
        if ! server_path=$(find_mcp_server); then
            exit 1
        fi
    elif [ ! -f "$server_path" ]; then
        error "Specified server path does not exist: $server_path"
        exit 1
    fi

    # Read server args if they exist
    local server_args=()
    if [ -f "/tmp/github_mcp_wrapper_args.$$" ]; then
        readarray -t server_args < /tmp/github_mcp_wrapper_args.$$
        rm -f /tmp/github_mcp_wrapper_args.$$
    fi

    # Start MCP server
    start_mcp_server "$token" "$server_path" "$PARSED_CUSTOM_PORT" "${server_args[@]}"
}

# Run main function if this script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
