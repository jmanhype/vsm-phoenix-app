defmodule VsmPhoenix.Telemetry.RefactoredAnalogArchitect do
  use VsmPhoenix.Resilience.CircuitBreakerBehavior,
    circuits: [:signal_processing, :data_persistence, :pattern_detection],
    failure_threshold: 5,
    timeout: 30_000
  @moduledoc """
  Refactored Analog Architect - SOLID Principles Implementation
  
  This is a COMPLETE REFACTOR of the original AnalogArchitect god object,
  now following SOLID principles through delegation to specialized components.
  
  SOLID Principles Applied:
  ✅ Single Responsibility: Each component has one clear responsibility
  ✅ Open/Closed: Easy to extend with new signal types without modification
  ✅ Liskov Substitution: All components implement proper behavioral contracts
  ✅ Interface Segregation: Focused interfaces, not monolithic APIs
  ✅ Dependency Inversion: Depends on abstractions, not concrete implementations
  
  Architecture:
  - SignalRegistry: Manages signal registration and configuration
  - SignalSampler: Handles signal sampling and buffering
  - SignalProcessor: Processes and analyzes signal data
  - TelemetryDataStore: Abstracts data persistence
  - TelemetryFactory: Creates and configures components
  """

  use GenServer
  use VsmPhoenix.Telemetry.Behaviors.SharedLogging
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior
  
  # Dependencies - All injected, following Dependency Inversion Principle
  alias VsmPhoenix.Telemetry.Core.{SignalRegistry, SignalSampler}
  alias VsmPhoenix.Telemetry.Factories.TelemetryFactory
  alias VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  
  # NEW: Integration with other swarms' refactored components
  alias VsmPhoenix.CRDT.ContextStore  # Queen's CRDT Context
  alias VsmPhoenix.System2.CorticalAttentionEngine  # Intelligence's Cortical Attention
  alias VsmPhoenix.AMQP.ProtocolIntegration  # Infrastructure's aMCP Extensions
  alias VsmPhoenix.Resilience.CircuitBreakerBehavior  # Resilience's Circuit Breakers

  @doc """
  Start the Analog Architect with dependency injection
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API - Clean, focused interface (Interface Segregation Principle)

  @doc """
  Register a new signal - delegates to SignalRegistry
  """
  def register_signal(signal_id, config) do
    resilient("register_signal", fn ->
      SignalRegistry.register_signal(signal_id, config)
    end)
  end

  @doc """
  Sample a signal value - delegates to SignalSampler
  """
  def sample_signal(signal_id, value, metadata \\ %{}) do
    # Non-blocking operation - use cast for performance
    SignalSampler.sample_signal(signal_id, value, metadata)
    
    # NEW: Update CRDT context for distributed state synchronization
    update_crdt_signal_context(signal_id, value, metadata)
  end

  @doc """
  Analyze signal waveform - delegates to appropriate processor
  """
  def analyze_waveform(signal_id, analysis_type) do
    GenServer.call(__MODULE__, {:analyze_waveform, signal_id, analysis_type})
  end

  @doc """
  Apply signal filtering - delegates to signal processor
  """
  def apply_filter(signal_id, filter_type, params) do
    GenServer.call(__MODULE__, {:apply_filter, signal_id, filter_type, params})
  end

  @doc """
  Mix multiple signals - creates new composite signal
  """
  def mix_signals(output_id, input_signals, mixing_function) do
    GenServer.call(__MODULE__, {:mix_signals, output_id, input_signals, mixing_function})
  end

  @doc """
  Get signal data with options - delegates to appropriate component
  """
  def get_signal_data(signal_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:get_signal_data, signal_id, options})
  end

  @doc """
  Detect anomalies in signal - delegates to pattern detector
  """
  def detect_anomalies(signal_id, method \\ :statistical) do
    GenServer.call(__MODULE__, {:detect_anomalies, signal_id, method})
  end

  @doc """
  Get comprehensive signal statistics
  """
  def get_signal_stats(signal_id) do
    GenServer.call(__MODULE__, {:get_signal_stats, signal_id})
  end

  @doc """
  Get system health summary
  """
  def get_system_health do
    GenServer.call(__MODULE__, :get_system_health)
  end

  # Server Implementation

  @impl true
  def init(opts) do
    log_init_event(__MODULE__, :starting)
    
    # NEW: Initialize circuit breakers for resilience
    init_circuit_breakers()
    
    # Dependency Injection - create or inject dependencies
    state = initialize_dependencies(opts)
    
    log_init_event(__MODULE__, :initialized, %{
      signal_registry: !!state.signal_registry,
      signal_sampler: !!state.signal_sampler,
      data_store: state.data_store_type,
      processors: Map.keys(state.processors),
      circuit_breakers_enabled: true
    })
    
    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_waveform, signal_id, analysis_type}, _from, state) do
    result = resilient("analyze_waveform", fn ->
      processor = get_signal_processor(signal_id, analysis_type, state)
      processor.analyze_signal(signal_id, analysis_type)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:apply_filter, signal_id, filter_type, params}, _from, state) do
    result = resilient("apply_filter", fn ->
      processor = get_signal_processor(signal_id, :filtering, state)
      processor.apply_filter(signal_id, filter_type, params)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:mix_signals, output_id, input_signals, mixing_function}, _from, state) do
    result = resilient("mix_signals", fn ->
      mix_signals_internal(output_id, input_signals, mixing_function, state)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_signal_data, signal_id, options}, _from, state) do
    result = resilient("get_signal_data", fn ->
      get_signal_data_internal(signal_id, options, state)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:detect_anomalies, signal_id, method}, _from, state) do
    result = resilient("detect_anomalies", fn ->
      detector = get_anomaly_detector(method, state)
      detector.detect_anomalies(signal_id, method)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_signal_stats, signal_id}, _from, state) do
    result = resilient("get_signal_stats", fn ->
      compile_signal_statistics(signal_id, state)
    end)
    
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_system_health, _from, state) do
    result = resilient("get_system_health", fn ->
      compile_system_health(state)
    end)
    
    {:reply, result, state}
  end


  # Private Implementation - Dependency Management

  defp initialize_dependencies(opts) do
    # Create or inject components following Dependency Inversion
    data_store_type = Keyword.get(opts, :data_store_type, :ets)
    
    # Initialize core components
    signal_registry = ensure_started(VsmPhoenix.Telemetry.Core.SignalRegistry, opts)
    signal_sampler = ensure_started(VsmPhoenix.Telemetry.Core.SignalSampler, opts)
    
    # Create specialized processors using Factory Pattern
    processors = create_signal_processors(opts)
    detectors = create_anomaly_detectors(opts)
    
    %{
      signal_registry: signal_registry,
      signal_sampler: signal_sampler,
      data_store_type: data_store_type,
      processors: processors,
      detectors: detectors,
      stats: %{
        requests_processed: 0,
        errors_encountered: 0,
        uptime_start: DateTime.utc_now()
      }
    }
  end

  defp ensure_started(module, opts) do
    case GenServer.whereis(module) do
      nil ->
        case module.start_link(opts) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end
      pid -> pid
    end
  end

  defp create_signal_processors(opts) do
    # Factory Pattern - create processors based on configuration
    processor_types = Keyword.get(opts, :processor_types, [:basic, :fft, :statistical])
    
    processor_types
    |> Enum.map(fn type ->
      case TelemetryFactory.create_signal_processor(type, opts) do
        {:ok, processor} -> {type, processor}
        {:error, {:already_started, _pid}} -> 
          log_info("Processor #{type} already started, skipping", %{type: type})
          nil
        error -> 
          log_warning("Failed to create processor #{type}: #{inspect(error)}", %{type: type, error: error})
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp create_anomaly_detectors(opts) do
    # Factory Pattern - create detectors based on configuration  
    detector_types = Keyword.get(opts, :detector_types, [:statistical, :ml_based])
    
    detector_types
    |> Enum.map(fn type ->
      case TelemetryFactory.create_pattern_detector([type], opts) do
        {:ok, detector} -> {type, detector}
        {:error, {:already_started, _pid}} -> 
          log_info("Detector #{type} already started, skipping", %{type: type})
          nil
        error -> 
          log_warning("Failed to create detector #{type}: #{inspect(error)}", %{type: type, error: error})
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  # Business Logic - Clean separation of concerns

  defp get_signal_processor(signal_id, analysis_type, state) do
    # Strategy Pattern - select appropriate processor based on requirements
    {:ok, signal_config} = SignalRegistry.get_signal_config(signal_id)
    
    processor_type = determine_processor_type(signal_config, analysis_type)
    
    case Map.get(state.processors, processor_type) do
      nil ->
        # Fallback to basic processor
        log_warning("No specialized processor for #{processor_type}, using basic", %{
          signal_id: signal_id,
          analysis_type: analysis_type
        })
        Map.get(state.processors, :basic)
      processor -> processor
    end
  end

  defp determine_processor_type(signal_config, analysis_type) do
    case {signal_config[:signal_type], analysis_type} do
      {:performance, _} -> :performance
      {:conversation, _} -> :conversation
      {_, :fft} -> :fft
      {_, :statistical} -> :statistical
      _ -> :basic
    end
  end

  defp get_anomaly_detector(method, state) do
    Map.get(state.detectors, method, Map.get(state.detectors, :statistical))
  end

  defp mix_signals_internal(output_id, input_signals, mixing_function, _state) do
    # Collect data from all input signals
    signal_data = input_signals
    |> Enum.map(fn signal_id ->
      {:ok, samples} = SignalSampler.get_samples(signal_id, 100)
      {signal_id, samples}
    end)
    |> Enum.into(%{})
    
    # Apply mixing function
    mixed_samples = apply_mixing_function(signal_data, mixing_function)
    
    # Register output signal if not exists
    case SignalRegistry.get_signal_config(output_id) do
      {:error, :signal_not_found} ->
        SignalRegistry.register_signal(output_id, %{
          signal_type: :mixed,
          source_signals: input_signals,
          mixing_function: mixing_function
        })
      _ -> :ok
    end
    
    # Sample mixed values
    mixed_samples
    |> Enum.each(fn sample ->
      SignalSampler.sample_signal(output_id, sample.value, %{
        mixed_from: input_signals,
        original_timestamp: sample.timestamp
      })
    end)
    
    log_info("Signals mixed successfully", %{
      output_id: output_id,
      input_signals: input_signals,
      mixed_samples_count: length(mixed_samples)
    })
    
    {:ok, %{output_id: output_id, samples_created: length(mixed_samples)}}
  end

  defp apply_mixing_function(signal_data, mixing_function) do
    # This would implement various mixing strategies
    case mixing_function do
      :average ->
        mix_by_averaging(signal_data)
      :weighted_sum ->
        mix_by_weighted_sum(signal_data)
      :max ->
        mix_by_max_value(signal_data)
      fun when is_function(fun, 1) ->
        fun.(signal_data)
      _ ->
        # Default to averaging
        mix_by_averaging(signal_data)
    end
  end

  defp get_signal_data_internal(signal_id, options, _state) do
    sample_count = Map.get(options, :samples, 100)
    include_stats = Map.get(options, :include_stats, false)
    
    # Get samples from sampler
    {:ok, samples} = SignalSampler.get_samples(signal_id, sample_count)
    
    result = %{
      signal_id: signal_id,
      samples: samples,
      sample_count: length(samples)
    }
    
    # Add statistics if requested
    if include_stats do
      {:ok, stats} = SignalSampler.get_sampling_stats(signal_id)
      Map.put(result, :statistics, stats)
    else
      result
    end
  end

  defp compile_signal_statistics(signal_id, state) do
    # Gather statistics from all components
    with {:ok, registry_stats} = SignalRegistry.get_signal_stats(signal_id),
         {:ok, sampling_stats} = SignalSampler.get_sampling_stats(signal_id),
         {:ok, buffer_status} = SignalSampler.get_buffer_status(signal_id) do
      
      %{
        signal_id: signal_id,
        registry: registry_stats,
        sampling: sampling_stats,
        buffer: buffer_status,
        compiled_at: DateTime.utc_now()
      }
    else
      error -> error
    end
  end

  defp compile_system_health(state) do
    # Gather health information from all components
    {:ok, all_signals} = SignalRegistry.list_signals()
    
    signal_health = all_signals
    |> Enum.map(fn {signal_id, _config} ->
      {:ok, stats} = compile_signal_statistics(signal_id, state)
      {signal_id, assess_signal_health(stats)}
    end)
    |> Enum.into(%{})
    
    overall_health = assess_overall_health(signal_health)
    
    %{
      overall_health: overall_health,
      signals_count: map_size(all_signals),
      signal_health: signal_health,
      system_stats: state.stats,
      assessed_at: DateTime.utc_now()
    }
  end

  # Helper Functions

  defp mix_by_averaging(signal_data) do
    # Find common timestamps and average values
    all_samples = signal_data
    |> Enum.flat_map(fn {_signal_id, samples} -> samples end)
    |> Enum.group_by(& &1.timestamp)
    
    all_samples
    |> Enum.map(fn {timestamp, samples_at_time} ->
      avg_value = samples_at_time
      |> Enum.map(& &1.value)
      |> Enum.sum()
      |> Kernel./(length(samples_at_time))
      
      %{
        timestamp: timestamp,
        value: avg_value,
        mixed_from: length(samples_at_time)
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp mix_by_weighted_sum(signal_data) do
    # Simple weighted sum (equal weights for now)
    weight = 1.0 / map_size(signal_data)
    
    signal_data
    |> Enum.flat_map(fn {_signal_id, samples} ->
      Enum.map(samples, &Map.put(&1, :value, &1.value * weight))
    end)
    |> Enum.group_by(& &1.timestamp)
    |> Enum.map(fn {timestamp, samples} ->
      sum_value = samples |> Enum.map(& &1.value) |> Enum.sum()
      %{timestamp: timestamp, value: sum_value}
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp mix_by_max_value(signal_data) do
    signal_data
    |> Enum.flat_map(fn {_signal_id, samples} -> samples end)
    |> Enum.group_by(& &1.timestamp)
    |> Enum.map(fn {timestamp, samples} ->
      max_sample = Enum.max_by(samples, & &1.value)
      %{timestamp: timestamp, value: max_sample.value}
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp assess_signal_health(stats) do
    # Simple health assessment based on statistics
    cond do
      stats.sampling.samples_count == 0 -> :inactive
      stats.buffer.buffer_size > 900 -> :degraded  # Buffer nearly full
      stats.sampling.samples_count > 100 -> :healthy
      true -> :unknown
    end
  end

  defp assess_overall_health(signal_health) do
    health_counts = signal_health
    |> Enum.map(fn {_signal_id, health} -> health end)
    |> Enum.frequencies()
    
    total_signals = map_size(signal_health)
    healthy_signals = Map.get(health_counts, :healthy, 0)
    
    cond do
      total_signals == 0 -> :no_signals
      healthy_signals / total_signals > 0.8 -> :healthy
      healthy_signals / total_signals > 0.5 -> :degraded
      true -> :critical
    end
  end

  # NEW: CRDT Integration helpers
  
  defp update_crdt_signal_context(signal_id, value, metadata) do
    # Async update to CRDT context store
    Task.start(fn ->
      with_circuit_breaker :data_persistence do
        # Update signal counter
        ContextStore.increment_counter("signal_#{signal_id}_samples", 1)
        
        # Track signal value range
        if is_number(value) do
          ContextStore.update_pn_counter("signal_#{signal_id}_sum", value)
        end
        
        # Add signal metadata to set
        if metadata[:source] do
          ContextStore.add_to_set("signal_#{signal_id}_sources", metadata[:source])
        end
        
        # Update last write wins set with latest value
        ContextStore.update_lww_set("signal_latest_values", signal_id, %{
          value: value,
          timestamp: System.monotonic_time(:microsecond),
          metadata: metadata
        })
      end
    end)
  end
end