#!/usr/bin/env node

/**
 * GitHub MCP Server Wrapper Script for Zed
 *
 * The Node.js wrapper that provides automatic GitHub authentication for the
 * GitHub MCP (Model Context Protocol) server, bypassing Zed's WASM sandbox
 * limitations to enable seamless integration with GitHub CLI and environment
 * variables.
 *
 * Features:
 * - Automatic token detection via GitHub CLI (`gh auth token`)
 * - Fallback to environment variables (GITHUB_TOKEN, etc.)
 * - Token file support (~/.config/gh/hosts.yml, ~/.github_token)
 * - Silent authentication verification
 * - Support for GitHub's official Go-based MCP server
 * - Comprehensive error handling and validation
 * - Auto-detection by Zed extension (no manual path configuration needed)
 *
 * Usage:
 *   Automatic: Set `use_wrapper_script: true` in Zed settings
 *   Manual: node github-mcp-wrapper.js [OPTIONS]
 *
 * Examples:
 *   node github-mcp-wrapper.js --validate
 *   node github-mcp-wrapper.js --port 3001
 *   LOG_LEVEL=debug node github-mcp-wrapper.js
 *
 * Part of the Zed GitHub MCP Extension
 * Repository: https://github.com/LoamStudios/zed-mcp-server-github
 *
 * @author Jeffrey Guenther <guenther.jeffrey@gmail.com>
 * @author James Inman <james@jamesinman.co.uk>
 * @version 0.0.4
 * @license MIT
 */

const { spawn, execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const https = require("https");
const os = require("os");

// Configuration
const config = {
  mcpServerPath: process.env.MCP_SERVER_PATH || "",
  defaultPort: process.env.GITHUB_MCP_PORT || 3000,
  logLevel: process.env.LOG_LEVEL || "info",
};

// Colors for output
const colors = {
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  reset: "\x1b[0m",
};

// Logging functions
function log(message) {
  const timestamp = new Date().toISOString();
  console.error(`${colors.blue}[${timestamp}] ${message}${colors.reset}`);
}

function error(message) {
  console.error(`${colors.red}[ERROR] ${message}${colors.reset}`);
}

function warn(message) {
  console.error(`${colors.yellow}[WARN] ${message}${colors.reset}`);
}

function success(message) {
  console.error(`${colors.green}[SUCCESS] ${message}${colors.reset}`);
}

/**
 * Check GitHub CLI authentication silently
 */
function checkGitHubCliAuth() {
  try {
    // Check if gh command exists
    execSync("which gh", { stdio: "pipe" });

    // Check if authenticated (gh auth status returns 0 if authenticated)
    execSync("gh auth status", { stdio: "pipe" });

    log("GitHub CLI authentication verified");
    return true;
  } catch (err) {
    if (err.status === 127) {
      warn("GitHub CLI not found - will try other authentication methods");
    } else {
      warn("GitHub CLI is installed but not authenticated");
      warn("Consider running 'gh auth login' for seamless authentication");
    }
    return false;
  }
}

/**
 * Get GitHub token using various methods
 */
async function getGitHubToken() {
  // Method 1: Try gh auth token command
  try {
    log("Attempting to get token from GitHub CLI...");
    const token = execSync("gh auth token", { encoding: "utf8", stdio: "pipe" }).trim();
    if (token && token !== "null" && token.length > 0) {
      log("Successfully retrieved token from GitHub CLI");
      return token;
    }
  } catch (err) {
    if (err.status === 127) {
      warn("GitHub CLI (gh) not found in PATH");
    } else {
      warn("GitHub CLI is installed but no valid token found");
    }
  }

  // Method 2: Try environment variables
  log("Checking environment variables...");
  const envTokens = ["GITHUB_TOKEN", "GITHUB_PERSONAL_ACCESS_TOKEN", "GH_TOKEN"];

  for (const envVar of envTokens) {
    if (process.env[envVar]) {
      log(`Found ${envVar} environment variable`);
      return process.env[envVar];
    }
  }

  // Method 3: Try reading from common token files
  const tokenFiles = [
    path.join(os.homedir(), ".config/gh/hosts.yml"),
    path.join(os.homedir(), ".github_token"),
    path.join(os.homedir(), ".config/github/token"),
  ];

  for (const tokenFile of tokenFiles) {
    if (fs.existsSync(tokenFile)) {
      log(`Checking token file: ${tokenFile}`);
      try {
        const content = fs.readFileSync(tokenFile, "utf8");

        if (tokenFile.endsWith("hosts.yml")) {
          // Parse GitHub CLI config file
          const lines = content.split("\n");
          let inGitHubSection = false;

          for (const line of lines) {
            if (line.includes("github.com:")) {
              inGitHubSection = true;
              continue;
            }
            if (inGitHubSection && line.includes("oauth_token:")) {
              const token = line.split("oauth_token:")[1]?.trim();
              if (token) {
                log(`Successfully retrieved token from ${tokenFile}`);
                return token;
              }
            }
          }
        } else {
          // Read plain token files
          const token = content.trim();
          if (token) {
            log(`Successfully retrieved token from ${tokenFile}`);
            return token;
          }
        }
      } catch (err) {
        warn(`Failed to read ${tokenFile}: ${err.message}`);
      }
    }
  }

  throw new Error("No GitHub token found");
}

/**
 * Validate GitHub token
 */
function validateToken(token) {
  return new Promise((resolve, reject) => {
    log("Validating GitHub token...");

    if (token.length < 20) {
      reject(new Error("Token appears to be too short (less than 20 characters)"));
      return;
    }

    const options = {
      hostname: "api.github.com",
      port: 443,
      path: "/user",
      method: "GET",
      headers: {
        Authorization: `token ${token}`,
        Accept: "application/vnd.github.v3+json",
        "User-Agent": "GitHub-MCP-Wrapper/1.0.0",
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        try {
          const response = JSON.parse(data);
          if (response.login) {
            success("Token validation successful");
            resolve(true);
          } else {
            reject(new Error("Token validation failed - no login field in response"));
          }
        } catch (err) {
          reject(new Error(`Token validation failed - invalid JSON response: ${err.message}`));
        }
      });
    });

    req.on("error", (err) => {
      reject(new Error(`Token validation failed - network error: ${err.message}`));
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error("Token validation failed - request timeout"));
    });

    req.end();
  });
}

