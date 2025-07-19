use schemars::JsonSchema;
use serde::Deserialize;
use std::fs;
use zed::settings::ContextServerSettings;
use zed_extension_api::{
    self as zed, serde_json, Command, ContextServerConfiguration, ContextServerId, Project, Result,
};

const REPO_NAME: &str = "github/github-mcp-server";
const BINARY_NAME: &str = "github-mcp-server";

#[derive(Debug, Deserialize, JsonSchema)]
struct GitHubContextServerSettings {
    github_personal_access_token: Option<String>,
    use_wrapper_script: Option<bool>,
}

struct GitHubModelContextExtension {
    cached_binary_path: Option<String>,
}

impl GitHubModelContextExtension {
    fn context_server_binary_path(
        &mut self,
        _context_server_id: &ContextServerId,
    ) -> Result<String> {
        if let Some(path) = &self.cached_binary_path {
            if fs::metadata(path).map_or(false, |stat| stat.is_file()) {
                return Ok(path.clone());
            }
        }

        let release = zed::latest_github_release(
            REPO_NAME,
            zed::GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )?;

        let (platform, arch) = zed::current_platform();
        let asset_name = format!(
            "{BINARY_NAME}_{os}_{arch}.{ext}",
            arch = match arch {
                zed::Architecture::Aarch64 => "arm64",
                zed::Architecture::X86 => "i386",
                zed::Architecture::X8664 => "x86_64",
            },
            os = match platform {
                zed::Os::Mac => "Darwin",
                zed::Os::Linux => "Linux",
                zed::Os::Windows => "Windows",
            },
            ext = match platform {
                zed::Os::Mac | zed::Os::Linux => "tar.gz",
                zed::Os::Windows => "zip",
            }
        );

        let asset = release
            .assets
            .iter()
            .find(|asset| asset.name == asset_name)
            .ok_or_else(|| format!("no asset found matching {:?}", asset_name))?;

        let version_dir = format!("{BINARY_NAME}-{}", release.version);
        fs::create_dir_all(&version_dir)
            .map_err(|err| format!("failed to create directory '{version_dir}': {err}"))?;
        let binary_path = format!("{version_dir}/{BINARY_NAME}");

        if !fs::metadata(&binary_path).map_or(false, |stat| stat.is_file()) {
            let file_kind = match platform {
                zed::Os::Mac | zed::Os::Linux => zed::DownloadedFileType::GzipTar,
                zed::Os::Windows => zed::DownloadedFileType::Zip,
            };

            zed::download_file(&asset.download_url, &version_dir, file_kind)
                .map_err(|e| format!("failed to download file: {e}"))?;

            zed::make_file_executable(&binary_path)?;

            // Removes old versions
            let entries =
                fs::read_dir(".").map_err(|e| format!("failed to list working directory {e}"))?;
            for entry in entries {
                let entry = entry.map_err(|e| format!("failed to load directory entry {e}"))?;
                if entry.file_name().to_str() != Some(&version_dir) {
                    fs::remove_dir_all(entry.path()).ok();
                }
            }
        }

        self.cached_binary_path = Some(binary_path.clone());
        Ok(binary_path)
    }
}

impl GitHubModelContextExtension {
    fn get_wrapper_script_path(&self) -> Option<(String, String)> {
        // Get the current working directory (extension directory)
        let current_dir = std::env::current_dir().ok()?;

        // Determine platform and check for appropriate wrapper script
        let (platform, _) = zed::current_platform();

        match platform {
            zed::Os::Windows => {
                // Check for PowerShell wrapper script
                let wrapper_ps1 = current_dir.join("wrappers").join("github-mcp-wrapper.ps1");
                if wrapper_ps1.exists() {
                    return wrapper_ps1
                        .to_str()
                        .map(|s| ("powershell".to_string(), s.to_string()));
                }
            }
            zed::Os::Mac | zed::Os::Linux => {
                // Check for shell wrapper script
                let wrapper_sh = current_dir.join("wrappers").join("github-mcp-wrapper.sh");
                if wrapper_sh.exists() {
                    return wrapper_sh
                        .to_str()
                        .map(|s| ("bash".to_string(), s.to_string()));
                }
            }
        }

        // Fallback to Node.js wrapper for backwards compatibility
        let wrapper_js = current_dir.join("wrappers").join("github-mcp-wrapper.js");
        if wrapper_js.exists() {
            return wrapper_js
                .to_str()
                .map(|s| ("node".to_string(), s.to_string()));
        }

        None
    }

