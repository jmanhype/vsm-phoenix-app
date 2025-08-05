# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :vsm_phoenix,
  ecto_repos: [VsmPhoenix.Repo],
  generators: [timestamp_type: :utc_datetime]

# Import Variety Engineering configuration
import_config "variety_engineering.exs"

# Configures the endpoint
config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: VsmPhoenixWeb.ErrorHTML, json: VsmPhoenixWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: VsmPhoenix.PubSub,
  live_view: [signing_salt: "VSM_PHOENIX_SALT"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :vsm_phoenix, VsmPhoenix.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# VSM-specific configuration
config :vsm_phoenix, :vsm,
  # System 5 - Queen Configuration
  queen: [
    policy_check_interval: 30_000,  # 30 seconds
    viability_threshold: 0.7,
    intervention_threshold: 0.6
  ],
  
  # System 4 - Intelligence Configuration
  intelligence: [
    scan_interval: 60_000,  # 1 minute
    tidewave_enabled: true,
    adaptation_timeout: 300_000,  # 5 minutes
    learning_rate: 0.1
  ],
  
  # System 3 - Control Configuration
  control: [
    optimization_interval: 30_000,  # 30 seconds
    resource_thresholds: %{
      compute: 0.8,
      memory: 0.85,
      network: 0.7,
      storage: 0.9
    }
  ],
  
  # System 2 - Coordinator Configuration
  coordinator: [
    sync_check_interval: 10_000,  # 10 seconds
    oscillation_detection_window: 5_000,  # 5 seconds
    max_message_frequency: 100  # per second
  ],
  
  # System 1 - Operations Configuration
  operations: [
    health_check_interval: 30_000,  # 30 seconds
    max_processing_time: 1_000,  # 1 second
    customer_response_target: 500  # 500ms
  ],
  
  # Telegram Agent Configuration
  telegram: [
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
    webhook_mode: false,  # Use polling by default
    webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL"),
    authorized_chats: [],  # Will be populated from env or runtime
    admin_chats: [],  # Will be populated from env or runtime
    rate_limit: 30,  # messages per minute per chat
    command_timeout: 5_000  # 5 seconds
  ]

# Tidewave Integration Configuration (if available)
config :tidewave,
  endpoint: "http://localhost:4000",
  api_key: System.get_env("TIDEWAVE_API_KEY"),
  timeout: 30_000

# Telegram Integration Configuration
config :vsm_phoenix, :telegram,
  # Default webhook timeout
  webhook_timeout: 30_000,
  
  # Maximum message length before truncation
  max_message_length: 4096,
  
  # Rate limiting
  rate_limit: %{
    messages_per_minute: 30,
    commands_per_minute: 20
  },
  
  # Default bot features
  default_features: %{
    variety_monitoring: true,
    vsm_status: true,
    algedonic_signals: true,
    auto_responses: true
  }

# Quantum Scheduler Configuration
config :vsm_phoenix, VsmPhoenix.Scheduler,
  jobs: [
    # System health audit every hour
    {"0 * * * *", {VsmPhoenix.HealthChecker, :run_system_audit, []}},
    
    # Performance metrics collection every 5 minutes
    {"*/5 * * * *", {VsmPhoenix.PerformanceMonitor, :collect_metrics, []}},
    
    # Viability assessment every 15 minutes
    {"*/15 * * * *", {VsmPhoenix.System5.Queen, :evaluate_viability, []}},
    
    # Environmental scan every 10 minutes
    {"*/10 * * * *", {VsmPhoenix.System4.Intelligence, :scan_environment, [:scheduled]}},
    
    # Resource optimization every 30 minutes
    {"*/30 * * * *", {VsmPhoenix.System3.Control, :optimize_performance, [:global]}}
  ]

# LLM Integration Configuration
config :vsm_phoenix, :llm,
  # API Keys (loaded from environment)
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  
  # Enable LLM features
  enable_llm_variety: System.get_env("ENABLE_LLM_VARIETY", "false") == "true",
  
  # Rate limiting
  rate_limit_per_minute: String.to_integer(System.get_env("LLM_RATE_LIMIT", "60")),
  
  # Cache configuration
  cache_ttl_hours: String.to_integer(System.get_env("LLM_CACHE_TTL", "24")),
  
  # Default provider and models
  default_provider: String.to_atom(System.get_env("DEFAULT_LLM_PROVIDER", "openai")),
  default_models: %{
    openai: System.get_env("OPENAI_DEFAULT_MODEL", "gpt-4-turbo"),
    anthropic: System.get_env("ANTHROPIC_DEFAULT_MODEL", "claude-3-sonnet")
  },
  
  # Cost optimization
  max_tokens_default: 1000,
  temperature_default: 0.7,
  
  # Fallback behavior
  enable_provider_fallback: true,
  
  # Streaming configuration
  streaming_enabled: true,
  streaming_chunk_size: 100

# Phase 2 Advanced Features Configuration
config :vsm_phoenix, :phase2,
  # GoldRush Pattern Engine
  goldrush: [
    enabled: true,
    max_patterns: 1000,
    max_pattern_complexity: 10,
    event_retention_hours: 168,  # 7 days
    aggregation_windows: ["1m", "5m", "15m", "1h", "1d"],
    alert_cooldown_seconds: 300,
    persistence_enabled: true,
    persistence_path: "priv/goldrush"
  ],
  
  # Telegram NLU Integration
  telegram_nlu: [
    enabled: true,
    provider: :openai,  # or :anthropic
    model: "gpt-4-turbo",
    confidence_threshold: 0.75,
    max_context_messages: 10,
    intent_categories: [
      "system_status",
      "variety_query",
      "pattern_analysis",
      "alert_management",
      "configuration",
      "help"
    ],
    entity_extractors: [
      "system_identifier",
      "metric_extractor",
      "timeframe_parser",
      "threshold_detector"
    ]
  ],
  
  # AMQP Security Protocol
  amqp_security: [
    enabled: true,
    encryption_algorithm: "aes-256-gcm",
    signature_algorithm: "ed25519",
    key_rotation_hours: 24,
    require_encryption: true,
    require_signatures: true,
    access_control_enabled: true,
    audit_all_messages: true,
    rate_limiting: %{
      per_source: 1000,  # messages per minute
      per_destination: 2000
    }
  ],
  
  # LLM Integration Enhancements
  llm_enhanced: [
    variety_amplification: true,
    intelligent_analysis: true,
    predictive_adaptation: true,
    multi_model_ensemble: false,  # Premium feature
    context_window_optimization: true,
    cost_optimization_mode: "balanced",  # "aggressive", "balanced", "quality"
    fallback_strategies: [
      "retry_with_smaller_context",
      "switch_provider",
      "use_cached_response",
      "fallback_to_rules"
    ]
  ],
  
  # Integration Features
  integration: [
    event_correlation_enabled: true,
    cross_system_patterns: true,
    distributed_decision_making: true,
    consensus_protocol: "byzantine_fault_tolerant",
    system_boundary_enforcement: true,
    telemetry_aggregation: true,
    performance_monitoring: true
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"