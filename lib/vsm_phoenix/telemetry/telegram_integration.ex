defmodule VsmPhoenix.Telemetry.TelegramIntegration do
  @moduledoc """
  Integration layer between Telegram bot and Analog-Signal Telemetry Architect
  
  Monitors Telegram bot activity using analog signal processing:
  - Message flow as continuous signal
  - Command patterns as waveforms
  - User interaction as frequency analysis
  - Error rates as anomaly detection
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Telemetry.{
    AnalogArchitect,
    SignalProcessor,
    PatternDetector,
    AdaptiveController,
    SignalVisualizer
  }
  
  @signal_ids %{
    message_rate: "telegram_message_rate",
    command_frequency: "telegram_command_freq",
    error_rate: "telegram_error_rate",
    response_time: "telegram_response_time",
    user_activity: "telegram_user_activity"
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def record_message(message_data) do
    GenServer.cast(__MODULE__, {:record_message, message_data})
  end
  
  def record_command(command, execution_time) do
    GenServer.cast(__MODULE__, {:record_command, command, execution_time})
  end
  
  def record_error(error_type, context) do
    GenServer.cast(__MODULE__, {:record_error, error_type, context})
  end
  
  def get_telegram_health do
    GenServer.call(__MODULE__, :get_health)
  end
  
  def get_performance_dashboard do
    GenServer.call(__MODULE__, :get_dashboard)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("📱🎛️ Initializing Telegram-Analog Telemetry Integration...")
    
    # Register signals with AnalogArchitect
    register_telegram_signals()
    
    # Set up adaptive thresholds
    setup_adaptive_monitoring()
    
    # Create visualizations
    create_telegram_dashboard()
    
    # Subscribe to Telegram events
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "telegram:events")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:telemetry")
    
    state = %{
      message_count: 0,
      command_count: 0,
      error_count: 0,
      start_time: DateTime.utc_now(),
      last_analysis: nil
    }
    
    # Schedule periodic analysis
    schedule_analysis()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_message, message_data}, state) do
    # Sample message rate signal
    timestamp = :erlang.system_time(:microsecond)
    
    # Record to message rate signal
    AnalogArchitect.sample_signal(
      @signal_ids.message_rate,
      1.0,  # One message
      %{
        chat_id: message_data[:chat_id],
        user_id: message_data[:user_id],
        text_length: String.length(message_data[:text] || ""),
        timestamp: timestamp
      }
    )
    
    # Record user activity signal
    user_activity_value = calculate_user_activity(message_data)
    AnalogArchitect.sample_signal(
      @signal_ids.user_activity,
      user_activity_value,
      %{user_id: message_data[:user_id]}
    )
    
    {:noreply, %{state | message_count: state.message_count + 1}}
  end
  
  @impl true
  def handle_cast({:record_command, command, execution_time}, state) do
    # Record command frequency
    AnalogArchitect.sample_signal(
      @signal_ids.command_frequency,
      1.0,
      %{command: command, timestamp: :erlang.system_time(:microsecond)}
    )
    
    # Record response time
    AnalogArchitect.sample_signal(
      @signal_ids.response_time,
      execution_time,
      %{command: command}
    )
    
    {:noreply, %{state | command_count: state.command_count + 1}}
  end
  
  @impl true
  def handle_cast({:record_error, error_type, context}, state) do
    # Record error rate signal with severity weighting
    error_weight = case error_type do
      :api_error -> 2.0
      :timeout -> 1.5
      :validation -> 0.5
      _ -> 1.0
    end
    
    AnalogArchitect.sample_signal(
      @signal_ids.error_rate,
      error_weight,
      %{
        error_type: error_type,
        context: context,
        timestamp: :erlang.system_time(:microsecond)
      }
    )
    
    {:noreply, %{state | error_count: state.error_count + 1}}
  end
  
  @impl true
  def handle_call(:get_health, _from, state) do
    # Analyze current signal patterns
    health_analysis = analyze_telegram_health(state)
    
    {:reply, health_analysis, state}
  end
  
  @impl true
  def handle_call(:get_dashboard, _from, state) do
    # Get visualization data for all signals
    dashboard_data = %{
      message_rate: SignalVisualizer.get_visualization_data("telegram_message_viz"),
      command_patterns: SignalVisualizer.get_visualization_data("telegram_command_viz"),
      error_analysis: SignalVisualizer.get_visualization_data("telegram_error_viz"),
      performance_metrics: SignalVisualizer.get_visualization_data("telegram_perf_viz")
    }
    
    {:reply, {:ok, dashboard_data}, state}
  end
  
  @impl true
  def handle_info(:analyze_signals, state) do
    # Perform comprehensive signal analysis
    analysis_results = perform_signal_analysis()
    
    # Check for anomalies
    check_for_anomalies(analysis_results)
    
    # Update adaptive thresholds
    update_adaptive_parameters(analysis_results)
    
    # Schedule next analysis
    schedule_analysis()
    
    {:noreply, %{state | last_analysis: analysis_results}}
  end
  
  @impl true
  def handle_info({:telegram_event, event}, state) do
    # Route telegram events to appropriate signal recording
    case event.type do
      :message_received -> record_message(event.data)
      :command_executed -> record_command(event.command, event.execution_time)
      :error_occurred -> record_error(event.error_type, event.context)
      _ -> :ok
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp register_telegram_signals do
    # Message rate signal - tracks messages per second
    AnalogArchitect.register_signal(@signal_ids.message_rate, %{
      sampling_rate: :high_frequency,
      buffer_size: 10000,
      filters: [
        %{type: :low_pass, params: %{cutoff: 10}},  # Filter out noise
        %{type: :butterworth, params: %{order: 2, cutoff: 5}}
      ],
      analysis_modes: [:frequency_spectrum, :peak_detection],
      metadata: %{
        unit: "messages/second",
        description: "Telegram message flow rate"
      }
    })
    
    # Command frequency signal
    AnalogArchitect.register_signal(@signal_ids.command_frequency, %{
      sampling_rate: :standard,
      buffer_size: 5000,
      analysis_modes: [:periodic, :trend],
      metadata: %{
        unit: "commands/minute",
        description: "Command execution frequency"
      }
    })
    
    # Error rate signal
    AnalogArchitect.register_signal(@signal_ids.error_rate, %{
      sampling_rate: :standard,
      buffer_size: 5000,
      filters: [
        %{type: :high_pass, params: %{cutoff: 0.1}}  # Detect spikes
      ],
      analysis_modes: [:anomaly, :trend],
      metadata: %{
        unit: "weighted errors/minute",
        description: "Error occurrence rate"
      }
    })
    
    # Response time signal
    AnalogArchitect.register_signal(@signal_ids.response_time, %{
      sampling_rate: :high_frequency,
      buffer_size: 10000,
      analysis_modes: [:envelope, :percentile],
      metadata: %{
        unit: "milliseconds",
        description: "Command execution response time"
      }
    })
    
    # User activity signal
    AnalogArchitect.register_signal(@signal_ids.user_activity, %{
      sampling_rate: :standard,
      buffer_size: 5000,
      analysis_modes: [:periodic, :clustering],
      metadata: %{
        unit: "activity score",
        description: "Aggregate user activity level"
      }
    })
  end
  
  defp setup_adaptive_monitoring do
    # Message rate adaptive threshold
    AdaptiveController.create_adaptive_threshold(@signal_ids.message_rate, %{
      strategy: :statistical,
      initial_threshold: 10.0,  # 10 messages/second baseline
      adaptation_rate: 0.1,
      hysteresis: 0.2,
      constraints: %{
        min: 1.0,
        max: 100.0
      }
    })
    
    # Error rate adaptive threshold
    AdaptiveController.create_adaptive_threshold(@signal_ids.error_rate, %{
      strategy: :percentile,
      target_percentile: 95,
      initial_threshold: 5.0,  # 5 weighted errors/minute
      adaptation_rate: 0.05
    })
    
    # Response time auto-scaler
    AdaptiveController.create_auto_scaler(@signal_ids.response_time, %{
      mode: :robust_scaling,
      input_range: {0, 10000},  # 0-10 seconds
      output_range: {0, 100},   # 0-100 performance score
      outlier_handling: :compress
    })
  end
  
  defp create_telegram_dashboard do
    # Message flow waveform
    SignalVisualizer.create_visualization("telegram_message_viz", %{
      type: :waveform,
      signal_ids: [@signal_ids.message_rate],
      update_rate: :fast,
      display_config: %{
        width: 800,
        height: 200,
        scale: :auto,
        colors: %{primary: "#0088cc"}
      }
    })
    
    # Command pattern spectrogram
    SignalVisualizer.create_visualization("telegram_command_viz", %{
      type: :spectrogram,
      signal_ids: [@signal_ids.command_frequency],
      update_rate: :normal,
      display_config: %{
        window_size: 256,
        overlap: 0.5,
        colormap: :viridis
      }
    })
    
    # Error anomaly detection
    SignalVisualizer.create_visualization("telegram_error_viz", %{
      type: :scatter_plot,
      signal_ids: [@signal_ids.error_rate],
      update_rate: :normal,
      display_config: %{
        dimensions: [:value, :timestamp],
        colors: %{danger: "#dc3545"}
      }
    })
    
    # Performance histogram
    SignalVisualizer.create_visualization("telegram_perf_viz", %{
      type: :histogram,
      signal_ids: [@signal_ids.response_time],
      update_rate: :slow,
      display_config: %{
        bins: 50,
        scale_type: :log
      }
    })
    
    # Create unified dashboard
    SignalVisualizer.create_dashboard("telegram_monitoring", [
      %{id: "telegram_message_viz"},
      %{id: "telegram_command_viz"},
      %{id: "telegram_error_viz"},
      %{id: "telegram_perf_viz"}
    ])
  end
  
  defp analyze_telegram_health(state) do
    # Get current signal values
    {:ok, message_rate} = AnalogArchitect.get_signal_data(@signal_ids.message_rate, %{last_n: 100})
    {:ok, error_rate} = AnalogArchitect.get_signal_data(@signal_ids.error_rate, %{last_n: 100})
    {:ok, response_time} = AnalogArchitect.get_signal_data(@signal_ids.response_time, %{last_n: 100})
    
    # Detect patterns
    {:ok, message_patterns} = PatternDetector.detect_patterns(@signal_ids.message_rate, [:trend, :anomaly])
    {:ok, error_patterns} = PatternDetector.find_anomalies(@signal_ids.error_rate, :high)
    
    # Calculate health scores
    message_health = calculate_message_health(message_rate, message_patterns)
    error_health = calculate_error_health(error_rate, error_patterns)
    performance_health = calculate_performance_health(response_time)
    
    # Overall health
    overall_health = (message_health + error_health + performance_health) / 3
    
    %{
      overall_health: overall_health,
      status: determine_health_status(overall_health),
      components: %{
        message_flow: %{
          health: message_health,
          current_rate: get_current_rate(message_rate),
          trend: message_patterns.trend
        },
        error_rate: %{
          health: error_health,
          anomalies: error_patterns.anomalies,
          current_rate: get_current_rate(error_rate)
        },
        performance: %{
          health: performance_health,
          avg_response_time: calculate_avg_response_time(response_time),
          p95_response_time: calculate_p95_response_time(response_time)
        }
      },
      uptime: DateTime.diff(DateTime.utc_now(), state.start_time),
      total_messages: state.message_count,
      total_errors: state.error_count
    }
  end
  
  defp perform_signal_analysis do
    # Comprehensive analysis of all Telegram signals
    %{
      message_flow: analyze_message_flow(),
      command_patterns: analyze_command_patterns(),
      error_analysis: analyze_errors(),
      user_behavior: analyze_user_behavior(),
      performance: analyze_performance()
    }
  end
  
  defp analyze_message_flow do
    {:ok, periodicity} = PatternDetector.find_periodicity(@signal_ids.message_rate)
    {:ok, trend} = PatternDetector.detect_trend(@signal_ids.message_rate)
    
    %{
      periodicity: periodicity,
      trend: trend,
      peak_hours: identify_peak_hours(periodicity),
      forecast: trend.forecast
    }
  end
  
  defp analyze_command_patterns do
    # Correlate command frequency with response times
    {:ok, correlation} = SignalProcessor.correlate_signals(
      @signal_ids.command_frequency,
      @signal_ids.response_time
    )
    
    %{
      correlation: correlation,
      command_clustering: detect_command_clusters(),
      bottlenecks: identify_performance_bottlenecks(correlation)
    }
  end
  
  defp check_for_anomalies(analysis_results) do
    # Check each component for anomalies
    Enum.each(analysis_results, fn {component, data} ->
      if has_anomaly?(data) do
        alert = %{
          component: component,
          anomaly_type: data.anomaly_type,
          severity: data.severity,
          timestamp: DateTime.utc_now()
        }
        
        # Broadcast alert
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "telegram:alerts",
          {:anomaly_detected, alert}
        )
        
        # Log for monitoring
        Logger.warning("📱⚠️ Telegram anomaly detected: #{inspect(alert)}")
      end
    end)
  end
  
  defp update_adaptive_parameters(analysis_results) do
    # Update adaptive thresholds based on analysis
    if analysis_results.message_flow.trend.type == :increasing do
      # Increase message rate threshold
      AdaptiveController.update_adaptation(
        @signal_ids.message_rate,
        %{
          error: 0.1,
          rate: analysis_results.message_flow.trend.slope
        }
      )
    end
    
    # Enable learning mode if patterns are stable
    if is_stable_pattern?(analysis_results) do
      AdaptiveController.enable_learning_mode(@signal_ids.message_rate)
      AdaptiveController.enable_learning_mode(@signal_ids.error_rate)
    end
  end
  
  # Helper Functions
  
  defp calculate_user_activity(message_data) do
    # Calculate activity score based on message characteristics
    base_score = 1.0
    
    # Adjust based on message length
    length_factor = min(String.length(message_data[:text] || "") / 100, 2.0)
    
    # Adjust based on command usage
    command_factor = if String.starts_with?(message_data[:text] || "", "/"), do: 1.5, else: 1.0
    
    base_score * length_factor * command_factor
  end
  
  defp calculate_message_health(signal_data, patterns) do
    # Health based on consistency and lack of anomalies
    anomalies = case patterns do
      %{anomaly: %{anomalies: anomaly_list}} -> anomaly_list
      %{anomalies: anomaly_list} -> anomaly_list
      _ -> []
    end
    
    if length(anomalies) == 0 do
      1.0
    else
      max(0.0, 1.0 - (length(anomalies) * 0.1))
    end
  end
  
  defp calculate_error_health(signal_data, error_patterns) do
    # Health inversely proportional to error rate
    error_score = case error_patterns do
      %{anomaly_score: score} -> score
      %{anomaly: %{anomaly_score: score}} -> score
      _ -> 0.0
    end
    max(0.0, 1.0 - error_score)
  end
  
  defp calculate_performance_health(response_time_data) do
    # Health based on response time consistency
    if response_time_data.sample_count > 0 do
      avg_time = calculate_avg_response_time(response_time_data)
      
      cond do
        avg_time < 100 -> 1.0      # Excellent
        avg_time < 500 -> 0.8      # Good
        avg_time < 1000 -> 0.6     # Fair
        avg_time < 5000 -> 0.4     # Poor
        true -> 0.2                # Critical
      end
    else
      0.5  # No data
    end
  end
  
  defp get_current_rate(signal_data) do
    if signal_data.sample_count > 0 do
      # Get last 10 samples and calculate rate
      recent_samples = signal_data.samples |> Enum.take(-10)
      
      if length(recent_samples) > 1 do
        time_span = (List.last(recent_samples).x - List.first(recent_samples).x) / 1_000_000
        total_value = recent_samples |> Enum.map(& &1.y) |> Enum.sum()
        
        if time_span > 0 do
          total_value / time_span
        else
          0.0
        end
      else
        0.0
      end
    else
      0.0
    end
  end
  
  defp calculate_avg_response_time(signal_data) do
    if signal_data.sample_count > 0 do
      values = Enum.map(signal_data.samples, & &1.y)
      Enum.sum(values) / length(values)
    else
      0
    end
  end
  
  defp calculate_p95_response_time(signal_data) do
    if signal_data.sample_count > 0 do
      values = signal_data.samples |> Enum.map(& &1.y) |> Enum.sort()
      index = round(length(values) * 0.95)
      Enum.at(values, index)
    else
      0
    end
  end
  
  defp determine_health_status(health_score) do
    cond do
      health_score >= 0.9 -> :excellent
      health_score >= 0.7 -> :good
      health_score >= 0.5 -> :fair
      health_score >= 0.3 -> :degraded
      true -> :critical
    end
  end
  
  defp identify_peak_hours(periodicity) do
    # Extract peak usage hours from periodicity analysis
    if periodicity.detected do
      # Simplified - would analyze actual time patterns
      ["09:00-10:00", "14:00-15:00", "20:00-21:00"]
    else
      []
    end
  end
  
  defp detect_command_clusters do
    # Simplified clustering
    %{clusters: [], method: :dbscan}
  end
  
  defp identify_performance_bottlenecks(correlation) do
    # Identify commands with high correlation to response time
    []
  end
  
  defp analyze_errors do
    %{patterns: [], severity: :low}
  end
  
  defp analyze_user_behavior do
    %{patterns: [], segments: []}
  end
  
  defp analyze_performance do
    %{bottlenecks: [], optimization_opportunities: []}
  end
  
  defp has_anomaly?(data) do
    Map.has_key?(data, :anomaly_type) && data.anomaly_type != nil
  end
  
  defp is_stable_pattern?(analysis_results) do
    # Check if patterns are stable enough for learning
    analysis_results.message_flow.trend.r_squared > 0.8
  end
  
  defp schedule_analysis do
    # Analyze every 30 seconds
    Process.send_after(self(), :analyze_signals, 30_000)
  end
end