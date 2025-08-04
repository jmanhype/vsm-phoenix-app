defmodule VsmPhoenix.QuantumVariety.QuantumState do
  @moduledoc """
  Quantum State Management for VSM Variety Engineering.
  
  Implements quantum superposition states where messages can exist in
  multiple states simultaneously until observed (collapsed).
  
  Key Concepts:
  - Superposition: Messages exist in multiple probability states
  - Coherence: Maintains quantum state integrity
  - Decoherence: Natural decay of quantum states over time
  - Observation: Collapses superposition to classical state
  """

  use GenServer
  require Logger
  alias VsmPhoenix.QuantumVariety.{WaveFunction, EntanglementManager}

  @type quantum_state :: %{
    id: String.t(),
    amplitudes: map(),  # Complex probability amplitudes
    phase: float(),      # Quantum phase
    coherence: float(),  # Coherence level (0-1)
    entangled_with: list(String.t()),
    created_at: DateTime.t(),
    last_interaction: DateTime.t(),
    metadata: map()
  }

  @type superposition :: %{
    states: list(quantum_state()),
    total_probability: float(),
    measurement_basis: atom(),
    collapsed: boolean()
  }

  # Quantum constants
  @planck_constant 6.62607015e-34  # Reduced for computational purposes
  @decoherence_rate 0.001          # Rate of coherence decay
  @entanglement_threshold 0.7       # Minimum coherence for entanglement
  @max_superposition_states 8       # Maximum simultaneous states

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a quantum superposition state for a message.
  The message can exist in multiple states simultaneously.
  """
  def create_superposition(message, possible_states) do
    GenServer.call(__MODULE__, {:create_superposition, message, possible_states})
  end

  @doc """
  Applies a quantum gate operation to transform the state.
  Supports Hadamard, Pauli-X/Y/Z, CNOT, and custom gates.
  """
  def apply_quantum_gate(state_id, gate_type, params \\ %{}) do
    GenServer.call(__MODULE__, {:apply_gate, state_id, gate_type, params})
  end

  @doc """
  Measures (observes) a quantum state, causing wave function collapse.
  Returns the collapsed classical state.
  """
  def measure(state_id, measurement_basis \\ :computational) do
    GenServer.call(__MODULE__, {:measure, state_id, measurement_basis})
  end

  @doc """
  Creates quantum entanglement between two states.
  Changes to one state instantly affect the other.
  """
  def entangle(state1_id, state2_id, entanglement_type \\ :bell) do
    GenServer.call(__MODULE__, {:entangle, state1_id, state2_id, entanglement_type})
  end

  @doc """
  Performs quantum teleportation of state information.
  Uses entanglement to transfer state without physical movement.
  """
  def teleport(source_id, target_id) do
    GenServer.call(__MODULE__, {:teleport, source_id, target_id})
  end

  @doc """
  Checks coherence level of a quantum state.
  Low coherence indicates decoherence and potential collapse.
  """
  def check_coherence(state_id) do
    GenServer.call(__MODULE__, {:check_coherence, state_id})
  end

  ## GenServer Callbacks

  def init(opts) do
    # Start decoherence monitoring
    schedule_decoherence_check()
    
    state = %{
      quantum_states: %{},
      superpositions: %{},
      entanglement_pairs: [],
      measurement_history: [],
      quantum_register: initialize_quantum_register(opts),
      stats: %{
        total_superpositions: 0,
        total_collapses: 0,
        total_entanglements: 0,
        total_teleportations: 0
      }
    }
    
    Logger.info("⚛️ Quantum State Manager initialized")
    {:ok, state}
  end

  def handle_call({:create_superposition, message, possible_states}, _from, state) do
    case create_quantum_superposition(message, possible_states, state) do
      {:ok, superposition, new_state} ->
        {:reply, {:ok, superposition}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_gate, state_id, gate_type, params}, _from, state) do
    case apply_gate_operation(state_id, gate_type, params, state) do
      {:ok, transformed_state, new_state} ->
        {:reply, {:ok, transformed_state}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:measure, state_id, basis}, _from, state) do
    case perform_measurement(state_id, basis, state) do
      {:ok, collapsed_state, new_state} ->
        {:reply, {:ok, collapsed_state}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:entangle, state1_id, state2_id, type}, _from, state) do
    case create_entanglement(state1_id, state2_id, type, state) do
      {:ok, entanglement, new_state} ->
        {:reply, {:ok, entanglement}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:teleport, source_id, target_id}, _from, state) do
    case perform_teleportation(source_id, target_id, state) do
      {:ok, result, new_state} ->
        {:reply, {:ok, result}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:check_coherence, state_id}, _from, state) do
    coherence = calculate_coherence(state_id, state)
    {:reply, {:ok, coherence}, state}
  end

  def handle_info(:check_decoherence, state) do
    new_state = apply_decoherence(state)
    schedule_decoherence_check()
    {:noreply, new_state}
  end

  ## Private Functions

  defp create_quantum_superposition(message, possible_states, state) do
    if length(possible_states) > @max_superposition_states do
      {:error, :too_many_states}
    else
      id = generate_quantum_id()
      
      # Create probability amplitudes using Born rule
      amplitudes = create_probability_amplitudes(possible_states)
      
      quantum_state = %{
        id: id,
        message: message,
        amplitudes: amplitudes,
        phase: :rand.uniform() * 2 * :math.pi(),
        coherence: 1.0,
        entangled_with: [],
        created_at: DateTime.utc_now(),
        last_interaction: DateTime.utc_now(),
        metadata: %{
          possible_states: possible_states,
          collapsed: false,
          measurement_count: 0
        }
      }
      
      superposition = %{
        states: possible_states,
        total_probability: 1.0,
        measurement_basis: :computational,
        collapsed: false
      }
      
      new_state = state
      |> put_in([:quantum_states, id], quantum_state)
      |> put_in([:superpositions, id], superposition)
      |> update_in([:stats, :total_superpositions], &(&1 + 1))
      
      Logger.info("⚛️ Created superposition #{id} with #{length(possible_states)} states")
      {:ok, quantum_state, new_state}
    end
  end

  defp apply_gate_operation(state_id, gate_type, params, state) do
    case get_in(state.quantum_states, [state_id]) do
      nil ->
        {:error, :state_not_found}
      
      quantum_state ->
        transformed = apply_quantum_gate_transform(quantum_state, gate_type, params)
        
        new_state = put_in(state, [:quantum_states, state_id], transformed)
        {:ok, transformed, new_state}
    end
  end

  defp apply_quantum_gate_transform(quantum_state, gate_type, params) do
    case gate_type do
      :hadamard ->
        apply_hadamard_gate(quantum_state)
      
      :pauli_x ->
        apply_pauli_x_gate(quantum_state)
      
      :pauli_y ->
        apply_pauli_y_gate(quantum_state)
      
      :pauli_z ->
        apply_pauli_z_gate(quantum_state)
      
      :cnot ->
        apply_cnot_gate(quantum_state, params)
      
      :phase ->
        apply_phase_gate(quantum_state, params[:phase] || :math.pi() / 4)
      
      :custom ->
        apply_custom_gate(quantum_state, params[:matrix])
      
      _ ->
        quantum_state
    end
  end

  defp apply_hadamard_gate(quantum_state) do
    # Hadamard gate creates equal superposition
    # H = (1/√2) * [[1, 1], [1, -1]]
    factor = 1 / :math.sqrt(2)
    
    new_amplitudes = quantum_state.amplitudes
    |> Enum.map(fn {state, amp} ->
      {state, amp * factor}
    end)
    |> Map.new()
    
    %{quantum_state | 
      amplitudes: new_amplitudes,
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_pauli_x_gate(quantum_state) do
    # Pauli-X gate (quantum NOT)
    # X = [[0, 1], [1, 0]]
    
    new_amplitudes = quantum_state.amplitudes
    |> Enum.map(fn {state, amp} ->
      {flip_state(state), amp}
    end)
    |> Map.new()
    
    %{quantum_state | 
      amplitudes: new_amplitudes,
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_pauli_y_gate(quantum_state) do
    # Pauli-Y gate
    # Y = [[0, -i], [i, 0]]
    
    new_amplitudes = quantum_state.amplitudes
    |> Enum.map(fn {state, amp} ->
      {flip_state(state), amp * :math.sqrt(-1)}
    end)
    |> Map.new()
    
    %{quantum_state | 
      amplitudes: new_amplitudes,
      phase: quantum_state.phase + :math.pi() / 2,
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_pauli_z_gate(quantum_state) do
    # Pauli-Z gate (phase flip)
    # Z = [[1, 0], [0, -1]]
    
    %{quantum_state | 
      phase: quantum_state.phase + :math.pi(),
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_cnot_gate(quantum_state, %{control: control_id}) do
    # CNOT gate requires entanglement with control qubit
    # This is a simplified implementation
    
    if control_id in quantum_state.entangled_with do
      apply_pauli_x_gate(quantum_state)
    else
      quantum_state
    end
  end

  defp apply_phase_gate(quantum_state, phase_shift) do
    %{quantum_state | 
      phase: quantum_state.phase + phase_shift,
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_custom_gate(quantum_state, matrix) when is_list(matrix) do
    # Apply custom unitary matrix transformation
    # Matrix must be unitary (U†U = I)
    
    new_amplitudes = transform_amplitudes_with_matrix(quantum_state.amplitudes, matrix)
    
    %{quantum_state | 
      amplitudes: new_amplitudes,
      last_interaction: DateTime.utc_now()
    }
  end

  defp apply_custom_gate(quantum_state, _), do: quantum_state

  defp perform_measurement(state_id, basis, state) do
    case get_in(state.quantum_states, [state_id]) do
      nil ->
        {:error, :state_not_found}
      
      quantum_state ->
        # Wave function collapse
        collapsed = collapse_wave_function(quantum_state, basis)
        
        # Update metadata
        updated_quantum_state = %{quantum_state |
          metadata: Map.merge(quantum_state.metadata, %{
            collapsed: true,
            collapse_time: DateTime.utc_now(),
            measurement_basis: basis,
            measurement_count: (quantum_state.metadata[:measurement_count] || 0) + 1
          }),
          coherence: 0.0
        }
        
        # Update superposition
        updated_superposition = case get_in(state.superpositions, [state_id]) do
          nil -> nil
          sup -> %{sup | collapsed: true}
        end
        
        new_state = state
        |> put_in([:quantum_states, state_id], updated_quantum_state)
        |> put_in([:superpositions, state_id], updated_superposition)
        |> update_in([:measurement_history], &([{state_id, collapsed, DateTime.utc_now()} | &1]))
        |> update_in([:stats, :total_collapses], &(&1 + 1))
        
        # Notify entangled states
        notify_entangled_states(quantum_state.entangled_with, state_id, collapsed)
        
        Logger.info("📏 Measured state #{state_id}, collapsed to: #{inspect(collapsed)}")
        {:ok, collapsed, new_state}
    end
  end

  defp collapse_wave_function(quantum_state, basis) do
    # Use Born rule: P(outcome) = |amplitude|²
    probabilities = quantum_state.amplitudes
    |> Enum.map(fn {state, amp} ->
      {state, :math.pow(abs(amp), 2)}
    end)
    
    # Select outcome based on probability distribution
    total_prob = Enum.reduce(probabilities, 0, fn {_, p}, acc -> acc + p end)
    random_value = :rand.uniform() * total_prob
    
    select_outcome(probabilities, random_value, 0)
  end

  defp select_outcome([{state, prob} | rest], random_value, accumulated) do
    new_accumulated = accumulated + prob
    
    if random_value <= new_accumulated do
      state
    else
      select_outcome(rest, random_value, new_accumulated)
    end
  end

  defp select_outcome([], _, _), do: :undefined

  defp create_entanglement(state1_id, state2_id, type, state) do
    with {:ok, state1} <- get_quantum_state(state1_id, state),
         {:ok, state2} <- get_quantum_state(state2_id, state),
         true <- can_entangle?(state1, state2) do
      
      entanglement = create_entanglement_pair(state1, state2, type)
      
      # Update both states with entanglement info
      updated_state1 = %{state1 | 
        entangled_with: [state2_id | state1.entangled_with],
        last_interaction: DateTime.utc_now()
      }
      
      updated_state2 = %{state2 | 
        entangled_with: [state1_id | state2.entangled_with],
        last_interaction: DateTime.utc_now()
      }
      
      new_state = state
      |> put_in([:quantum_states, state1_id], updated_state1)
      |> put_in([:quantum_states, state2_id], updated_state2)
      |> update_in([:entanglement_pairs], &([entanglement | &1]))
      |> update_in([:stats, :total_entanglements], &(&1 + 1))
      
      # Notify EntanglementManager
      EntanglementManager.register_entanglement(entanglement)
      
      Logger.info("🔗 Created #{type} entanglement between #{state1_id} and #{state2_id}")
      {:ok, entanglement, new_state}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :cannot_entangle}
    end
  end

  defp create_entanglement_pair(state1, state2, type) do
    %{
      id: generate_quantum_id(),
      type: type,
      state1_id: state1.id,
      state2_id: state2.id,
      correlation: calculate_correlation(state1, state2),
      created_at: DateTime.utc_now(),
      metadata: %{
        bell_state: type == :bell,
        ghz_state: type == :ghz,
        max_entangled: type == :max
      }
    }
  end

  defp can_entangle?(state1, state2) do
    state1.coherence >= @entanglement_threshold and
    state2.coherence >= @entanglement_threshold and
    not Map.get(state1.metadata, :collapsed, false) and
    not Map.get(state2.metadata, :collapsed, false)
  end

  defp perform_teleportation(source_id, target_id, state) do
    with {:ok, source} <- get_quantum_state(source_id, state),
         {:ok, target} <- get_quantum_state(target_id, state),
         true <- target_id in source.entangled_with do
      
      # Quantum teleportation protocol
      # 1. Measure source in Bell basis
      measurement = collapse_wave_function(source, :bell)
      
      # 2. Apply correction to target based on measurement
      corrected_target = apply_teleportation_correction(target, measurement)
      
      # 3. Source state is destroyed, target receives state
      destroyed_source = %{source | 
        coherence: 0.0,
        metadata: Map.put(source.metadata, :teleported, true)
      }
      
      new_state = state
      |> put_in([:quantum_states, source_id], destroyed_source)
      |> put_in([:quantum_states, target_id], corrected_target)
      |> update_in([:stats, :total_teleportations], &(&1 + 1))
      
      Logger.info("🌌 Teleported state from #{source_id} to #{target_id}")
      {:ok, %{measurement: measurement, target_state: corrected_target}, new_state}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :not_entangled}
    end
  end

  defp apply_teleportation_correction(target, measurement) do
    # Apply Pauli corrections based on Bell measurement
    case measurement do
      :bell_00 -> target
      :bell_01 -> apply_pauli_x_gate(target)
      :bell_10 -> apply_pauli_z_gate(target)
      :bell_11 -> target |> apply_pauli_x_gate() |> apply_pauli_z_gate()
      _ -> target
    end
  end

  defp calculate_coherence(state_id, state) do
    case get_in(state.quantum_states, [state_id]) do
      nil -> 0.0
      quantum_state -> quantum_state.coherence
    end
  end

  defp apply_decoherence(state) do
    # Apply decoherence to all quantum states
    updated_states = state.quantum_states
    |> Enum.map(fn {id, quantum_state} ->
      if quantum_state.coherence > 0 and not Map.get(quantum_state.metadata, :collapsed, false) do
        time_elapsed = DateTime.diff(DateTime.utc_now(), quantum_state.last_interaction, :millisecond)
        decay = :math.exp(-@decoherence_rate * time_elapsed / 1000)
        new_coherence = quantum_state.coherence * decay
        
        # Auto-collapse if coherence too low
        if new_coherence < 0.1 do
          collapsed = collapse_wave_function(quantum_state, :environmental)
          
          updated = %{quantum_state |
            coherence: 0.0,
            metadata: Map.merge(quantum_state.metadata, %{
              collapsed: true,
              auto_collapsed: true,
              collapse_reason: :decoherence
            })
          }
          
          Logger.debug("⚠️ State #{id} auto-collapsed due to decoherence")
          {id, updated}
        else
          {id, %{quantum_state | coherence: new_coherence}}
        end
      else
        {id, quantum_state}
      end
    end)
    |> Map.new()
    
    %{state | quantum_states: updated_states}
  end

  defp create_probability_amplitudes(possible_states) do
    # Equal superposition initially
    amplitude = 1 / :math.sqrt(length(possible_states))
    
    possible_states
    |> Enum.map(fn state ->
      {state, amplitude}
    end)
    |> Map.new()
  end

  defp flip_state(state) when is_atom(state) do
    case state do
      :up -> :down
      :down -> :up
      :left -> :right
      :right -> :left
      :in -> :out
      :out -> :in
      other -> other
    end
  end

  defp flip_state(state), do: state

  defp transform_amplitudes_with_matrix(amplitudes, matrix) do
    # Simplified matrix multiplication for amplitude transformation
    amplitudes
    |> Enum.map(fn {state, amp} ->
      # Apply matrix transformation
      {state, amp}  # Simplified - full implementation would do actual matrix math
    end)
    |> Map.new()
  end

  defp calculate_correlation(state1, state2) do
    # Calculate quantum correlation between states
    # Simplified - real implementation would use density matrices
    min(state1.coherence, state2.coherence)
  end

  defp get_quantum_state(state_id, state) do
    case get_in(state.quantum_states, [state_id]) do
      nil -> {:error, :state_not_found}
      quantum_state -> {:ok, quantum_state}
    end
  end

  defp notify_entangled_states(entangled_ids, collapsed_id, collapsed_value) do
    # Send notifications to entangled states about collapse
    Enum.each(entangled_ids, fn id ->
      send(self(), {:entangled_collapse, id, collapsed_id, collapsed_value})
    end)
  end

  defp initialize_quantum_register(opts) do
    %{
      size: Keyword.get(opts, :register_size, 8),
      qubits: [],
      gates_applied: [],
      circuit_depth: 0
    }
  end

  defp generate_quantum_id do
    "quantum_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp schedule_decoherence_check do
    Process.send_after(self(), :check_decoherence, 100)  # Check every 100ms
  end

  defp abs(x) when x < 0, do: -x
  defp abs(x), do: x
end