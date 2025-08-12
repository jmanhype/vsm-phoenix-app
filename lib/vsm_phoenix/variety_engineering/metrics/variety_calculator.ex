defmodule VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator do
  @moduledoc """
  Calculates variety metrics for each VSM system level.
  
  Variety is measured as the rate of distinct message types and patterns
  flowing through each system boundary.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @metric_window 60_000  # 1 minute sliding window
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def record_message(system_level, direction, message_type) do
    GenServer.cast(@name, {:record_message, system_level, direction, message_type})
  end
  
  def get_variety(system_level) do
    GenServer.call(@name, {:get_variety, system_level})
  end
  
  def get_all_metrics do
    GenServer.call(@name, :get_all_metrics)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("📊 Starting Variety Calculator...")
    
    state = %{
      # Track messages for each system level and direction
      messages: %{
        s1: %{inbound: [], outbound: []},
        s2: %{inbound: [], outbound: []},
        s3: %{inbound: [], outbound: []},
        s4: %{inbound: [], outbound: []},
        s5: %{inbound: [], outbound: []}
      },
      # Calculated variety metrics
      variety_metrics: %{
        s1: %{input_variety: 0, output_variety: 0, ratio: 0, entropy: 0.0},
        s2: %{input_variety: 0, output_variety: 0, ratio: 0, entropy: 0.0},
        s3: %{input_variety: 0, output_variety: 0, ratio: 0, entropy: 0.0},
        s4: %{input_variety: 0, output_variety: 0, ratio: 0, entropy: 0.0},
        s5: %{input_variety: 0, output_variety: 0, ratio: 0, entropy: 0.0}
      },
      # Track message patterns and frequencies
      message_patterns: %{
        s1: %{inbound: %{}, outbound: %{}},
        s2: %{inbound: %{}, outbound: %{}},
        s3: %{inbound: %{}, outbound: %{}},
        s4: %{inbound: %{}, outbound: %{}},
        s5: %{inbound: %{}, outbound: %{}}
      },
      # Track rate of variety change
      variety_velocity: %{
        s1: 0.0, s2: 0.0, s3: 0.0, s4: 0.0, s5: 0.0
      },
      # Historical entropy for trend analysis
      entropy_history: %{
        s1: [], s2: [], s3: [], s4: [], s5: []
      }
    }
    
    # Schedule periodic metric calculation
    schedule_metric_calculation()
    
    # Subscribe to all VSM message channels
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system1")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system2")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system3")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system4")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system5")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:coordination")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:policy")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:algedonic")
    
    # Subscribe to operational message patterns
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:commands")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:events")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm.agent.operations")
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_message, system_level, direction, message_type}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    # Ensure the system level exists in state
    current_messages = get_in(state, [:messages, system_level, direction]) || []
    
    # Update messages list
    new_messages = [{timestamp, message_type} | current_messages]
    |> clean_old_messages(timestamp)
    
    updated_messages = put_in(state, [:messages, system_level, direction], new_messages)
    
    # Update message pattern frequencies safely
    current_patterns = get_in(state, [:message_patterns, system_level, direction]) || %{}
    updated_patterns = Map.update(current_patterns, message_type, 1, &(&1 + 1))
    
    new_state = updated_messages
    |> put_in([:message_patterns, system_level, direction], updated_patterns)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get_variety, system_level}, _from, state) do
    variety = state.variety_metrics[system_level]
    {:reply, variety, state}
  end
  
  @impl true
  def handle_call(:get_all_metrics, _from, state) do
    metrics = %{
      variety_metrics: state.variety_metrics,
      timestamp: DateTime.utc_now(),
      summary: calculate_summary(state.variety_metrics)
    }
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_info(:calculate_metrics, state) do
    current_time = System.monotonic_time(:millisecond)
    
    # Calculate comprehensive metrics
    new_metrics = Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      # Basic variety counts
      input_messages = state.messages[level].inbound
      output_messages = state.messages[level].outbound
      
      input_variety = calculate_variety(input_messages)
      output_variety = calculate_variety(output_messages)
      
      # Calculate Shannon entropy for true diversity measurement
      input_entropy = calculate_entropy(input_messages)
      output_entropy = calculate_entropy(output_messages)
      
      # Variety ratio with protection against division by zero
      ratio = if input_variety > 0, do: output_variety / input_variety, else: 0
      
      # Entropy ratio for information-theoretic balance
      entropy_ratio = if input_entropy > 0, do: output_entropy / input_entropy, else: 0
      
      # Message volume and rate
      input_volume = length(input_messages)
      output_volume = length(output_messages)
      
      # Calculate variety velocity (rate of change)
      previous_entropy = List.first(state.entropy_history[level] || [0.0]) || 0.0
      velocity = (input_entropy - previous_entropy) / 5.0  # Change per second
      
      Map.put(acc, level, %{
        input_variety: input_variety,
        output_variety: output_variety,
        ratio: ratio,
        entropy: %{
          input: input_entropy,
          output: output_entropy,
          ratio: entropy_ratio
        },
        volume: %{
          input: input_volume,
          output: output_volume
        },
        velocity: velocity,
        timestamp: current_time
      })
    end)
    
    # Update variety velocity and entropy history
    new_velocity = Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      Map.put(acc, level, new_metrics[level].velocity)
    end)
    
    new_entropy_history = Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      history = [new_metrics[level].entropy.input | state.entropy_history[level] || []]
      |> Enum.take(20)  # Keep last 20 measurements
      Map.put(acc, level, history)
    end)
    
    # Decay old pattern frequencies to emphasize recent patterns
    new_patterns = decay_pattern_frequencies(state.message_patterns)
    
    # Broadcast variety metrics
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:variety_metrics",
      {:variety_update, new_metrics}
    )
    
    schedule_metric_calculation()
    
    new_state = %{state | 
      variety_metrics: new_metrics,
      variety_velocity: new_velocity,
      entropy_history: new_entropy_history,
      message_patterns: new_patterns
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({topic, message}, state) when is_binary(topic) do
    # Intercept VSM messages to calculate variety
    system_level = extract_system_level(topic)
    direction = infer_direction(topic, message)
    message_type = extract_message_type(message)
    
    if system_level && direction && message_type do
      handle_cast({:record_message, system_level, direction, message_type}, state)
    else
      {:noreply, state}
    end
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  # Private functions
  
  defp clean_old_messages(messages, current_time) do
    cutoff = current_time - @metric_window
    Enum.filter(messages, fn {timestamp, _} -> timestamp > cutoff end)
  end
  
  defp calculate_variety(messages) do
    messages
    |> Enum.map(fn {_, type} -> type end)
    |> Enum.uniq()
    |> length()
    |> Kernel.*(1.0)  # Convert to float
  end
  
  defp calculate_summary(metrics) do
    # Ensure metrics is a map and filter out non-map values
    valid_metrics = metrics
                    |> Enum.filter(fn {_k, v} -> is_map(v) end)
                    |> Enum.into(%{})
    
    avg_ratio = valid_metrics
                |> Map.values()
                |> Enum.map(fn metric ->
                  Map.get(metric, :ratio, 0)
                end)
                |> Enum.sum()
                |> Kernel./(5)
    
    avg_entropy_ratio = valid_metrics
                        |> Map.values()
                        |> Enum.map(fn metric ->
                          case metric do
                            %{entropy: %{ratio: ratio}} when is_number(ratio) -> ratio
                            %{entropy: entropy} when is_map(entropy) -> 
                              Map.get(entropy, :ratio, 0)
                            _ -> 0
                          end
                        end)
                        |> Enum.sum()
                        |> Kernel./(5)
    
    total_input = valid_metrics
                  |> Map.values()
                  |> Enum.map(fn metric ->
                    Map.get(metric, :input_variety, 0)
                  end)
                  |> Enum.sum()
    
    total_output = valid_metrics
                   |> Map.values()
                   |> Enum.map(fn metric ->
                     Map.get(metric, :output_variety, 0)
                   end)
                   |> Enum.sum()
    
    total_input_entropy = valid_metrics
                          |> Map.values()
                          |> Enum.map(fn metric ->
                            case metric do
                              %{entropy: %{input: input}} when is_number(input) -> input
                              %{entropy: entropy} when is_map(entropy) -> 
                                Map.get(entropy, :input, 0)
                              _ -> 0
                            end
                          end)
                          |> Enum.sum()
    
    total_output_entropy = valid_metrics
                           |> Map.values()
                           |> Enum.map(fn metric ->
                             case metric do
                               %{entropy: %{output: output}} when is_number(output) -> output
                               %{entropy: entropy} when is_map(entropy) -> 
                                 Map.get(entropy, :output, 0)
                               _ -> 0
                             end
                           end)
                           |> Enum.sum()
    
    avg_velocity = valid_metrics
                   |> Map.values()
                   |> Enum.map(fn metric ->
                     Map.get(metric, :velocity, 0)
                   end)
                   |> Enum.sum()
                   |> Kernel./(5)
    
    %{
      average_ratio: avg_ratio,
      average_entropy_ratio: avg_entropy_ratio,
      total_input_variety: total_input,
      total_output_variety: total_output,
      total_input_entropy: total_input_entropy,
      total_output_entropy: total_output_entropy,
      average_velocity: avg_velocity,
      balance_score: calculate_balance_score(metrics),
      information_efficiency: calculate_information_efficiency(metrics)
    }
  end
  
  defp calculate_balance_score(metrics) do
    # Perfect balance = 1.0 ratio at each level
    deviations = metrics
                 |> Map.values()
                 |> Enum.map(fn metric ->
                   if is_map(metric) do
                     ratio = Map.get(metric, :ratio, 0)
                     abs(ratio - 1.0)
                   else
                     1.0  # Maximum deviation for non-map values
                   end
                 end)
                 |> Enum.sum()
    
    1.0 - (deviations / 5.0)  # Normalize to 0-1 scale
  end
  
  defp extract_system_level(topic) do
    cond do
      String.contains?(topic, "system1") -> :s1
      String.contains?(topic, "system2") -> :s2
      String.contains?(topic, "system3") -> :s3
      String.contains?(topic, "system4") -> :s4
      String.contains?(topic, "system5") -> :s5
      String.contains?(topic, "policy") -> :s5
      String.contains?(topic, "coordination") -> :s2
      true -> nil
    end
  end
  
  defp infer_direction(_topic, message) do
    # Simplified - in production would analyze message flow patterns
    case message do
      {:upward, _} -> :inbound
      {:downward, _} -> :outbound
      _ -> :inbound  # Default
    end
  end
  
  defp extract_message_type(message) do
    case message do
      {type, _} when is_atom(type) -> type
      %{type: type} -> type
      %{"type" => type} -> String.to_atom(type)
      %{command: cmd} -> :"cmd_#{cmd}"
      %{"command" => cmd} -> :"cmd_#{cmd}"
      %{event: evt} -> :"evt_#{evt}"
      %{"event" => evt} -> :"evt_#{evt}"
      %{action: act} -> :"act_#{act}"
      %{"action" => act} -> :"act_#{act}"
      {:coordination_rule, rule} -> :"rule_#{rule.type}"
      {:operational_task, task} -> :"task_#{task.type}"
      {:command_response, _} -> :command_response
      {:event_notification, _} -> :event_notification
      {:telemetry_event, _, _, _} -> :telemetry
      {:DOWN, _, _, _, _} -> :process_down
      _ when is_atom(message) -> message
      _ -> :unknown
    end
  end
  
  defp schedule_metric_calculation do
    Process.send_after(self(), :calculate_metrics, 5_000)  # Every 5 seconds
  end
  
  defp calculate_entropy(messages) do
    # Calculate Shannon entropy H = -Σ(p_i * log2(p_i))
    if Enum.empty?(messages) do
      0.0
    else
      # Count occurrences of each message type
      type_counts = messages
      |> Enum.map(fn {_, type} -> type end)
      |> Enum.frequencies()
      
      total = Enum.sum(Map.values(type_counts))
      
      if total == 0 do
        0.0
      else
        type_counts
        |> Map.values()
        |> Enum.map(fn count ->
          probability = count / total
          if probability > 0 do
            -probability * :math.log2(probability)
          else
            0.0
          end
        end)
        |> Enum.sum()
      end
    end
  end
  
  defp calculate_information_efficiency(metrics) do
    # Information efficiency: how well variety is preserved through transformations
    efficiencies = metrics
    |> Map.values()
    |> Enum.map(fn m ->
      # Check if m is a map before accessing nested fields
      if is_map(m) do
        input_entropy = get_in(m, [:entropy, :input]) || 0
        output_entropy = get_in(m, [:entropy, :output]) || 0
        
        if input_entropy > 0 do
          # Efficiency is ratio of output to input entropy, capped at 1.0
          min(output_entropy / input_entropy, 1.0)
        else
          0.0
        end
      else
        0.0  # Default efficiency for non-map values
      end
    end)
    
    # Average efficiency across all levels
    if length(efficiencies) > 0 do
      Enum.sum(efficiencies) / length(efficiencies)
    else
      0.0
    end
  end
  
  defp decay_pattern_frequencies(patterns) do
    # Decay frequencies to emphasize recent patterns
    decay_factor = 0.95  # 5% decay per interval
    
    Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      level_patterns = patterns[level]
      
      decayed_patterns = %{
        inbound: decay_frequency_map(level_patterns.inbound, decay_factor),
        outbound: decay_frequency_map(level_patterns.outbound, decay_factor)
      }
      
      Map.put(acc, level, decayed_patterns)
    end)
  end
  
  defp decay_frequency_map(freq_map, decay_factor) do
    freq_map
    |> Enum.reduce(%{}, fn {type, count}, acc ->
      new_count = count * decay_factor
      # Remove very small frequencies to prevent unbounded growth
      if new_count > 0.1 do
        Map.put(acc, type, new_count)
      else
        acc
      end
    end)
  end
end