/**
 * Find MCP server executable
 */
function findMcpServer() {
  const possiblePaths = [
    config.mcpServerPath,
    // Try GitHub's official Go-based MCP server
    (() => {
      try {
        // Check if Go is available
        execSync("which go", { stdio: "pipe" });
        // Return special marker for Go-based server
        return "github.com/github/github-mcp-server/cmd/github-mcp-server@latest";
      } catch {
        return "";
      }
    })(),
    // Try which command for legacy servers
    (() => {
      try {
        return execSync("which mcp-server-github", { encoding: "utf8", stdio: "pipe" }).trim();
      } catch {
        return "";
      }
    })(),
    // Try npm global for legacy servers
    (() => {
      try {
        const npmRoot = execSync("npm root -g", { encoding: "utf8", stdio: "pipe" }).trim();
        const legacyPath = path.join(npmRoot, "@modelcontextprotocol", "server-github", "dist", "index.js");
        if (fs.existsSync(legacyPath)) {
          return legacyPath;
        }
        return path.join(npmRoot, "mcp-server-github", "dist", "index.js");
      } catch {
        return "";
      }
    })(),
    // Common locations
    path.join(os.homedir(), ".local/bin/mcp-server-github"),
    path.join(os.homedir(), ".npm-global/bin/mcp-server-github"),
    path.join(process.cwd(), "node_modules/.bin/mcp-server-github"),
  ];

  for (const serverPath of possiblePaths) {
    if (serverPath) {
      // Special handling for Go-based server
      if (serverPath.includes("github.com/github/github-mcp-server")) {
        log(`Found GitHub's official Go-based MCP server`);
        return serverPath;
      }
      // Check if file exists for other paths
      if (fs.existsSync(serverPath)) {
        log(`Found MCP server at: ${serverPath}`);
        return serverPath;
      }
    }
  }

  throw new Error("MCP server not found. Please install Go or mcp-server-github, or set MCP_SERVER_PATH");
}

/**
 * Start MCP server with token
 */
function startMcpServer(token, serverPath, port, serverArgs = []) {
  log("Starting GitHub MCP server...");
  log(`Server path: ${serverPath}`);
  log(`Port: ${port}`);

  // Set environment variables for the MCP server
  const env = {
    ...process.env,
    GITHUB_TOKEN: token,
    GITHUB_PERSONAL_ACCESS_TOKEN: token,
    PORT: port.toString(),
    LOG_LEVEL: config.logLevel,
  };

  let command, args;

  // Handle GitHub's official Go-based MCP server
  if (serverPath.includes("github.com/github/github-mcp-server")) {
    log("Starting GitHub's official Go-based MCP server...");
    command = "go";
    args = ["run", serverPath, "stdio", ...serverArgs];
  } else if (serverPath.endsWith(".js")) {
    log("Starting Node.js MCP server...");
    command = "node";
    args = [serverPath, ...serverArgs];
  } else if (
    fs.accessSync &&
    (() => {
      try {
        fs.accessSync(serverPath, fs.constants.X_OK);
        return true;
      } catch {
        return false;
      }
    })()
  ) {
    log("Starting executable MCP server...");
    command = serverPath;
    args = serverArgs;
  } else {
    throw new Error(`Unknown server type or server not executable: ${serverPath}`);
  }

  const child = spawn(command, args, {
    env,
    stdio: "inherit",
  });

  // Handle process signals
  process.on("SIGTERM", () => {
    log("Received SIGTERM, shutting down...");
    child.kill("SIGTERM");
  });

  process.on("SIGINT", () => {
    log("Received SIGINT, shutting down...");
    child.kill("SIGINT");
  });

  child.on("error", (err) => {
    error(`Failed to start MCP server: ${err.message}`);
    process.exit(1);
  });

  child.on("exit", (code, signal) => {
    if (signal) {
      log(`MCP server terminated by signal ${signal}`);
    } else {
      log(`MCP server exited with code ${code}`);
    }
    process.exit(code || 0);
  });
}

