defmodule VsmPhoenix.QuantumVariety.WaveFunction do
  @moduledoc """
  Wave Function Management and Collapse for VSM Quantum Variety.
  
  Manages the quantum wave functions representing variety states and
  implements collapse mechanisms when states are observed or measured.
  
  Key Concepts:
  - Wave Function: Mathematical description of quantum state
  - Collapse: Reduction from superposition to definite state
  - Measurement: Observation that causes collapse
  - Decoherence: Environmental interaction causing collapse
  """

  use GenServer
  require Logger
  alias VsmPhoenix.QuantumVariety.{QuantumState, EntanglementManager}

  @type wave_function :: %{
    id: String.t(),
    amplitudes: list(complex()),
    basis_states: list(any()),
    normalization: float(),
    phase: float(),
    coherence_time: float(),
    metadata: map()
  }

  @type complex :: {float(), float()}  # {real, imaginary}

  @type collapse_event :: %{
    wave_function_id: String.t(),
    measurement_type: atom(),
    collapsed_state: any(),
    measurement_basis: atom(),
    timestamp: DateTime.t(),
    metadata: map()
  }

  @type measurement_operator :: %{
    matrix: list(list(complex())),
    eigenvalues: list(float()),
    eigenvectors: list(list(complex()))
  }

  # Wave function constants
  @coherence_decay_rate 0.01       # Decoherence rate
  @measurement_noise 0.05           # Measurement uncertainty
  @collapse_threshold 0.99          # Probability threshold for collapse
  @max_basis_states 16             # Maximum basis states in superposition

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a wave function from basis states and amplitudes.
  """
  def create_wave_function(basis_states, amplitudes \\ nil) do
    GenServer.call(__MODULE__, {:create_wave_function, basis_states, amplitudes})
  end

  @doc """
  Evolves wave function according to Schrödinger equation.
  """
  def evolve(wave_function_id, hamiltonian, time_step) do
    GenServer.call(__MODULE__, {:evolve, wave_function_id, hamiltonian, time_step})
  end

  @doc """
  Measures wave function causing collapse.
  """
  def measure(wave_function_id, measurement_operator \\ nil) do
    GenServer.call(__MODULE__, {:measure, wave_function_id, measurement_operator})
  end

  @doc """
  Performs weak measurement without full collapse.
  """
  def weak_measure(wave_function_id, strength \\ 0.1) do
    GenServer.call(__MODULE__, {:weak_measure, wave_function_id, strength})
  end

  @doc """
  Calculates expectation value for an observable.
  """
  def expectation_value(wave_function_id, observable) do
    GenServer.call(__MODULE__, {:expectation_value, wave_function_id, observable})
  end

  @doc """
  Projects wave function onto subspace.
  """
  def project(wave_function_id, projection_operator) do
    GenServer.call(__MODULE__, {:project, wave_function_id, projection_operator})
  end

  @doc """
  Calculates interference pattern between wave functions.
  """
  def calculate_interference(wf1_id, wf2_id) do
    GenServer.call(__MODULE__, {:calculate_interference, wf1_id, wf2_id})
  end

  @doc """
  Applies decoherence to simulate environmental interaction.
  """
  def apply_decoherence(wave_function_id, environment_strength) do
    GenServer.call(__MODULE__, {:apply_decoherence, wave_function_id, environment_strength})
  end

  ## GenServer Callbacks

  def init(opts) do
    # Start decoherence simulation
    schedule_decoherence_update()
    
    state = %{
      wave_functions: %{},
      collapse_events: [],
      measurement_operators: initialize_measurement_operators(),
      hamiltonians: %{},
      environment: initialize_environment(opts),
      stats: %{
        total_wave_functions: 0,
        total_collapses: 0,
        total_measurements: 0,
        average_coherence_time: 0.0
      }
    }
    
    Logger.info("🌊 Wave Function Manager initialized")
    {:ok, state}
  end

  def handle_call({:create_wave_function, basis_states, amplitudes}, _from, state) do
    case create_wf(basis_states, amplitudes, state) do
      {:ok, wave_function, new_state} ->
        {:reply, {:ok, wave_function}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:evolve, wf_id, hamiltonian, time_step}, _from, state) do
    case evolve_wave_function(wf_id, hamiltonian, time_step, state) do
      {:ok, evolved_wf, new_state} ->
        {:reply, {:ok, evolved_wf}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:measure, wf_id, operator}, _from, state) do
    case perform_measurement(wf_id, operator, state) do
      {:ok, collapse_event, new_state} ->
        {:reply, {:ok, collapse_event}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:weak_measure, wf_id, strength}, _from, state) do
    case perform_weak_measurement(wf_id, strength, state) do
      {:ok, result, new_state} ->
        {:reply, {:ok, result}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:expectation_value, wf_id, observable}, _from, state) do
    case calculate_expectation(wf_id, observable, state) do
      {:ok, value} -> {:reply, {:ok, value}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:project, wf_id, projection_op}, _from, state) do
    case project_wave_function(wf_id, projection_op, state) do
      {:ok, projected_wf, new_state} ->
        {:reply, {:ok, projected_wf}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:calculate_interference, wf1_id, wf2_id}, _from, state) do
    case compute_interference(wf1_id, wf2_id, state) do
      {:ok, pattern} -> {:reply, {:ok, pattern}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_decoherence, wf_id, strength}, _from, state) do
    case simulate_decoherence(wf_id, strength, state) do
      {:ok, decohered_wf, new_state} ->
        {:reply, {:ok, decohered_wf}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:update_decoherence, state) do
    new_state = update_all_decoherence(state)
    schedule_decoherence_update()
    {:noreply, new_state}
  end

  ## Private Functions

  defp create_wf(basis_states, amplitudes, state) do
    if length(basis_states) > @max_basis_states do
      {:error, :too_many_basis_states}
    else
      id = generate_wf_id()
      
      # Initialize amplitudes if not provided
      amps = amplitudes || initialize_equal_amplitudes(length(basis_states))
      
      # Normalize wave function
      normalized_amps = normalize_amplitudes(amps)
      
      wave_function = %{
        id: id,
        amplitudes: normalized_amps,
        basis_states: basis_states,
        normalization: calculate_norm(normalized_amps),
        phase: 0.0,
        coherence_time: calculate_coherence_time(normalized_amps),
        created_at: DateTime.utc_now(),
        last_evolved: DateTime.utc_now(),
        metadata: %{
          collapsed: false,
          measurements: 0,
          entangled: false
        }
      }
      
      new_state = state
      |> put_in([:wave_functions, id], wave_function)
      |> update_in([:stats, :total_wave_functions], &(&1 + 1))
      
      Logger.info("🌊 Created wave function #{id} with #{length(basis_states)} basis states")
      {:ok, wave_function, new_state}
    end
  end

  defp evolve_wave_function(wf_id, hamiltonian, time_step, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # Time evolution: |ψ(t)> = exp(-iHt/ħ)|ψ(0)>
        evolved_amplitudes = apply_time_evolution(wf.amplitudes, hamiltonian, time_step)
        
        evolved_wf = %{wf |
          amplitudes: evolved_amplitudes,
          phase: wf.phase + calculate_phase_evolution(hamiltonian, time_step),
          last_evolved: DateTime.utc_now()
        }
        
        new_state = put_in(state, [:wave_functions, wf_id], evolved_wf)
        
        Logger.debug("⏱️ Evolved wave function #{wf_id} by #{time_step}s")
        {:ok, evolved_wf, new_state}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_measurement(wf_id, operator, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # Select measurement operator
        meas_op = operator || get_default_measurement_operator(state)
        
        # Calculate measurement probabilities
        probabilities = calculate_measurement_probabilities(wf, meas_op)
        
        # Select outcome based on Born rule
        outcome_index = select_measurement_outcome(probabilities)
        collapsed_state = Enum.at(wf.basis_states, outcome_index)
        
        # Create collapse event
        collapse_event = %{
          wave_function_id: wf_id,
          measurement_type: :projective,
          collapsed_state: collapsed_state,
          measurement_basis: meas_op[:basis] || :computational,
          probability: Enum.at(probabilities, outcome_index),
          timestamp: DateTime.utc_now(),
          metadata: %{
            pre_measurement_entropy: calculate_entropy(probabilities),
            measurement_operator: meas_op
          }
        }
        
        # Update wave function to collapsed state
        collapsed_wf = %{wf |
          amplitudes: create_collapsed_amplitudes(outcome_index, length(wf.basis_states)),
          metadata: Map.merge(wf.metadata, %{
            collapsed: true,
            collapse_time: DateTime.utc_now(),
            measurements: wf.metadata.measurements + 1
          })
        }
        
        new_state = state
        |> put_in([:wave_functions, wf_id], collapsed_wf)
        |> update_in([:collapse_events], &([collapse_event | &1]))
        |> update_in([:stats, :total_collapses], &(&1 + 1))
        |> update_in([:stats, :total_measurements], &(&1 + 1))
        
        # Notify quantum state system
        notify_collapse(wf_id, collapsed_state)
        
        Logger.info("📏 Measured #{wf_id}: collapsed to state #{inspect(collapsed_state)} (P=#{Float.round(collapse_event.probability, 3)})")
        {:ok, collapse_event, new_state}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_weak_measurement(wf_id, strength, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # Weak measurement partially collapses the wave function
        weakly_measured = apply_weak_measurement(wf, strength)
        
        result = %{
          wave_function_id: wf_id,
          measurement_strength: strength,
          partial_information: extract_weak_measurement_info(weakly_measured),
          post_measurement_state: weakly_measured,
          timestamp: DateTime.utc_now()
        }
        
        new_state = state
        |> put_in([:wave_functions, wf_id], weakly_measured)
        |> update_in([:stats, :total_measurements], &(&1 + 1))
        
        Logger.debug("🔍 Weak measurement on #{wf_id} (strength: #{strength})")
        {:ok, result, new_state}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp calculate_expectation(wf_id, observable, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # <ψ|O|ψ> = expectation value
        expectation = compute_expectation_value(wf, observable)
        {:ok, expectation}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp project_wave_function(wf_id, projection_op, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # P|ψ> = projected state
        projected_amplitudes = apply_projection(wf.amplitudes, projection_op)
        
        # Renormalize after projection
        normalized = normalize_amplitudes(projected_amplitudes)
        
        projected_wf = %{wf |
          amplitudes: normalized,
          normalization: calculate_norm(normalized),
          metadata: Map.put(wf.metadata, :projected, true)
        }
        
        new_state = put_in(state, [:wave_functions, wf_id], projected_wf)
        
        Logger.debug("📦 Projected wave function #{wf_id}")
        {:ok, projected_wf, new_state}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp compute_interference(wf1_id, wf2_id, state) do
    with {:ok, wf1} <- get_wave_function(wf1_id, state),
         {:ok, wf2} <- get_wave_function(wf2_id, state) do
      
      # Calculate interference pattern |ψ1 + ψ2|²
      pattern = calculate_interference_pattern(wf1, wf2)
      
      {:ok, %{
        pattern: pattern,
        visibility: calculate_visibility(pattern),
        phase_difference: calculate_phase_difference(wf1, wf2),
        constructive_points: find_constructive_interference(pattern),
        destructive_points: find_destructive_interference(pattern)
      }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp simulate_decoherence(wf_id, strength, state) do
    case get_wave_function(wf_id, state) do
      {:ok, wf} ->
        # Apply environmental decoherence
        decohered = apply_environmental_decoherence(wf, strength, state.environment)
        
        new_state = put_in(state, [:wave_functions, wf_id], decohered)
        
        # Check if decoherence caused collapse
        if should_collapse_from_decoherence?(decohered) do
          perform_measurement(wf_id, nil, new_state)
        else
          {:ok, decohered, new_state}
        end
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_all_decoherence(state) do
    # Apply gradual decoherence to all wave functions
    updated_wfs = state.wave_functions
    |> Enum.map(fn {id, wf} ->
      if not wf.metadata.collapsed do
        time_elapsed = DateTime.diff(DateTime.utc_now(), wf.last_evolved, :millisecond) / 1000
        coherence_decay = :math.exp(-@coherence_decay_rate * time_elapsed)
        
        updated = %{wf |
          coherence_time: wf.coherence_time * coherence_decay,
          amplitudes: add_phase_noise(wf.amplitudes, 1 - coherence_decay)
        }
        
        {id, updated}
      else
        {id, wf}
      end
    end)
    |> Map.new()
    
    %{state | wave_functions: updated_wfs}
  end

  defp apply_time_evolution(amplitudes, hamiltonian, time_step) do
    # Simplified time evolution (would use matrix exponentiation in production)
    energy_factor = calculate_energy_factor(hamiltonian, time_step)
    
    amplitudes
    |> Enum.map(fn {real, imag} ->
      # Rotate in complex plane
      angle = energy_factor
      new_real = real * :math.cos(angle) - imag * :math.sin(angle)
      new_imag = real * :math.sin(angle) + imag * :math.cos(angle)
      {new_real, new_imag}
    end)
  end

  defp calculate_measurement_probabilities(wf, measurement_operator) do
    # |<basis|measurement|ψ>|² for each basis state
    wf.amplitudes
    |> Enum.map(fn {real, imag} ->
      :math.pow(real, 2) + :math.pow(imag, 2)
    end)
  end

  defp select_measurement_outcome(probabilities) do
    # Weighted random selection based on probabilities
    total = Enum.sum(probabilities)
    random = :rand.uniform() * total
    
    probabilities
    |> Enum.with_index()
    |> Enum.reduce_while({0, 0}, fn {prob, index}, {acc, _} ->
      new_acc = acc + prob
      if random <= new_acc do
        {:halt, {new_acc, index}}
      else
        {:cont, {new_acc, index}}
      end
    end)
    |> elem(1)
  end

  defp create_collapsed_amplitudes(collapsed_index, total_states) do
    0..(total_states - 1)
    |> Enum.map(fn index ->
      if index == collapsed_index do
        {1.0, 0.0}  # Amplitude = 1 for collapsed state
      else
        {0.0, 0.0}  # Amplitude = 0 for other states
      end
    end)
  end

  defp apply_weak_measurement(wf, strength) do
    # Weak measurement partially disturbs the state
    disturbed_amplitudes = wf.amplitudes
    |> Enum.map(fn {real, imag} ->
      # Add small disturbance proportional to measurement strength
      noise_real = (:rand.uniform() - 0.5) * strength * 0.1
      noise_imag = (:rand.uniform() - 0.5) * strength * 0.1
      
      {real + noise_real, imag + noise_imag}
    end)
    |> normalize_amplitudes()
    
    %{wf |
      amplitudes: disturbed_amplitudes,
      metadata: Map.update(wf.metadata, :measurements, 1, &(&1 + 1))
    }
  end

  defp extract_weak_measurement_info(wf) do
    # Extract partial information from weakly measured state
    %{
      dominant_state: find_dominant_state(wf),
      entropy: calculate_wf_entropy(wf),
      coherence: calculate_coherence(wf)
    }
  end

  defp compute_expectation_value(wf, observable) do
    # Simplified expectation value calculation
    # In production, would do full matrix multiplication
    wf.amplitudes
    |> Enum.zip(observable[:eigenvalues] || List.duplicate(1.0, length(wf.amplitudes)))
    |> Enum.map(fn {{real, imag}, eigenvalue} ->
      (:math.pow(real, 2) + :math.pow(imag, 2)) * eigenvalue
    end)
    |> Enum.sum()
  end

  defp apply_projection(amplitudes, projection_op) do
    # Apply projection operator to amplitudes
    # Simplified - would use full matrix multiplication
    amplitudes
    |> Enum.with_index()
    |> Enum.map(fn {amp, index} ->
      if index in (projection_op[:subspace] || []) do
        amp
      else
        {0.0, 0.0}
      end
    end)
  end

  defp calculate_interference_pattern(wf1, wf2) do
    # |ψ1 + ψ2|² = |ψ1|² + |ψ2|² + 2Re(ψ1*ψ2)
    Enum.zip(wf1.amplitudes, wf2.amplitudes)
    |> Enum.map(fn {{r1, i1}, {r2, i2}} ->
      # Intensity at this point
      intensity1 = :math.pow(r1, 2) + :math.pow(i1, 2)
      intensity2 = :math.pow(r2, 2) + :math.pow(i2, 2)
      interference = 2 * (r1 * r2 + i1 * i2)
      
      intensity1 + intensity2 + interference
    end)
  end

  defp calculate_visibility(pattern) do
    # Visibility = (Imax - Imin) / (Imax + Imin)
    max_intensity = Enum.max(pattern)
    min_intensity = Enum.min(pattern)
    
    if max_intensity + min_intensity > 0 do
      (max_intensity - min_intensity) / (max_intensity + min_intensity)
    else
      0.0
    end
  end

  defp calculate_phase_difference(wf1, wf2) do
    wf1.phase - wf2.phase
  end

  defp find_constructive_interference(pattern) do
    # Find indices where interference is constructive
    mean = Enum.sum(pattern) / length(pattern)
    
    pattern
    |> Enum.with_index()
    |> Enum.filter(fn {intensity, _} -> intensity > mean * 1.5 end)
    |> Enum.map(fn {_, index} -> index end)
  end

  defp find_destructive_interference(pattern) do
    # Find indices where interference is destructive
    mean = Enum.sum(pattern) / length(pattern)
    
    pattern
    |> Enum.with_index()
    |> Enum.filter(fn {intensity, _} -> intensity < mean * 0.5 end)
    |> Enum.map(fn {_, index} -> index end)
  end

  defp apply_environmental_decoherence(wf, strength, environment) do
    # Environmental interaction causes decoherence
    noise_level = strength * environment.noise_level
    
    decohered_amplitudes = wf.amplitudes
    |> Enum.map(fn {real, imag} ->
      # Add environmental noise
      noise_real = (:rand.uniform() - 0.5) * noise_level
      noise_imag = (:rand.uniform() - 0.5) * noise_level
      
      {real * (1 - noise_level) + noise_real,
       imag * (1 - noise_level) + noise_imag}
    end)
    |> normalize_amplitudes()
    
    %{wf |
      amplitudes: decohered_amplitudes,
      coherence_time: wf.coherence_time * (1 - strength)
    }
  end

  defp should_collapse_from_decoherence?(wf) do
    # Check if decoherence has made one state dominant
    probabilities = wf.amplitudes
    |> Enum.map(fn {real, imag} ->
      :math.pow(real, 2) + :math.pow(imag, 2)
    end)
    
    max_prob = Enum.max(probabilities)
    max_prob > @collapse_threshold
  end

  defp add_phase_noise(amplitudes, noise_level) do
    amplitudes
    |> Enum.map(fn {real, imag} ->
      # Add random phase noise
      phase_noise = (:rand.uniform() - 0.5) * noise_level * :math.pi()
      
      # Rotate by phase noise
      new_real = real * :math.cos(phase_noise) - imag * :math.sin(phase_noise)
      new_imag = real * :math.sin(phase_noise) + imag * :math.cos(phase_noise)
      
      {new_real, new_imag}
    end)
  end

  defp initialize_equal_amplitudes(n) do
    # Equal superposition: 1/√n for each state
    amplitude = 1 / :math.sqrt(n)
    List.duplicate({amplitude, 0.0}, n)
  end

  defp normalize_amplitudes(amplitudes) do
    norm = calculate_norm(amplitudes)
    
    if norm > 0 do
      amplitudes
      |> Enum.map(fn {real, imag} ->
        {real / norm, imag / norm}
      end)
    else
      amplitudes
    end
  end

  defp calculate_norm(amplitudes) do
    sum_squared = amplitudes
    |> Enum.map(fn {real, imag} ->
      :math.pow(real, 2) + :math.pow(imag, 2)
    end)
    |> Enum.sum()
    
    :math.sqrt(sum_squared)
  end

  defp calculate_coherence_time(amplitudes) do
    # Estimate coherence time based on superposition complexity
    entropy = calculate_amplitude_entropy(amplitudes)
    base_time = 1000.0  # milliseconds
    
    base_time / (1 + entropy)
  end

  defp calculate_amplitude_entropy(amplitudes) do
    probabilities = amplitudes
    |> Enum.map(fn {real, imag} ->
      :math.pow(real, 2) + :math.pow(imag, 2)
    end)
    
    calculate_entropy(probabilities)
  end

  defp calculate_entropy(probabilities) do
    # Shannon entropy: -Σ p log(p)
    probabilities
    |> Enum.filter(&(&1 > 0))
    |> Enum.map(fn p ->
      -p * :math.log2(p)
    end)
    |> Enum.sum()
  end

  defp calculate_wf_entropy(wf) do
    calculate_amplitude_entropy(wf.amplitudes)
  end

  defp calculate_coherence(wf) do
    # Measure of quantum coherence
    off_diagonal_sum = calculate_off_diagonal_coherence(wf.amplitudes)
    diagonal_sum = calculate_diagonal_sum(wf.amplitudes)
    
    if diagonal_sum > 0 do
      off_diagonal_sum / diagonal_sum
    else
      0.0
    end
  end

  defp calculate_off_diagonal_coherence(amplitudes) do
    # Simplified - would calculate actual density matrix off-diagonals
    amplitudes
    |> Enum.map(fn {real, imag} -> abs(imag) end)
    |> Enum.sum()
  end

  defp calculate_diagonal_sum(amplitudes) do
    amplitudes
    |> Enum.map(fn {real, _imag} -> abs(real) end)
    |> Enum.sum()
  end

  defp find_dominant_state(wf) do
    wf.amplitudes
    |> Enum.with_index()
    |> Enum.map(fn {{real, imag}, index} ->
      {:math.pow(real, 2) + :math.pow(imag, 2), index}
    end)
    |> Enum.max_by(fn {prob, _} -> prob end)
    |> elem(1)
    |> then(&Enum.at(wf.basis_states, &1))
  end

  defp calculate_energy_factor(hamiltonian, time_step) do
    # Simplified energy calculation
    # E = ħω, phase evolution = Et/ħ
    energy = hamiltonian[:energy] || 1.0
    energy * time_step
  end

  defp calculate_phase_evolution(hamiltonian, time_step) do
    # Phase evolves as exp(-iEt/ħ)
    calculate_energy_factor(hamiltonian, time_step)
  end

  defp get_default_measurement_operator(state) do
    # Default to computational basis measurement
    Map.get(state.measurement_operators, :computational, %{
      basis: :computational,
      eigenvalues: [0, 1]
    })
  end

  defp initialize_measurement_operators do
    %{
      computational: %{
        basis: :computational,
        eigenvalues: [0, 1],
        eigenvectors: [[{1, 0}, {0, 0}], [{0, 0}, {1, 0}]]
      },
      hadamard: %{
        basis: :hadamard,
        eigenvalues: [1, -1],
        eigenvectors: [
          [{1/:math.sqrt(2), 0}, {1/:math.sqrt(2), 0}],
          [{1/:math.sqrt(2), 0}, {-1/:math.sqrt(2), 0}]
        ]
      },
      pauli_x: %{
        basis: :pauli_x,
        eigenvalues: [1, -1],
        eigenvectors: [
          [{1/:math.sqrt(2), 0}, {1/:math.sqrt(2), 0}],
          [{1/:math.sqrt(2), 0}, {-1/:math.sqrt(2), 0}]
        ]
      }
    }
  end

  defp initialize_environment(opts) do
    %{
      temperature: Keyword.get(opts, :temperature, 300),  # Kelvin
      noise_level: Keyword.get(opts, :noise_level, 0.01),
      coupling_strength: Keyword.get(opts, :coupling_strength, 0.1)
    }
  end

  defp get_wave_function(wf_id, state) do
    case get_in(state.wave_functions, [wf_id]) do
      nil -> {:error, :wave_function_not_found}
      wf -> {:ok, wf}
    end
  end

  defp notify_collapse(wf_id, collapsed_state) do
    # Notify QuantumState about collapse
    send(QuantumState, {:wave_function_collapsed, wf_id, collapsed_state})
    
    # Broadcast collapse event
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "quantum:collapse",
      %{
        type: :wave_function_collapse,
        wave_function_id: wf_id,
        collapsed_state: collapsed_state,
        timestamp: DateTime.utc_now()
      }
    )
  end

  defp generate_wf_id do
    "wf_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp schedule_decoherence_update do
    Process.send_after(self(), :update_decoherence, 100)  # Every 100ms
  end

  defp abs(x) when x < 0, do: -x
  defp abs(x), do: x
end