defmodule VsmPhoenix.Telemetry.Factories.TelemetryFactory do
  @moduledoc """
  Telemetry Factory - Factory Pattern Implementation
  
  Provides consistent object creation patterns across the telemetry system,
  eliminating inconsistent initialization and reducing coupling.
  
  Features:
  - Centralized configuration management
  - Consistent initialization patterns
  - Dependency injection support
  - Environment-aware defaults
  - Performance optimization
  """

  alias VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  alias VsmPhoenix.Telemetry.Behaviors.SharedLogging

  @default_signal_config %{
    sampling_rate: :standard,
    buffer_size: 1000,
    analysis_modes: [:basic],
    retention_policy: :default,
    compression_enabled: false
  }

  @signal_types %{
    performance: %{
      sampling_rate: :high,
      buffer_size: 2000,
      analysis_modes: [:basic, :trend, :anomaly],
      thresholds: %{warning: 1000, critical: 5000}  # microseconds
    },
    conversation: %{
      sampling_rate: :standard,
      buffer_size: 500,
      analysis_modes: [:basic, :semantic],
      retention_policy: :extended
    },
    system_health: %{
      sampling_rate: :high,
      buffer_size: 1500,
      analysis_modes: [:basic, :anomaly, :correlation],
      alert_thresholds: %{degraded: 0.7, critical: 0.4}
    },
    user_interaction: %{
      sampling_rate: :adaptive,
      buffer_size: 1000,
      analysis_modes: [:pattern, :semantic],
      privacy_mode: true
    }
  }

  @doc """
  Create a signal processor with appropriate configuration
  """
  def create_signal_processor(signal_type, opts \\ []) do
    config = build_signal_config(signal_type, opts)
    data_store = create_data_store(config.data_store_type)
    
    SharedLogging.log_telemetry_event(:info, :factory, 
      "Creating signal processor for #{signal_type}")
    
    processor_module = determine_processor_module(signal_type, config)
    
    case processor_module.start_link(config) do
      {:ok, pid} -> 
        register_processor(signal_type, pid, config)
        {:ok, pid}
      error -> error
    end
  end

  @doc """
  Create a pattern detector with specific capabilities
  """
  def create_pattern_detector(detection_types, opts \\ []) do
    config = build_pattern_detector_config(detection_types, opts)
    data_store = create_data_store(config.data_store_type)
    
    SharedLogging.log_telemetry_event(:info, :factory,
      "Creating pattern detector for #{inspect(detection_types)}")
    
    VsmPhoenix.Telemetry.PatternDetector.start_link(
      Map.merge(config, %{data_store: data_store})
    )
  end

  @doc """
  Create a semantic processor with language capabilities
  """
  def create_semantic_processor(language_features, opts \\ []) do
    config = build_semantic_config(language_features, opts)
    
    SharedLogging.log_telemetry_event(:info, :factory,
      "Creating semantic processor with features: #{inspect(language_features)}")
    
    VsmPhoenix.Telemetry.SemanticBlockProcessor.start_link(config)
  end

  @doc """
  Create appropriate data store based on requirements
  """
  def create_data_store(type \\ :ets, opts \\ []) do
    # Data stores should be started separately in supervisors
    # This factory just returns the module to use
    TelemetryDataStore.create(type)
  end

  @doc """
  Create a complete telemetry pipeline
  """
  def create_telemetry_pipeline(pipeline_config) do
    SharedLogging.log_telemetry_event(:info, :factory,
      "Creating telemetry pipeline: #{pipeline_config.name}")
    
    with {:ok, data_store} <- create_data_store(pipeline_config.data_store_type),
         {:ok, signal_processor} <- create_signal_processor(pipeline_config.signal_type),
         {:ok, pattern_detector} <- create_pattern_detector(pipeline_config.patterns),
         {:ok, semantic_processor} <- create_semantic_processor(pipeline_config.semantics) do
      
      pipeline = %{
        name: pipeline_config.name,
        data_store: data_store,
        signal_processor: signal_processor,
        pattern_detector: pattern_detector,
        semantic_processor: semantic_processor,
        created_at: DateTime.utc_now()
      }
      
      register_pipeline(pipeline_config.name, pipeline)
      {:ok, pipeline}
    else
      error ->
        SharedLogging.log_telemetry_event(:error, :factory,
          "Failed to create telemetry pipeline: #{inspect(error)}")
        {:error, :pipeline_creation_failed}
    end
  end

  @doc """
  Create analysis configuration for specific domains
  """
  def create_analysis_config(domain, requirements \\ []) do
    base_config = get_domain_config(domain)
    
    requirements
    |> Enum.reduce(base_config, fn requirement, config ->
      apply_requirement(config, requirement)
    end)
    |> validate_analysis_config()
  end

  @doc """
  Create monitoring setup for operational visibility
  """
  def create_monitoring_setup(component, monitoring_level \\ :standard) do
    config = build_monitoring_config(component, monitoring_level)
    
    SharedLogging.log_telemetry_event(:info, :factory,
      "Setting up #{monitoring_level} monitoring for #{component}")
    
    # Create monitoring pipeline
    monitoring_signals = create_monitoring_signals(component, config)
    alerting_rules = create_alerting_rules(component, config)
    dashboards = create_dashboard_config(component, config)
    
    %{
      component: component,
      level: monitoring_level,
      signals: monitoring_signals,
      alerting: alerting_rules,
      dashboards: dashboards,
      config: config
    }
  end

  # Private Implementation Functions

  defp build_signal_config(signal_type, opts) do
    base_config = Map.get(@signal_types, signal_type, @default_signal_config)
    user_config = Enum.into(opts, %{})
    
    Map.merge(base_config, user_config)
    |> Map.put(:signal_type, signal_type)
    |> Map.put(:data_store_type, determine_data_store_type(signal_type, user_config))
  end

  defp determine_processor_module(signal_type, config) do
    case signal_type do
      :performance -> 
        if :trend in config.analysis_modes do
          VsmPhoenix.Telemetry.PerformanceSignalProcessor
        else
          VsmPhoenix.Telemetry.BasicSignalProcessor
        end
      :conversation ->
        if :semantic in config.analysis_modes do
          VsmPhoenix.Telemetry.ConversationSignalProcessor
        else
          VsmPhoenix.Telemetry.BasicSignalProcessor
        end
      :system_health ->
        VsmPhoenix.Telemetry.HealthSignalProcessor
      _ ->
        VsmPhoenix.Telemetry.SignalProcessor  # Default processor
    end
  end

  defp build_pattern_detector_config(detection_types, opts) do
    %{
      detection_types: detection_types,
      data_store_type: Keyword.get(opts, :data_store, :ets),
      sensitivity: Keyword.get(opts, :sensitivity, :medium),
      window_size: Keyword.get(opts, :window_size, 100),
      correlation_threshold: Keyword.get(opts, :correlation_threshold, 0.7)
    }
  end

  defp build_semantic_config(language_features, opts) do
    %{
      language_features: language_features,
      xml_processing: :xml in language_features,
      context_aware: :context in language_features,
      meaning_graphs: :meaning_graphs in language_features,
      data_store_type: Keyword.get(opts, :data_store, :ets)
    }
  end

  defp build_data_store_config(type, opts) do
    base_configs = %{
      ets: %{
        table_opts: [:set, :public, :named_table, {:write_concurrency, true}]
      },
      crdt: %{
        sync_interval: 5000,
        node_discovery: true
      },
      memory: %{
        max_memory_mb: 100,
        cleanup_interval: 60_000
      },
      persistent: %{
        storage_path: "./data/telemetry",
        compression: true
      }
    }
    
    base_config = Map.get(base_configs, type, %{})
    user_config = Enum.into(opts, %{})
    
    Map.merge(base_config, user_config)
  end

  defp determine_data_store_type(:performance, config) when map_size(config) > 0 do
    if config[:high_volume], do: :ets, else: :memory
  end

  defp determine_data_store_type(:conversation, _config), do: :crdt  # Needs distribution

  defp determine_data_store_type(:system_health, _config), do: :ets  # High performance

  defp determine_data_store_type(_, config) do
    config[:data_store] || :memory
  end

  defp get_domain_config(domain) do
    domain_configs = %{
      telegram: %{
        signals: [:message_rate, :response_time, :user_satisfaction],
        patterns: [:conversation_flow, :user_behavior],
        semantics: [:intent_detection, :context_maintenance]
      },
      system_monitoring: %{
        signals: [:cpu_usage, :memory_usage, :response_time],
        patterns: [:load_spikes, :degradation_trends],
        semantics: [:health_classification]
      },
      performance: %{
        signals: [:execution_time, :throughput, :error_rate],
        patterns: [:performance_regression, :bottlenecks],
        semantics: [:performance_classification]
      }
    }
    
    Map.get(domain_configs, domain, %{
      signals: [:generic_metric],
      patterns: [:basic_patterns],
      semantics: [:basic_classification]
    })
  end

  defp apply_requirement(config, {:high_accuracy, _}) do
    Map.merge(config, %{
      sampling_rate: :high,
      analysis_depth: :comprehensive,
      validation_enabled: true
    })
  end

  defp apply_requirement(config, {:low_latency, _}) do
    Map.merge(config, %{
      buffer_size: 100,
      analysis_modes: [:basic],
      async_processing: true
    })
  end

  defp apply_requirement(config, {:high_volume, _}) do
    Map.merge(config, %{
      buffer_size: 5000,
      compression_enabled: true,
      batch_processing: true
    })
  end

  defp apply_requirement(config, requirement) do
    # Default: no change for unrecognized requirements
    config
  end

  defp validate_analysis_config(config) do
    # Ensure required fields are present
    required_fields = [:signals, :patterns]
    
    Enum.reduce(required_fields, config, fn field, acc ->
      if Map.has_key?(acc, field) do
        acc
      else
        Map.put(acc, field, [])
      end
    end)
  end

  defp build_monitoring_config(component, level) do
    base_config = %{
      metrics_collection: true,
      performance_tracking: level in [:standard, :comprehensive],
      health_monitoring: true,
      alerting_enabled: level in [:comprehensive]
    }
    
    level_configs = %{
      basic: %{alert_thresholds: %{error_rate: 0.1}},
      standard: %{
        alert_thresholds: %{error_rate: 0.05, response_time_p95: 1000}
      },
      comprehensive: %{
        alert_thresholds: %{
          error_rate: 0.01,
          response_time_p95: 500,
          memory_usage: 0.8,
          cpu_usage: 0.7
        },
        trend_analysis: true,
        predictive_alerts: true
      }
    }
    
    Map.merge(base_config, Map.get(level_configs, level, %{}))
  end

  defp create_monitoring_signals(component, config) do
    base_signals = ["#{component}_health", "#{component}_performance"]
    
    additional_signals = if config.performance_tracking do
      ["#{component}_response_time", "#{component}_throughput", "#{component}_error_rate"]
    else
      []
    end
    
    base_signals ++ additional_signals
  end

  defp create_alerting_rules(component, config) do
    if config.alerting_enabled do
      config.alert_thresholds
      |> Enum.map(fn {metric, threshold} ->
        %{
          component: component,
          metric: metric,
          threshold: threshold,
          severity: determine_alert_severity(metric, threshold)
        }
      end)
    else
      []
    end
  end

  defp create_dashboard_config(component, config) do
    %{
      component: component,
      charts: create_chart_config(component, config),
      refresh_interval: if(config.performance_tracking, do: 5000, else: 30000)
    }
  end

  defp create_chart_config(component, config) do
    base_charts = [
      %{type: :line, metric: "#{component}_health", title: "Health Status"},
      %{type: :gauge, metric: "#{component}_performance", title: "Performance"}
    ]
    
    if config.performance_tracking do
      performance_charts = [
        %{type: :line, metric: "#{component}_response_time", title: "Response Time"},
        %{type: :bar, metric: "#{component}_error_rate", title: "Error Rate"}
      ]
      base_charts ++ performance_charts
    else
      base_charts
    end
  end

  defp determine_alert_severity(metric, threshold) do
    case metric do
      metric when metric in [:error_rate, :failure_rate] -> :critical
      metric when metric in [:response_time_p95, :cpu_usage, :memory_usage] -> :warning
      _ -> :info
    end
  end

  defp register_processor(signal_type, pid, config) do
    Registry.register(VsmPhoenix.Telemetry.ProcessorRegistry, signal_type, %{
      pid: pid,
      config: config,
      created_at: DateTime.utc_now()
    })
  end

  defp register_pipeline(name, pipeline) do
    Registry.register(VsmPhoenix.Telemetry.PipelineRegistry, name, pipeline)
  end
end