import Config

# VSM Infrastructure Configuration
# This file defines the configuration for the abstraction layer

# AMQP Exchange Configuration
# You can override any exchange name using environment variables:
# VSM_EXCHANGE_ALGEDONIC=prod.vsm.algedonic
# VSM_EXCHANGE_COMMANDS=prod.vsm.commands
config :vsm_phoenix, :amqp_exchanges, %{
  # Core VSM exchanges
  recursive: System.get_env("VSM_EXCHANGE_RECURSIVE", "vsm.recursive"),
  algedonic: System.get_env("VSM_EXCHANGE_ALGEDONIC", "vsm.algedonic"),
  coordination: System.get_env("VSM_EXCHANGE_COORDINATION", "vsm.coordination"),
  control: System.get_env("VSM_EXCHANGE_CONTROL", "vsm.control"),
  intelligence: System.get_env("VSM_EXCHANGE_INTELLIGENCE", "vsm.intelligence"),
  policy: System.get_env("VSM_EXCHANGE_POLICY", "vsm.policy"),
  audit: System.get_env("VSM_EXCHANGE_AUDIT", "vsm.audit"),
  meta: System.get_env("VSM_EXCHANGE_META", "vsm.meta"),
  commands: System.get_env("VSM_EXCHANGE_COMMANDS", "vsm.commands"),
  swarm: System.get_env("VSM_EXCHANGE_SWARM", "vsm.swarm"),
  s1_commands: System.get_env("VSM_EXCHANGE_S1_COMMANDS", "vsm.s1.commands")
}

# HTTP Service Configuration
# Configure external service endpoints
config :vsm_phoenix, :http_services, %{
  anthropic: %{
    url: System.get_env("VSM_SERVICE_ANTHROPIC_URL", "https://api.anthropic.com"),
    api_key: System.get_env("ANTHROPIC_API_KEY"),
    version: System.get_env("ANTHROPIC_VERSION", "2023-06-01")
  },
  telegram: %{
    url: System.get_env("VSM_SERVICE_TELEGRAM_URL", "https://api.telegram.org"),
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN")
  },
  mcp_registry: %{
    url: System.get_env("VSM_SERVICE_MCP_REGISTRY_URL", "https://mcp-registry.anthropic.com")
  }
}

# HTTP Client Configuration
config :vsm_phoenix, :http_client, %{
  timeout: String.to_integer(System.get_env("VSM_HTTP_TIMEOUT", "30000")),
  max_retries: String.to_integer(System.get_env("VSM_HTTP_MAX_RETRIES", "3")),
  retry_delay: String.to_integer(System.get_env("VSM_HTTP_RETRY_DELAY", "1000")),
  
  # Circuit breaker configuration
  circuit_breaker: %{
    enabled: System.get_env("VSM_HTTP_CIRCUIT_BREAKER_ENABLED", "true") == "true",
    failure_threshold: String.to_integer(System.get_env("VSM_HTTP_CIRCUIT_BREAKER_THRESHOLD", "5")),
    reset_timeout: String.to_integer(System.get_env("VSM_HTTP_CIRCUIT_BREAKER_RESET", "60000")),
    half_open_requests: String.to_integer(System.get_env("VSM_HTTP_CIRCUIT_BREAKER_HALF_OPEN", "3"))
  }
}

# AMQP Connection Configuration
config :vsm_phoenix, :amqp_connection, %{
  host: System.get_env("RABBITMQ_HOST", "localhost"),
  port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
  username: System.get_env("RABBITMQ_USER", "guest"),
  password: System.get_env("RABBITMQ_PASS", "guest"),
  virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
  
  # Connection pool settings
  pool_size: String.to_integer(System.get_env("VSM_AMQP_POOL_SIZE", "10")),
  reconnect_interval: String.to_integer(System.get_env("VSM_AMQP_RECONNECT_INTERVAL", "5000"))
}

# Environment prefix for all VSM resources
config :vsm_phoenix, :env_prefix, System.get_env("VSM_ENV_PREFIX", "vsm")