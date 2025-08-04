defmodule VsmPhoenix.QuantumVariety.QuantumVarietyManager do
  @moduledoc """
  Main Quantum Variety Manager for VSM Phoenix.
  
  Integrates quantum concepts into the Viable System Model's variety engineering:
  - Superposition: Messages exist in multiple states simultaneously
  - Entanglement: Creates instantaneous correlations between variety flows
  - Tunneling: Emergency bypass for critical messages
  - Collapse: Observation causes definite state selection
  
  This creates a quantum-enhanced variety management system that can handle
  complex, non-deterministic variety requirements with quantum mechanical principles.
  """

  use GenServer
  require Logger
  
  alias VsmPhoenix.QuantumVariety.{
    QuantumState,
    EntanglementManager,
    QuantumTunnel,
    WaveFunction
  }

  @type quantum_variety :: %{
    id: String.t(),
    classical_variety: map(),
    quantum_states: list(String.t()),
    entanglements: list(String.t()),
    tunnels: list(String.t()),
    wave_functions: list(String.t()),
    metadata: map()
  }

  @type quantum_message :: %{
    id: String.t(),
    content: any(),
    superposition_states: list(any()),
    entangled_with: list(String.t()),
    priority: atom(),
    quantum_properties: map()
  }

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a quantum-enhanced variety flow.
  """
  def create_quantum_variety(classical_variety, quantum_config \\ %{}) do
    GenServer.call(__MODULE__, {:create_quantum_variety, classical_variety, quantum_config})
  end

  @doc """
  Sends a message with quantum properties through the variety system.
  """
  def send_quantum_message(message, options \\ []) do
    GenServer.call(__MODULE__, {:send_quantum_message, message, options})
  end

  @doc """
  Observes a quantum message, causing wave function collapse.
  """
  def observe_message(message_id) do
    GenServer.call(__MODULE__, {:observe_message, message_id})
  end

  @doc """
  Creates quantum entanglement between variety flows.
  """
  def entangle_varieties(variety1_id, variety2_id) do
    GenServer.call(__MODULE__, {:entangle_varieties, variety1_id, variety2_id})
  end

  @doc """
  Creates emergency quantum tunnel for critical messages.
  """
  def create_emergency_tunnel(source, target) do
    GenServer.call(__MODULE__, {:create_emergency_tunnel, source, target})
  end

  @doc """
  Gets the quantum state of the variety system.
  """
  def get_quantum_state do
    GenServer.call(__MODULE__, :get_quantum_state)
  end

  @doc """
  Performs quantum measurement on the variety system.
  """
  def measure_variety(measurement_type \\ :full) do
    GenServer.call(__MODULE__, {:measure_variety, measurement_type})
  end

  ## GenServer Callbacks

  def init(opts) do
    # Start quantum subsystems
    {:ok, _} = QuantumState.start_link()
    {:ok, _} = EntanglementManager.start_link()
    {:ok, _} = QuantumTunnel.start_link()
    {:ok, _} = WaveFunction.start_link()
    
    # Subscribe to quantum events
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "quantum:tunneling")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "quantum:collapse")
    
    # Schedule periodic quantum operations
    schedule_quantum_maintenance()
    
    state = %{
      quantum_varieties: %{},
      quantum_messages: %{},
      active_superpositions: [],
      active_entanglements: [],
      active_tunnels: [],
      measurement_history: [],
      quantum_config: parse_quantum_config(opts),
      stats: %{
        total_quantum_messages: 0,
        total_collapses: 0,
        total_entanglements: 0,
        total_tunnels: 0,
        quantum_efficiency: 1.0
      }
    }
    
    Logger.info("⚛️ Quantum Variety Manager initialized")
    {:ok, state}
  end

  def handle_call({:create_quantum_variety, classical_variety, quantum_config}, _from, state) do
    case create_quantum_enhanced_variety(classical_variety, quantum_config, state) do
      {:ok, quantum_variety, new_state} ->
        {:reply, {:ok, quantum_variety}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:send_quantum_message, message, options}, _from, state) do
    case process_quantum_message(message, options, state) do
      {:ok, quantum_message, new_state} ->
        {:reply, {:ok, quantum_message}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:observe_message, message_id}, _from, state) do
    case observe_and_collapse(message_id, state) do
      {:ok, collapsed_state, new_state} ->
        {:reply, {:ok, collapsed_state}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:entangle_varieties, variety1_id, variety2_id}, _from, state) do
    case create_variety_entanglement(variety1_id, variety2_id, state) do
      {:ok, entanglement, new_state} ->
        {:reply, {:ok, entanglement}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:create_emergency_tunnel, source, target}, _from, state) do
    case establish_emergency_tunnel(source, target, state) do
      {:ok, tunnel, new_state} ->
        {:reply, {:ok, tunnel}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_quantum_state, _from, state) do
    quantum_state_summary = summarize_quantum_state(state)
    {:reply, {:ok, quantum_state_summary}, state}
  end

  def handle_call({:measure_variety, measurement_type}, _from, state) do
    case perform_variety_measurement(measurement_type, state) do
      {:ok, measurement_result, new_state} ->
        {:reply, {:ok, measurement_result}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info({:tunneled_message, message, priority}, state) do
    # Handle message that came through quantum tunnel
    new_state = handle_tunneled_message(message, priority, state)
    {:noreply, new_state}
  end

  def handle_info({:wave_function_collapsed, wf_id, collapsed_state}, state) do
    # Handle wave function collapse notification
    new_state = handle_wave_collapse(wf_id, collapsed_state, state)
    {:noreply, new_state}
  end

  def handle_info(:quantum_maintenance, state) do
    new_state = perform_quantum_maintenance(state)
    schedule_quantum_maintenance()
    {:noreply, new_state}
  end

  ## Private Functions

  defp create_quantum_enhanced_variety(classical_variety, quantum_config, state) do
    id = generate_quantum_variety_id()
    
    # Create superposition of variety states
    possible_states = generate_variety_states(classical_variety)
    {:ok, quantum_state} = QuantumState.create_superposition(
      classical_variety,
      possible_states
    )
    
    # Create wave function for variety
    {:ok, wave_function} = WaveFunction.create_wave_function(
      possible_states,
      nil  # Equal superposition initially
    )
    
    quantum_variety = %{
      id: id,
      classical_variety: classical_variety,
      quantum_states: [quantum_state.id],
      entanglements: [],
      tunnels: [],
      wave_functions: [wave_function.id],
      created_at: DateTime.utc_now(),
      metadata: Map.merge(quantum_config, %{
        coherence: 1.0,
        fidelity: 1.0,
        collapsed: false
      })
    }
    
    new_state = state
    |> put_in([:quantum_varieties, id], quantum_variety)
    |> update_in([:active_superpositions], &([quantum_state.id | &1]))
    
    Logger.info("⚛️ Created quantum variety #{id} with #{length(possible_states)} superposition states")
    {:ok, quantum_variety, new_state}
  end

  defp process_quantum_message(message, options, state) do
    id = generate_quantum_message_id()
    priority = Keyword.get(options, :priority, :normal)
    
    # Determine if message needs quantum properties
    quantum_properties = determine_quantum_properties(message, priority)
    
    # Create superposition if needed
    superposition_states = if quantum_properties.use_superposition do
      generate_message_superpositions(message)
    else
      [message]
    end
    
    {:ok, quantum_state} = QuantumState.create_superposition(
      message,
      superposition_states
    )
    
    quantum_message = %{
      id: id,
      content: message,
      superposition_states: superposition_states,
      quantum_state_id: quantum_state.id,
      entangled_with: [],
      priority: priority,
      quantum_properties: quantum_properties,
      created_at: DateTime.utc_now(),
      metadata: %{
        collapsed: false,
        tunneled: false,
        observations: 0
      }
    }
    
    # Check if emergency tunneling needed
    new_state = if priority == :critical and quantum_properties.use_tunneling do
      case QuantumTunnel.emergency_tunnel(message, options[:target]) do
        {:ok, tunnel_event} ->
          Logger.warn("🆘 Emergency tunneled message #{id}")
          
          state
          |> put_in([:quantum_messages, id], %{quantum_message | 
              metadata: Map.put(quantum_message.metadata, :tunneled, true)
            })
          |> update_in([:stats, :total_tunnels], &(&1 + 1))
        
        _ -> 
          put_in(state, [:quantum_messages, id], quantum_message)
      end
    else
      # Normal quantum processing
      process_normal_quantum_message(quantum_message, state)
    end
    
    final_state = update_in(new_state, [:stats, :total_quantum_messages], &(&1 + 1))
    
    {:ok, quantum_message, final_state}
  end

  defp process_normal_quantum_message(quantum_message, state) do
    # Check for entanglement opportunities
    entangled_messages = find_entanglement_candidates(quantum_message, state)
    
    updated_message = if length(entangled_messages) > 0 do
      # Create entanglements
      Enum.reduce(entangled_messages, quantum_message, fn other_id, acc ->
        case EntanglementManager.create_bell_pair(
          quantum_message.quantum_state_id,
          other_id
        ) do
          {:ok, _bell_pair} ->
            %{acc | entangled_with: [other_id | acc.entangled_with]}
          _ ->
            acc
        end
      end)
    else
      quantum_message
    end
    
    put_in(state, [:quantum_messages, quantum_message.id], updated_message)
  end

  defp observe_and_collapse(message_id, state) do
    case get_in(state.quantum_messages, [message_id]) do
      nil ->
        {:error, :message_not_found}
      
      quantum_message ->
        if quantum_message.metadata.collapsed do
          {:ok, quantum_message.content, state}
        else
          # Perform measurement to collapse superposition
          {:ok, collapsed} = QuantumState.measure(
            quantum_message.quantum_state_id,
            :computational
          )
          
          # Update message with collapsed state
          updated_message = %{quantum_message |
            content: collapsed,
            metadata: quantum_message.metadata
            |> Map.put(:collapsed, true)
            |> Map.put(:collapse_time, DateTime.utc_now())
            |> Map.update(:observations, 1, &(&1 + 1))
          }
          
          new_state = state
          |> put_in([:quantum_messages, message_id], updated_message)
          |> update_in([:measurement_history], &([{message_id, collapsed, DateTime.utc_now()} | &1]))
          |> update_in([:stats, :total_collapses], &(&1 + 1))
          
          # Notify entangled messages
          notify_entangled_collapse(quantum_message.entangled_with, collapsed)
          
          Logger.info("📏 Observed message #{message_id}: collapsed to #{inspect(collapsed)}")
          {:ok, collapsed, new_state}
        end
    end
  end

  defp create_variety_entanglement(variety1_id, variety2_id, state) do
    with {:ok, variety1} <- get_quantum_variety(variety1_id, state),
         {:ok, variety2} <- get_quantum_variety(variety2_id, state) do
      
      # Get primary quantum states
      state1_id = List.first(variety1.quantum_states)
      state2_id = List.first(variety2.quantum_states)
      
      # Create entanglement
      case EntanglementManager.create_bell_pair(state1_id, state2_id) do
        {:ok, bell_pair} ->
          # Update varieties with entanglement info
          updated_variety1 = %{variety1 |
            entanglements: [bell_pair.id | variety1.entanglements]
          }
          
          updated_variety2 = %{variety2 |
            entanglements: [bell_pair.id | variety2.entanglements]
          }
          
          new_state = state
          |> put_in([:quantum_varieties, variety1_id], updated_variety1)
          |> put_in([:quantum_varieties, variety2_id], updated_variety2)
          |> update_in([:active_entanglements], &([bell_pair.id | &1]))
          |> update_in([:stats, :total_entanglements], &(&1 + 1))
          
          Logger.info("🔗 Entangled varieties #{variety1_id} <-> #{variety2_id}")
          {:ok, bell_pair, new_state}
        
        error -> error
      end
    else
      _ -> {:error, :variety_not_found}
    end
  end

  defp establish_emergency_tunnel(source, target, state) do
    case QuantumTunnel.create_tunnel(source, target, 2.0) do
      {:ok, tunnel} ->
        new_state = update_in(state, [:active_tunnels], &([tunnel.id | &1]))
        
        Logger.warn("🌌 Created emergency tunnel: #{source} -> #{target}")
        {:ok, tunnel, new_state}
      
      error -> error
    end
  end

  defp summarize_quantum_state(state) do
    %{
      total_varieties: map_size(state.quantum_varieties),
      total_messages: map_size(state.quantum_messages),
      active_superpositions: length(state.active_superpositions),
      active_entanglements: length(state.active_entanglements),
      active_tunnels: length(state.active_tunnels),
      uncollapsed_messages: count_uncollapsed_messages(state),
      quantum_efficiency: calculate_quantum_efficiency(state),
      stats: state.stats
    }
  end

  defp perform_variety_measurement(measurement_type, state) do
    case measurement_type do
      :full ->
        # Collapse all superpositions
        collapsed_states = state.quantum_messages
        |> Enum.filter(fn {_id, msg} -> not msg.metadata.collapsed end)
        |> Enum.map(fn {id, _msg} ->
          {:ok, collapsed, _} = observe_and_collapse(id, state)
          {id, collapsed}
        end)
        
        {:ok, %{type: :full, collapsed: collapsed_states}, state}
      
      :weak ->
        # Perform weak measurements without full collapse
        weak_results = state.active_superpositions
        |> Enum.take(5)  # Sample a few
        |> Enum.map(fn state_id ->
          {:ok, result} = WaveFunction.weak_measure(state_id, 0.1)
          {state_id, result}
        end)
        
        {:ok, %{type: :weak, results: weak_results}, state}
      
      :statistical ->
        # Get statistical overview without collapse
        stats = %{
          average_superposition_size: calculate_avg_superposition_size(state),
          entanglement_density: calculate_entanglement_density(state),
          tunnel_utilization: calculate_tunnel_utilization(state)
        }
        
        {:ok, %{type: :statistical, stats: stats}, state}
      
      _ ->
        {:error, :unknown_measurement_type}
    end
  end

  defp handle_tunneled_message(message, priority, state) do
    # Process message that came through quantum tunnel
    Logger.info("🌌 Received tunneled message with priority: #{priority}")
    
    # Create record of tunneled message
    id = generate_quantum_message_id()
    
    tunneled_message = %{
      id: id,
      content: message,
      superposition_states: [message],
      quantum_state_id: nil,
      entangled_with: [],
      priority: priority,
      quantum_properties: %{tunneled: true},
      created_at: DateTime.utc_now(),
      metadata: %{
        collapsed: true,
        tunneled: true,
        observations: 0
      }
    }
    
    state
    |> put_in([:quantum_messages, id], tunneled_message)
    |> update_in([:stats, :total_tunnels], &(&1 + 1))
  end

  defp handle_wave_collapse(wf_id, collapsed_state, state) do
    # Handle wave function collapse from WaveFunction module
    affected_messages = find_messages_by_wave_function(wf_id, state)
    
    Enum.reduce(affected_messages, state, fn msg_id, acc_state ->
      update_in(acc_state, [:quantum_messages, msg_id], fn
        nil -> nil
        msg -> %{msg |
          content: collapsed_state,
          metadata: Map.merge(msg.metadata, %{
            collapsed: true,
            collapse_time: DateTime.utc_now(),
            collapse_source: :wave_function
          })
        }
      end)
    end)
    |> update_in([:stats, :total_collapses], &(&1 + 1))
  end

  defp perform_quantum_maintenance(state) do
    # Clean up old collapsed messages
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
    
    cleaned_messages = state.quantum_messages
    |> Enum.filter(fn {_id, msg} ->
      not (msg.metadata.collapsed and 
           msg.created_at < cutoff_time)
    end)
    |> Map.new()
    
    # Update quantum efficiency
    new_efficiency = calculate_quantum_efficiency(state)
    
    state
    |> Map.put(:quantum_messages, cleaned_messages)
    |> put_in([:stats, :quantum_efficiency], new_efficiency)
  end

  defp generate_variety_states(classical_variety) do
    # Generate possible quantum states for variety
    base_states = [:high_variety, :medium_variety, :low_variety, :zero_variety]
    
    # Add context-specific states
    if Map.get(classical_variety, :type) == :regulatory do
      base_states ++ [:regulatory_override, :compliance_mode]
    else
      base_states
    end
  end

  defp generate_message_superpositions(message) do
    # Generate superposition states for message
    [
      message,
      Map.put(message, :priority, :high),
      Map.put(message, :priority, :normal),
      Map.put(message, :priority, :low)
    ]
  end

  defp determine_quantum_properties(message, priority) do
    %{
      use_superposition: Map.get(message, :uncertain, false) or priority == :adaptive,
      use_entanglement: Map.get(message, :correlated, false),
      use_tunneling: priority in [:critical, :emergency],
      coherence_time: if(priority == :critical, do: 10000, else: 1000)
    }
  end

  defp find_entanglement_candidates(quantum_message, state) do
    # Find messages that could be entangled
    state.quantum_messages
    |> Enum.filter(fn {id, msg} ->
      id != quantum_message.id and
      not msg.metadata.collapsed and
      compatible_for_entanglement?(quantum_message, msg)
    end)
    |> Enum.map(fn {_id, msg} -> msg.quantum_state_id end)
    |> Enum.take(3)  # Limit entanglements
  end

  defp compatible_for_entanglement?(msg1, msg2) do
    # Check if messages are compatible for entanglement
    msg1.priority == msg2.priority or
    Map.get(msg1.quantum_properties, :use_entanglement, false)
  end

  defp find_messages_by_wave_function(wf_id, state) do
    state.quantum_messages
    |> Enum.filter(fn {_id, msg} ->
      msg.quantum_state_id == wf_id
    end)
    |> Enum.map(fn {id, _msg} -> id end)
  end

  defp count_uncollapsed_messages(state) do
    Enum.count(state.quantum_messages, fn {_id, msg} ->
      not msg.metadata.collapsed
    end)
  end

  defp calculate_quantum_efficiency(state) do
    if state.stats.total_quantum_messages > 0 do
      successful_tunnels = state.stats.total_tunnels
      useful_collapses = state.stats.total_collapses
      total_operations = state.stats.total_quantum_messages
      
      (successful_tunnels + useful_collapses) / total_operations
    else
      1.0
    end
  end

  defp calculate_avg_superposition_size(state) do
    sizes = state.quantum_messages
    |> Enum.map(fn {_id, msg} -> length(msg.superposition_states) end)
    
    if length(sizes) > 0 do
      Enum.sum(sizes) / length(sizes)
    else
      0.0
    end
  end

  defp calculate_entanglement_density(state) do
    total_messages = map_size(state.quantum_messages)
    
    if total_messages > 0 do
      entangled_count = Enum.count(state.quantum_messages, fn {_id, msg} ->
        length(msg.entangled_with) > 0
      end)
      
      entangled_count / total_messages
    else
      0.0
    end
  end

  defp calculate_tunnel_utilization(state) do
    if length(state.active_tunnels) > 0 do
      state.stats.total_tunnels / (length(state.active_tunnels) * 10)  # Normalized
    else
      0.0
    end
  end

  defp notify_entangled_collapse(entangled_ids, collapsed_state) do
    Enum.each(entangled_ids, fn id ->
      send(self(), {:entangled_collapse, id, collapsed_state})
    end)
  end

  defp get_quantum_variety(variety_id, state) do
    case get_in(state.quantum_varieties, [variety_id]) do
      nil -> {:error, :variety_not_found}
      variety -> {:ok, variety}
    end
  end

  defp parse_quantum_config(opts) do
    %{
      max_superposition_size: Keyword.get(opts, :max_superposition, 8),
      entanglement_threshold: Keyword.get(opts, :entanglement_threshold, 0.7),
      tunnel_energy_budget: Keyword.get(opts, :tunnel_budget, 1000.0),
      decoherence_rate: Keyword.get(opts, :decoherence_rate, 0.01),
      auto_collapse: Keyword.get(opts, :auto_collapse, true)
    }
  end

  defp generate_quantum_variety_id do
    "qvariety_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp generate_quantum_message_id do
    "qmsg_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp schedule_quantum_maintenance do
    Process.send_after(self(), :quantum_maintenance, 60_000)  # Every minute
  end
end