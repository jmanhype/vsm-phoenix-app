import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :vsm_phoenix, VsmPhoenix.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "vsm_phoenix_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "VSM_PHOENIX_SECRET_KEY_BASE_TEST_VERY_LONG_STRING_FOR_SECURITY",
  server: false

# In test we don't send emails.
config :vsm_phoenix, VsmPhoenix.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# VSM Test Configuration
config :vsm_phoenix, :vsm,
  # Disable external integrations in tests
  queen: [
    policy_check_interval: 100,  # 100ms for fast tests
    viability_threshold: 0.5,
    intervention_threshold: 0.3
  ],
  
  intelligence: [
    scan_interval: 100,  # 100ms for fast tests
    tidewave_enabled: false,  # Disable external service
    adaptation_timeout: 5_000,  # 5 seconds
    learning_rate: 0.5
  ],
  
  control: [
    optimization_interval: 100,  # 100ms for fast tests
    resource_thresholds: %{
      compute: 0.95,
      memory: 0.95,
      network: 0.9,
      storage: 0.98
    }
  ],
  
  coordinator: [
    sync_check_interval: 100,  # 100ms for fast tests
    oscillation_detection_window: 500,  # 500ms
    max_message_frequency: 1000  # per second
  ],
  
  operations: [
    health_check_interval: 100,  # 100ms for fast tests
    max_processing_time: 100,  # 100ms
    customer_response_target: 50  # 50ms
  ]

# Disable Quantum in tests
config :vsm_phoenix, VsmPhoenix.Scheduler,
  jobs: []

# Mock external dependencies
config :tidewave,
  endpoint: "http://localhost:4003",
  api_key: "test_key",
  timeout: 1_000