defmodule VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1.Helpers do
  @moduledoc """
  Helper functions for S2ToS1 amplifier - temporary patch for missing functions.
  """

  def calculate_effective_amplification(_rule_type, state) do
    # Simple implementation - uses base amplification factor
    state.amplification_factor
  end

  def generate_task_id do
    # Generate unique task ID
    "task_" <> (:erlang.unique_integer([:positive, :monotonic]) |> to_string())
  end

  def update_performance_metrics(metrics, status, duration) do
    # Update metrics based on task outcome
    Map.update(metrics, status, 1, &(&1 + 1))
    |> Map.put(:last_duration, duration)
    |> Map.put(:last_update, System.monotonic_time(:millisecond))
  end

  def update_rule_effectiveness(effectiveness, rule_type, status) do
    # Track rule effectiveness
    rule_key = {rule_type, status}
    Map.update(effectiveness, rule_key, 1, &(&1 + 1))
  end

  def calculate_overall_effectiveness(state) do
    # Calculate effectiveness based on success rate
    total_tasks = map_size(state.task_outcomes)
    if total_tasks == 0 do
      0.5  # Default effectiveness
    else
      completed = Enum.count(state.task_outcomes, fn {_, task} ->
        task[:status] == :completed
      end)
      completed / total_tasks
    end
  end

  def adapt_amplification_factor(current_factor, effectiveness, _metrics) do
    # Adapt factor based on effectiveness
    cond do
      effectiveness > 0.9 -> min(current_factor * 1.1, 10.0)
      effectiveness < 0.5 -> max(current_factor * 0.9, 1.0)
      true -> current_factor
    end
  end

  def clean_old_outcomes(state) do
    # Remove outcomes older than 1 hour
    cutoff = System.monotonic_time(:millisecond) - 3600_000
    
    new_outcomes = state.task_outcomes
    |> Enum.filter(fn {_, task} ->
      Map.get(task, :completed_at, cutoff + 1) > cutoff
    end)
    |> Map.new()
    
    %{state | task_outcomes: new_outcomes}
  end
end