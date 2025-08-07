# Bulletproof configuration for VSM Phoenix
# This configuration enables resilient operation even when external dependencies fail

import Config

# Enable bulletproof MCP mode
config :vsm_phoenix,
  bulletproof_mcp: true,
  disable_mcp_servers: false

# Configure MCP with graceful degradation
config :vsm_phoenix, :mcp,
  require_magg: false,
  auto_connect: true,
  health_check_interval: 60_000,
  availability_check_interval: 300_000,
  max_reconnect_attempts: 3

# Configure supervisor strategies
config :vsm_phoenix, :supervisor,
  max_restarts: 10,
  max_seconds: 60,
  shutdown: 10_000

# Log configuration for better debugging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module, :function]

# Development-specific bulletproof settings
if config_env() == :dev do
  config :vsm_phoenix,
    bulletproof_warnings: true,
    log_mcp_failures: true
end

# Production-specific bulletproof settings
if config_env() == :prod do
  config :vsm_phoenix,
    bulletproof_warnings: false,
    log_mcp_failures: false,
    auto_restart_mcp: true
end