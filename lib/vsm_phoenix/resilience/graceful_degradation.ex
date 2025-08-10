defmodule VsmPhoenix.Resilience.GracefulDegradation do
  @moduledoc """
  Claude Code-inspired graceful degradation strategies based on context management patterns.
  
  Implements intelligent system degradation that preserves core functionality while 
  reducing resource consumption during stress conditions, similar to how Claude 
  manages context window constraints.
  """

  use GenServer
  require Logger

  defstruct name: nil,
            # Current degradation level (0 = normal, 5 = emergency)
            current_level: 0,
            # Context management inspired by Claude
            context_windows: %{},
            essential_operations: MapSet.new(),
            non_essential_operations: MapSet.new(),
            # Stress monitoring
            stress_indicators: %{},
            stress_thresholds: %{
              level_1: %{cpu: 70, memory: 80, response_time: 200},
              level_2: %{cpu: 80, memory: 85, response_time: 500}, 
              level_3: %{cpu: 85, memory: 90, response_time: 1000},
              level_4: %{cpu: 90, memory: 95, response_time: 2000},
              level_5: %{cpu: 95, memory: 98, response_time: 5000}
            },
            # Claude-inspired context preservation
            context_preservation_strategy: :adaptive,
            operation_priority_map: %{},
            resource_reallocation: %{},
            # Metrics
            metrics: %{
              degradations_triggered: 0,
              operations_shed: 0,
              context_compressions: 0,
              recovery_time: 0,
              user_impact_score: 0.0
            }

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register an operation as essential (Claude core functionality equivalent)
  """
  def register_essential_operation(degradation_server, operation_id) do
    GenServer.cast(degradation_server, {:register_essential, operation_id})
  end

  @doc """
  Register an operation as non-essential (Claude auxiliary features equivalent)
  """
  def register_non_essential_operation(degradation_server, operation_id) do
    GenServer.cast(degradation_server, {:register_non_essential, operation_id})
  end

  @doc """
  Check if an operation should proceed given current degradation level
  """
  def should_execute_operation?(degradation_server, operation_id) do
    GenServer.call(degradation_server, {:should_execute, operation_id})
  end

  @doc """
  Report stress indicators to trigger degradation assessment
  """
  def report_stress_indicators(degradation_server, indicators) do
    GenServer.cast(degradation_server, {:update_stress, indicators})
  end

  @doc """
  Create a context window for operation management (Claude-inspired)
  """
  def create_context_window(degradation_server, context_id, max_operations, priority_fn) do
    GenServer.cast(degradation_server, {:create_context, context_id, max_operations, priority_fn})
  end

  @doc """
  Compress context window by removing low-priority operations (Claude's context management)
  """
  def compress_context_window(degradation_server, context_id, target_size) do
    GenServer.call(degradation_server, {:compress_context, context_id, target_size})
  end

  @doc """
  Force degradation to a specific level (for testing/emergency)
  """
  def set_degradation_level(degradation_server, level) do
    GenServer.cast(degradation_server, {:force_degradation, level})
  end

  @doc """
  Get current degradation status
  """
  def get_status(degradation_server) do
    GenServer.call(degradation_server, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    
    # Initialize essential operations (similar to Claude's core capabilities)
    essential_ops = MapSet.new([
      :authentication,
      :data_persistence, 
      :critical_api_endpoints,
      :health_checks,
      :error_handling
    ])

    # Non-essential operations (similar to Claude's auxiliary features)
    non_essential_ops = MapSet.new([
      :detailed_logging,
      :metrics_collection,
      :background_analytics,
      :cache_warming,
      :performance_profiling,
      :feature_flags_sync
    ])

    state = %__MODULE__{
      name: name,
      essential_operations: essential_ops,
      non_essential_operations: non_essential_ops,
      operation_priority_map: create_default_priority_map()
    }

    # Start monitoring stress indicators
    schedule_stress_assessment(5_000)  # Every 5 seconds
    
    Logger.info("🎛️ Graceful degradation system #{name} initialized")
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:register_essential, operation_id}, state) do
    new_essential = MapSet.put(state.essential_operations, operation_id)
    new_non_essential = MapSet.delete(state.non_essential_operations, operation_id)
    
    {:noreply, %{state | 
      essential_operations: new_essential, 
      non_essential_operations: new_non_essential
    }}
  end

  @impl true
  def handle_cast({:register_non_essential, operation_id}, state) do
    new_non_essential = MapSet.put(state.non_essential_operations, operation_id)
    new_essential = MapSet.delete(state.essential_operations, operation_id)
    
    {:noreply, %{state | 
      essential_operations: new_essential,
      non_essential_operations: new_non_essential  
    }}
  end

  @impl true
  def handle_cast({:update_stress, indicators}, state) do
    updated_indicators = Map.merge(state.stress_indicators, indicators)
    new_state = %{state | stress_indicators: updated_indicators}
    
    # Assess if degradation level needs to change
    assessed_state = assess_degradation_level(new_state)
    
    {:noreply, assessed_state}
  end

  @impl true
  def handle_cast({:create_context, context_id, max_operations, priority_fn}, state) do
    context_window = %{
      id: context_id,
      max_operations: max_operations,
      current_operations: [],
      priority_function: priority_fn,
      created_at: System.monotonic_time(:millisecond)
    }
    
    new_contexts = Map.put(state.context_windows, context_id, context_window)
    
    Logger.info("🪟 Created context window #{context_id} with capacity #{max_operations}")
    
    {:noreply, %{state | context_windows: new_contexts}}
  end

  @impl true
  def handle_cast({:force_degradation, level}, state) do
    new_state = transition_to_degradation_level(state, level, :forced)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:should_execute, operation_id}, _from, state) do
    decision = make_operation_decision(state, operation_id)
    {:reply, decision, state}
  end

  @impl true 
  def handle_call({:compress_context, context_id, target_size}, _from, state) do
    case Map.get(state.context_windows, context_id) do
      nil ->
        {:reply, {:error, :context_not_found}, state}
      
      context ->
        compressed_context = compress_context_claude_style(context, target_size)
        new_contexts = Map.put(state.context_windows, context_id, compressed_context)
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :context_compressions, &(&1 + 1))
        
        new_state = %{state | 
          context_windows: new_contexts,
          metrics: new_metrics
        }
        
        operations_removed = length(context.current_operations) - length(compressed_context.current_operations)
        Logger.info("🗜️ Compressed context #{context_id}: removed #{operations_removed} operations")
        
        {:reply, {:ok, operations_removed}, new_state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      current_level: state.current_level,
      stress_indicators: state.stress_indicators,
      essential_operations_count: MapSet.size(state.essential_operations),
      non_essential_operations_count: MapSet.size(state.non_essential_operations),
      context_windows_count: map_size(state.context_windows),
      metrics: state.metrics
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_info(:assess_stress, state) do
    # Periodic stress assessment (Claude's continuous evaluation approach)
    updated_state = collect_and_assess_stress_indicators(state)
    
    # Schedule next assessment
    schedule_stress_assessment(5_000)
    
    {:noreply, updated_state}
  end

  # Private Functions

  defp create_default_priority_map() do
    %{
      # Essential operations (highest priority)
      :authentication => 100,
      :data_persistence => 95,
      :critical_api_endpoints => 90,
      :health_checks => 85,
      :error_handling => 80,
      
      # Important but degradable
      :user_requests => 70,
      :api_responses => 65,
      :data_retrieval => 60,
      
      # Nice-to-have features
      :metrics_collection => 40,
      :detailed_logging => 30,
      :background_analytics => 20,
      :cache_warming => 15,
      :performance_profiling => 10,
      :feature_flags_sync => 5
    }
  end

  defp make_operation_decision(state, operation_id) do
    cond do
      # Always allow essential operations
      MapSet.member?(state.essential_operations, operation_id) ->
        {:ok, :essential}
      
      # Block non-essential operations at higher degradation levels  
      MapSet.member?(state.non_essential_operations, operation_id) and state.current_level >= 2 ->
        {:blocked, :non_essential_shed, state.current_level}
      
      # Use priority-based decisions for other operations
      true ->
        priority = Map.get(state.operation_priority_map, operation_id, 50)
        required_priority = calculate_required_priority(state.current_level)
        
        if priority >= required_priority do
          {:ok, :priority_based}
        else
          {:blocked, :insufficient_priority, state.current_level}
        end
    end
  end

  defp calculate_required_priority(degradation_level) do
    case degradation_level do
      0 -> 0    # Normal - all operations allowed
      1 -> 20   # Light degradation - drop lowest priority
      2 -> 40   # Moderate degradation - focus on important operations
      3 -> 60   # Heavy degradation - essential + important only
      4 -> 80   # Critical degradation - near-essential only
      5 -> 95   # Emergency - essential operations only
    end
  end

  defp assess_degradation_level(state) do
    # Claude-style assessment: systematic evaluation of multiple factors
    stress_level = calculate_stress_level(state.stress_indicators, state.stress_thresholds)
    
    if stress_level != state.current_level do
      transition_to_degradation_level(state, stress_level, :stress_triggered)
    else
      state
    end
  end

  defp calculate_stress_level(indicators, thresholds) do
    # Evaluate each threshold level to find appropriate degradation
    Enum.find_value(5..1, 0, fn level ->
      level_thresholds = Map.get(thresholds, String.to_atom("level_#{level}"))
      
      if level_thresholds && exceeds_thresholds?(indicators, level_thresholds) do
        level
      else
        nil
      end
    end)
  end

  defp exceeds_thresholds?(indicators, thresholds) do
    # Check if any stress indicator exceeds its threshold (Claude's conservative approach)
    cpu_stressed = Map.get(indicators, :cpu_usage, 0) > Map.get(thresholds, :cpu, 100)
    memory_stressed = Map.get(indicators, :memory_usage, 0) > Map.get(thresholds, :memory, 100)
    response_stressed = Map.get(indicators, :avg_response_time, 0) > Map.get(thresholds, :response_time, 999999)
    
    cpu_stressed or memory_stressed or response_stressed
  end

  defp transition_to_degradation_level(state, new_level, reason) do
    if new_level != state.current_level do
      old_level = state.current_level
      
      Logger.warning("""
      🚨 Degradation level changing: #{old_level} → #{new_level} (#{reason})
      Stress: CPU #{Map.get(state.stress_indicators, :cpu_usage, "N/A")}%, 
              Memory #{Map.get(state.stress_indicators, :memory_usage, "N/A")}%, 
              Response #{Map.get(state.stress_indicators, :avg_response_time, "N/A")}ms
      """)
      
      # Apply degradation strategies (Claude's systematic approach)
      degraded_state = apply_degradation_strategies(state, new_level)
      
      # Update metrics
      new_metrics = Map.update!(degraded_state.metrics, :degradations_triggered, &(&1 + 1))
      
      %{degraded_state | 
        current_level: new_level, 
        metrics: new_metrics
      }
    else
      state
    end
  end

  defp apply_degradation_strategies(state, level) do
    # Apply Claude-inspired strategies based on degradation level
    case level do
      0 ->
        # Normal operation - no restrictions
        state
      
      1 ->
        # Light degradation - reduce background tasks
        shed_operations(state, [:background_analytics, :cache_warming], "light degradation")
      
      2 ->
        # Moderate degradation - disable detailed logging and metrics
        shed_operations(state, [:detailed_logging, :performance_profiling, :feature_flags_sync], "moderate degradation")
      
      3 ->
        # Heavy degradation - compress context windows, essential operations only
        state
        |> shed_operations([:metrics_collection], "heavy degradation") 
        |> compress_all_context_windows(0.7)  # Reduce to 70% capacity
      
      4 ->
        # Critical degradation - emergency mode preparation
        state
        |> compress_all_context_windows(0.5)  # Reduce to 50% capacity
        |> reallocate_resources_for_critical_operations()
      
      5 ->
        # Emergency mode - essential operations only
        state
        |> shed_all_non_essential_operations()
        |> compress_all_context_windows(0.3)  # Minimal context
        |> activate_emergency_resource_allocation()
    end
  end

  defp shed_operations(state, operations_to_shed, reason) do
    Logger.info("✂️ Shedding operations due to #{reason}: #{inspect(operations_to_shed)}")
    
    # Update operations shed metric
    new_metrics = Map.update!(state.metrics, :operations_shed, &(&1 + length(operations_to_shed)))
    
    %{state | metrics: new_metrics}
  end

  defp compress_all_context_windows(state, compression_ratio) do
    new_contexts = state.context_windows
                   |> Enum.map(fn {id, context} ->
                        target_size = round(context.max_operations * compression_ratio)
                        compressed = compress_context_claude_style(context, target_size)
                        {id, compressed}
                      end)
                   |> Map.new()
    
    compression_count = map_size(state.context_windows)
    new_metrics = Map.update!(state.metrics, :context_compressions, &(&1 + compression_count))
    
    Logger.info("🗜️ Compressed #{compression_count} context windows to #{compression_ratio * 100}% capacity")
    
    %{state | 
      context_windows: new_contexts,
      metrics: new_metrics
    }
  end

  defp compress_context_claude_style(context, target_size) do
    if length(context.current_operations) <= target_size do
      context
    else
      # Sort operations by priority and keep highest priority ones (Claude's approach)
      prioritized_ops = context.current_operations
                       |> Enum.sort_by(fn op -> 
                            context.priority_function.(op) 
                          end, :desc)
                       |> Enum.take(target_size)
      
      %{context | current_operations: prioritized_ops}
    end
  end

  defp reallocate_resources_for_critical_operations(state) do
    # Simulate resource reallocation (in real implementation, this would adjust thread pools, memory limits, etc.)
    reallocation = %{
      cpu_reserved_for_essential: 80,
      memory_reserved_for_essential: 70,
      thread_pools_consolidated: true
    }
    
    Logger.info("♻️ Reallocating resources for critical operations: #{inspect(reallocation)}")
    
    %{state | resource_reallocation: reallocation}
  end

  defp shed_all_non_essential_operations(state) do
    non_essential_list = MapSet.to_list(state.non_essential_operations)
    Logger.warning("🚨 Emergency mode: shedding all non-essential operations: #{inspect(non_essential_list)}")
    
    new_metrics = Map.update!(state.metrics, :operations_shed, &(&1 + length(non_essential_list)))
    
    %{state | metrics: new_metrics}
  end

  defp activate_emergency_resource_allocation(state) do
    emergency_allocation = %{
      cpu_reserved_for_essential: 95,
      memory_reserved_for_essential: 90,
      network_priority_boost: true,
      background_processes_suspended: true
    }
    
    Logger.error("🆘 Emergency resource allocation activated: #{inspect(emergency_allocation)}")
    
    %{state | resource_reallocation: emergency_allocation}
  end

  defp collect_and_assess_stress_indicators(state) do
    # In real implementation, this would collect actual system metrics
    # For now, simulate with basic checks
    current_stress = %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(), 
      avg_response_time: get_avg_response_time(),
      error_rate: get_error_rate()
    }
    
    updated_state = %{state | stress_indicators: current_stress}
    assess_degradation_level(updated_state)
  end

  defp schedule_stress_assessment(delay_ms) do
    Process.send_after(self(), :assess_stress, delay_ms)
  end

  # Placeholder functions for system metrics (would be replaced with real monitoring)
  defp get_cpu_usage(), do: :rand.uniform(100)
  defp get_memory_usage(), do: :rand.uniform(100)  
  defp get_avg_response_time(), do: :rand.uniform(1000)
  defp get_error_rate(), do: :rand.uniform(10)
end