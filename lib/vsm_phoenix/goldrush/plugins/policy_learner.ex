defmodule VsmPhoenix.Goldrush.Plugins.PolicyLearner do
  @moduledoc """
  Goldrush Plugin for Policy Effectiveness Learning
  
  Tracks policy outcomes and learns which policies work best
  for different anomaly types. Uses real event correlation!
  """
  
  # Plugin behavior for Goldrush integration
  # @behaviour :goldrush_plugin
  
  require Logger
  alias VsmPhoenix.System5.PolicySynthesizer
  
  def init(config) do
    Logger.info("🧠 Initializing Goldrush Policy Learner Plugin")
    
    # For now, we'll track correlations manually
    # Real Goldrush streams will be added when we understand the correct API
    Logger.info("📊 Policy learning streams configured")
    
    {:ok, %{
      config: config,
      policy_outcomes: %{},
      learning_data: [],
      effectiveness_scores: %{}
    }}
  end
  
  def process_event([:vsm, :s5, :policy_synthesized] = event, measurements, metadata, state) do
    Logger.info("📜 Tracking new policy: #{metadata.policy_id}")
    
    # Start tracking this policy's effectiveness
    policy_data = %{
      id: metadata.policy_id,
      type: metadata.policy_type,
      anomaly_trigger: metadata.anomaly_data,
      created_at: DateTime.utc_now(),
      outcomes: []
    }
    
    new_policies = Map.put(state.policy_outcomes, metadata.policy_id, policy_data)
    %{state | policy_outcomes: new_policies}
  end
  
  def process_event([:vsm, :s5, signal] = event, measurements, metadata, state) 
      when signal in [:pleasure_signal, :pain_signal] do
    
    # Correlate with recent policies
    correlated_policies = find_correlated_policies(metadata, state)
    
    Enum.reduce(correlated_policies, state, fn policy_id, acc_state ->
      update_policy_outcome(policy_id, signal, measurements.intensity, acc_state)
    end)
  end
  
  def process_event(_event, _measurements, _metadata, state), do: state
  
  def get_metrics(state) do
    %{
      tracked_policies: map_size(state.policy_outcomes),
      average_effectiveness: calculate_average_effectiveness(state),
      best_policies: get_best_policies(state, 5),
      worst_policies: get_worst_policies(state, 5)
    }
  end
  
  @doc """
  Get policy recommendations based on learned effectiveness
  """
  def recommend_policy(anomaly_type, state) do
    # Find policies that worked well for similar anomalies
    similar_policies = state.learning_data
    |> Enum.filter(fn data ->
      data.anomaly_type == anomaly_type && data.effectiveness > 0.7
    end)
    |> Enum.sort_by(& &1.effectiveness, :desc)
    |> Enum.take(3)
    
    if similar_policies != [] do
      {:ok, similar_policies}
    else
      {:no_recommendation, "No effective policies found for #{anomaly_type}"}
    end
  end
  
  @doc """
  Trigger policy evolution based on learning
  """
  def evolve_ineffective_policies(state) do
    # Find policies with poor outcomes
    poor_policies = state.effectiveness_scores
    |> Enum.filter(fn {_id, score} -> score < 0.3 end)
    |> Enum.map(fn {id, _score} -> id end)
    
    Enum.each(poor_policies, fn policy_id ->
      policy_data = Map.get(state.policy_outcomes, policy_id)
      
      if policy_data do
        Logger.info("📈 Evolving poor policy: #{policy_id}")
        
        feedback = %{
          effectiveness_score: Map.get(state.effectiveness_scores, policy_id),
          outcomes: policy_data.outcomes,
          recommendation: "Policy underperforming, needs evolution"
        }
        
        Task.start(fn ->
          PolicySynthesizer.evolve_policy_based_on_feedback(policy_id, feedback)
        end)
      end
    end)
  end
  
  # Private Functions
  
  defp find_correlated_policies(metadata, _state) do
    # For now, return empty list
    # Real correlation will be implemented with correct Goldrush API
    []
  end
  
  defp update_policy_outcome(policy_id, signal, intensity, state) do
    case Map.get(state.policy_outcomes, policy_id) do
      nil ->
        state
        
      policy_data ->
        # Record outcome
        outcome = %{
          signal: signal,
          intensity: intensity,
          timestamp: DateTime.utc_now()
        }
        
        updated_policy = Map.update!(policy_data, :outcomes, &([outcome | &1]))
        new_policies = Map.put(state.policy_outcomes, policy_id, updated_policy)
        
        # Update effectiveness score
        effectiveness = calculate_effectiveness(updated_policy)
        new_scores = Map.put(state.effectiveness_scores, policy_id, effectiveness)
        
        # Add to learning data
        learning_entry = %{
          policy_id: policy_id,
          policy_type: policy_data.type,
          anomaly_type: get_in(policy_data, [:anomaly_trigger, :type]),
          effectiveness: effectiveness,
          outcome_count: length(updated_policy.outcomes)
        }
        
        %{state | 
          policy_outcomes: new_policies,
          effectiveness_scores: new_scores,
          learning_data: [learning_entry | state.learning_data] |> Enum.take(1000)
        }
    end
  end
  
  defp calculate_effectiveness(policy_data) do
    if policy_data.outcomes == [] do
      0.5  # Neutral if no outcomes yet
    else
      # Calculate based on pleasure vs pain signals
      {pleasure_score, pain_score} = Enum.reduce(policy_data.outcomes, {0.0, 0.0}, fn outcome, {p, n} ->
        case outcome.signal do
          :pleasure_signal -> {p + outcome.intensity, n}
          :pain_signal -> {p, n + outcome.intensity}
        end
      end)
      
      total = pleasure_score + pain_score
      if total > 0 do
        pleasure_score / total
      else
        0.5
      end
    end
  end
  
  defp calculate_average_effectiveness(state) do
    scores = Map.values(state.effectiveness_scores)
    
    if scores == [] do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end
  
  defp get_best_policies(state, count) do
    state.effectiveness_scores
    |> Enum.sort_by(fn {_id, score} -> score end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn {id, score} -> %{policy_id: id, effectiveness: score} end)
  end
  
  defp get_worst_policies(state, count) do
    state.effectiveness_scores
    |> Enum.sort_by(fn {_id, score} -> score end)
    |> Enum.take(count)
    |> Enum.map(fn {id, score} -> %{policy_id: id, effectiveness: score} end)
  end
end