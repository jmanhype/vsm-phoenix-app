defmodule VsmPhoenix.SelfModifying.AdaptiveBehavior do
  @moduledoc """
  Adaptive behavior system for VSM runtime adaptation.
  
  Monitors system performance, detects patterns, and automatically
  adapts behavior through learned responses and self-modification.
  """
  
  require Logger
  use GenServer
  
  alias VsmPhoenix.SelfModifying.{CodeGenerator, SafeSandbox, GeneticProgramming}
  
  defstruct [
    :id,
    :adaptation_rules,
    :behavior_patterns,
    :performance_metrics,
    :learning_history,
    :current_adaptations,
    :environment_state,
    :feedback_loop,
    :adaptation_strategies
  ]
  
  @adaptation_types [
    :performance_optimization,
    :error_handling,
    :resource_management,
    :user_interaction,
    :data_processing,
    :system_scaling
  ]
  
  ## Public API
  
  @doc """
  Starts the adaptive behavior system.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Registers a new behavior pattern for adaptation.
  
  ## Parameters
  - pattern_id: Unique identifier for the pattern
  - trigger_conditions: Conditions that activate the pattern
  - adaptation_logic: Function or module that handles adaptation
  - opts: Configuration options
  
  ## Examples
      iex> AdaptiveBehavior.register_pattern(
      ...>   :high_cpu_usage,
      ...>   %{cpu_usage: :gt, threshold: 80},
      ...>   &optimize_cpu_intensive_code/1
      ...> )
      :ok
  """
  def register_pattern(pattern_id, trigger_conditions, adaptation_logic, opts \\ []) do
    GenServer.call(__MODULE__, {:register_pattern, pattern_id, trigger_conditions, adaptation_logic, opts})
  end
  
  @doc """
  Monitors a system metric and triggers adaptations when thresholds are met.
  """
  def monitor_metric(metric_name, current_value, opts \\ []) do
    GenServer.cast(__MODULE__, {:monitor_metric, metric_name, current_value, opts})
  end
  
  @doc """
  Manually triggers adaptation for a specific scenario.
  """
  def trigger_adaptation(adaptation_type, context \\ %{}) do
    GenServer.call(__MODULE__, {:trigger_adaptation, adaptation_type, context})
  end
  
  @doc """
  Records feedback about an adaptation's effectiveness.
  """
  def record_feedback(adaptation_id, feedback, metrics \\ %{}) do
    GenServer.cast(__MODULE__, {:record_feedback, adaptation_id, feedback, metrics})
  end
  
  @doc """
  Gets current adaptation statistics and status.
  """
  def get_adaptation_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Creates a self-adapting function that improves based on usage patterns.
  """
  def create_adaptive_function(base_function, fitness_criteria, opts \\ []) do
    adaptation_id = generate_adaptation_id()
    
    adaptive_wrapper = fn args ->
      start_time = System.monotonic_time(:microsecond)
      
      try do
        result = base_function.(args)
        execution_time = System.monotonic_time(:microsecond) - start_time
        
        # Record performance metrics
        record_execution_metrics(adaptation_id, %{
          execution_time: execution_time,
          success: true,
          result_quality: evaluate_result_quality(result, fitness_criteria)
        })
        
        # Check if adaptation is needed
        maybe_adapt_function(adaptation_id, base_function, fitness_criteria, opts)
        
        result
      rescue
        e ->
          execution_time = System.monotonic_time(:microsecond) - start_time
          
          record_execution_metrics(adaptation_id, %{
            execution_time: execution_time,
            success: false,
            error: Exception.message(e)
          })
          
          # Trigger error handling adaptation
          trigger_adaptation(:error_handling, %{
            error: e,
            function_id: adaptation_id,
            args: args
          })
          
          reraise e, __STACKTRACE__
      end
    end
    
    {:ok, adaptive_wrapper, adaptation_id}
  end
  
  @doc """
  Learns from system behavior and updates adaptation strategies.
  """
  def learn_from_patterns(time_window \\ :hour) do
    GenServer.call(__MODULE__, {:learn_patterns, time_window})
  end
  
  ## GenServer Implementation
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: Keyword.get(opts, :id, generate_adaptation_id()),
      adaptation_rules: %{},
      behavior_patterns: %{},
      performance_metrics: %{},
      learning_history: [],
      current_adaptations: %{},
      environment_state: %{},
      feedback_loop: %{},
      adaptation_strategies: initialize_default_strategies()
    }
    
    # Start monitoring timer
    schedule_monitoring()
    
    Logger.info("Adaptive behavior system initialized: #{state.id}")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_pattern, pattern_id, conditions, logic, opts}, _from, state) do
    pattern = %{
      id: pattern_id,
      conditions: conditions,
      adaptation_logic: logic,
      options: opts,
      registered_at: DateTime.utc_now(),
      activation_count: 0,
      success_rate: 0.0
    }
    
    new_patterns = Map.put(state.behavior_patterns, pattern_id, pattern)
    {:reply, :ok, %{state | behavior_patterns: new_patterns}}
  end
  
  @impl true
  def handle_call({:trigger_adaptation, type, context}, _from, state) do
    case execute_adaptation(type, context, state) do
      {:ok, adaptation_result} ->
        updated_state = record_adaptation(adaptation_result, state)
        {:reply, {:ok, adaptation_result}, updated_state}
      
      {:error, reason} ->
        Logger.error("Adaptation failed: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_patterns: map_size(state.behavior_patterns),
      active_adaptations: map_size(state.current_adaptations),
      learning_samples: length(state.learning_history),
      environment_metrics: state.environment_state,
      adaptation_success_rate: calculate_success_rate(state)
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call({:learn_patterns, time_window}, _from, state) do
    case learn_behavioral_patterns(state, time_window) do
      {:ok, learned_patterns} ->
        updated_state = update_learning_state(state, learned_patterns)
        {:reply, {:ok, learned_patterns}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast({:monitor_metric, metric_name, value, opts}, state) do
    updated_metrics = Map.put(state.performance_metrics, metric_name, %{
      value: value,
      timestamp: DateTime.utc_now(),
      options: opts
    })
    
    # Check if any patterns should be triggered
    triggered_patterns = check_pattern_triggers(metric_name, value, state.behavior_patterns)
    
    # Execute triggered adaptations
    new_state = Enum.reduce(triggered_patterns, state, fn pattern, acc ->
      case execute_pattern_adaptation(pattern, %{metric: metric_name, value: value}, acc) do
        {:ok, updated_state} -> updated_state
        {:error, _reason} -> acc
      end
    end)
    
    {:noreply, %{new_state | performance_metrics: updated_metrics}}
  end
  
  @impl true
  def handle_cast({:record_feedback, adaptation_id, feedback, metrics}, state) do
    feedback_entry = %{
      adaptation_id: adaptation_id,
      feedback: feedback,
      metrics: metrics,
      timestamp: DateTime.utc_now()
    }
    
    updated_feedback = Map.update(state.feedback_loop, adaptation_id, [feedback_entry], fn existing ->
      [feedback_entry | existing] |> Enum.take(100) # Keep last 100 feedback entries
    end)
    
    {:noreply, %{state | feedback_loop: updated_feedback}}
  end
  
  @impl true
  def handle_info(:monitor_environment, state) do
    # Periodic environment monitoring
    environment_metrics = collect_environment_metrics()
    
    updated_state = %{state | 
      environment_state: Map.merge(state.environment_state, environment_metrics)
    }
    
    # Check for environment-based adaptations
    adaptation_candidates = analyze_environment_changes(environment_metrics, state)
    
    final_state = Enum.reduce(adaptation_candidates, updated_state, fn candidate, acc ->
      case execute_adaptation(candidate.type, candidate.context, acc) do
        {:ok, adaptation_result} -> record_adaptation(adaptation_result, acc)
        {:error, _} -> acc
      end
    end)
    
    schedule_monitoring()
    {:noreply, final_state}
  end
  
  ## Private Functions
  
  defp generate_adaptation_id do
    "adapt_#{System.unique_integer([:positive])}_#{System.system_time(:second)}"
  end
  
  defp initialize_default_strategies do
    %{
      performance_optimization: %{
        triggers: [:high_latency, :high_cpu, :high_memory],
        actions: [:code_optimization, :caching, :resource_scaling]
      },
      error_handling: %{
        triggers: [:exception_rate, :failure_pattern],
        actions: [:circuit_breaker, :retry_logic, :fallback_behavior]
      },
      resource_management: %{
        triggers: [:resource_exhaustion, :inefficient_allocation],
        actions: [:garbage_collection, :pool_resizing, :load_balancing]
      }
    }
  end
  
  defp schedule_monitoring do
    Process.send_after(self(), :monitor_environment, 5000) # Monitor every 5 seconds
  end
  
  defp execute_adaptation(type, context, state) do
    strategy = Map.get(state.adaptation_strategies, type)
    
    if strategy do
      adaptation_id = generate_adaptation_id()
      
      Logger.info("Executing #{type} adaptation: #{adaptation_id}")
      
      case apply_adaptation_strategy(strategy, context, adaptation_id) do
        {:ok, result} ->
          {:ok, %{
            id: adaptation_id,
            type: type,
            context: context,
            result: result,
            timestamp: DateTime.utc_now()
          }}
        
        {:error, reason} ->
          {:error, "Strategy execution failed: #{reason}"}
      end
    else
      {:error, "Unknown adaptation type: #{type}"}
    end
  end
  
  defp apply_adaptation_strategy(strategy, context, adaptation_id) do
    # Select appropriate action based on context
    action = select_best_action(strategy.actions, context)
    
    case action do
      :code_optimization ->
        optimize_code_performance(context, adaptation_id)
      
      :caching ->
        implement_caching_strategy(context, adaptation_id)
      
      :circuit_breaker ->
        implement_circuit_breaker(context, adaptation_id)
      
      :retry_logic ->
        implement_retry_logic(context, adaptation_id)
      
      :resource_scaling ->
        scale_resources(context, adaptation_id)
      
      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end
  
  defp select_best_action(actions, context) do
    # Simple selection based on context - could be enhanced with ML
    cond do
      Map.has_key?(context, :cpu_usage) and context.cpu_usage > 80 ->
        :code_optimization
      
      Map.has_key?(context, :error_rate) and context.error_rate > 0.1 ->
        :circuit_breaker
      
      Map.has_key?(context, :latency) and context.latency > 1000 ->
        :caching
      
      true ->
        Enum.random(actions)
    end
  end
  
  defp optimize_code_performance(context, adaptation_id) do
    # Use genetic programming to optimize performance-critical code
    if Map.has_key?(context, :target_function) do
      fitness_function = fn code ->
        case SafeSandbox.execute(code, [], timeout: 1000) do
          {:ok, result} ->
            # Fitness based on execution time and correctness
            execution_time = Map.get(context, :execution_time, 1000)
            1.0 / (execution_time / 1000.0 + 1.0) # Prefer faster execution
          
          {:error, _} -> 0
        end
      end
      
      case GeneticProgramming.evolve(context.target_function, fitness_function, %{generations: 20}) do
        {:ok, evolved_result} ->
          Logger.info("Code optimization completed for #{adaptation_id}")
          {:ok, %{optimized_code: evolved_result.best_code, improvement: evolved_result.best_fitness}}
        
        {:error, reason} ->
          {:error, "Code optimization failed: #{reason}"}
      end
    else
      {:error, "No target function provided for optimization"}
    end
  end
  
  defp implement_caching_strategy(context, adaptation_id) do
    # Generate caching logic based on context
    cache_template = """
    defmodule DynamicCache#{adaptation_id} do
      use GenServer
      
      def start_link do
        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
      end
      
      def get(key) do
        GenServer.call(__MODULE__, {:get, key})
      end
      
      def put(key, value) do
        GenServer.cast(__MODULE__, {:put, key, value})
      end
      
      def init(state) do
        {:ok, state}
      end
      
      def handle_call({:get, key}, _from, state) do
        {:reply, Map.get(state, key), state}
      end
      
      def handle_cast({:put, key, value}, state) do
        {:noreply, Map.put(state, key, value)}
      end
    end
    """
    
    case CodeGenerator.create_module(:"DynamicCache#{adaptation_id}", cache_template) do
      {:ok, module_name} ->
        Logger.info("Dynamic cache created: #{module_name}")
        {:ok, %{cache_module: module_name, strategy: :lru}}
      
      {:error, reason} ->
        {:error, "Cache creation failed: #{reason}"}
    end
  end
  
  defp implement_circuit_breaker(context, adaptation_id) do
    # Create a dynamic circuit breaker
    circuit_breaker_code = """
    defmodule CircuitBreaker#{adaptation_id} do
      use GenServer
      
      defstruct [
        :failure_threshold,
        :recovery_timeout,
        :failure_count,
        :last_failure_time,
        :state
      ]
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def call(fun) do
        GenServer.call(__MODULE__, {:call, fun})
      end
      
      def init(opts) do
        state = %__MODULE__{
          failure_threshold: Keyword.get(opts, :failure_threshold, 5),
          recovery_timeout: Keyword.get(opts, :recovery_timeout, 30000),
          failure_count: 0,
          last_failure_time: nil,
          state: :closed
        }
        {:ok, state}
      end
      
      def handle_call({:call, fun}, _from, state) do
        case state.state do
          :open ->
            if should_attempt_reset?(state) do
              execute_and_update({:half_open, fun}, state)
            else
              {:reply, {:error, :circuit_open}, state}
            end
          
          _ ->
            execute_and_update({state.state, fun}, state)
        end
      end
      
      defp should_attempt_reset?(%{last_failure_time: nil}), do: false
      defp should_attempt_reset?(state) do
        DateTime.diff(DateTime.utc_now(), state.last_failure_time, :millisecond) > state.recovery_timeout
      end
      
      defp execute_and_update({circuit_state, fun}, state) do
        try do
          result = fun.()
          new_state = %{state | failure_count: 0, state: :closed}
          {:reply, {:ok, result}, new_state}
        rescue
          _ ->
            failure_count = state.failure_count + 1
            new_circuit_state = if failure_count >= state.failure_threshold, do: :open, else: circuit_state
            
            new_state = %{state | 
              failure_count: failure_count,
              last_failure_time: DateTime.utc_now(),
              state: new_circuit_state
            }
            
            {:reply, {:error, :function_failed}, new_state}
        end
      end
    end
    """
    
    case CodeGenerator.create_module(:"CircuitBreaker#{adaptation_id}", circuit_breaker_code) do
      {:ok, module_name} ->
        {:ok, %{circuit_breaker: module_name, threshold: Map.get(context, :failure_threshold, 5)}}
        
      {:error, reason} ->
        {:error, "Circuit breaker creation failed: #{reason}"}
    end
  end
  
  defp implement_retry_logic(context, _adaptation_id) do
    max_retries = Map.get(context, :max_retries, 3)
    base_delay = Map.get(context, :base_delay, 1000)
    
    retry_function = fn fun ->
      Enum.reduce_while(1..max_retries, nil, fn attempt, _acc ->
        try do
          result = fun.()
          {:halt, {:ok, result}}
        rescue
          e ->
            if attempt == max_retries do
              {:halt, {:error, Exception.message(e)}}
            else
              delay = base_delay * :math.pow(2, attempt - 1) # Exponential backoff
              Process.sleep(round(delay))
              {:cont, nil}
            end
        end
      end)
    end
    
    {:ok, %{retry_function: retry_function, max_retries: max_retries}}
  end
  
  defp scale_resources(context, _adaptation_id) do
    current_load = Map.get(context, :current_load, 0.5)
    
    scaling_decision = cond do
      current_load > 0.8 -> :scale_up
      current_load < 0.2 -> :scale_down
      true -> :maintain
    end
    
    # This would integrate with actual resource management systems
    Logger.info("Resource scaling decision: #{scaling_decision} (load: #{current_load})")
    
    {:ok, %{action: scaling_decision, current_load: current_load}}
  end
  
  defp record_adaptation(adaptation_result, state) do
    updated_adaptations = Map.put(state.current_adaptations, adaptation_result.id, adaptation_result)
    
    %{state | current_adaptations: updated_adaptations}
  end
  
  defp check_pattern_triggers(metric_name, value, patterns) do
    Enum.filter(patterns, fn {_id, pattern} ->
      check_trigger_conditions(pattern.conditions, metric_name, value)
    end)
    |> Enum.map(fn {_id, pattern} -> pattern end)
  end
  
  defp check_trigger_conditions(conditions, metric_name, value) do
    Enum.any?(Map.keys(conditions), fn condition_key ->
      case condition_key do
        ^metric_name ->
          condition_value = Map.get(conditions, metric_name)
          evaluate_condition(condition_value, value)
        
        _ -> false
      end
    end)
  end
  
  defp evaluate_condition(%{operator: :gt, threshold: threshold}, value) when value > threshold, do: true
  defp evaluate_condition(%{operator: :lt, threshold: threshold}, value) when value < threshold, do: true
  defp evaluate_condition(%{operator: :eq, threshold: threshold}, value) when value == threshold, do: true
  defp evaluate_condition(threshold, value) when is_number(threshold), do: value > threshold
  defp evaluate_condition(_, _), do: false
  
  defp execute_pattern_adaptation(pattern, trigger_context, state) do
    try do
      case pattern.adaptation_logic do
        fun when is_function(fun) ->
          result = fun.(trigger_context)
          updated_pattern = %{pattern | activation_count: pattern.activation_count + 1}
          updated_patterns = Map.put(state.behavior_patterns, pattern.id, updated_pattern)
          
          {:ok, %{state | behavior_patterns: updated_patterns}}
        
        _ ->
          {:error, "Invalid adaptation logic"}
      end
    rescue
      e -> {:error, "Pattern execution failed: #{Exception.message(e)}"}
    end
  end
  
  defp collect_environment_metrics do
    %{
      memory_usage: get_memory_usage(),
      cpu_usage: get_cpu_usage(),
      process_count: get_process_count(),
      network_latency: get_network_latency(),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp get_memory_usage do
    case :erlang.memory() do
      memory_info when is_list(memory_info) ->
        total = Keyword.get(memory_info, :total, 0)
        total / (1024 * 1024) # Convert to MB
      _ -> 0
    end
  end
  
  defp get_cpu_usage do
    # Simplified CPU usage estimation
    case :cpu_sup.util() do
      {:all, usage} when is_number(usage) -> usage
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp get_process_count do
    length(Process.list())
  end
  
  defp get_network_latency do
    # Simplified network latency check
    start_time = System.monotonic_time(:microsecond)
    
    case :inet.gethostname() do
      {:ok, _hostname} ->
        (System.monotonic_time(:microsecond) - start_time) / 1000.0
      _ -> 0
    end
  rescue
    _ -> 0
  end
  
  defp analyze_environment_changes(current_metrics, state) do
    previous_metrics = state.environment_state
    
    changes = []
    
    # Check for significant changes
    changes = if Map.has_key?(previous_metrics, :memory_usage) do
      memory_change = current_metrics.memory_usage - previous_metrics.memory_usage
      if abs(memory_change) > 50 do # 50MB change
        [%{type: :resource_management, context: %{memory_change: memory_change}} | changes]
      else
        changes
      end
    else
      changes
    end
    
    changes = if Map.has_key?(previous_metrics, :cpu_usage) do
      cpu_change = current_metrics.cpu_usage - previous_metrics.cpu_usage
      if abs(cpu_change) > 20 do # 20% change
        [%{type: :performance_optimization, context: %{cpu_change: cpu_change}} | changes]
      else
        changes
      end
    else
      changes
    end
    
    changes
  end
  
  defp calculate_success_rate(state) do
    if map_size(state.current_adaptations) == 0 do
      0.0
    else
      successful = state.current_adaptations
      |> Map.values()
      |> Enum.count(fn adaptation ->
        feedback = Map.get(state.feedback_loop, adaptation.id, [])
        Enum.any?(feedback, fn f -> f.feedback == :success end)
      end)
      
      successful / map_size(state.current_adaptations)
    end
  end
  
  defp learn_behavioral_patterns(state, time_window) do
    # Analyze historical data to learn new patterns
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window_to_seconds(time_window), :second)
    
    recent_adaptations = state.current_adaptations
    |> Map.values()
    |> Enum.filter(fn adaptation ->
      DateTime.compare(adaptation.timestamp, cutoff_time) == :gt
    end)
    
    # Group by type and analyze success patterns
    patterns_by_type = Enum.group_by(recent_adaptations, & &1.type)
    
    learned_patterns = Enum.map(patterns_by_type, fn {type, adaptations} ->
      success_rate = calculate_type_success_rate(adaptations, state.feedback_loop)
      common_contexts = extract_common_contexts(adaptations)
      
      %{
        type: type,
        success_rate: success_rate,
        common_contexts: common_contexts,
        sample_size: length(adaptations),
        confidence: calculate_confidence(length(adaptations))
      }
    end)
    
    {:ok, learned_patterns}
  end
  
  defp time_window_to_seconds(:hour), do: 3600
  defp time_window_to_seconds(:day), do: 86400
  defp time_window_to_seconds(:week), do: 604800
  defp time_window_to_seconds(seconds) when is_integer(seconds), do: seconds
  
  defp calculate_type_success_rate(adaptations, feedback_loop) do
    if length(adaptations) == 0 do
      0.0
    else
      successful = Enum.count(adaptations, fn adaptation ->
        feedback = Map.get(feedback_loop, adaptation.id, [])
        Enum.any?(feedback, fn f -> f.feedback == :success end)
      end)
      
      successful / length(adaptations)
    end
  end
  
  defp extract_common_contexts(adaptations) do
    # Find common patterns in adaptation contexts
    all_contexts = Enum.map(adaptations, & &1.context)
    
    # Simple analysis: find most common keys and value ranges
    common_keys = all_contexts
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_key, count} -> count > length(adaptations) / 2 end)
    |> Enum.map(fn {key, _count} -> key end)
    
    %{common_keys: common_keys}
  end
  
  defp calculate_confidence(sample_size) do
    # Simple confidence calculation based on sample size
    cond do
      sample_size >= 100 -> 0.95
      sample_size >= 50 -> 0.90
      sample_size >= 20 -> 0.80
      sample_size >= 10 -> 0.70
      true -> 0.50
    end
  end
  
  defp update_learning_state(state, learned_patterns) do
    learning_entry = %{
      patterns: learned_patterns,
      timestamp: DateTime.utc_now(),
      total_adaptations: map_size(state.current_adaptations)
    }
    
    updated_history = [learning_entry | state.learning_history]
    |> Enum.take(50) # Keep last 50 learning cycles
    
    %{state | learning_history: updated_history}
  end
  
  defp record_execution_metrics(adaptation_id, metrics) do
    # This would typically store metrics in a time-series database
    Logger.debug("Recording metrics for #{adaptation_id}: #{inspect(metrics)}")
  end
  
  defp evaluate_result_quality(result, criteria) when is_function(criteria) do
    try do
      criteria.(result)
    rescue
      _ -> 0.5 # Default quality if evaluation fails
    end
  end
  defp evaluate_result_quality(_result, _criteria), do: 0.5
  
  defp maybe_adapt_function(adaptation_id, _base_function, _criteria, _opts) do
    # This would check if the function needs adaptation based on performance history
    # For now, just log the check
    Logger.debug("Checking adaptation needs for function #{adaptation_id}")
  end
end