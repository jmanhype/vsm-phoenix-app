# VSM Phoenix Resilience Configuration
# Production-ready configuration for all resilience patterns

import Config

# Circuit Breaker Configuration
config :vsm_phoenix, :circuit_breaker,
  # Default thresholds
  failure_threshold: 5,      # Failures before opening circuit
  success_threshold: 3,      # Successes to close from half-open
  timeout: 30_000,          # Time before half-open (30s)
  reset_timeout: 60_000,    # Time to reset failure count (1min)
  
  # Service-specific overrides
  services: %{
    amqp_connection: %{
      failure_threshold: 3,   # AMQP more sensitive
      timeout: 60_000        # Longer recovery time
    },
    telegram_api: %{
      failure_threshold: 10,  # Telegram rate limits are common
      timeout: 120_000       # 2 minute recovery
    },
    claude_api: %{
      failure_threshold: 3,   # LLM APIs expensive
      timeout: 180_000       # 3 minute recovery
    },
    external_apis: %{
      failure_threshold: 5,
      timeout: 30_000
    }
  }

# Retry Logic Configuration
config :vsm_phoenix, :retry,
  max_attempts: 5,
  base_backoff: 100,        # 100ms initial backoff
  max_backoff: 30_000,      # 30s maximum backoff
  backoff_multiplier: 2,
  jitter: true,             # Prevent thundering herd
  
  # Operation-specific settings
  operations: %{
    amqp_connection: %{
      max_attempts: 10,       # More attempts for AMQP
      base_backoff: 1_000,    # 1s initial
      max_backoff: 60_000     # 1min max
    },
    http_request: %{
      max_attempts: 3,
      base_backoff: 200,
      max_backoff: 5_000
    },
    llm_request: %{
      max_attempts: 5,
      base_backoff: 2_000,    # LLM APIs need more time
      max_backoff: 30_000
    },
    database_operation: %{
      max_attempts: 3,
      base_backoff: 100,
      max_backoff: 2_000
    }
  }

# Bulkhead Configuration
config :vsm_phoenix, :bulkheads,
  # AMQP Channel Pool
  amqp_channels: %{
    max_concurrent: 25,       # Production AMQP capacity
    max_waiting: 150,         # Large queue for burst traffic
    checkout_timeout: 10_000  # 10s timeout
  },
  
  # HTTP Connection Pool
  http_connections: %{
    max_concurrent: 100,      # High HTTP throughput
    max_waiting: 500,         # Large queue for web traffic
    checkout_timeout: 5_000   # 5s timeout
  },
  
  # LLM Request Pool (expensive operations)
  llm_requests: %{
    max_concurrent: 5,        # Limit concurrent LLM calls
    max_waiting: 20,          # Small queue for cost control
    checkout_timeout: 60_000  # 1min timeout for LLM
  },
  
  # Agent Spawning Pool
  agent_spawning: %{
    max_concurrent: 10,       # Reasonable agent creation rate
    max_waiting: 50,
    checkout_timeout: 30_000  # 30s for agent initialization
  },
  
  # Service Bus Operations
  service_bus: %{
    max_concurrent: 20,
    max_waiting: 100,
    checkout_timeout: 15_000
  }

# Health Monitoring Configuration
config :vsm_phoenix, :health_monitor,
  check_interval: 30_000,     # 30s health checks
  
  # Component-specific health check timeouts
  component_timeouts: %{
    amqp_connection: 5_000,
    circuit_breakers: 1_000,
    bulkheads: 1_000,
    http_clients: 3_000
  },
  
  # Alerting thresholds
  alert_thresholds: %{
    circuit_breaker_trips: 5,    # Alert after 5 trips in check interval
    bulkhead_rejections: 100,    # Alert after 100 rejections
    failed_health_checks: 3      # Alert after 3 consecutive failures
  }

