import Config

# Production configuration for VSM Phoenix
# This file is loaded before runtime.exs

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: {:system, "PORT"}],
  https: [
    ip: {0, 0, 0, 0},
    port: {:system, "HTTPS_PORT"},
    cipher_suite: :strong,
    keyfile: {:system, "SSL_KEY_PATH"},
    certfile: {:system, "SSL_CERT_PATH"}
  ],
  check_origin: false,
  code_reloader: false,
  server: true,
  root: ".",
  version: Application.spec(:vsm_phoenix, :vsn),
  cache_static_manifest: "priv/static/cache_manifest.json"

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: VsmPhoenix.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Database configuration for production
config :vsm_phoenix, VsmPhoenix.Repo,
  # ssl: true,
  url: {:system, "DATABASE_URL"},
  pool_size: {:system, :integer, "POOL_SIZE", 10},
  queue_target: 5000,
  queue_interval: 10000,
  migration_primary_key: [name: :id, type: :uuid],
  migration_timestamps: [type: :utc_datetime]

# VSM Production Configuration
config :vsm_phoenix, :vsm,
  # System 5 - Queen Configuration
  queen: [
    policy_check_interval: 60_000,  # 1 minute in production
    viability_threshold: 0.75,      # Higher threshold for production
    intervention_threshold: 0.65,
    emergency_threshold: 0.5
  ],
  
  # System 4 - Intelligence Configuration
  intelligence: [
    scan_interval: 120_000,         # 2 minutes
    tidewave_enabled: true,
    adaptation_timeout: 600_000,    # 10 minutes
    learning_rate: 0.05,            # More conservative learning
    batch_size: 100,
    max_concurrent_scans: 5
  ],
  
  # System 3 - Control Configuration
  control: [
    optimization_interval: 60_000,  # 1 minute
    resource_thresholds: %{
      compute: 0.75,                # More conservative in production
      memory: 0.80,
      network: 0.70,
      storage: 0.85,
      database_connections: 0.90
    },
    auto_scaling: %{
      enabled: true,
      min_instances: 2,
      max_instances: 10,
      scale_up_threshold: 0.80,
      scale_down_threshold: 0.30,
      cooldown_period: 300_000      # 5 minutes
    }
  ],
  
  # System 2 - Coordinator Configuration
  coordinator: [
    sync_check_interval: 5_000,     # 5 seconds
    oscillation_detection_window: 10_000,  # 10 seconds
    max_message_frequency: 200,     # per second
    circuit_breaker: %{
      enabled: true,
      failure_threshold: 10,
      recovery_timeout: 60_000      # 1 minute
    }
  ],
  
  # System 1 - Operations Configuration
  operations: [
    health_check_interval: 30_000,  # 30 seconds
    max_processing_time: 5_000,     # 5 seconds for production
    customer_response_target: 200,  # 200ms target
    max_concurrent_operations: 1000,
    backup_strategy: %{
      enabled: true,
      interval: 3600_000,           # 1 hour
      retention_days: 30
    }
  ]

# Security Configuration
config :vsm_phoenix, :security,
  # Authentication
  jwt_secret: {:system, "JWT_SECRET"},
  jwt_ttl: {1, :hour},
  refresh_token_ttl: {30, :days},
  password_reset_ttl: {1, :hour},
  api_key_ttl: {365, :days},
  
  # Rate limiting (stricter in production)
  rate_limits: %{
    login: [limit: 5, window: 300_000],      # 5 attempts per 5 minutes
    api: [limit: 1000, window: 3600_000],    # 1000 requests per hour
    password_reset: [limit: 3, window: 3600_000],  # 3 resets per hour
    registration: [limit: 5, window: 86400_000]    # 5 registrations per day
  },
  
  # Password requirements
  password_policy: %{
    min_length: 12,
    require_uppercase: true,
    require_lowercase: true,
    require_numbers: true,
    require_symbols: true,
    prevent_reuse: 12,                       # Last 12 passwords
    max_age_days: 90
  },
  
  # Session security
  session_timeout: 28800_000,                # 8 hours
  concurrent_sessions_limit: 5,
  
  # Security headers
  security_headers: %{
    content_security_policy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
    x_frame_options: "DENY",
    x_content_type_options: "nosniff",
    x_xss_protection: "1; mode=block",
    strict_transport_security: "max-age=31536000; includeSubDomains"
  }

# LLM Production Configuration
config :vsm_phoenix, :openai,
  api_key: {:system, "OPENAI_API_KEY"},
  model: "gpt-4",
  base_url: "https://api.openai.com/v1",
  timeout: 60_000,
  max_retries: 3,
  rate_limit: 60  # requests per minute

config :vsm_phoenix, :anthropic,
  api_key: {:system, "ANTHROPIC_API_KEY"},
  model: "claude-3-opus-20240229",
  base_url: "https://api.anthropic.com/v1",
  timeout: 60_000,
  max_retries: 3,
  rate_limit: 50  # requests per minute

