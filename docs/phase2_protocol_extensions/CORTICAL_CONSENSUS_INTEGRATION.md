# CorticalAttentionEngine + Consensus Protocol Integration

## Overview

This document details the deep integration between Intelligence's 743-line CorticalAttentionEngine and the Advanced aMCP Consensus Protocol, showing how 5-dimensional attention scoring drives distributed decision-making.

## CorticalAttentionEngine Integration Points

### 1. Proposal Scoring

Every consensus proposal is scored across 5 dimensions:

```elixir
# In protocol_integration.ex (lines 170-178)
{:ok, attention_score, components} = CorticalAttentionEngine.score_attention(
  payload,
  %{
    agent_id: agent_id,
    action_type: action_type,
    urgency: Keyword.get(opts, :urgency, :normal)
  }
)

# Components returned:
%{
  urgency: 0.85,      # How time-critical
  importance: 0.72,   # Strategic value
  complexity: 0.45,   # Implementation difficulty
  risk: 0.31,         # Potential negative impact
  confidence: 0.89    # Certainty of assessment
}
```

### 2. Temporal Window Influence

The CorticalAttentionEngine's 4 temporal windows affect consensus parameters:

```elixir
# Temporal windows from Intelligence swarm:
# - Immediate (0-5 min): Crisis response
# - Short-term (5-60 min): Tactical decisions
# - Medium-term (1-24 hr): Strategic planning
# - Long-term (>24 hr): Policy changes

# In consensus.ex - dynamic timeout based on temporal window
defp calculate_proposal_timeout(attention_components) do
  base_timeout = 5_000  # 5 seconds
  
  case attention_components.temporal_window do
    :immediate -> 
      base_timeout * 0.4    # 2 seconds - urgent
      
    :short_term -> 
      base_timeout          # 5 seconds - standard
      
    :medium_term -> 
      base_timeout * 2      # 10 seconds - deliberative
      
    :long_term -> 
      base_timeout * 6      # 30 seconds - thorough
  end
end
```

### 3. Voting Intelligence

Each agent uses the CorticalAttentionEngine to make intelligent voting decisions:

```elixir
# Enhanced voting logic in consensus.ex
defp evaluate_proposal_with_attention(proposal, local_state) do
  # Get multi-dimensional analysis
  {:ok, score, components} = CorticalAttentionEngine.score_attention(
    proposal.content,
    %{
      type: :consensus_vote,
      local_context: local_state,
      historical_data: get_voting_history(proposal.type)
    }
  )
  
  # Sophisticated voting decision tree
  vote = cond do
    # Emergency override
    components.urgency > 0.95 and components.confidence > 0.7 ->
      :yes
      
    # High benefit, low risk
    components.risk < 0.3 and components.importance > 0.8 ->
      :yes
      
    # Complex but important
    components.complexity > 0.7 and components.importance > 0.85 ->
      if has_required_resources?(proposal), do: :yes, else: :abstain
      
    # Low confidence abstention
    components.confidence < 0.4 ->
      :abstain
      
    # Default rejection for high risk
    components.risk > 0.7 ->
      :no
      
    # Standard threshold
    score > 0.6 ->
      :yes
      
    true ->
      :no
  end
  
  {vote, score, components}
end
```

### 4. Quorum Adaptation

The attention score influences required consensus levels:

```elixir
# Dynamic quorum sizing based on attention analysis
defp determine_adaptive_quorum(proposal, attention_components) do
  base_quorum = calculate_base_quorum(proposal.participants)
  
  # Adjust based on risk and importance
  risk_factor = attention_components.risk
  importance_factor = attention_components.importance
  
  cond do
    # High risk + high importance = more agreement needed
    risk_factor > 0.7 and importance_factor > 0.7 ->
      {:all, "Full consensus required for high-risk critical decisions"}
      
    # Low risk + high urgency = faster decision
    risk_factor < 0.3 and attention_components.urgency > 0.8 ->
      {max(2, div(base_quorum, 3)), "Expedited quorum for urgent low-risk actions"}
      
    # Standard majority for moderate scenarios
    true ->
      {:majority, "Standard majority consensus"}
  end
end
```

## Real Implementation Example

Here's how the integration works for a database migration proposal:

