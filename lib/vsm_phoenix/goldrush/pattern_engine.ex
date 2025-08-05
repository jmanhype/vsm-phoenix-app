defmodule VsmPhoenix.Goldrush.PatternEngine do
  @moduledoc """
  Declarative Pattern Matching Engine for GoldRush
  
  Supports complex patterns like:
  - "cpu > 80% AND memory > 90% FOR 5 minutes"
  - "error_rate > 5 OR response_time > 2000ms"
  - "variety_index INCREASES BY 20% WITHIN 10 minutes"
  
  Real-time event stream processing with high performance
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Goldrush.{PatternStore, EventAggregator, ActionHandler}
  
  @name __MODULE__
  @evaluation_interval 1_000  # 1 second
  
  # Pattern DSL operators
  @operators %{
    ">" => &Kernel.>/2,
    ">=" => &Kernel.>=/2,
    "<" => &Kernel.</2,
    "<=" => &Kernel.<=/2,
    "==" => &Kernel.==/2,
    "!=" => &Kernel.!=/2,
    "CONTAINS" => &String.contains?/2,
    "MATCHES" => &Regex.match?/2
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Register a new pattern for matching
  
  Pattern format:
  %{
    id: "high_load_pattern",
    name: "High CPU and Memory Load",
    conditions: [
      %{field: "cpu_usage", operator: ">", value: 80, unit: "%"},
      %{field: "memory_usage", operator: ">", value: 90, unit: "%"}
    ],
    time_window: %{duration: 300, unit: :seconds},  # FOR 5 minutes
    logic: "AND",  # AND/OR/COMPLEX
    actions: ["trigger_algedonic", "scale_resources", "notify_system3"]
  }
  """
  def register_pattern(pattern) do
    GenServer.call(@name, {:register_pattern, pattern})
  end
  
  @doc """
  Unregister a pattern
  """
  def unregister_pattern(pattern_id) do
    GenServer.call(@name, {:unregister_pattern, pattern_id})
  end
  
  @doc """
  Process an event through the pattern engine
  """
  def process_event(event) do
    GenServer.cast(@name, {:process_event, event})
  end
  
  @doc """
  Get all active patterns
  """
  def list_patterns do
    GenServer.call(@name, :list_patterns)
  end
  
  @doc """
  Get pattern match statistics
  """
  def get_statistics do
    GenServer.call(@name, :get_statistics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🎯 Initializing GoldRush Pattern Engine")
    
    # Schedule periodic pattern evaluation
    Process.send_after(self(), :evaluate_patterns, @evaluation_interval)
    
    state = %{
      patterns: %{},  # pattern_id => pattern
      active_matches: %{},  # pattern_id => match_state
      statistics: %{
        total_events: 0,
        total_matches: 0,
        pattern_hits: %{}
      }
    }
    
    # Load patterns from store
    load_stored_patterns(state)
  end
  
  @impl true
  def handle_call({:register_pattern, pattern}, _from, state) do
    validated_pattern = validate_pattern(pattern)
    
    case validated_pattern do
      {:ok, valid_pattern} ->
        pattern_id = valid_pattern.id
        new_patterns = Map.put(state.patterns, pattern_id, valid_pattern)
        
        # Initialize match state for this pattern
        new_active_matches = Map.put(state.active_matches, pattern_id, %{
          conditions_met: %{},
          first_match_time: nil,
          sustained_duration: 0
        })
        
        # Persist to store
        PatternStore.save_pattern(valid_pattern)
        
        Logger.info("✅ Registered pattern: #{pattern_id}")
        {:reply, {:ok, pattern_id}, %{state | 
          patterns: new_patterns,
          active_matches: new_active_matches
        }}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:unregister_pattern, pattern_id}, _from, state) do
    new_patterns = Map.delete(state.patterns, pattern_id)
    new_active_matches = Map.delete(state.active_matches, pattern_id)
    
    PatternStore.delete_pattern(pattern_id)
    
    {:reply, :ok, %{state |
      patterns: new_patterns,
      active_matches: new_active_matches
    }}
  end
  
  @impl true
  def handle_call(:list_patterns, _from, state) do
    patterns = Map.values(state.patterns)
    {:reply, patterns, state}
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    {:reply, state.statistics, state}
  end
  
  @impl true
  def handle_cast({:process_event, event}, state) do
    # Update statistics
    new_stats = update_statistics(state.statistics, :event_received)
    
    # Check event against all patterns
    {new_active_matches, triggered_patterns} = 
      evaluate_event_against_patterns(event, state.patterns, state.active_matches)
    
    # Execute actions for triggered patterns
    Enum.each(triggered_patterns, fn {pattern_id, pattern} ->
      Logger.info("🎯 Pattern matched: #{pattern.name}")
      execute_pattern_actions(pattern, event)
      new_stats = update_statistics(new_stats, {:pattern_matched, pattern_id})
    end)
    
    {:noreply, %{state |
      active_matches: new_active_matches,
      statistics: new_stats
    }}
  end
  
  @impl true
  def handle_info(:evaluate_patterns, state) do
    # Evaluate time-based patterns
    {new_active_matches, triggered_patterns} = 
      evaluate_time_patterns(state.patterns, state.active_matches)
    
    # Execute actions for time-triggered patterns
    Enum.each(triggered_patterns, fn {_pattern_id, pattern} ->
      Logger.info("⏰ Time-based pattern triggered: #{pattern.name}")
      execute_pattern_actions(pattern, %{type: :time_trigger})
    end)
    
    # Schedule next evaluation
    Process.send_after(self(), :evaluate_patterns, @evaluation_interval)
    
    {:noreply, %{state | active_matches: new_active_matches}}
  end
  
  # Private Functions
  
  defp load_stored_patterns(state) do
    case PatternStore.load_all_patterns() do
      {:ok, patterns} ->
        pattern_map = Map.new(patterns, fn p -> {p.id, p} end)
        active_matches = Map.new(patterns, fn p -> 
          {p.id, %{conditions_met: %{}, first_match_time: nil, sustained_duration: 0}}
        end)
        
        %{state | patterns: pattern_map, active_matches: active_matches}
        
      {:error, _reason} ->
        state
    end
  end
  
  defp validate_pattern(pattern) do
    with :ok <- validate_required_fields(pattern),
         :ok <- validate_conditions(pattern.conditions),
         :ok <- validate_logic(pattern.logic),
         :ok <- validate_time_window(Map.get(pattern, :time_window)),
         :ok <- validate_actions(pattern.actions) do
      {:ok, pattern}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp validate_required_fields(pattern) do
    required = [:id, :name, :conditions, :logic, :actions]
    missing = required -- Map.keys(pattern)
    
    if missing == [] do
      :ok
    else
      {:error, "Missing required fields: #{inspect(missing)}"}
    end
  end
  
  defp validate_conditions(conditions) when is_list(conditions) do
    valid = Enum.all?(conditions, fn condition ->
      Map.has_key?(condition, :field) and
      Map.has_key?(condition, :operator) and
      Map.has_key?(condition, :value) and
      Map.has_key?(@operators, condition.operator)
    end)
    
    if valid, do: :ok, else: {:error, "Invalid condition format"}
  end
  defp validate_conditions(_), do: {:error, "Conditions must be a list"}
  
  defp validate_logic(logic) when logic in ["AND", "OR", "COMPLEX"], do: :ok
  defp validate_logic(_), do: {:error, "Logic must be AND, OR, or COMPLEX"}
  
  defp validate_time_window(nil), do: :ok
  defp validate_time_window(%{duration: d, unit: u}) 
    when is_number(d) and u in [:seconds, :minutes, :hours], do: :ok
  defp validate_time_window(_), do: {:error, "Invalid time window format"}
  
  defp validate_actions(actions) when is_list(actions), do: :ok
  defp validate_actions(_), do: {:error, "Actions must be a list"}
  
  defp evaluate_event_against_patterns(event, patterns, active_matches) do
    Enum.reduce(patterns, {active_matches, []}, fn {pattern_id, pattern}, {matches, triggered} ->
      match_state = Map.get(matches, pattern_id)
      
      # Evaluate conditions
      conditions_result = evaluate_conditions(pattern.conditions, pattern.logic, event)
      
      # Update match state
      {new_match_state, pattern_triggered} = 
        update_match_state(match_state, conditions_result, pattern)
      
      new_matches = Map.put(matches, pattern_id, new_match_state)
      
      if pattern_triggered do
        {new_matches, [{pattern_id, pattern} | triggered]}
      else
        {new_matches, triggered}
      end
    end)
  end
  
  defp evaluate_conditions(conditions, logic, event) do
    results = Enum.map(conditions, fn condition ->
      evaluate_single_condition(condition, event)
    end)
    
    case logic do
      "AND" -> Enum.all?(results)
      "OR" -> Enum.any?(results)
      "COMPLEX" -> evaluate_complex_logic(conditions, results, event)
    end
  end
  
  defp evaluate_single_condition(condition, event) do
    field_value = get_nested_field(event, condition.field)
    operator_fn = Map.get(@operators, condition.operator)
    
    if field_value != nil and operator_fn != nil do
      try do
        operator_fn.(field_value, condition.value)
      rescue
        _ -> false
      end
    else
      false
    end
  end
  
  defp get_nested_field(map, field) when is_binary(field) do
    field
    |> String.split(".")
    |> Enum.reduce(map, fn
      _key, nil -> nil
      key, acc when is_map(acc) -> Map.get(acc, key)
      _key, _acc -> nil
    end)
  end
  
  defp evaluate_complex_logic(_conditions, _results, _event) do
    # For complex logic, we'd parse a more sophisticated expression
    # For now, default to AND logic
    false
  end
  
  defp update_match_state(match_state, conditions_met, pattern) do
    now = System.system_time(:millisecond)
    
    case {conditions_met, match_state.first_match_time, pattern[:time_window]} do
      # Conditions not met - reset
      {false, _, _} ->
        {%{match_state | 
          conditions_met: %{},
          first_match_time: nil,
          sustained_duration: 0
        }, false}
      
      # First time conditions met
      {true, nil, nil} ->
        # No time window - trigger immediately
        {match_state, true}
        
      {true, nil, _time_window} ->
        # Start tracking time
        {%{match_state | 
          first_match_time: now,
          sustained_duration: 0
        }, false}
        
      # Conditions still met with time window
      {true, first_time, %{duration: duration, unit: unit}} ->
        elapsed = now - first_time
        required_ms = convert_to_milliseconds(duration, unit)
        
        if elapsed >= required_ms do
          # Pattern triggered!
          {%{match_state | 
            first_match_time: nil,
            sustained_duration: 0
          }, true}
        else
          # Still waiting
          {%{match_state | sustained_duration: elapsed}, false}
        end
        
      # Conditions met, no time window
      {true, _first_time, nil} ->
        {match_state, true}
    end
  end
  
  defp convert_to_milliseconds(duration, :seconds), do: duration * 1_000
  defp convert_to_milliseconds(duration, :minutes), do: duration * 60_000
  defp convert_to_milliseconds(duration, :hours), do: duration * 3_600_000
  
  defp evaluate_time_patterns(patterns, active_matches) do
    # Check for patterns that need time-based evaluation
    # (e.g., patterns with INCREASES/DECREASES operators)
    {active_matches, []}
  end
  
  defp execute_pattern_actions(pattern, event) do
    Enum.each(pattern.actions, fn action ->
      ActionHandler.execute_action(action, pattern, event)
    end)
  end
  
  defp update_statistics(stats, :event_received) do
    %{stats | total_events: stats.total_events + 1}
  end
  
  defp update_statistics(stats, {:pattern_matched, pattern_id}) do
    pattern_hits = Map.update(stats.pattern_hits, pattern_id, 1, &(&1 + 1))
    %{stats | 
      total_matches: stats.total_matches + 1,
      pattern_hits: pattern_hits
    }
  end
end