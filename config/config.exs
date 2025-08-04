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

# LLM Integration Configuration
config :vsm_phoenix, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  model: "gpt-4-turbo-preview",
  base_url: "https://api.openai.com/v1",
  timeout: 30_000

config :vsm_phoenix, :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  model: "claude-3-opus-20240229",
  base_url: "https://api.anthropic.com/v1",
  timeout: 30_000

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

# Rate limiting configuration for Hammer
config :hammer,
  backend: {Hammer.Backend.ETS, [
    expiry_ms: 60_000 * 60 * 4,
    cleanup_interval_ms: 60_000 * 10
  ]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"