    fn check_wrapper_prerequisites(&self, command: &str) -> bool {
        // Check if the wrapper command is available
        std::process::Command::new(command)
            .arg("--version")
            .output()
            .is_ok()
    }
}

impl zed::Extension for GitHubModelContextExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn context_server_command(
        &mut self,
        context_server_id: &ContextServerId,
        project: &Project,
    ) -> Result<Command> {
        let settings = ContextServerSettings::for_project("mcp-server-github", project)?;
        let settings: GitHubContextServerSettings = if let Some(settings) = settings.settings {
            serde_json::from_value(settings).map_err(|e| e.to_string())?
        } else {
            GitHubContextServerSettings {
                github_personal_access_token: None,
                use_wrapper_script: None,
            }
        };

        // Check if wrapper mode is enabled
        if settings.use_wrapper_script.unwrap_or(false) {
            // Try to use wrapper script
            if let Some((command, wrapper_path)) = self.get_wrapper_script_path() {
                if self.check_wrapper_prerequisites(&command) {
                    let args = match command.as_str() {
                        "powershell" => vec![
                            "-ExecutionPolicy".to_string(),
                            "Bypass".to_string(),
                            "-File".to_string(),
                            wrapper_path,
                        ],
                        "bash" => vec![wrapper_path],
                        "node" => vec![wrapper_path],
                        _ => vec![wrapper_path],
                    };

                    return Ok(Command {
                        command,
                        args,
                        env: vec![],
                    });
                } else {
                    let dependency = match command.as_str() {
                        "powershell" => "PowerShell",
                        "bash" => "Bash shell",
                        "node" => "Node.js",
                        _ => &command,
                    };
                    return Err(format!("Wrapper script found but {} not available. Please install {} or disable wrapper mode.", dependency, dependency));
                }
            } else {
                return Err("Wrapper mode enabled but no wrapper script found in wrappers/ directory. Please disable wrapper mode or use traditional token configuration.".to_string());
            }
        }

        // Traditional mode - require token
        let token = if let Some(token) = settings.github_personal_access_token {
            token
        } else {
            // Try to get token from environment variables
            std::env::var("GITHUB_TOKEN")
                .or_else(|_| std::env::var("GITHUB_PERSONAL_ACCESS_TOKEN"))
                .map_err(|_| {
                    "No GitHub token found. Please set `github_personal_access_token` in settings, set GITHUB_TOKEN/GITHUB_PERSONAL_ACCESS_TOKEN environment variable, or enable `use_wrapper_script` for automatic authentication. You can get a token with: gh auth token"
                })?
        };

        Ok(Command {
            command: self.context_server_binary_path(context_server_id)?,
            args: vec!["stdio".to_string()],
            env: vec![("GITHUB_PERSONAL_ACCESS_TOKEN".into(), token)],
        })
    }

    fn context_server_configuration(
        &mut self,
        _context_server_id: &ContextServerId,
        _project: &Project,
    ) -> Result<Option<ContextServerConfiguration>> {
        let installation_instructions = include_str!("../docs/configuration.md").to_string();
        let default_settings = include_str!("../configuration/default_settings.jsonc").to_string();
        let settings_schema =
            serde_json::to_string(&schemars::schema_for!(GitHubContextServerSettings))
                .map_err(|e| e.to_string())?;

        Ok(Some(ContextServerConfiguration {
            installation_instructions,
            default_settings,
            settings_schema,
        }))
    }
}

zed::register_extension!(GitHubModelContextExtension);
