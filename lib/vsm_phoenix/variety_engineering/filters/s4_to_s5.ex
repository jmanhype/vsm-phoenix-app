defmodule VsmPhoenix.VarietyEngineering.Filters.S4ToS5 do
  @moduledoc """
  Insights to Policy Filter: S4 → S5
  
  Synthesizes policy-relevant information from System 4
  intelligence for System 5 governance decisions.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def increase_filtering do
    GenServer.cast(@name, :increase_filtering)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔽 Starting S4→S5 Insights Filter...")
    
    # Subscribe to S4 intelligence insights
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system4")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:intelligence")
    
    {:ok, %{
      filtering_level: 1.0,
      policy_relevance_threshold: 0.8
    }}
  end
  
  @impl true
  def handle_cast(:increase_filtering, state) do
    {:noreply, %{state | filtering_level: min(state.filtering_level * 1.2, 2.0)}}
  end
  
  @impl true
  def handle_info({:environmental_insight, insight}, state) do
    # Filter for policy-relevant insights
    if is_policy_relevant?(insight, state) do
      policy_input = transform_to_policy_input(insight)
      
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:system5",
        {:policy_consideration, policy_input}
      )
      
      # Direct notification for critical insights
      if insight[:severity] > 0.9 do
        VsmPhoenix.System5.Queen.synthesize_adaptive_policy(policy_input)
      end
      
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s5, :inbound, :policy_input)
    end
    
    {:noreply, state}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp is_policy_relevant?(insight, state) do
    relevance_score = calculate_policy_relevance(insight)
    relevance_score >= (state.policy_relevance_threshold * state.filtering_level)
  end
  
  defp calculate_policy_relevance(insight) do
    # Score based on strategic impact
    base_score = 0.5
    
    # Adjust for various factors
    severity_score = Map.get(insight, :severity, 0.5) * 0.3
    scope_score = if insight[:scope] in [:strategic, :identity], do: 0.2, else: 0.0
    viability_score = if insight[:viability_impact], do: 0.2, else: 0.0
    
    base_score + severity_score + scope_score + viability_score
  end
  
  defp transform_to_policy_input(insight) do
    %{
      source: :s4_intelligence,
      type: categorize_for_policy(insight),
      data: insight,
      recommendations: generate_policy_recommendations(insight),
      urgency: insight[:urgency] || :normal
    }
  end
  
  defp categorize_for_policy(insight) do
    cond do
      insight[:type] in [:threat, :risk] -> :risk_management
      insight[:type] in [:opportunity, :innovation] -> :strategic_opportunity
      insight[:type] == :anomaly -> :adaptation_required
      true -> :general_intelligence
    end
  end
  
  defp generate_policy_recommendations(insight) do
    # Generate high-level policy recommendations
    case insight[:type] do
      :threat -> ["strengthen_defenses", "increase_monitoring", "prepare_contingency"]
      :opportunity -> ["allocate_resources", "adjust_strategy", "enable_innovation"]
      :anomaly -> ["investigate_cause", "adapt_policies", "monitor_closely"]
      _ -> ["review_policies", "maintain_vigilance"]
    end
  end
end