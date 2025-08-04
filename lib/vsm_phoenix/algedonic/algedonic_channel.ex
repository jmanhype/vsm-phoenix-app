defmodule VsmPhoenix.Algedonic.AlgedonicChannel do
  @moduledoc """
  Algedonic Channel for direct S1→S5 emergency communication.
  
  Implements direct pain/pleasure signaling that bypasses the normal
  hierarchical channels when immediate attention is required.
  
  Pain signals: Critical system issues requiring immediate intervention
  Pleasure signals: Positive reinforcement for successful adaptations
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System1.Registry, as: S1Registry
  alias VsmPhoenix.Algedonic.{PainProcessor, PleasureProcessor, AutonomicResponse}
  
  @type signal_type :: :pain | :pleasure
  @type signal_intensity :: :low | :medium | :high | :critical
  
  @type algedonic_signal :: %{
    type: signal_type(),
    intensity: signal_intensity(),
    source: String.t(),
    timestamp: DateTime.t(),
    data: map(),
    bypass_hierarchy: boolean()
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Send a pain signal (critical issue) directly to S5
  """
  def pain_signal(source, intensity, data) when intensity in [:high, :critical] do
    signal = %{
      type: :pain,
      intensity: intensity,
      source: source,
      timestamp: DateTime.utc_now(),
      data: data,
      bypass_hierarchy: true
    }
    
    GenServer.cast(__MODULE__, {:algedonic_signal, signal})
  end
  
  @doc """
  Send a pleasure signal (positive feedback) for reinforcement
  """
  def pleasure_signal(source, intensity, data) do
    signal = %{
      type: :pleasure,
      intensity: intensity,
      source: source,
      timestamp: DateTime.utc_now(),
      data: data,
      bypass_hierarchy: intensity in [:high, :critical]
    }
    
    GenServer.cast(__MODULE__, {:algedonic_signal, signal})
  end
  
  @doc """
  Check if algedonic threshold has been crossed
  """
  def threshold_crossed?(metric, value) do
    GenServer.call(__MODULE__, {:check_threshold, metric, value})
  end
  
  @doc """
  Get recent algedonic signals for analysis
  """
  def recent_signals(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_recent_signals, limit})
  end
  
  # Server Callbacks
  
  def init(_opts) do
    state = %{
      signals: [],
      thresholds: configure_thresholds(),
      autonomic_responses: %{},
      direct_channel_open: false,
      signal_buffer: :queue.new(),
      metrics: %{
        pain_count: 0,
        pleasure_count: 0,
        bypassed_count: 0,
        autonomic_triggers: 0
      }
    }
    
    # Subscribe to system telemetry for automatic monitoring
    :telemetry.attach(
      "algedonic-monitor",
      [:vsm, :system, :critical],
      &handle_telemetry_event/4,
      nil
    )
    
    {:ok, state}
  end
  
  def handle_cast({:algedonic_signal, signal}, state) do
    Logger.info("Algedonic signal received: #{signal.type} - #{signal.intensity} from #{signal.source}")
    
    # Update metrics
    state = update_metrics(state, signal)
    
    # Process based on signal type
    state = case signal.type do
      :pain -> process_pain_signal(signal, state)
      :pleasure -> process_pleasure_signal(signal, state)
    end
    
    # Store signal in buffer
    state = buffer_signal(state, signal)
    
    # Check for autonomic response triggers
    state = check_autonomic_triggers(state, signal)
    
    {:noreply, state}
  end
  
  def handle_call({:check_threshold, metric, value}, _from, state) do
    threshold = Map.get(state.thresholds, metric, :infinity)
    crossed = value >= threshold
    
    if crossed do
      # Automatically generate pain signal for threshold breach
      pain_signal("threshold_monitor", :high, %{
        metric: metric,
        value: value,
        threshold: threshold
      })
    end
    
    {:reply, crossed, state}
  end
  
  def handle_call({:get_recent_signals, limit}, _from, state) do
    recent = Enum.take(state.signals, limit)
    {:reply, recent, state}
  end
  
  # Private Functions
  
  defp process_pain_signal(signal, state) do
    case signal.intensity do
      :critical ->
        # Open direct channel to S5 immediately
        open_direct_channel(signal)
        
        # Trigger autonomic response
        AutonomicResponse.trigger_emergency(signal)
        
        # Notify all systems
        broadcast_emergency(signal)
        
        %{state | direct_channel_open: true}
        
      :high ->
        # Send to S5 with high priority
        send_to_s5(signal, :high_priority)
        
        # Alert S3 for immediate control action
        notify_s3_control(signal)
        
        state
        
      _ ->
        # Regular pain processing through normal channels
        PainProcessor.process(signal)
        state
    end
  end
  
  defp process_pleasure_signal(signal, state) do
    # Process pleasure signal for positive reinforcement
    PleasureProcessor.process(signal)
    
    # If high intensity, notify S5 for policy learning
    if signal.intensity in [:high, :critical] do
      send_to_s5(signal, :learning_opportunity)
    end
    
    # Update learning metrics
    update_learning_metrics(state, signal)
  end
  
  defp open_direct_channel(signal) do
    Logger.error("🚨 OPENING DIRECT ALGEDONIC CHANNEL S1→S5")
    
    # Bypass all intermediate systems
    Queen.emergency_signal(%{
      type: :algedonic_pain,
      severity: :critical,
      source: signal.source,
      data: signal.data,
      timestamp: signal.timestamp,
      bypass_hierarchy: true
    })
  end
  
  defp send_to_s5(signal, priority) do
    Queen.receive_signal(%{
      type: :algedonic,
      signal: signal,
      priority: priority
    })
  end
  
  defp notify_s3_control(signal) do
    GenServer.cast(VsmPhoenix.System3.Control, {:algedonic_alert, signal})
  end
  
  defp broadcast_emergency(signal) do
    # Notify all systems of emergency
    :telemetry.execute(
      [:vsm, :algedonic, :emergency],
      %{severity: 1.0},
      %{signal: signal}
    )
  end
  
  defp check_autonomic_triggers(state, signal) do
    # Check if this signal should trigger autonomic response
    if should_trigger_autonomic?(signal, state) do
      AutonomicResponse.execute(signal, state.autonomic_responses)
      %{state | metrics: Map.update!(state.metrics, :autonomic_triggers, &(&1 + 1))}
    else
      state
    end
  end
  
  defp should_trigger_autonomic?(signal, state) do
    # Trigger autonomic response for:
    # - Critical pain signals
    # - Repeated high-intensity signals
    # - Specific emergency patterns
    signal.intensity == :critical or
    (signal.type == :pain and state.metrics.pain_count > 5) or
    pattern_match_emergency?(signal.data)
  end
  
  defp pattern_match_emergency?(data) do
    # Check for known emergency patterns
    Map.get(data, :emergency, false) or
    Map.get(data, :system_failure, false) or
    Map.get(data, :security_breach, false)
  end
  
  defp buffer_signal(state, signal) do
    # Add to buffer and maintain size limit
    buffer = :queue.in(signal, state.signal_buffer)
    buffer = if :queue.len(buffer) > 1000 do
      {_, buffer} = :queue.out(buffer)
      buffer
    else
      buffer
    end
    
    %{state | 
      signal_buffer: buffer,
      signals: [signal | Enum.take(state.signals, 999)]
    }
  end
  
  defp update_metrics(state, signal) do
    metrics = case signal.type do
      :pain -> Map.update!(state.metrics, :pain_count, &(&1 + 1))
      :pleasure -> Map.update!(state.metrics, :pleasure_count, &(&1 + 1))
    end
    
    metrics = if signal.bypass_hierarchy do
      Map.update!(metrics, :bypassed_count, &(&1 + 1))
    else
      metrics
    end
    
    %{state | metrics: metrics}
  end
  
  defp update_learning_metrics(state, signal) do
    # Track positive reinforcement for learning
    :telemetry.execute(
      [:vsm, :algedonic, :learning],
      %{intensity: intensity_to_value(signal.intensity)},
      %{signal: signal}
    )
    
    state
  end
  
  defp intensity_to_value(:low), do: 0.25
  defp intensity_to_value(:medium), do: 0.5
  defp intensity_to_value(:high), do: 0.75
  defp intensity_to_value(:critical), do: 1.0
  
  defp configure_thresholds do
    %{
      error_rate: 0.1,        # 10% error rate triggers pain
      latency_ms: 5000,       # 5 second latency triggers pain
      memory_usage: 0.9,      # 90% memory usage triggers pain
      cpu_usage: 0.95,        # 95% CPU usage triggers pain
      variety_imbalance: 2.0, # 2x variety imbalance triggers pain
      success_rate: 0.95      # 95% success rate triggers pleasure
    }
  end
  
  defp handle_telemetry_event(_event_name, measurements, metadata, _config) do
    # Monitor telemetry for automatic algedonic signal generation
    if measurements[:severity] && measurements[:severity] > 0.8 do
      pain_signal(
        "telemetry_monitor",
        :high,
        Map.merge(measurements, metadata)
      )
    end
  end
end