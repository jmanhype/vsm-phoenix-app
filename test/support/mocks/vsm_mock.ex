defmodule VsmPhoenix.Mocks.VSMMock do
  @moduledoc """
  Mock implementations for VSM system components during testing.
  """
  
  use GenServer
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_system_status(system) do
    GenServer.call(__MODULE__, {:get_system_status, system})
  end
  
  def set_system_status(system, status) do
    GenServer.call(__MODULE__, {:set_system_status, system, status})
  end
  
  def get_viability_score do
    GenServer.call(__MODULE__, :get_viability_score)
  end
  
  def set_viability_score(score) do
    GenServer.call(__MODULE__, {:set_viability_score, score})
  end
  
  def get_variety_level(system) do
    GenServer.call(__MODULE__, {:get_variety_level, system})
  end
  
  def set_variety_level(system, level) do
    GenServer.call(__MODULE__, {:set_variety_level, system, level})
  end
  
  def simulate_system_failure(system) do
    GenServer.call(__MODULE__, {:simulate_failure, system})
  end
  
  def simulate_system_recovery(system) do
    GenServer.call(__MODULE__, {:simulate_recovery, system})
  end
  
  def reset_all_systems do
    GenServer.call(__MODULE__, :reset_all_systems)
  end
  
  def get_active_agents(system) do
    GenServer.call(__MODULE__, {:get_active_agents, system})
  end
  
  def set_active_agents(system, count) do
    GenServer.call(__MODULE__, {:set_active_agents, system, count})
  end
  
  # Mock VSM System Operations
  
  def system1_operation(operation_type, params \\ %{}) do
    case operation_type do
      :health_check ->
        {:ok, %{status: :healthy, response_time: 50}}
      
      :execute_command ->
        command = Map.get(params, :command, "unknown")
        {:ok, %{command: command, result: "executed", duration: 100}}
      
      :spawn_agent ->
        agent_id = Ecto.UUID.generate()
        {:ok, %{agent_id: agent_id, type: Map.get(params, :type, "worker")}}
      
      _ ->
        {:error, :unknown_operation}
    end
  end
  
  def system2_coordination(action, params \\ %{}) do
    case action do
      :sync_check ->
        {:ok, %{synchronized: true, latency: 25}}
      
      :detect_oscillation ->
        {:ok, %{oscillation_detected: false, frequency: 0}}
      
      :coordinate_systems ->
        systems = Map.get(params, :systems, [1, 2, 3, 4, 5])
        {:ok, %{coordinated_systems: systems, status: :coordinated}}
      
      _ ->
        {:error, :unknown_action}
    end
  end
  
  def system3_control(control_type, params \\ %{}) do
    case control_type do
      :optimize_resources ->
        {:ok, %{optimization: %{cpu: 0.75, memory: 0.80, network: 0.60}}}
      
      :audit_bypass ->
        target = Map.get(params, :target, "system1")
        {:ok, %{audit_result: %{target: target, status: :inspected, findings: []}}}
      
      :performance_monitoring ->
        {:ok, %{metrics: %{throughput: 1200, latency: 150, errors: 2}}}
      
      _ ->
        {:error, :unknown_control_type}
    end
  end
  
  def system4_intelligence(intelligence_type, params \\ %{}) do
    case intelligence_type do
      :scan_environment ->
        {:ok, %{scan_result: %{complexity: 0.75, new_patterns: 3, adaptation_needed: true}}}
      
      :detect_variety ->
        {:ok, %{variety_detected: true, level: 4, source: "external_api"}}
      
      :adapt_system ->
        adaptation = Map.get(params, :adaptation, %{})
        {:ok, %{adaptation_applied: adaptation, success: true}}
      
      _ ->
        {:error, :unknown_intelligence_type}
    end
  end
  
  def system5_policy(policy_action, params \\ %{}) do
    case policy_action do
      :evaluate_viability ->
        {:ok, %{viability_score: 0.85, threshold_met: true, action_required: false}}
      
      :synthesize_policy ->
        context = Map.get(params, :context, %{})
        {:ok, %{policy: "Increase resilience by 15%", confidence: 0.92, context: context}}
      
      :make_decision ->
        decision_type = Map.get(params, :type, "resource_allocation")
        {:ok, %{decision: decision_type, outcome: "approved", reasoning: "Optimal configuration"}}
      
      _ ->
        {:error, :unknown_policy_action}
    end
  end
  
  # GenServer Implementation
  
  @impl true
  def init(_opts) do
    initial_state = %{
      systems: %{
        1 => %{status: :healthy, variety_level: 2, active_agents: 5},
        2 => %{status: :healthy, variety_level: 1, active_agents: 3},
        3 => %{status: :healthy, variety_level: 3, active_agents: 4},
        4 => %{status: :healthy, variety_level: 4, active_agents: 2},
        5 => %{status: :healthy, variety_level: 2, active_agents: 1}
      },
      viability_score: 0.85,
      events: [],
      failures: MapSet.new()
    }
    {:ok, initial_state}
  end
  
  @impl true
  def handle_call({:get_system_status, system}, _from, state) do
    status = get_in(state.systems, [system, :status]) || :unknown
    {:reply, status, state}
  end
  
  @impl true
  def handle_call({:set_system_status, system, status}, _from, state) do
    new_state = put_in(state.systems[system][:status], status)
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_viability_score, _from, state) do
    {:reply, state.viability_score, state}
  end
  
  @impl true
  def handle_call({:set_viability_score, score}, _from, state) do
    new_state = %{state | viability_score: score}
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:get_variety_level, system}, _from, state) do
    level = get_in(state.systems, [system, :variety_level]) || 0
    {:reply, level, state}
  end
  
  @impl true
  def handle_call({:set_variety_level, system, level}, _from, state) do
    new_state = put_in(state.systems[system][:variety_level], level)
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:simulate_failure, system}, _from, state) do
    new_state = 
      state
      |> put_in([:systems, system, :status], :failed)
      |> Map.put(:failures, MapSet.put(state.failures, system))
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:simulate_recovery, system}, _from, state) do
    new_state = 
      state
      |> put_in([:systems, system, :status], :healthy)
      |> Map.put(:failures, MapSet.delete(state.failures, system))
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:reset_all_systems, _from, _state) do
    {:ok, new_state} = init([])
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:get_active_agents, system}, _from, state) do
    count = get_in(state.systems, [system, :active_agents]) || 0
    {:reply, count, state}
  end
  
  @impl true
  def handle_call({:set_active_agents, system, count}, _from, state) do
    new_state = put_in(state.systems[system][:active_agents], count)
    {:reply, :ok, new_state}
  end
end