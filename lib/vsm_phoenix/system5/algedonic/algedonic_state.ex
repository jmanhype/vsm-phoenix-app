defmodule VsmPhoenix.System5.Algedonic.AlgedonicState do
  @moduledoc """
  Algedonic State Management - Encapsulates pain/pleasure state calculations.
  
  Extracted from Queen god object to follow Single Responsibility Principle.
  Handles ONLY algedonic state calculations and updates.
  """
  
  @enforce_keys [:pain_level, :pleasure_level, :balance, :viability_impact]
  defstruct [
    :pain_level,
    :pleasure_level,
    :balance,
    :viability_impact,
    trend: :stable,
    weighted_history: [],
    last_updated: nil,
    signal_count: 0
  ]
  
  @type t :: %__MODULE__{
    pain_level: float(),
    pleasure_level: float(),
    balance: float(),
    viability_impact: float(),
    trend: :increasing | :decreasing | :stable,
    weighted_history: list(),
    last_updated: integer() | nil,
    signal_count: integer()
  }
  
  @doc """
  Create a new algedonic state with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      pain_level: 0.0,
      pleasure_level: 0.5,
      balance: 0.5,
      viability_impact: 1.0,
      trend: :stable,
      weighted_history: [],
      last_updated: System.system_time(:millisecond),
      signal_count: 0
    }
  end
  
  @doc """
  Update algedonic state based on a new signal.
  """
  @spec update(t(), map()) :: t()
  def update(state, signal) do
    timestamp = System.system_time(:millisecond)
    
    # Calculate temporal weights (recent signals have more impact)
    time_weight = calculate_time_weight(state.last_updated, timestamp)
    intensity_weight = calculate_intensity_weight(signal.intensity)
    context_weight = calculate_context_weight(signal.context)
    
    combined_weight = time_weight * intensity_weight * context_weight
    
    # Update levels based on signal type
    {new_pain, new_pleasure} = case signal.type do
      :pain -> 
        new_pain = update_pain_level(state.pain_level, signal.intensity, combined_weight)
        new_pleasure = decay_pleasure_level(state.pleasure_level, signal.intensity * 0.3)
        {new_pain, new_pleasure}
        
      :pleasure ->
        new_pleasure = update_pleasure_level(state.pleasure_level, signal.intensity, combined_weight)
        new_pain = decay_pain_level(state.pain_level, signal.intensity * 0.2)
        {new_pain, new_pleasure}
        
      _ ->
        {state.pain_level, state.pleasure_level}
    end
    
    # Calculate new balance and viability impact
    new_balance = calculate_balance(new_pain, new_pleasure)
    new_viability_impact = calculate_viability_impact(new_pain, new_pleasure, new_balance)
    
    # Calculate trend
    new_trend = calculate_trend(state, new_balance)
    
    # Update weighted history
    new_history = update_weighted_history(
      state.weighted_history,
      {signal.type, signal.intensity, combined_weight, timestamp}
    )
    
    %{state |
      pain_level: new_pain,
      pleasure_level: new_pleasure,
      balance: new_balance,
      viability_impact: new_viability_impact,
      trend: new_trend,
      weighted_history: new_history,
      last_updated: timestamp,
      signal_count: state.signal_count + 1
    }
  end
  
  @doc """
  Get a summary of the current algedonic state.
  """
  @spec summary(t()) :: map()
  def summary(state) do
    %{
      pain_level: state.pain_level,
      pleasure_level: state.pleasure_level,
      balance: state.balance,
      viability_impact: state.viability_impact,
      trend: state.trend,
      health_status: determine_health_status(state),
      intervention_needed: requires_intervention?(state),
      signal_count: state.signal_count,
      last_updated: state.last_updated
    }
  end
  
  # Private Functions
  
  defp calculate_time_weight(nil, _current), do: 1.0
  defp calculate_time_weight(last_time, current_time) do
    time_diff = current_time - last_time
    # More recent signals have higher weight (exponential decay)
    :math.exp(-time_diff / 60_000)  # 1 minute half-life
  end
  
  defp calculate_intensity_weight(intensity) do
    # Non-linear weighting - extreme signals have disproportionate impact
    :math.pow(intensity, 1.5)
  end
  
  defp calculate_context_weight(%{"priority" => priority}) when priority in ["critical", "high"] do
    1.5
  end
  defp calculate_context_weight(%{"system" => system}) when system in ["system5", "queen"] do
    1.3
  end
  defp calculate_context_weight(_), do: 1.0
  
  defp update_pain_level(current_pain, signal_intensity, weight) do
    # Pain accumulates more rapidly than it decays
    new_pain = current_pain + (signal_intensity * weight * 0.7)
    min(new_pain, 1.0)
  end
  
  defp update_pleasure_level(current_pleasure, signal_intensity, weight) do
    # Pleasure has diminishing returns
    max_increase = 1.0 - current_pleasure
    increase = signal_intensity * weight * 0.5 * max_increase
    current_pleasure + increase
  end
  
  defp decay_pain_level(current_pain, decay_amount) do
    # Pain decays slower than pleasure
    max(current_pain - (decay_amount * 0.8), 0.0)
  end
  
  defp decay_pleasure_level(current_pleasure, decay_amount) do
    # Pleasure decays faster during pain
    max(current_pleasure - (decay_amount * 1.2), 0.0)
  end
  
  defp calculate_balance(pain_level, pleasure_level) do
    # Balance ranges from -1 (all pain) to +1 (all pleasure)
    # 0 represents equilibrium
    pleasure_level - pain_level
  end
  
  defp calculate_viability_impact(pain_level, pleasure_level, balance) do
    # High pain or very low pleasure reduces viability
    # Balanced systems have higher viability
    base_viability = 1.0 - (pain_level * 0.8)
    pleasure_bonus = pleasure_level * 0.3
    balance_factor = 1.0 - (abs(balance) * 0.2)
    
    (base_viability + pleasure_bonus) * balance_factor
    |> max(0.0)
    |> min(1.0)
  end
  
  defp calculate_trend(state, new_balance) do
    if length(state.weighted_history) < 3 do
      :stable
    else
      recent_balances = state.weighted_history
                       |> Enum.take(5)
                       |> Enum.map(fn {_, _, _, _} -> new_balance end)  # Simplified for now
      
      cond do
        Enum.all?(recent_balances, &(&1 > state.balance)) -> :increasing
        Enum.all?(recent_balances, &(&1 < state.balance)) -> :decreasing
        true -> :stable
      end
    end
  end
  
  defp update_weighted_history(history, new_entry) do
    [new_entry | history]
    |> Enum.take(100)  # Keep last 100 weighted entries
  end
  
  defp determine_health_status(state) do
    cond do
      state.pain_level >= 0.8 -> :critical
      state.pain_level >= 0.6 -> :degraded
      state.viability_impact <= 0.4 -> :concerning
      state.balance >= 0.3 -> :healthy
      state.balance >= 0.0 -> :stable
      true -> :declining
    end
  end
  
  defp requires_intervention?(state) do
    state.pain_level >= 0.7 or 
    state.viability_impact <= 0.3 or
    (state.pleasure_level <= 0.2 and state.pain_level >= 0.4)
  end
end