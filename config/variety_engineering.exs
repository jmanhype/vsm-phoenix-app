import Config

# Variety Engineering Configuration
config :vsm_phoenix, :variety_engineering,
  # Filtering thresholds (0.0 - 1.0)
  filters: %{
    s1_to_s2: %{
      aggregation_window: 5_000,      # 5 seconds
      pattern_threshold: 0.7,         # 70% significance required
      initial_filtering_level: 1.0
    },
    s2_to_s3: %{
      pattern_threshold: 0.6,
      resource_urgency_boost: 0.2
    },
    s3_to_s4: %{
      trend_window: 60_000,           # 1 minute
      min_data_points: 5,
      trend_significance: 0.7
    },
    s4_to_s5: %{
      policy_relevance_threshold: 0.8,
      critical_severity: 0.9
    }
  },
  
  # Amplification factors (multipliers)
  amplifiers: %{
    s5_to_s4: %{
      initial_factor: 3,              # 1 policy → 3 directives
      max_factor: 10,
      policy_expansion_depth: 3
    },
    s4_to_s3: %{
      initial_factor: 2,              # 1 adaptation → 2 resource plans
      max_factor: 8
    },
    s3_to_s2: %{
      initial_factor: 3,              # 1 allocation → 3 coordination rules
      max_factor: 10
    },
    s2_to_s1: %{
      initial_factor: 5,              # 1 rule → 5 operational tasks
      max_factor: 15
    }
  },
  
  # Balance monitoring settings
  balance_monitor: %{
    check_interval: 10_000,           # 10 seconds
    imbalance_threshold: 0.3,         # 30% deviation triggers alert
    critical_threshold: 0.5,          # 50% deviation is critical
    auto_rebalance: true
  },
  
  # Variety metrics collection
  metrics: %{
    window_size: 60_000,              # 1 minute sliding window
    calculation_interval: 5_000,      # Calculate every 5 seconds
    history_limit: 100                # Keep last 100 measurements
  },
  
  # Performance tuning
  performance: %{
    max_buffer_size: 10_000,          # Max events to buffer
    parallel_processing: true,
    batch_size: 100
  }