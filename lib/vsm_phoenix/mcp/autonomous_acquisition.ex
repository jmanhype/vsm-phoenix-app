defmodule VsmPhoenix.MCP.AutonomousAcquisition do
  @moduledoc """
  Autonomous decision-making system for MCP server acquisition.
  Implements cybernetic control principles for variety management.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.MCP.{CapabilityAnalyzer, MCPRegistry, IntegrationEngine}
  alias VsmPhoenix.System1
  alias VsmPhoenix.System2
  alias VsmPhoenix.System3

  @acquisition_threshold 0.7  # Minimum score to acquire
  @learning_rate 0.1         # How fast we adapt decisions
  @scan_interval 30_000      # Scan for gaps every 30 seconds

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Evaluate if a capability should be acquired based on cybernetic principles.
  """
  def should_acquire?(capability, context) do
    GenServer.call(__MODULE__, {:should_acquire, capability, context})
  end

  @doc """
  Perform cost-benefit analysis for acquiring an MCP server.
  """
  def evaluate_cost_benefit(server) do
    GenServer.call(__MODULE__, {:evaluate_cost_benefit, server})
  end

  @doc """
  Start the autonomous acquisition loop.
  """
  def start_acquisition_loop do
    GenServer.cast(__MODULE__, :start_loop)
  end

  @doc """
  Integrate a new capability into the VSM hierarchy.
  """
  def integrate_capability(server) do
    GenServer.call(__MODULE__, {:integrate_capability, server})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      acquisition_history: [],
      decision_weights: default_weights(),
      active_capabilities: %{},
      variety_gaps: [],
      learning_memory: %{}
    }

    # Schedule the first scan
    Process.send_after(self(), :scan_variety_gaps, 1000)

    {:ok, state}
  end

  @impl true
  def handle_call({:should_acquire, capability, context}, _from, state) do
    # Apply cybernetic decision logic
    decision = evaluate_acquisition_decision(capability, context, state)
    
    # Learn from the decision
    new_state = update_learning_memory(state, capability, decision)
    
    {:reply, decision, new_state}
  end

  @impl true
  def handle_call({:evaluate_cost_benefit, server}, _from, state) do
    analysis = %{
      # Variety contribution - how much it reduces uncertainty
      variety_contribution: calculate_variety_contribution(server, state),
      
      # Integration complexity - how hard to integrate
      integration_cost: estimate_integration_cost(server),
      
      # Operational overhead - ongoing maintenance
      operational_cost: estimate_operational_cost(server),
      
      # Strategic value - long-term benefits
      strategic_value: calculate_strategic_value(server, state),
      
      # Risk assessment
      risk_factor: assess_risk(server)
    }
    
    # Calculate final score using weighted factors
    score = calculate_acquisition_score(analysis, state.decision_weights)
    
    result = %{
      analysis: analysis,
      score: score,
      recommendation: score > @acquisition_threshold,
      reasoning: generate_reasoning(analysis, score)
    }
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:integrate_capability, server}, _from, state) do
    case perform_integration(server, state) do
      {:ok, integration_result} ->
        new_state = %{state |
          active_capabilities: Map.put(state.active_capabilities, server.id, integration_result),
          acquisition_history: [{server, DateTime.utc_now(), :success} | state.acquisition_history]
        }
        {:reply, {:ok, integration_result}, new_state}
        
      {:error, reason} ->
        new_state = %{state |
          acquisition_history: [{server, DateTime.utc_now(), {:error, reason}} | state.acquisition_history]
        }
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_cast(:start_loop, state) do
    # Main autonomous loop is driven by periodic messages
    Logger.info("Autonomous acquisition loop started")
    {:noreply, state}
  end

  @impl true
  def handle_info(:scan_variety_gaps, state) do
    # Scan for variety gaps
    gaps = identify_variety_gaps(state)
    
    # For each gap, find potential solutions
    acquisitions = Enum.flat_map(gaps, fn gap ->
      find_capability_solutions(gap, state)
    end)
    
    # Make autonomous decisions
    new_state = Enum.reduce(acquisitions, state, fn {gap, server}, acc_state ->
      if should_acquire_autonomously?(gap, server, acc_state) do
        case integrate_capability(server) do
          {:ok, _} ->
            Logger.info("Autonomously acquired #{server.id} to address #{gap.type}")
            record_successful_acquisition(acc_state, gap, server)
            
          {:error, reason} ->
            Logger.warning("Failed to acquire #{server.id}: #{reason}")
            record_failed_acquisition(acc_state, gap, server, reason)
        end
      else
        acc_state
      end
    end)
    
    # Schedule next scan
    Process.send_after(self(), :scan_variety_gaps, @scan_interval)
    
    {:noreply, new_state}
  end

  # Private Functions

  defp default_weights do
    %{
      variety_contribution: 0.3,
      integration_cost: -0.2,
      operational_cost: -0.1,
      strategic_value: 0.25,
      risk_factor: -0.15
    }
  end

  defp evaluate_acquisition_decision(capability, context, state) do
    # Check if we already have this capability
    if Map.has_key?(state.active_capabilities, capability.id) do
      {:already_acquired, false}
    else
      # Check variety gap match
      gap_match = find_matching_gap(capability, state.variety_gaps)
      
      # Check resource constraints
      resources_available = check_resources(context)
      
      # Apply learning from past decisions
      historical_success = get_historical_success_rate(capability, state)
      
      # Make decision
      decision_score = calculate_decision_score(gap_match, resources_available, historical_success)
      
      {decision_score > @acquisition_threshold, decision_score}
    end
  end

  defp calculate_variety_contribution(server, state) do
    # How many variety gaps does this server address?
    addressed_gaps = Enum.count(state.variety_gaps, fn gap ->
      server_addresses_gap?(server, gap)
    end)
    
    # Normalize by total gaps
    total_gaps = length(state.variety_gaps)
    if total_gaps > 0, do: addressed_gaps / total_gaps, else: 0
  end

  defp estimate_integration_cost(server) do
    # Base cost factors
    factors = %{
      dependencies: length(Map.get(server, :dependencies, [])) * 0.1,
      complexity: estimate_complexity(server),
      compatibility: estimate_compatibility(server)
    }
    
    # Sum weighted factors
    Enum.reduce(factors, 0, fn {_key, value}, acc -> acc + value end) / map_size(factors)
  end

  defp estimate_operational_cost(server) do
    # Estimate ongoing operational overhead
    %{
      memory_usage: estimate_memory_usage(server),
      cpu_usage: estimate_cpu_usage(server),
      maintenance_burden: estimate_maintenance(server)
    }
    |> Map.values()
    |> Enum.sum()
    |> (fn sum -> sum / 3 end).()
  end

  defp calculate_strategic_value(server, state) do
    # Long-term strategic considerations
    %{
      future_extensibility: rate_extensibility(server),
      ecosystem_fit: rate_ecosystem_fit(server, state),
      innovation_potential: rate_innovation_potential(server)
    }
    |> Map.values()
    |> Enum.sum()
    |> (fn sum -> sum / 3 end).()
  end

  defp assess_risk(server) do
    # Risk factors
    %{
      security_risk: assess_security_risk(server),
      stability_risk: assess_stability_risk(server),
      vendor_lock_in: assess_vendor_lock_in(server)
    }
    |> Map.values()
    |> Enum.sum()
    |> (fn sum -> sum / 3 end).()
  end

  defp calculate_acquisition_score(analysis, weights) do
    Enum.reduce(analysis, 0, fn {factor, value}, acc ->
      weight = Map.get(weights, factor, 0)
      acc + (value * weight)
    end)
  end

  defp generate_reasoning(analysis, score) do
    factors = analysis
    |> Enum.map(fn {k, v} -> "#{k}: #{Float.round(v, 2)}" end)
    |> Enum.join(", ")
    
    "Acquisition score: #{Float.round(score, 2)}. Factors: #{factors}"
  end

  defp identify_variety_gaps(_state) do
    # For now, return simulated gaps until Systems are properly integrated
    # TODO: Integrate with actual System modules when their APIs are complete
    
    operational_gaps = [
      %{type: "data_processing", priority: :high, source: :system1, required_capability: "data_processing"},
      %{type: "api_integration", priority: :medium, source: :system1, required_capability: "api_integration"}
    ]
    
    coordination_gaps = [
      %{type: "cross_context_messaging", priority: :medium, source: :system2, required_capability: "cross_context_messaging"}
    ]
    
    optimization_gaps = [
      %{type: "resource_allocation", priority: :low, source: :system3, required_capability: "resource_allocation"}
    ]
    
    # Combine and prioritize
    (operational_gaps ++ coordination_gaps ++ optimization_gaps)
    |> Enum.uniq_by(& &1.type)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  defp find_capability_solutions(gap, _state) do
    # Search MCP registry for servers that can address this gap
    MCPRegistry.search_by_capability(gap.required_capability)
    |> Enum.map(fn server -> {gap, server} end)
  end

  defp should_acquire_autonomously?(gap, server, state) do
    # Autonomous decision criteria
    criteria = %{
      gap_severity: gap.severity > 0.7,
      server_reliability: server_reliability_score(server, state) > 0.8,
      no_conflicts: !has_conflicts?(server, state.active_capabilities),
      resources_available: has_sufficient_resources?(server),
      learning_indicates_success: predict_success(gap, server, state) > 0.75
    }
    
    # All criteria must be met for autonomous acquisition
    Enum.all?(criteria, fn {_criterion, met?} -> met? end)
  end

  defp perform_integration(server, state) do
    # Use the integration engine to safely integrate the capability
    with {:ok, validated} <- IntegrationEngine.validate_server(server),
         {:ok, installed} <- IntegrationEngine.install_server(validated),
         {:ok, integrated} <- IntegrationEngine.integrate_with_vsm(installed, state) do
      {:ok, integrated}
    end
  end

  defp update_learning_memory(state, capability, decision) do
    # Update learning memory with decision outcome
    memory_key = capability_memory_key(capability)
    
    updated_memory = Map.update(
      state.learning_memory,
      memory_key,
      %{decisions: [decision], success_rate: 0},
      fn existing ->
        %{existing |
          decisions: [decision | existing.decisions],
          success_rate: calculate_success_rate([decision | existing.decisions])
        }
      end
    )
    
    %{state | learning_memory: updated_memory}
  end

  defp record_successful_acquisition(state, gap, server) do
    # Update weights based on success
    new_weights = adjust_weights_for_success(state.decision_weights, gap, server)
    
    %{state |
      decision_weights: new_weights,
      variety_gaps: Enum.reject(state.variety_gaps, & &1.id == gap.id)
    }
  end

  defp record_failed_acquisition(state, gap, server, reason) do
    # Update weights based on failure
    new_weights = adjust_weights_for_failure(state.decision_weights, gap, server, reason)
    
    %{state | decision_weights: new_weights}
  end

  defp adjust_weights_for_success(weights, _gap, _server) do
    # Reinforce successful decision patterns
    Map.new(weights, fn {factor, weight} ->
      {factor, weight + @learning_rate * 0.1}
    end)
  end

  defp adjust_weights_for_failure(weights, _gap, _server, _reason) do
    # Adjust weights to avoid similar failures
    Map.new(weights, fn {factor, weight} ->
      {factor, weight - @learning_rate * 0.05}
    end)
  end

  # Helper functions (simplified implementations)

  defp server_addresses_gap?(server, gap) do
    Enum.any?(server.capabilities, fn cap ->
      cap.type == gap.required_capability
    end)
  end

  defp estimate_complexity(server) do
    # Simplified complexity estimation
    length(Map.get(server, :capabilities, [])) * 0.1
  end

  defp estimate_compatibility(_server), do: 0.8
  defp estimate_memory_usage(_server), do: 0.2
  defp estimate_cpu_usage(_server), do: 0.1
  defp estimate_maintenance(_server), do: 0.15
  defp rate_extensibility(_server), do: 0.7
  defp rate_ecosystem_fit(_server, _state), do: 0.8
  defp rate_innovation_potential(_server), do: 0.6
  defp assess_security_risk(_server), do: 0.1
  defp assess_stability_risk(_server), do: 0.15
  defp assess_vendor_lock_in(_server), do: 0.2

  defp find_matching_gap(capability, gaps) do
    Enum.find(gaps, fn gap ->
      gap.required_capability == capability.type
    end)
  end

  defp check_resources(_context), do: true

  defp get_historical_success_rate(capability, state) do
    memory_key = capability_memory_key(capability)
    
    case Map.get(state.learning_memory, memory_key) do
      nil -> 0.5  # No history, neutral
      %{success_rate: rate} -> rate
    end
  end

  defp calculate_decision_score(gap_match, resources_available, historical_success) do
    gap_score = if gap_match, do: 0.4, else: 0
    resource_score = if resources_available, do: 0.3, else: 0
    history_score = historical_success * 0.3
    
    gap_score + resource_score + history_score
  end

  defp capability_memory_key(capability) do
    "capability:#{capability.type}:#{capability.id}"
  end

  defp calculate_success_rate(decisions) do
    successful = Enum.count(decisions, fn {outcome, _} -> outcome == :success end)
    total = length(decisions)
    
    if total > 0, do: successful / total, else: 0
  end

  defp server_reliability_score(_server, _state), do: 0.85
  defp has_conflicts?(_server, _active_capabilities), do: false
  defp has_sufficient_resources?(_server), do: true

  defp predict_success(_gap, _server, state) do
    # Use historical data to predict success probability
    # Simplified: return average success rate
    if map_size(state.learning_memory) > 0 do
      state.learning_memory
      |> Map.values()
      |> Enum.map(& &1.success_rate)
      |> Enum.sum()
      |> (fn sum -> sum / map_size(state.learning_memory) end).()
    else
      0.8  # Optimistic default
    end
  end
end