# ML Configuration for Production
config :vsm_phoenix, :ml,
  # Model serving
  model_cache_size: 1000,
  model_timeout: 30_000,
  max_concurrent_inferences: 50,
  
  # Training
  training_data_retention_days: 90,
  max_training_time: 3600_000,  # 1 hour
  checkpoint_interval: 600_000,  # 10 minutes
  
  # Storage
  model_storage_path: {:system, "ML_MODELS_PATH", "/opt/vsm_phoenix/ml_models"},
  checkpoint_storage_path: {:system, "ML_CHECKPOINTS_PATH", "/opt/vsm_phoenix/ml_checkpoints"}

# Event Processing Configuration
config :vsm_phoenix, :events,
  # Event store
  max_events_per_stream: 10_000,
  snapshot_frequency: 1000,
  
  # Event processing
  batch_size: 100,
  max_concurrent_processors: 10,
  retry_attempts: 5,
  retry_backoff: 1000,  # milliseconds
  
  # Event retention
  retention_policy: %{
    default_retention_days: 365,
    audit_retention_days: 2555,  # 7 years
    performance_retention_days: 90
  }

# Monitoring and Observability
config :vsm_phoenix, :telemetry,
  # Metrics
  metrics_export_interval: 60_000,  # 1 minute
  metrics_retention_days: 30,
  
  # Logging
  log_level: :info,
  structured_logging: true,
  log_correlation_id: true,
  
  # Tracing
  tracing_enabled: true,
  trace_sample_rate: 0.1,  # 10% sampling
  
  # Health checks
  health_check_timeout: 5_000,
  health_check_interval: 30_000

# Deployment Configuration
config :vsm_phoenix, :deployment,
  # Zero-downtime deployment
  graceful_shutdown_timeout: 30_000,
  health_check_path: "/health",
  readiness_check_path: "/ready",
  
  # Load balancing
  load_balancer: %{
    algorithm: "round_robin",
    health_check_interval: 10_000,
    failure_threshold: 3,
    recovery_threshold: 2
  },
  
  # Auto-scaling
  auto_scaling: %{
    enabled: true,
    target_cpu_utilization: 70,
    target_memory_utilization: 80,
    scale_up_cooldown: 300_000,    # 5 minutes
    scale_down_cooldown: 600_000   # 10 minutes
  }

# External Service Configuration
config :vsm_phoenix, :external_services,
  # Service discovery
  consul_url: {:system, "CONSUL_URL"},
  
  # Message queue
  rabbitmq_url: {:system, "RABBITMQ_URL"},
  
  # Cache
  redis_url: {:system, "REDIS_URL"},
  
  # Object storage
  s3_bucket: {:system, "S3_BUCKET"},
  s3_region: {:system, "S3_REGION"},
  
  # Secrets management
  vault_url: {:system, "VAULT_URL"},
  vault_token: {:system, "VAULT_TOKEN"}

# Quantum Scheduler Production Configuration
config :vsm_phoenix, VsmPhoenix.Scheduler,
  jobs: [
    # System health audit every 30 minutes
    {"*/30 * * * *", {VsmPhoenix.HealthChecker, :run_system_audit, []}},
    
    # Performance metrics collection every 5 minutes
    {"*/5 * * * *", {VsmPhoenix.PerformanceMonitor, :collect_metrics, []}},
    
    # Viability assessment every 10 minutes
    {"*/10 * * * *", {VsmPhoenix.System5.Queen, :evaluate_viability, []}},
    
    # Environmental scan every 15 minutes
    {"*/15 * * * *", {VsmPhoenix.System4.Intelligence, :scan_environment, [:scheduled]}},
    
    # Resource optimization every 20 minutes
    {"*/20 * * * *", {VsmPhoenix.System3.Control, :optimize_performance, [:global]}},
    
    # Security audit log cleanup - daily at 2 AM
    {"0 2 * * *", {VsmPhoenix.SecurityAudit, :cleanup_old_logs, []}},
    
    # Model performance evaluation - daily at 3 AM
    {"0 3 * * *", {VsmPhoenix.ML.ModelManager, :evaluate_model_performance, []}},
    
    # Database maintenance - weekly on Sunday at 4 AM
    {"0 4 * * 0", {VsmPhoenix.DatabaseMaintenance, :run_maintenance, []}},
    
    # Backup creation - daily at 1 AM
    {"0 1 * * *", {VsmPhoenix.BackupManager, :create_backup, []}}
  ]

# Feature flags for production
config :vsm_phoenix, :features,
  mcp_servers_enabled: true,
  magg_integration_enabled: true,
  llm_variety_enabled: true,
  chaos_engineering_enabled: false,  # Disabled in production by default
  quantum_logic_enabled: true,
  emergent_intelligence_enabled: true,
  meta_vsm_enabled: true,
  algedonic_system_enabled: true,
  advanced_monitoring_enabled: true,
  auto_scaling_enabled: true

# Phoenix LiveView configuration for production
config :phoenix, :live_view,
  signing_salt: {:system, "LIVE_VIEW_SIGNING_SALT"}

# CORS configuration for production
config :cors_plug,
  origin: {:system, :list, "CORS_ORIGINS", []},
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"]