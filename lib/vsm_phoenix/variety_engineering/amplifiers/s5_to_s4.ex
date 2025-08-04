defmodule VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4 do
  @moduledoc """
  Policy Amplification: S5 → S4
  
  Expands high-level policies from System 5 into specific
  environmental scanning directives and adaptation constraints
  for System 4.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @amplification_factor 3  # Default expansion ratio
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def set_factor(factor) do
    GenServer.call(@name, {:set_factor, factor})
  end
  
  def increase_amplification do
    GenServer.cast(@name, :increase_amplification)
  end
  
  def get_stats do
    GenServer.call(@name, :get_stats)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔼 Starting S5→S4 Policy Amplifier...")
    
    state = %{
      amplification_factor: @amplification_factor,
      policy_templates: load_policy_templates(),
      stats: %{
        policies_received: 0,
        directives_generated: 0,
        amplification_ratio: 0.0
      }
    }
    
    # Subscribe to S5 policy updates
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:policy")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system5")
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:set_factor, factor}, _from, state) do
    {:reply, :ok, %{state | amplification_factor: factor}}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end
  
  @impl true
  def handle_cast(:increase_amplification, state) do
    new_factor = min(state.amplification_factor * 1.5, 10)
    Logger.info("📈 Increasing S5→S4 amplification to #{new_factor}")
    {:noreply, %{state | amplification_factor: new_factor}}
  end
  
  @impl true
  def handle_info({:policy_update, policy_type, policy_data}, state) do
    # Amplify policy into S4 directives
    directives = amplify_policy(policy_type, policy_data, state)
    
    # Forward each directive to S4
    Enum.each(directives, fn directive ->
      forward_to_s4(directive)
    end)
    
    # Update stats
    new_stats = state.stats
                |> Map.update(:policies_received, 1, &(&1 + 1))
                |> Map.update(:directives_generated, length(directives), &(&1 + length(directives)))
                |> Map.put(:amplification_ratio, calculate_ratio(state.stats))
    
    {:noreply, %{state | stats: new_stats}}
  end
  
  @impl true
  def handle_info({:new_policy, policy}, state) do
    # Handle synthesized policies from S5
    handle_info({:policy_update, policy.type, policy}, state)
  end
  
  # Handle other S5 message formats
  def handle_info({topic, message}, state) when is_binary(topic) do
    if String.contains?(topic, "policy") do
      case extract_policy_info(message) do
        {policy_type, policy_data} ->
          handle_info({:policy_update, policy_type, policy_data}, state)
        _ ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  # Private functions
  
  defp amplify_policy(policy_type, policy_data, state) do
    base_directives = generate_base_directives(policy_type, policy_data)
    
    # Expand based on amplification factor
    expanded_directives = base_directives
                          |> Enum.flat_map(fn directive ->
                            expand_directive(directive, state.amplification_factor)
                          end)
    
    # Add contextual variations
    expanded_directives
    |> add_temporal_variations(policy_data)
    |> add_environmental_contexts(policy_type)
    |> prioritize_directives()
  end
  
  defp generate_base_directives(:governance, policy_data) do
    [
      %{
        type: :scan_compliance,
        scope: :regulatory,
        parameters: extract_governance_params(policy_data),
        priority: :high
      },
      %{
        type: :scan_stakeholders,
        scope: :internal_external,
        parameters: %{focus: policy_data[:autonomy_levels]},
        priority: :medium
      },
      %{
        type: :monitor_thresholds,
        scope: :system_health,
        parameters: policy_data[:intervention_triggers],
        priority: :high
      }
    ]
  end
  
  defp generate_base_directives(:adaptation, policy_data) do
    [
      %{
        type: :scan_opportunities,
        scope: :innovation,
        parameters: %{constraints: policy_data[:adaptation_limits]},
        priority: :medium
      },
      %{
        type: :scan_threats,
        scope: :environmental,
        parameters: %{types: policy_data[:allowed_adaptations]},
        priority: :high
      },
      %{
        type: :evaluate_readiness,
        scope: :capability,
        parameters: policy_data[:evaluation_criteria],
        priority: :medium
      }
    ]
  end
  
  defp generate_base_directives(:resource_allocation, policy_data) do
    [
      %{
        type: :scan_resource_markets,
        scope: :external,
        parameters: %{limits: policy_data[:resource_limits]},
        priority: :medium
      },
      %{
        type: :monitor_efficiency,
        scope: :internal,
        parameters: policy_data[:efficiency_targets],
        priority: :high
      }
    ]
  end
  
  defp generate_base_directives(:identity_preservation, policy_data) do
    [
      %{
        type: :scan_identity_threats,
        scope: :strategic,
        parameters: %{markers: policy_data[:identity_markers]},
        priority: :critical
      },
      %{
        type: :monitor_coherence,
        scope: :organizational,
        parameters: policy_data[:evolution_constraints],
        priority: :high
      }
    ]
  end
  
  defp generate_base_directives(_, policy_data) do
    # Generic amplification for unknown policy types
    [
      %{
        type: :general_scan,
        scope: :comprehensive,
        parameters: policy_data,
        priority: :medium
      }
    ]
  end
  
  defp expand_directive(directive, factor) do
    # Create multiple specific directives from one general directive
    1..round(factor)
    |> Enum.map(fn i ->
      Map.merge(directive, %{
        variant: i,
        specificity: add_specificity(directive, i),
        timeframe: calculate_timeframe(directive, i)
      })
    end)
  end
  
  defp add_specificity(directive, variant) do
    case directive.type do
      :scan_compliance ->
        %{
          regulations: select_regulations(variant),
          depth: if(variant == 1, do: :surface, else: :deep)
        }
      :scan_opportunities ->
        %{
          sectors: select_sectors(variant),
          innovation_types: select_innovation_types(variant)
        }
      _ ->
        %{level: variant}
    end
  end
  
  defp calculate_timeframe(directive, variant) do
    base_time = case directive.priority do
      :critical -> {1, :hour}
      :high -> {4, :hour}
      :medium -> {1, :day}
      :low -> {1, :week}
    end
    
    adjust_timeframe(base_time, variant)
  end
  
  defp adjust_timeframe({amount, unit}, variant) do
    %{
      frequency: {amount * variant, unit},
      window: {amount * variant * 2, unit}
    }
  end
  
  defp add_temporal_variations(directives, _policy_data) do
    # Add time-based variations
    Enum.flat_map(directives, fn directive ->
      [
        directive,
        Map.put(directive, :temporal, :immediate),
        Map.put(directive, :temporal, :scheduled),
        Map.put(directive, :temporal, :continuous)
      ]
    end)
  end
  
  defp add_environmental_contexts(directives, policy_type) do
    contexts = case policy_type do
      :governance -> [:market, :regulatory, :social]
      :adaptation -> [:technological, :competitive, :environmental]
      :resource_allocation -> [:supply_chain, :financial, :human_resources]
      :identity_preservation -> [:cultural, :strategic, :operational]
      _ -> [:general]
    end
    
    Enum.flat_map(directives, fn directive ->
      Enum.map(contexts, fn context ->
        Map.put(directive, :environmental_context, context)
      end)
    end)
  end
  
  defp prioritize_directives(directives) do
    directives
    |> Enum.sort_by(fn d -> 
      {priority_weight(d.priority), d[:temporal] == :immediate}
    end, :desc)
    |> Enum.take(20)  # Limit total directives to prevent overload
  end
  
  defp priority_weight(:critical), do: 4
  defp priority_weight(:high), do: 3
  defp priority_weight(:medium), do: 2
  defp priority_weight(:low), do: 1
  
  defp forward_to_s4(directive) do
    # Send amplified directive to System 4
    message = {:intelligence_directive, directive}
    
    # Via PubSub
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:system4",
      message
    )
    
    # Direct call for critical directives
    if directive.priority == :critical do
      VsmPhoenix.System4.Intelligence.scan_environment(directive)
    end
    
    # Track variety flow
    VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s4, :inbound, directive.type)
  end
  
  defp calculate_ratio(stats) do
    if stats.policies_received > 0 do
      stats.directives_generated / stats.policies_received
    else
      0.0
    end
  end
  
  defp extract_policy_info(message) do
    case message do
      {:policy_decision, decision} ->
        {String.to_atom(decision.decision_type), decision}
      {:policy_update, type, data} ->
        {type, data}
      %{type: type, data: data} ->
        {type, data}
      _ ->
        nil
    end
  end
  
  defp load_policy_templates do
    # Load predefined policy expansion templates
    %{
      governance: load_governance_templates(),
      adaptation: load_adaptation_templates(),
      resource: load_resource_templates(),
      identity: load_identity_templates()
    }
  end
  
  defp load_governance_templates do
    # Templates for expanding governance policies
    %{
      regulatory_compliance: ["SOX", "GDPR", "HIPAA", "ISO27001"],
      stakeholder_groups: ["customers", "employees", "shareholders", "community"],
      governance_metrics: ["transparency", "accountability", "fairness", "sustainability"]
    }
  end
  
  defp load_adaptation_templates do
    %{
      innovation_areas: ["product", "process", "business_model", "organizational"],
      adaptation_strategies: ["incremental", "radical", "disruptive", "evolutionary"],
      change_dimensions: ["structure", "culture", "technology", "capability"]
    }
  end
  
  defp load_resource_templates do
    %{
      resource_types: ["financial", "human", "technological", "informational"],
      optimization_targets: ["efficiency", "effectiveness", "resilience", "scalability"],
      allocation_strategies: ["priority_based", "balanced", "dynamic", "reserved"]
    }
  end
  
  defp load_identity_templates do
    %{
      identity_dimensions: ["mission", "vision", "values", "culture"],
      preservation_strategies: ["reinforce", "evolve", "protect", "communicate"],
      coherence_measures: ["alignment", "consistency", "integration", "authenticity"]
    }
  end
  
  defp extract_governance_params(policy_data) do
    %{
      thresholds: policy_data[:decision_thresholds],
      autonomy: policy_data[:autonomy_levels],
      triggers: policy_data[:intervention_triggers]
    }
  end
  
  defp select_regulations(variant) do
    all_regulations = ["SOX", "GDPR", "HIPAA", "ISO27001", "PCI-DSS", "CCPA"]
    Enum.take(Enum.drop(all_regulations, variant - 1), 3)
  end
  
  defp select_sectors(variant) do
    all_sectors = ["technology", "healthcare", "finance", "retail", "manufacturing", "energy"]
    Enum.take(Enum.drop(all_sectors, variant - 1), 2)
  end
  
  defp select_innovation_types(variant) do
    all_types = ["product", "service", "process", "business_model", "organizational"]
    Enum.take(Enum.drop(all_types, variant - 1), 2)
  end
end