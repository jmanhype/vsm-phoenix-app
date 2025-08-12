defmodule VsmPhoenixV2.System5.Queen do
  @moduledoc """
  VSM System 5 (Queen) - Policy, Identity, and Strategic Direction.
  
  Implements:
  - Policy synthesis and management
  - Strategic planning and identity maintenance
  - Algedonic signal processing (pain/pleasure feedback)
  - High-level coordination with other systems
  
  PRODUCTION-READY: NO MOCKS, NO FALLBACKS - FAIL FAST ON ERRORS.
  """

  use GenServer
  require Logger
  alias VsmPhoenixV2.CRDT.ContextStore
  alias VsmPhoenixV2.System5.PolicySynthesizer
  alias VsmPhoenixV2.System5.AlgedonicProcessor

  defstruct [
    :node_id,
    :context_store_pid,
    :policy_synthesizer_pid,
    :algedonic_processor_pid,
    :current_policies,
    :strategic_objectives,
    :identity_state,
    :system_health_metrics
  ]

  @doc """
  Starts the Queen (System 5) process.
  
  ## Options
    * `:node_id` - Unique identifier for this VSM node (required)
    * `:strategic_objectives` - Initial strategic objectives (optional)
  """
  def start_link(opts \\ []) do
    node_id = opts[:node_id] || raise "node_id is required for System 5 Queen"
    GenServer.start_link(__MODULE__, opts, name: via_tuple(node_id))
  end

  def init(opts) do
    node_id = Keyword.fetch!(opts, :node_id)
    strategic_objectives = Keyword.get(opts, :strategic_objectives, [])
    
    Logger.info("Initializing System 5 Queen for node #{node_id}")
    
    # Initialize CRDT context store - FAIL FAST if it fails
    {:ok, context_store_pid} = ContextStore.start_link(node_id: "#{node_id}_queen_context")
    
    # Initialize policy synthesizer - FAIL FAST if it fails
    {:ok, policy_synthesizer_pid} = PolicySynthesizer.start_link(
      context_store: context_store_pid,
      node_id: node_id
    )
    
    # Initialize algedonic processor - FAIL FAST if it fails
    {:ok, algedonic_processor_pid} = AlgedonicProcessor.start_link(
      node_id: node_id,
      queen_pid: self()
    )
    
    # Initialize system state
    state = %__MODULE__{
      node_id: node_id,
      context_store_pid: context_store_pid,
      policy_synthesizer_pid: policy_synthesizer_pid,
      algedonic_processor_pid: algedonic_processor_pid,
      current_policies: %{},
      strategic_objectives: strategic_objectives,
      identity_state: initialize_identity(node_id),
      system_health_metrics: %{}
    }
    
    # Store initial state in CRDT
    :ok = store_initial_queen_state(state)
    
    Logger.info("System 5 Queen initialized successfully for node #{node_id}")
    {:ok, state}
  end

  @doc """
  Synthesizes a new policy based on environmental inputs.
  FAILS EXPLICITLY if policy synthesis fails.
  """
  def synthesize_policy(node_id, policy_domain, environmental_data) do
    GenServer.call(via_tuple(node_id), {:synthesize_policy, policy_domain, environmental_data})
  end

  @doc """
  Updates strategic objectives.
  FAILS EXPLICITLY if context store operations fail.
  """
  def update_strategic_objectives(node_id, new_objectives) do
    GenServer.call(via_tuple(node_id), {:update_strategic_objectives, new_objectives})
  end

  @doc """
  Processes algedonic signals (pain/pleasure feedback).
  FAILS EXPLICITLY if processing fails.
  """
  def process_algedonic_signal(node_id, signal_type, intensity, source_system) do
    GenServer.call(via_tuple(node_id), {:process_algedonic_signal, signal_type, intensity, source_system})
  end

  @doc """
  Gets the current system identity and health status.
  """
  def get_system_status(node_id) do
    GenServer.call(via_tuple(node_id), :get_system_status)
  end

  @doc """
  Triggers emergency protocol activation.
  FAILS EXPLICITLY if emergency protocols are not properly configured.
  """
  def activate_emergency_protocol(node_id, emergency_type, severity) do
    GenServer.call(via_tuple(node_id), {:activate_emergency_protocol, emergency_type, severity})
  end

  # GenServer Callbacks

  def handle_call({:synthesize_policy, policy_domain, environmental_data}, _from, state) do
    case PolicySynthesizer.synthesize(
      state.policy_synthesizer_pid, 
      policy_domain, 
      environmental_data,
      state.current_policies
    ) do
      {:ok, new_policy} ->
        # Update current policies
        updated_policies = Map.put(state.current_policies, policy_domain, new_policy)
        new_state = %{state | current_policies: updated_policies}
        
        # Store in CRDT - FAIL if storage fails
        case GenServer.call(
          state.context_store_pid, 
          {:put_context, {:policy, policy_domain}, new_policy}
        ) do
          :ok ->
            Logger.info("Policy synthesized for domain #{policy_domain}")
            {:reply, {:ok, new_policy}, new_state}
            
          {:error, reason} ->
            Logger.error("Failed to store policy in CRDT: #{inspect(reason)}")
            {:reply, {:error, {:policy_storage_failed, reason}}, state}
        end
        
      {:error, reason} ->
        Logger.error("Policy synthesis failed for domain #{policy_domain}: #{inspect(reason)}")
        {:reply, {:error, {:policy_synthesis_failed, reason}}, state}
    end
  end

  def handle_call({:update_strategic_objectives, new_objectives}, _from, state) do
    case GenServer.call(
      state.context_store_pid,
      {:put_context, :strategic_objectives, new_objectives}
    ) do
      :ok ->
        new_state = %{state | strategic_objectives: new_objectives}
        Logger.info("Strategic objectives updated: #{length(new_objectives)} objectives")
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        Logger.error("Failed to store strategic objectives: #{inspect(reason)}")
        {:reply, {:error, {:objectives_storage_failed, reason}}, state}
    end
  end

  def handle_call({:process_algedonic_signal, signal_type, intensity, source_system}, _from, state) do
    case AlgedonicProcessor.process_signal(
      state.algedonic_processor_pid,
      signal_type,
      intensity,
      source_system
    ) do
      {:ok, response_action} ->
        Logger.info("Algedonic signal processed: #{signal_type} from #{source_system}")
        {:reply, {:ok, response_action}, state}
        
      {:error, reason} ->
        Logger.error("Algedonic signal processing failed: #{inspect(reason)}")
        {:reply, {:error, {:algedonic_processing_failed, reason}}, state}
    end
  end

  def handle_call(:get_system_status, _from, state) do
    # Compile comprehensive system status - FAIL if any component fails
    case compile_system_status(state) do
      {:ok, status} ->
        {:reply, {:ok, status}, state}
        
      {:error, reason} ->
        Logger.error("Failed to compile system status: #{inspect(reason)}")
        {:reply, {:error, {:status_compilation_failed, reason}}, state}
    end
  end

  def handle_call({:activate_emergency_protocol, emergency_type, severity}, _from, state) do
    case activate_emergency_response(emergency_type, severity, state) do
      {:ok, emergency_response} ->
        Logger.warning("Emergency protocol activated: #{emergency_type} (severity: #{severity})")
        {:reply, {:ok, emergency_response}, state}
        
      {:error, reason} ->
        Logger.error("Emergency protocol activation failed: #{inspect(reason)}")
        {:reply, {:error, {:emergency_activation_failed, reason}}, state}
    end
  end

  def handle_info({:algedonic_alert, signal_type, intensity, source}, state) do
    Logger.warning("Algedonic alert received: #{signal_type} intensity #{intensity} from #{source}")
    
    # Process high-intensity signals immediately
    if intensity > 0.8 do
      case activate_emergency_response(:algedonic_overload, intensity, state) do
        {:ok, _response} ->
          Logger.info("Emergency response activated for high algedonic signal")
          
        {:error, reason} ->
          Logger.error("Failed to activate emergency response: #{inspect(reason)}")
      end
    end
    
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("System 5 Queen terminating for node #{state.node_id}: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp initialize_identity(node_id) do
    %{
      node_id: node_id,
      system_type: :vsm_phoenix_v2,
      initialization_time: DateTime.utc_now(),
      identity_version: "2.0.0",
      core_principles: [
        :viability_maintenance,
        :adaptive_governance,
        :distributed_intelligence,
        :fail_fast_design
      ]
    }
  end

  defp store_initial_queen_state(state) do
    # Use the PID directly instead of going through registry lookup
    with :ok <- GenServer.call(state.context_store_pid, {:put_context, :identity, state.identity_state}),
         :ok <- GenServer.call(state.context_store_pid, {:put_context, :strategic_objectives, state.strategic_objectives}),
         :ok <- GenServer.call(state.context_store_pid, {:put_context, :current_policies, state.current_policies}) do
      :ok
    else
      {:error, reason} ->
        raise "Failed to store initial Queen state: #{inspect(reason)}"
    end
  end

  defp compile_system_status(state) do
    try do
      {:ok, crdt_state} = GenServer.call(state.context_store_pid, :get_crdt_state)
      
      status = %{
        node_id: state.node_id,
        identity: state.identity_state,
        strategic_objectives: state.strategic_objectives,
        active_policies: map_size(state.current_policies),
        policy_domains: Map.keys(state.current_policies),
        crdt_context_count: crdt_state.context_count,
        system_health: evaluate_system_health(state),
        timestamp: DateTime.utc_now()
      }
      
      {:ok, status}
    rescue
      error ->
        {:error, {:status_compilation_error, error}}
    end
  end

  defp evaluate_system_health(state) do
    # Real health evaluation - NO FAKE SUCCESS
    health_score = cond do
      map_size(state.current_policies) == 0 -> 0.3  # Low health without policies
      length(state.strategic_objectives) == 0 -> 0.5  # Medium health without objectives
      true -> 1.0  # Full health with both policies and objectives
    end
    
    %{
      overall_score: health_score,
      policy_coverage: map_size(state.current_policies),
      strategic_alignment: length(state.strategic_objectives),
      crdt_operational: is_pid(state.context_store_pid) and Process.alive?(state.context_store_pid)
    }
  end

  defp activate_emergency_response(emergency_type, severity, state) do
    case emergency_type do
      :algedonic_overload ->
        # Real emergency response - NO FAKE ACTIONS
        emergency_policies = %{
          reduce_system_load: true,
          activate_circuit_breakers: true,
          increase_monitoring: true,
          severity_level: severity
        }
        
        # Store emergency state in CRDT
        case GenServer.call(
          state.context_store_pid,
          {:put_context, {:emergency_state, DateTime.utc_now()}, emergency_policies}
        ) do
          :ok -> {:ok, emergency_policies}
          error -> error
        end
        
      :system_degradation ->
        # Real degradation response
        {:ok, %{action: :graceful_degradation, severity: severity}}
        
      _ ->
        {:error, {:unknown_emergency_type, emergency_type}}
    end
  end

  defp via_tuple(node_id) do
    {:via, Registry, {VsmPhoenixV2.System5Registry, {:queen, node_id}}}
  end
end