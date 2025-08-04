defmodule VsmPhoenix.Algedonic.PleasureProcessor do
  @moduledoc """
  Pleasure Processor for positive reinforcement and system learning.
  
  Processes pleasure signals to:
  - Reinforce successful adaptations
  - Identify optimal patterns
  - Strengthen effective policies
  - Promote beneficial behaviors
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Queen
  
  @type pleasure_level :: :satisfaction | :pleasure | :delight | :euphoria
  @type pleasure_source :: :performance | :efficiency | :innovation | :adaptation | :learning
  
  @type pleasure_signal :: %{
    level: pleasure_level(),
    source: pleasure_source(),
    trigger: String.t(),
    timestamp: DateTime.t(),
    metrics: map(),
    learning_value: float()
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Process a pleasure signal for positive reinforcement
  """
  def process(signal) do
    GenServer.cast(__MODULE__, {:process_pleasure, signal})
  end
  
  @doc """
  Analyze successful patterns for replication
  """
  def analyze_success_patterns(timeframe \\ :last_day) do
    GenServer.call(__MODULE__, {:analyze_success, timeframe})
  end
  
  @doc """
  Get reinforcement recommendations
  """
  def get_reinforcements do
    GenServer.call(__MODULE__, :get_reinforcements)
  end
  
  @doc """
  Register a success pattern for tracking
  """
  def register_success(pattern, metrics) do
    GenServer.call(__MODULE__, {:register_success, pattern, metrics})
  end
  
  # Server Callbacks
  
  def init(_opts) do
    state = %{
      pleasure_history: [],
      success_patterns: %{},
      reinforcement_queue: [],
      learning_accumulator: %{},
      reward_mechanisms: configure_rewards(),
      metrics: %{
        total_pleasures: 0,
        patterns_learned: 0,
        reinforcements_applied: 0,
        success_rate: 0.0
      }
    }
    
    # Schedule periodic analysis
    Process.send_after(self(), :analyze_and_reinforce, 300_000)  # 5 minutes
    
    {:ok, state}
  end
  
  def handle_cast({:process_pleasure, signal}, state) do
    Logger.info("Processing pleasure signal: #{inspect(signal)}")
    
    # Calculate learning value
    learning_value = calculate_learning_value(signal, state)
    signal = Map.put(signal, :learning_value, learning_value)
    
    # Determine pleasure level
    pleasure_level = calculate_pleasure_level(signal, state)
    
    # Record pleasure
    state = record_pleasure(state, signal, pleasure_level)
    
    # Process based on pleasure level
    state = case pleasure_level do
      :euphoria -> handle_euphoria(signal, state)
      :delight -> handle_delight(signal, state)
      :pleasure -> handle_pleasure(signal, state)
      :satisfaction -> handle_satisfaction(signal, state)
    end
    
    # Extract and store learning
    state = extract_learning(state, signal)
    
    # Update success patterns
    state = update_success_patterns(state, signal)
    
    {:noreply, state}
  end
  
  def handle_call({:analyze_success, timeframe}, _from, state) do
    patterns = analyze_success_patterns_internal(state.pleasure_history, timeframe)
    
    # Identify replicable successes
    replicable = identify_replicable_patterns(patterns, state)
    
    {:reply, %{patterns: patterns, replicable: replicable}, state}
  end
  
  def handle_call(:get_reinforcements, _from, state) do
    # Get queued reinforcements ready for application
    {:reply, state.reinforcement_queue, state}
  end
  
  def handle_call({:register_success, pattern, metrics}, _from, state) do
    success_record = %{
      pattern: pattern,
      metrics: metrics,
      timestamp: DateTime.utc_now(),
      reinforcement_count: 0
    }
    
    patterns = Map.put(state.success_patterns, pattern, success_record)
    {:reply, :ok, %{state | success_patterns: patterns}}
  end
  
  def handle_info(:analyze_and_reinforce, state) do
    # Periodic analysis and reinforcement
    state = analyze_and_apply_reinforcements(state)
    
    # Schedule next analysis
    Process.send_after(self(), :analyze_and_reinforce, 300_000)
    
    {:noreply, state}
  end
  
  def handle_info({:reinforcement_applied, reinforcement_id, result}, state) do
    # Handle reinforcement result
    state = case result do
      :success ->
        %{state | 
          metrics: Map.update!(state.metrics, :reinforcements_applied, &(&1 + 1))
        }
      :failure ->
        Logger.warning("Reinforcement #{reinforcement_id} failed")
        state
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp calculate_learning_value(signal, state) do
    # Calculate how valuable this signal is for learning
    base_value = intensity_to_value(Map.get(signal, :intensity, :medium))
    
    # Adjust based on novelty
    novelty_factor = calculate_novelty(signal, state)
    
    # Adjust based on impact
    impact_factor = calculate_impact(signal)
    
    base_value * novelty_factor * impact_factor
  end
  
  defp calculate_novelty(signal, state) do
    # How novel is this success pattern?
    similar_count = Enum.count(state.pleasure_history, fn p ->
      similar_pleasure?(p, signal)
    end)
    
    case similar_count do
      0 -> 2.0  # Completely novel
      1 -> 1.5  # Rare
      2 -> 1.2  # Uncommon
      _ -> 1.0  # Common
    end
  end
  
  defp similar_pleasure?(p1, p2) do
    p1.source == p2.source and
    abs(Map.get(p1, :learning_value, 0) - Map.get(p2, :learning_value, 0)) < 0.1
  end
  
  defp calculate_impact(signal) do
    metrics = Map.get(signal, :data, %{})
    
    # Calculate impact based on improvement metrics
    performance_gain = Map.get(metrics, :performance_improvement, 0)
    efficiency_gain = Map.get(metrics, :efficiency_improvement, 0)
    
    1.0 + (performance_gain + efficiency_gain) / 2
  end
  
  defp calculate_pleasure_level(signal, _state) do
    intensity = Map.get(signal, :intensity, :medium)
    learning_value = Map.get(signal, :learning_value, 0.5)
    
    cond do
      intensity == :critical and learning_value > 0.8 -> :euphoria
      intensity == :high and learning_value > 0.6 -> :delight
      intensity == :medium and learning_value > 0.4 -> :pleasure
      true -> :satisfaction
    end
  end
  
  defp handle_euphoria(signal, state) do
    Logger.info("🎉 EUPHORIA - Exceptional success detected!")
    
    # Immediately notify S5 for policy reinforcement
    Queen.exceptional_success(%{
      type: :pleasure_euphoria,
      signal: signal,
      learning_value: signal.learning_value,
      timestamp: DateTime.utc_now()
    })
    
    # Queue strong reinforcement
    reinforcement = create_strong_reinforcement(signal)
    
    %{state | 
      reinforcement_queue: [reinforcement | state.reinforcement_queue]
    }
  end
  
  defp handle_delight(signal, state) do
    Logger.info("Delight signal - significant success")
    
    # Notify S4 for pattern analysis
    Intelligence.analyze_success(signal)
    
    # Queue moderate reinforcement
    reinforcement = create_moderate_reinforcement(signal)
    
    %{state | 
      reinforcement_queue: [reinforcement | state.reinforcement_queue]
    }
  end
  
  defp handle_pleasure(signal, state) do
    Logger.debug("Pleasure signal - positive outcome")
    
    # Queue light reinforcement
    reinforcement = create_light_reinforcement(signal)
    
    %{state | 
      reinforcement_queue: [reinforcement | state.reinforcement_queue]
    }
  end
  
  defp handle_satisfaction(signal, state) do
    Logger.debug("Satisfaction noted")
    
    # Just track for pattern analysis
    state
  end
  
  defp create_strong_reinforcement(signal) do
    %{
      type: :strong,
      pattern: extract_pattern(signal),
      weight: 2.0,
      apply_to: determine_reinforcement_targets(signal),
      created_at: DateTime.utc_now()
    }
  end
  
  defp create_moderate_reinforcement(signal) do
    %{
      type: :moderate,
      pattern: extract_pattern(signal),
      weight: 1.5,
      apply_to: determine_reinforcement_targets(signal),
      created_at: DateTime.utc_now()
    }
  end
  
  defp create_light_reinforcement(signal) do
    %{
      type: :light,
      pattern: extract_pattern(signal),
      weight: 1.1,
      apply_to: determine_reinforcement_targets(signal),
      created_at: DateTime.utc_now()
    }
  end
  
  defp extract_pattern(signal) do
    # Extract the successful pattern from the signal
    %{
      source: signal.source,
      trigger: Map.get(signal, :trigger, "unknown"),
      conditions: Map.get(signal, :conditions, %{}),
      actions: Map.get(signal, :actions, [])
    }
  end
  
  defp determine_reinforcement_targets(signal) do
    # Determine what should be reinforced
    case signal.source do
      "S1" -> [:operations, :sensors]
      "S2" -> [:coordination, :communication]
      "S3" -> [:control, :optimization]
      "S4" -> [:intelligence, :analysis]
      "S5" -> [:policy, :strategy]
      _ -> [:general]
    end
  end
  
  defp extract_learning(state, signal) do
    learning_entry = %{
      signal: signal,
      pattern: extract_pattern(signal),
      value: signal.learning_value,
      timestamp: DateTime.utc_now()
    }
    
    # Accumulate learning by pattern type
    pattern_key = {signal.source, signal.trigger}
    accumulator = Map.update(
      state.learning_accumulator,
      pattern_key,
      [learning_entry],
      &[learning_entry | &1]
    )
    
    %{state | 
      learning_accumulator: accumulator,
      metrics: Map.update!(state.metrics, :patterns_learned, &(&1 + 1))
    }
  end
  
  defp update_success_patterns(state, signal) do
    pattern_key = extract_pattern(signal)
    
    patterns = Map.update(
      state.success_patterns,
      pattern_key,
      %{count: 1, last_seen: DateTime.utc_now(), value: signal.learning_value},
      fn existing ->
        %{existing | 
          count: existing.count + 1,
          last_seen: DateTime.utc_now(),
          value: (existing.value + signal.learning_value) / 2
        }
      end
    )
    
    %{state | success_patterns: patterns}
  end
  
  defp record_pleasure(state, signal, pleasure_level) do
    pleasure_record = Map.merge(signal, %{
      pleasure_level: pleasure_level,
      recorded_at: DateTime.utc_now()
    })
    
    %{state | 
      pleasure_history: [pleasure_record | Enum.take(state.pleasure_history, 999)],
      metrics: Map.update!(state.metrics, :total_pleasures, &(&1 + 1))
    }
  end
  
  defp analyze_and_apply_reinforcements(state) do
    # Analyze accumulated learning
    valuable_patterns = identify_valuable_patterns(state.learning_accumulator)
    
    # Create reinforcement actions
    reinforcements = Enum.map(valuable_patterns, &create_reinforcement_action/1)
    
    # Apply reinforcements
    Enum.each(reinforcements, &apply_reinforcement(&1, state))
    
    # Clear old reinforcements from queue
    queue = Enum.filter(state.reinforcement_queue, fn r ->
      DateTime.diff(DateTime.utc_now(), r.created_at) < 3600
    end)
    
    %{state | reinforcement_queue: queue}
  end
  
  defp identify_valuable_patterns(accumulator) do
    accumulator
    |> Enum.filter(fn {_, entries} -> length(entries) > 2 end)
    |> Enum.map(fn {pattern, entries} ->
      avg_value = Enum.sum(Enum.map(entries, & &1.value)) / length(entries)
      {pattern, avg_value}
    end)
    |> Enum.filter(fn {_, value} -> value > 0.6 end)
    |> Enum.sort_by(fn {_, value} -> value end, :desc)
    |> Enum.take(10)
  end
  
  defp create_reinforcement_action({pattern, value}) do
    %{
      pattern: pattern,
      strength: value,
      action: determine_action(pattern, value)
    }
  end
  
  defp determine_action({source, _trigger}, value) do
    base_action = case source do
      "S1" -> :optimize_operations
      "S2" -> :enhance_coordination
      "S3" -> :strengthen_control
      "S4" -> :improve_intelligence
      "S5" -> :reinforce_policy
      _ -> :general_improvement
    end
    
    {base_action, value}
  end
  
  defp apply_reinforcement(reinforcement, _state) do
    Task.start(fn ->
      # Apply the reinforcement
      result = execute_reinforcement(reinforcement)
      
      # Report result
      send(self(), {:reinforcement_applied, generate_reinforcement_id(), result})
    end)
  end
  
  defp execute_reinforcement(reinforcement) do
    # Execute the reinforcement action
    :telemetry.execute(
      [:vsm, :algedonic, :reinforcement],
      %{strength: reinforcement.strength},
      %{action: reinforcement.action}
    )
    
    :success
  end
  
  defp analyze_success_patterns_internal(history, timeframe) do
    filtered = filter_by_timeframe(history, timeframe)
    
    %{
      frequent_successes: find_frequent_successes(filtered),
      high_value_patterns: find_high_value_patterns(filtered),
      emerging_patterns: find_emerging_patterns(filtered),
      sustained_patterns: find_sustained_patterns(filtered)
    }
  end
  
  defp filter_by_timeframe(history, :last_day) do
    cutoff = DateTime.add(DateTime.utc_now(), -86400, :second)
    Enum.filter(history, fn p -> DateTime.compare(p.timestamp, cutoff) == :gt end)
  end
  
  defp find_frequent_successes(history) do
    history
    |> Enum.group_by(& &1.source)
    |> Enum.filter(fn {_, list} -> length(list) > 5 end)
    |> Map.new(fn {source, list} -> {source, length(list)} end)
  end
  
  defp find_high_value_patterns(history) do
    history
    |> Enum.filter(fn p -> p.learning_value > 0.7 end)
    |> Enum.map(fn p -> {extract_pattern(p), p.learning_value} end)
    |> Enum.uniq_by(fn {pattern, _} -> pattern end)
  end
  
  defp find_emerging_patterns(history) do
    # Find patterns that are increasing in frequency
    recent = Enum.take(history, 100)
    older = Enum.slice(history, 100, 100)
    
    recent_patterns = MapSet.new(Enum.map(recent, &extract_pattern/1))
    older_patterns = MapSet.new(Enum.map(older, &extract_pattern/1))
    
    MapSet.difference(recent_patterns, older_patterns)
    |> MapSet.to_list()
  end
  
  defp find_sustained_patterns(history) do
    # Find patterns that appear consistently over time
    history
    |> Enum.chunk_every(50)
    |> Enum.map(fn chunk ->
      MapSet.new(Enum.map(chunk, &extract_pattern/1))
    end)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
  end
  
  defp identify_replicable_patterns(patterns, _state) do
    # Identify which patterns can be replicated
    high_value = Map.get(patterns, :high_value_patterns, [])
    sustained = Map.get(patterns, :sustained_patterns, [])
    
    # Patterns that are both high-value and sustained are most replicable
    Enum.filter(high_value, fn {pattern, _} ->
      pattern in sustained
    end)
  end
  
  defp generate_reinforcement_id do
    "reinforce_#{:erlang.unique_integer([:positive])}"
  end
  
  defp configure_rewards do
    %{
      performance_improvement: 1.5,
      efficiency_gain: 1.3,
      innovation: 2.0,
      successful_adaptation: 1.8,
      learning_achievement: 1.6
    }
  end
  
  defp intensity_to_value(:low), do: 0.25
  defp intensity_to_value(:medium), do: 0.5
  defp intensity_to_value(:high), do: 0.75
  defp intensity_to_value(:critical), do: 1.0
end