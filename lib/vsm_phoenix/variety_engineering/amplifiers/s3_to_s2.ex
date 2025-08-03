defmodule VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2 do
  @moduledoc """
  Resource Amplification: S3 → S2
  
  Transforms resource decisions from System 3 into
  coordination rules for System 2.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def increase_amplification do
    GenServer.cast(@name, :increase_amplification)
  end
  
  def set_factor(factor) do
    GenServer.call(@name, {:set_factor, factor})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔼 Starting S3→S2 Resource Amplifier...")
    
    # Subscribe to S3 resource decisions
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system3")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:resources")
    
    {:ok, %{amplification_factor: 3}}
  end
  
  @impl true
  def handle_call({:set_factor, factor}, _from, state) do
    {:reply, :ok, %{state | amplification_factor: factor}}
  end
  
  @impl true
  def handle_cast(:increase_amplification, state) do
    {:noreply, %{state | amplification_factor: min(state.amplification_factor * 1.5, 10)}}
  end
  
  @impl true
  def handle_info({:resource_allocation, allocation}, state) do
    # Amplify resource allocation into coordination rules
    coordination_rules = amplify_to_rules(allocation, state.amplification_factor)
    
    Enum.each(coordination_rules, fn rule ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:system2",
        {:coordination_rule, rule}
      )
      
      # Direct call for critical rules
      if rule.enforcement == :strict do
        VsmPhoenix.System2.Coordinator.broadcast_coordination("vsm:coordination", rule)
      end
      
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s2, :inbound, :coordination_rule)
    end)
    
    {:noreply, state}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp amplify_to_rules(allocation, factor) do
    base_rules = generate_base_rules(allocation)
    
    # Expand rules based on factor
    base_rules
    |> Enum.flat_map(fn rule ->
      1..round(factor)
      |> Enum.map(fn i ->
        specialize_rule(rule, allocation, i)
      end)
    end)
  end
  
  defp generate_base_rules(allocation) do
    [
      %{
        type: :rate_limiting,
        scope: :message_flow,
        enforcement: determine_enforcement(allocation)
      },
      %{
        type: :synchronization,
        scope: :context_coordination,
        enforcement: :recommended
      },
      %{
        type: :priority_routing,
        scope: :resource_access,
        enforcement: :strict
      }
    ]
  end
  
  defp specialize_rule(base_rule, allocation, variant) do
    Map.merge(base_rule, %{
      variant: variant,
      parameters: generate_rule_parameters(base_rule.type, allocation, variant),
      contexts: select_contexts(allocation, variant),
      duration: calculate_rule_duration(allocation)
    })
  end
  
  defp generate_rule_parameters(:rate_limiting, allocation, variant) do
    %{
      max_rate: 100 / variant,  # More specific = lower rate
      window_ms: 1000 * variant,
      burst_allowed: allocation[:priority] == :high
    }
  end
  
  defp generate_rule_parameters(:synchronization, _allocation, variant) do
    %{
      sync_interval: 1000 * variant,
      coordination_depth: min(variant, 3),
      conflict_resolution: :consensus
    }
  end
  
  defp generate_rule_parameters(:priority_routing, allocation, _variant) do
    %{
      priority_levels: 3,
      allocation_weights: allocation[:weights] || %{high: 0.5, medium: 0.3, low: 0.2},
      preemption_allowed: allocation[:priority] == :critical
    }
  end
  
  defp select_contexts(allocation, variant) do
    all_contexts = allocation[:contexts] || [:operations, :monitoring, :control]
    Enum.take(Enum.drop(all_contexts, variant - 1), 2)
  end
  
  defp calculate_rule_duration(allocation) do
    case allocation[:duration] do
      :permanent -> :permanent
      nil -> {1, :hour}
      duration -> duration
    end
  end
  
  defp determine_enforcement(allocation) do
    case allocation[:priority] do
      :critical -> :strict
      :high -> :strict
      :normal -> :recommended
      _ -> :optional
    end
  end
end