# Telemetry Configuration
config :vsm_phoenix, :resilience_telemetry,
  # Enable/disable telemetry events
  enabled: true,
  
  # Metrics publishing interval
  metrics_interval: 5_000,    # 5s metrics broadcast
  
  # Telemetry event filters
  events: %{
    circuit_breaker_state_changes: true,
    retry_attempts: false,              # Too noisy for production
    bulkhead_checkouts: false,          # Too noisy for production
    health_checks: true,
    http_requests: false               # Enable for debugging only
  },
  
  # Prometheus metrics export
  prometheus: %{
    enabled: true,
    endpoint: "/metrics/resilience",
    auth_required: true
  }

# Production Overrides
# These settings are optimized for production workloads
if config_env() == :prod do
  config :vsm_phoenix, :circuit_breaker,
    services: %{
      amqp_connection: %{
        failure_threshold: 2,   # Fail fast in production
        timeout: 30_000
      },
      telegram_api: %{
        failure_threshold: 15,  # More tolerant of rate limits
        timeout: 300_000       # 5 minute recovery
      },
      claude_api: %{
        failure_threshold: 2,   # Expensive, fail fast
        timeout: 300_000       # 5 minute recovery
      }
    }
  
  config :vsm_phoenix, :bulkheads,
    # Increased capacity for production
    amqp_channels: %{
      max_concurrent: 50,
      max_waiting: 300,
      checkout_timeout: 15_000
    },
    
    http_connections: %{
      max_concurrent: 200,
      max_waiting: 1000,
      checkout_timeout: 10_000
    },
    
    llm_requests: %{
      max_concurrent: 10,      # Higher LLM concurrency for production
      max_waiting: 50,
      checkout_timeout: 120_000  # 2min timeout
    }
  
  config :vsm_phoenix, :health_monitor,
    check_interval: 15_000,    # More frequent checks in production
    
    alert_thresholds: %{
      circuit_breaker_trips: 3,     # Lower threshold for production alerts
      bulkhead_rejections: 50,
      failed_health_checks: 2
    }
  
  config :vsm_phoenix, :resilience_telemetry,
    metrics_interval: 10_000,       # More frequent metrics in production
    
    events: %{
      circuit_breaker_state_changes: true,
      retry_attempts: false,         # Keep disabled for performance
      bulkhead_checkouts: false,     # Keep disabled for performance
      health_checks: true,
      http_requests: false          # Disable unless debugging
    }
end

# Development Overrides
# These settings are optimized for development and testing
if config_env() == :dev do
  config :vsm_phoenix, :circuit_breaker,
    # More forgiving thresholds for development
    failure_threshold: 10,
    timeout: 10_000,           # Faster recovery in dev
    
    services: %{
      amqp_connection: %{
        failure_threshold: 5,
        timeout: 15_000
      }
    }
  
  config :vsm_phoenix, :bulkheads,
    # Lower capacity for development
    amqp_channels: %{max_concurrent: 10, max_waiting: 50},
    http_connections: %{max_concurrent: 20, max_waiting: 100},
    llm_requests: %{max_concurrent: 3, max_waiting: 10}
  
  config :vsm_phoenix, :resilience_telemetry,
    events: %{
      circuit_breaker_state_changes: true,
      retry_attempts: true,          # Enable for debugging
      bulkhead_checkouts: true,      # Enable for debugging
      health_checks: true,
      http_requests: true           # Enable for debugging
    }
end

# Test Environment
if config_env() == :test do
  config :vsm_phoenix, :circuit_breaker,
    # Fast failures for testing
    failure_threshold: 2,
    success_threshold: 1,
    timeout: 100,
    reset_timeout: 200
  
  config :vsm_phoenix, :retry,
    max_attempts: 2,
    base_backoff: 10,
    max_backoff: 100
  
  config :vsm_phoenix, :bulkheads,
    # Small capacity for tests
    amqp_channels: %{max_concurrent: 3, max_waiting: 5},
    http_connections: %{max_concurrent: 5, max_waiting: 10},
    llm_requests: %{max_concurrent: 2, max_waiting: 3}
  
  config :vsm_phoenix, :health_monitor,
    check_interval: 1_000        # Fast checks for testing
  
  config :vsm_phoenix, :resilience_telemetry,
    enabled: false             # Disable telemetry in tests
end