/**
 * Show usage information
 */
function showUsage() {
  console.log(`
GitHub MCP Server Wrapper (Node.js)

USAGE:
    node ${path.basename(__filename)} [OPTIONS] [-- SERVER_ARGS...]

OPTIONS:
    -p, --port PORT         Port for MCP server (default: ${config.defaultPort})
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
    node ${path.basename(__filename)}                              # Auto-detect token and start server
    node ${path.basename(__filename)} --port 3001                  # Start on custom port
    node ${path.basename(__filename)} --token ghp_xxxxx            # Use specific token
    node ${path.basename(__filename)} --validate                   # Validate token before starting
    node ${path.basename(__filename)} -- --additional-server-args  # Pass args to MCP server
`);
}

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    validateToken: false,
    validationOnly: false,
    customToken: "",
    customPort: config.defaultPort,
    customServerPath: config.mcpServerPath,
    serverArgs: [],
    showHelp: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      case "-h":
      case "--help":
        options.showHelp = true;
        return options;

      case "-p":
      case "--port":
        if (i + 1 >= args.length) {
          throw new Error(`${arg} requires a value`);
        }
        options.customPort = parseInt(args[++i], 10);
        if (isNaN(options.customPort)) {
          throw new Error(`Invalid port number: ${args[i]}`);
        }
        break;

      case "-s":
      case "--server":
        if (i + 1 >= args.length) {
          throw new Error(`${arg} requires a value`);
        }
        options.customServerPath = args[++i];
        break;

      case "-t":
      case "--token":
        if (i + 1 >= args.length) {
          throw new Error(`${arg} requires a value`);
        }
        options.customToken = args[++i];
        break;

      case "-v":
      case "--validate":
        options.validateToken = true;
        options.validationOnly = true;
        break;

      case "--":
        options.serverArgs = args.slice(i + 1);
        return options;

      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

/**
 * Main execution function
 */
async function main() {
  try {
    log("GitHub MCP Server Wrapper starting...");

    // Check GitHub CLI authentication silently first
    checkGitHubCliAuth();

    // Parse command line arguments
    let options;
    try {
      options = parseArgs();
    } catch (err) {
      error(err.message);
      showUsage();
      process.exit(1);
    }

    if (options.showHelp) {
      showUsage();
      process.exit(0);
    }

    // Get GitHub token
    let token = options.customToken;
    if (!token) {
      try {
        token = await getGitHubToken();
      } catch (err) {
        error("Failed to obtain GitHub token");
        console.error("");
        console.error("Please ensure one of the following:");
        console.error("  1. GitHub CLI is installed and authenticated (gh auth login)");
        console.error("  2. Set GITHUB_TOKEN environment variable");
        console.error("  3. Set GITHUB_PERSONAL_ACCESS_TOKEN environment variable");
        console.error("  4. Use --token flag to provide token directly");
        process.exit(1);
      }
    }

    // Validate token if requested
    if (options.validateToken) {
      try {
        await validateToken(token);
      } catch (err) {
        error(`Token validation failed: ${err.message}`);
        process.exit(1);
      }
    }

    // If validation-only mode, exit after successful validation
    if (options.validationOnly) {
      success("All validation checks passed - wrapper is ready!");
      process.exit(0);
    }

    // Find MCP server
    let serverPath = options.customServerPath;
    if (!serverPath) {
      try {
        serverPath = findMcpServer();
      } catch (err) {
        error(err.message);
        process.exit(1);
      }
    } else if (!fs.existsSync(serverPath)) {
      error(`Specified server path does not exist: ${serverPath}`);
      process.exit(1);
    }

    // Start MCP server
    startMcpServer(token, serverPath, options.customPort, options.serverArgs);
  } catch (err) {
    error(`Unexpected error: ${err.message}`);
    process.exit(1);
  }
}

// Run main function if this script is executed directly
if (require.main === module) {
  main().catch((err) => {
    error(`Fatal error: ${err.message}`);
    process.exit(1);
  });
}

module.exports = {
  getGitHubToken,
  validateToken,
  findMcpServer,
  startMcpServer,
};