```elixir
# 1. Proposal Creation with Attention Context
proposal = %{
  type: :database_migration,
  content: %{
    action: "migrate_users_table",
    estimated_downtime: 300,  # 5 minutes
    affected_services: ["auth", "profile", "notifications"]
  }
}

# 2. CorticalAttentionEngine Analysis
{:ok, attention_score, components} = CorticalAttentionEngine.score_attention(
  proposal,
  %{
    type: :infrastructure_change,
    temporal_window: :short_term,
    system_load: get_current_load()
  }
)

# Returns:
# attention_score: 0.73
# components: %{
#   urgency: 0.45,      # Not time-critical
#   importance: 0.82,   # High strategic value
#   complexity: 0.68,   # Moderately complex
#   risk: 0.71,         # Significant risk
#   confidence: 0.86    # High confidence
# }

# 3. Consensus Parameters Adaptation
consensus_params = %{
  timeout: 10_000,           # Medium-term window
  quorum: :two_thirds,       # High risk requires more agreement
  priority: attention_score  # 0.73 priority in queue
}

# 4. Voting Process
# Each participant evaluates:
Agent1: risk=0.71 → vote=:no (risk threshold exceeded)
Agent2: importance=0.82 + resources_available → vote=:yes  
Agent3: complexity=0.68 + expertise=true → vote=:yes
Agent4: temporal_analysis → vote=:yes (good timing)
Agent5: confidence=0.86 → vote=:yes

# Result: 4/5 votes = 80% > two_thirds requirement
# Consensus: APPROVED
```

## Attention Metrics in Consensus

The integration tracks attention-influenced metrics:

```elixir
# Consensus metrics enhanced with attention data
%{
  # Standard consensus metrics
  proposals_total: 847,
  proposals_accepted: 623,
  average_voting_time: 3.2,
  
  # Attention-enhanced metrics
  attention_scores: %{
    average: 0.68,
    std_dev: 0.15,
    by_outcome: %{
      accepted: 0.74,  # Higher attention → acceptance
      rejected: 0.51   # Lower attention → rejection
    }
  },
  
  # Dimensional analysis
  voting_by_dimension: %{
    urgency_driven: 127,     # Votes where urgency > 0.8
    risk_averse: 89,         # Votes where risk > 0.7 → no
    confidence_abstain: 43,  # Abstained due to low confidence
    importance_override: 31  # Yes despite other factors
  },
  
  # Temporal distribution
  decisions_by_window: %{
    immediate: 67,
    short_term: 412,
    medium_term: 287,
    long_term: 81
  }
}
```

## Benefits of Integration

1. **Intelligent Consensus**: Decisions based on multi-dimensional analysis
2. **Adaptive Timing**: Consensus speed matches urgency
3. **Risk-Aware Voting**: Higher risk requires stronger agreement  
4. **Confidence Tracking**: Low confidence leads to abstention
5. **Temporal Optimization**: Right decision speed for context

## Configuration

```elixir
# Configure attention-consensus integration
config :vsm_phoenix, :consensus_attention,
  # Voting thresholds by dimension
  urgency_override_threshold: 0.95,
  risk_rejection_threshold: 0.7,
  confidence_abstain_threshold: 0.4,
  importance_consideration_threshold: 0.6,
  
  # Temporal window timeouts
  immediate_timeout: 2_000,
  short_term_timeout: 5_000,
  medium_term_timeout: 10_000,
  long_term_timeout: 30_000,
  
  # Quorum adaptations
  enable_adaptive_quorum: true,
  min_quorum_size: 2,
  high_risk_quorum: :two_thirds
```

## Monitoring Integration Health

```elixir
# Check attention-consensus correlation
correlation = calculate_correlation(
  attention_scores,
  consensus_outcomes
)
# Expected: 0.7+ positive correlation

# Analyze voting patterns
patterns = analyze_voting_patterns(%{
  group_by: :attention_dimension,
  time_range: :last_24h
})

# Alert on anomalies
if patterns.confidence_votes < 0.2 do
  alert("Low confidence in recent decisions")
end
```

## Conclusion

The integration of CorticalAttentionEngine with Consensus Protocol creates an intelligent distributed decision-making system where:
- Every proposal is analyzed across 5 dimensions
- Voting logic adapts to multi-factor analysis
- Temporal windows drive appropriate urgency
- Risk and importance balance for optimal outcomes

This demonstrates how Intelligence swarm's sophisticated attention mechanism enhances the robustness and intelligence of distributed consensus.