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
        s1: %{input_variety: 0, output_variety: 0, ratio: 0},
        s2: %{input_variety: 0, output_variety: 0, ratio: 0},
        s3: %{input_variety: 0, output_variety: 0, ratio: 0},
        s4: %{input_variety: 0, output_variety: 0, ratio: 0},
        s5: %{input_variety: 0, output_variety: 0, ratio: 0}
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
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:record_message, system_level, direction, message_type}, state) do
    timestamp = System.monotonic_time(:millisecond)
    
    new_messages = update_in(
      state.messages[system_level][direction],
      fn messages ->
        [{timestamp, message_type} | messages]
        |> clean_old_messages(timestamp)
      end
    )
    
    {:noreply, %{state | messages: put_in(state.messages[system_level], new_messages[system_level])}}
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
    new_metrics = Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      input_variety = calculate_variety(state.messages[level].inbound)
      output_variety = calculate_variety(state.messages[level].outbound)
      ratio = if input_variety > 0, do: output_variety / input_variety, else: 0
      
      Map.put(acc, level, %{
        input_variety: input_variety,
        output_variety: output_variety,
        ratio: ratio
      })
    end)
    
    # Broadcast variety metrics
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:variety_metrics",
      {:variety_update, new_metrics}
    )
    
    schedule_metric_calculation()
    {:noreply, %{state | variety_metrics: new_metrics}}
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
    avg_ratio = metrics
                |> Map.values()
                |> Enum.map(& &1.ratio)
                |> Enum.sum()
                |> Kernel./(5)
    
    total_input = metrics
                  |> Map.values()
                  |> Enum.map(& &1.input_variety)
                  |> Enum.sum()
    
    total_output = metrics
                   |> Map.values()
                   |> Enum.map(& &1.output_variety)
                   |> Enum.sum()
    
    %{
      average_ratio: avg_ratio,
      total_input_variety: total_input,
      total_output_variety: total_output,
      balance_score: calculate_balance_score(metrics)
    }
  end
  
  defp calculate_balance_score(metrics) do
    # Perfect balance = 1.0 ratio at each level
    deviations = metrics
                 |> Map.values()
                 |> Enum.map(& abs(&1.ratio - 1.0))
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
      _ -> :unknown
    end
  end
  
  defp schedule_metric_calculation do
    Process.send_after(self(), :calculate_metrics, 5_000)  # Every 5 seconds
  end
end