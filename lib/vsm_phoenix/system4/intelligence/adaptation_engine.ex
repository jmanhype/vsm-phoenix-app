defmodule VsmPhoenix.System4.Intelligence.AdaptationEngine do
  @moduledoc """
  Adaptation Engine - Generates, implements, and monitors system adaptations

  Responsibilities:
  - Adaptation proposal generation
  - Model selection and management (incremental, transformational, defensive)
  - Adaptation implementation coordination
  - Progress monitoring and metrics
  - Resource coordination with System 3
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System3.Control

  @name __MODULE__

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def generate_proposal(challenge) do
    GenServer.call(@name, {:generate_proposal, challenge})
  end

  def implement_adaptation(proposal) do
    GenServer.cast(@name, {:implement_adaptation, proposal})
  end

  def get_active_adaptations do
    GenServer.call(@name, :get_active_adaptations)
  end

  def get_adaptation_metrics do
    GenServer.call(@name, :get_adaptation_metrics)
  end

  def request_proposals_for_viability(viability_metrics) do
    GenServer.cast(@name, {:request_proposals, viability_metrics})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("AdaptationEngine: Initializing adaptation engine...")

    state = %{
      adaptation_models: %{
        incremental: load_incremental_model(),
        transformational: load_transformational_model(),
        defensive: load_defensive_model()
      },
      current_adaptations: [],
      adaptation_metrics: %{
        success_rate: 0.9,
        average_completion_time: 0,
        resource_efficiency: 0.85,
        innovation_index: 0.7
      },
      adaptation_history: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:generate_proposal, challenge}, _from, state) do
    Logger.info("AdaptationEngine: Generating proposal for challenge: #{inspect(challenge.type)}")

    proposal = create_adaptation_proposal(challenge, state)

    {:reply, {:ok, proposal}, state}
  end

  @impl true
  def handle_call(:get_active_adaptations, _from, state) do
    active =
      Enum.map(state.current_adaptations, fn adaptation ->
        %{
          id: adaptation.id,
          type: adaptation.model_type,
          status: adaptation[:status] || :in_progress,
          started_at: adaptation[:started_at]
        }
      end)

    {:reply, {:ok, active}, state}
  end

  @impl true
  def handle_call(:get_adaptation_metrics, _from, state) do
    metrics =
      Map.merge(state.adaptation_metrics, %{
        active_adaptations: length(state.current_adaptations),
        adaptation_capacity: calculate_adaptation_capacity(state)
      })

    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_cast({:implement_adaptation, proposal}, state) do
    Logger.info("AdaptationEngine: Implementing adaptation #{proposal.id}")

    # Add implementation details
    adaptation =
      Map.merge(proposal, %{
        status: :in_progress,
        started_at: DateTime.utc_now()
      })

    # Add to current adaptations
    new_adaptations = [adaptation | state.current_adaptations]

    # Coordinate with System 3 for resources
    Control.allocate_for_adaptation(proposal)

    # Schedule monitoring
    schedule_adaptation_monitoring(adaptation.id)

    {:noreply, %{state | current_adaptations: new_adaptations}}
  end

  @impl true
  def handle_cast({:request_proposals, viability_metrics}, state) do
    Logger.info("AdaptationEngine: Generating proposals for viability issues")

    challenges = identify_challenges_from_metrics(viability_metrics)

    Enum.each(challenges, fn challenge ->
      proposal = create_adaptation_proposal(challenge, state)
      Queen.approve_adaptation(proposal)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:adaptation_needed, challenge}, state) do
    Logger.info("AdaptationEngine: Received adaptation request from Analyzer")

    proposal = create_adaptation_proposal(challenge, state)

    # Submit to Queen for approval
    Queen.approve_adaptation(proposal)

    {:noreply, state}
  end

  @impl true
  def handle_info({:monitor_adaptation, adaptation_id}, state) do
    adaptation = Enum.find(state.current_adaptations, &(&1.id == adaptation_id))

    if adaptation do
      progress = monitor_adaptation_progress(adaptation)

      if progress.completed do
        # Update metrics
        new_metrics = update_adaptation_metrics(state.adaptation_metrics, progress)

        # Move to history
        completed_adaptation =
          Map.merge(adaptation, %{
            status: :completed,
            completed_at: DateTime.utc_now(),
            results: progress
          })

        new_history = [completed_adaptation | state.adaptation_history] |> Enum.take(100)
        new_adaptations = Enum.reject(state.current_adaptations, &(&1.id == adaptation_id))

        {:noreply,
         %{
           state
           | current_adaptations: new_adaptations,
             adaptation_metrics: new_metrics,
             adaptation_history: new_history
         }}
      else
        # Continue monitoring
        schedule_adaptation_monitoring(adaptation_id)
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp create_adaptation_proposal(challenge, state) do
    # Select appropriate model
    model = select_adaptation_model(challenge, state.adaptation_models)

    %{
      id: generate_proposal_id(),
      challenge: challenge,
      model_type: model.type,
      actions: model[:generate_actions].(challenge),
      impact: model[:estimate_impact].(challenge),
      resources_required: model[:estimate_resources].(challenge),
      timeline: model[:estimate_timeline].(challenge),
      risks: model[:identify_risks].(challenge),
      created_at: DateTime.utc_now()
    }
  end

  defp select_adaptation_model(challenge, models) do
    case challenge[:urgency] || :medium do
      :high -> models.defensive
      :medium -> models.incremental
      :low -> models.transformational
    end
  end

  defp load_incremental_model do
    %{
      type: :incremental,
      generate_actions: fn challenge ->
        base_actions = ["optimize_processes", "enhance_features"]

        if challenge[:type] == :efficiency do
          ["streamline_operations" | base_actions]
        else
          base_actions
        end
      end,
      estimate_impact: fn _challenge -> 0.2 + :rand.uniform() * 0.1 end,
      estimate_resources: fn _challenge -> %{time: "2_weeks", cost: :low} end,
      estimate_timeline: fn _challenge -> "1_month" end,
      identify_risks: fn _challenge -> [:minimal_disruption] end
    }
  end

  defp load_transformational_model do
    %{
      type: :transformational,
      generate_actions: fn challenge ->
        base_actions = ["restructure_operations", "new_capabilities"]

        case challenge[:type] do
          :market_shift -> ["pivot_strategy" | base_actions]
          :technology_disruption -> ["adopt_new_tech" | base_actions]
          _ -> base_actions
        end
      end,
      estimate_impact: fn _challenge -> 0.6 + :rand.uniform() * 0.2 end,
      estimate_resources: fn _challenge -> %{time: "3_months", cost: :high} end,
      estimate_timeline: fn _challenge -> "6_months" end,
      identify_risks: fn _challenge -> [:disruption, :resistance, :resource_strain] end
    }
  end

  defp load_defensive_model do
    %{
      type: :defensive,
      generate_actions: fn challenge ->
        base_actions = ["strengthen_core", "reduce_exposure"]

        if challenge[:type] == :health do
          ["emergency_stabilization" | base_actions]
        else
          base_actions
        end
      end,
      estimate_impact: fn _challenge -> 0.3 + :rand.uniform() * 0.1 end,
      estimate_resources: fn _challenge -> %{time: "1_month", cost: :medium} end,
      estimate_timeline: fn _challenge -> "2_months" end,
      identify_risks: fn _challenge -> [:opportunity_loss, :competitive_disadvantage] end
    }
  end

  defp generate_proposal_id do
    "ADAPT-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end

  defp calculate_adaptation_capacity(state) do
    active_count = length(state.current_adaptations)

    cond do
      active_count >= 5 -> 0.2
      active_count >= 3 -> 0.5
      true -> 0.9
    end
  end

  defp identify_challenges_from_metrics(metrics) do
    challenges = []

    challenges =
      if metrics[:system_health] && metrics.system_health < 0.7 do
        [%{type: :health, urgency: :high, scope: :system_wide} | challenges]
      else
        challenges
      end

    challenges =
      if metrics[:resource_efficiency] && metrics.resource_efficiency < 0.6 do
        [%{type: :efficiency, urgency: :medium, scope: :operational} | challenges]
      else
        challenges
      end

    challenges =
      if metrics[:innovation_lag] && metrics.innovation_lag > 0.8 do
        [%{type: :innovation, urgency: :low, scope: :strategic} | challenges]
      else
        challenges
      end

    challenges
  end

  defp monitor_adaptation_progress(adaptation) do
    # Simulate progress monitoring with error handling
    try do
      started_at = adaptation[:started_at] || DateTime.utc_now()
      elapsed = DateTime.diff(DateTime.utc_now(), started_at, :second)
      expected_duration = estimate_duration_seconds(adaptation[:timeline])

      # Protect against division by zero
      progress_percent = 
        if expected_duration > 0 do
          min(elapsed / expected_duration, 1.0)
        else
          # If no valid duration, use elapsed time heuristic
          min(elapsed / (30 * 24 * 60 * 60), 1.0)  # Default to 1 month
        end

      %{
        completed: progress_percent >= 0.9 && :rand.uniform() > 0.3,
        progress: progress_percent,
        success: true,
        metrics_impact: %{
          efficiency: 0.1 * progress_percent,
          effectiveness: 0.15 * progress_percent
        }
      }
    rescue
      e ->
        Logger.error("Error monitoring adaptation progress: #{inspect(e)}")
        # Return safe default
        %{
          completed: false,
          progress: 0.0,
          success: false,
          metrics_impact: %{efficiency: 0.0, effectiveness: 0.0}
        }
    end
  end

  defp estimate_duration_seconds(timeline) do
    case timeline do
      "1_month" -> 30 * 24 * 60 * 60
      "2_months" -> 60 * 24 * 60 * 60
      "3_months" -> 90 * 24 * 60 * 60
      "6_months" -> 180 * 24 * 60 * 60
      "2_weeks" -> 14 * 24 * 60 * 60
      "1_week" -> 7 * 24 * 60 * 60
      # Handle numeric values (assumed to be in seconds)
      n when is_number(n) and n > 0 -> n
      # Default to 1 month for any invalid input
      _ -> 30 * 24 * 60 * 60
    end
  end

  defp update_adaptation_metrics(metrics, progress) do
    if progress.success do
      %{
        metrics
        | success_rate: metrics.success_rate * 0.95 + 0.05,
          resource_efficiency:
            min(metrics.resource_efficiency + progress.metrics_impact.efficiency * 0.1, 1.0)
      }
    else
      %{metrics | success_rate: metrics.success_rate * 0.95}
    end
  end

  defp schedule_adaptation_monitoring(adaptation_id) do
    # Check every 10 seconds
    Process.send_after(self(), {:monitor_adaptation, adaptation_id}, 10_000)
  end
end
