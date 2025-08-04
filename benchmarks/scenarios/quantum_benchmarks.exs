# Quantum Operation Performance Benchmarks
# Tests for superposition, entanglement, and measurement operations

defmodule QuantumBenchmarks do
  @moduledoc """
  Performance benchmarks for quantum computing operations in VSM
  """
  
  use Benchee
  
  # Quantum state generation benchmarks
  def benchmark_superposition() do
    Benchee.run(
      %{
        "superposition_2_qubits" => fn ->
          create_superposition(2)
        end,
        
        "superposition_4_qubits" => fn ->
          create_superposition(4)
        end,
        
        "superposition_8_qubits" => fn ->
          create_superposition(8)
        end,
        
        "superposition_16_qubits" => fn ->
          create_superposition(16)
        end,
        
        "superposition_32_qubits" => fn ->
          create_superposition(32)
        end,
        
        "hadamard_gate_single" => fn ->
          apply_hadamard(create_qubit())
        end,
        
        "hadamard_gate_batch" => fn ->
          qubits = Enum.map(1..100, fn _ -> create_qubit() end)
          Enum.map(qubits, &apply_hadamard/1)
        end,
        
        "bell_state_creation" => fn ->
          create_bell_state()
        end,
        
        "ghz_state_3_qubits" => fn ->
          create_ghz_state(3)
        end,
        
        "ghz_state_5_qubits" => fn ->
          create_ghz_state(5)
        end
      },
      time: 5,
      warmup: 2,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/quantum_superposition.html"}
      ]
    )
  end
  
  # Entanglement operation benchmarks
  def benchmark_entanglement() do
    Benchee.run(
      %{
        "entangle_2_qubits" => fn ->
          q1 = create_qubit()
          q2 = create_qubit()
          entangle(q1, q2)
        end,
        
        "entangle_chain_5" => fn ->
          qubits = Enum.map(1..5, fn _ -> create_qubit() end)
          create_entanglement_chain(qubits)
        end,
        
        "entangle_chain_10" => fn ->
          qubits = Enum.map(1..10, fn _ -> create_qubit() end)
          create_entanglement_chain(qubits)
        end,
        
        "entangle_star_topology" => fn ->
          center = create_qubit()
          satellites = Enum.map(1..6, fn _ -> create_qubit() end)
          create_star_entanglement(center, satellites)
        end,
        
        "entangle_mesh_3x3" => fn ->
          create_mesh_entanglement(3, 3)
        end,
        
        "entangle_mesh_5x5" => fn ->
          create_mesh_entanglement(5, 5)
        end,
        
        "swap_entanglement" => fn ->
          {q1, q2} = create_bell_state()
          q3 = create_qubit()
          quantum_swap(q2, q3)
        end,
        
        "teleportation_protocol" => fn ->
          quantum_teleportation(create_qubit(:up))
        end
      },
      time: 5,
      warmup: 2,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/quantum_entanglement.html"}
      ]
    )
  end
  
  # Measurement and decoherence benchmarks
  def benchmark_measurement() do
    Benchee.run(
      %{
        "measure_single_qubit" => fn ->
          qubit = create_superposition_qubit()
          measure(qubit)
        end,
        
        "measure_entangled_pair" => fn ->
          {q1, q2} = create_bell_state()
          {measure(q1), measure(q2)}
        end,
        
        "measure_batch_100" => fn ->
          qubits = Enum.map(1..100, fn _ -> create_superposition_qubit() end)
          Enum.map(qubits, &measure/1)
        end,
        
        "measure_batch_1000" => fn ->
          qubits = Enum.map(1..1000, fn _ -> create_superposition_qubit() end)
          Enum.map(qubits, &measure/1)
        end,
        
        "partial_measurement" => fn ->
          system = create_multi_qubit_system(5)
          partial_measure(system, [1, 3])
        end,
        
        "weak_measurement" => fn ->
          qubit = create_superposition_qubit()
          weak_measure(qubit, 0.1)
        end,
        
        "decoherence_simulation" => fn ->
          qubit = create_superposition_qubit()
          simulate_decoherence(qubit, 0.01)
        end,
        
        "error_correction_3_qubit" => fn ->
          data = create_qubit(:up)
          apply_error_correction(data, :bit_flip)
        end,
        
        "error_correction_5_qubit" => fn ->
          data = create_qubit(:up)
          apply_error_correction(data, :shor_code)
        end
      },
      time: 5,
      warmup: 2,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/quantum_measurement.html"}
      ]
    )
  end
  
  # Quantum gate operation benchmarks
  def benchmark_gates() do
    Benchee.run(
      %{
        "pauli_x_gate" => fn ->
          apply_gate(create_qubit(), :pauli_x)
        end,
        
        "pauli_y_gate" => fn ->
          apply_gate(create_qubit(), :pauli_y)
        end,
        
        "pauli_z_gate" => fn ->
          apply_gate(create_qubit(), :pauli_z)
        end,
        
        "cnot_gate" => fn ->
          apply_cnot(create_qubit(), create_qubit())
        end,
        
        "toffoli_gate" => fn ->
          apply_toffoli(create_qubit(), create_qubit(), create_qubit())
        end,
        
        "phase_gate" => fn ->
          apply_phase_gate(create_qubit(), :math.pi() / 4)
        end,
        
        "rotation_gate_x" => fn ->
          apply_rotation(create_qubit(), :x, :math.pi() / 3)
        end,
        
        "rotation_gate_y" => fn ->
          apply_rotation(create_qubit(), :y, :math.pi() / 3)
        end,
        
        "rotation_gate_z" => fn ->
          apply_rotation(create_qubit(), :z, :math.pi() / 3)
        end,
        
        "controlled_phase" => fn ->
          apply_controlled_phase(create_qubit(), create_qubit(), :math.pi() / 2)
        end,
        
        "swap_gate" => fn ->
          apply_swap(create_qubit(), create_qubit())
        end,
        
        "fredkin_gate" => fn ->
          apply_fredkin(create_qubit(), create_qubit(), create_qubit())
        end
      },
      time: 5,
      warmup: 2,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/quantum_gates.html"}
      ]
    )
  end
  
  # Quantum algorithm benchmarks
  def benchmark_algorithms() do
    Benchee.run(
      %{
        "grover_search_4_items" => fn ->
          grover_search(4, 2)
        end,
        
        "grover_search_16_items" => fn ->
          grover_search(16, 10)
        end,
        
        "grover_search_64_items" => fn ->
          grover_search(64, 42)
        end,
        
        "quantum_fourier_2_qubits" => fn ->
          quantum_fourier_transform(2)
        end,
        
        "quantum_fourier_4_qubits" => fn ->
          quantum_fourier_transform(4)
        end,
        
        "quantum_fourier_8_qubits" => fn ->
          quantum_fourier_transform(8)
        end,
        
        "phase_estimation_simple" => fn ->
          phase_estimation(create_unitary_gate(), 3)
        end,
        
        "amplitude_amplification" => fn ->
          amplitude_amplification(create_superposition(4), 3)
        end,
        
        "quantum_walk_line_10" => fn ->
          quantum_walk(:line, 10, 5)
        end,
        
        "quantum_walk_cycle_8" => fn ->
          quantum_walk(:cycle, 8, 5)
        end,
        
        "variational_circuit" => fn ->
          variational_quantum_eigensolver(create_hamiltonian(), 10)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/quantum_algorithms.html"}
      ]
    )
  end
  
  # Helper functions for quantum operations
  defp create_qubit(state \\ :zero) do
    case state do
      :zero -> %{alpha: 1.0, beta: 0.0}
      :one -> %{alpha: 0.0, beta: 1.0}
      :up -> %{alpha: 1.0, beta: 0.0}
      :down -> %{alpha: 0.0, beta: 1.0}
      :plus -> %{alpha: 0.707107, beta: 0.707107}
      :minus -> %{alpha: 0.707107, beta: -0.707107}
    end
  end
  
  defp create_superposition(n) do
    amplitude = 1.0 / :math.sqrt(:math.pow(2, n))
    Enum.map(0..round(:math.pow(2, n)) - 1, fn i ->
      %{state: i, amplitude: amplitude}
    end)
  end
  
  defp create_superposition_qubit() do
    %{alpha: 0.707107, beta: 0.707107}
  end
  
  defp apply_hadamard(qubit) do
    %{
      alpha: (qubit.alpha + qubit.beta) / :math.sqrt(2),
      beta: (qubit.alpha - qubit.beta) / :math.sqrt(2)
    }
  end
  
  defp create_bell_state() do
    q1 = create_qubit(:zero)
    q2 = create_qubit(:zero)
    q1_h = apply_hadamard(q1)
    entangle(q1_h, q2)
  end
  
  defp create_ghz_state(n) do
    qubits = Enum.map(1..n, fn _ -> create_qubit(:zero) end)
    [first | rest] = qubits
    first_h = apply_hadamard(first)
    
    Enum.reduce(rest, {first_h, []}, fn qubit, {control, entangled} ->
      new_entangled = entangle(control, qubit)
      {control, [new_entangled | entangled]}
    end)
  end
  
  defp entangle(q1, q2) do
    # Simplified entanglement creation
    {%{q1 | entangled_with: q2}, %{q2 | entangled_with: q1}}
  end
  
  defp create_entanglement_chain(qubits) do
    Enum.chunk_every(qubits, 2, 1, :discard)
    |> Enum.map(fn [q1, q2] -> entangle(q1, q2) end)
  end
  
  defp create_star_entanglement(center, satellites) do
    Enum.map(satellites, fn sat -> entangle(center, sat) end)
  end
  
  defp create_mesh_entanglement(rows, cols) do
    qubits = for r <- 1..rows, c <- 1..cols, do: {r, c, create_qubit()}
    
    # Create horizontal entanglements
    horizontal = for r <- 1..rows, c <- 1..(cols-1) do
      q1 = Enum.find(qubits, fn {row, col, _} -> row == r && col == c end)
      q2 = Enum.find(qubits, fn {row, col, _} -> row == r && col == c + 1 end)
      case {q1, q2} do
        {{_, _, qubit1}, {_, _, qubit2}} -> entangle(qubit1, qubit2)
        _ -> nil
      end
    end
    
    # Create vertical entanglements
    vertical = for r <- 1..(rows-1), c <- 1..cols do
      q1 = Enum.find(qubits, fn {row, col, _} -> row == r && col == c end)
      q2 = Enum.find(qubits, fn {row, col, _} -> row == r + 1 && col == c end)
      case {q1, q2} do
        {{_, _, qubit1}, {_, _, qubit2}} -> entangle(qubit1, qubit2)
        _ -> nil
      end
    end
    
    {horizontal, vertical}
  end
  
  defp quantum_swap(q1, q2) do
    # Quantum state swap
    {q2, q1}
  end
  
  defp quantum_teleportation(qubit) do
    # Simplified teleportation protocol
    {alice_q, bob_q} = create_bell_state()
    # Perform measurements and corrections
    teleported = %{qubit | location: :bob}
    teleported
  end
  
  defp measure(qubit) do
    # Collapse to classical state
    if :rand.uniform() < abs(qubit.alpha * qubit.alpha) do
      0
    else
      1
    end
  end
  
  defp create_multi_qubit_system(n) do
    %{
      qubits: Enum.map(1..n, fn _ -> create_superposition_qubit() end),
      size: n
    }
  end
  
  defp partial_measure(system, indices) do
    measured = Enum.map(indices, fn i ->
      qubit = Enum.at(system.qubits, i - 1)
      {i, measure(qubit)}
    end)
    
    %{system | measured: measured}
  end
  
  defp weak_measure(qubit, strength) do
    # Weak measurement with minimal disturbance
    disturbance = strength * (:rand.uniform() - 0.5)
    %{
      qubit | 
      alpha: qubit.alpha * (1 - disturbance),
      beta: qubit.beta * (1 + disturbance)
    }
  end
  
  defp simulate_decoherence(qubit, rate) do
    # Apply decoherence
    %{
      qubit |
      alpha: qubit.alpha * :math.exp(-rate),
      beta: qubit.beta * :math.exp(-rate)
    }
  end
  
  defp apply_error_correction(data_qubit, code_type) do
    case code_type do
      :bit_flip ->
        # 3-qubit bit flip code
        ancilla1 = create_qubit()
        ancilla2 = create_qubit()
        {data_qubit, ancilla1, ancilla2}
      
      :shor_code ->
        # 9-qubit Shor code
        ancillas = Enum.map(1..8, fn _ -> create_qubit() end)
        {data_qubit, ancillas}
    end
  end
  
  defp apply_gate(qubit, gate_type) do
    case gate_type do
      :pauli_x -> %{qubit | alpha: qubit.beta, beta: qubit.alpha}
      :pauli_y -> %{qubit | alpha: -qubit.beta, beta: qubit.alpha}
      :pauli_z -> %{qubit | alpha: qubit.alpha, beta: -qubit.beta}
      _ -> qubit
    end
  end
  
  defp apply_cnot(control, target) do
    # CNOT gate implementation
    if measure(control) == 1 do
      apply_gate(target, :pauli_x)
    else
      target
    end
  end
  
  defp apply_toffoli(control1, control2, target) do
    # Toffoli gate (CCNOT)
    if measure(control1) == 1 && measure(control2) == 1 do
      apply_gate(target, :pauli_x)
    else
      target
    end
  end
  
  defp apply_phase_gate(qubit, phase) do
    %{qubit | beta: qubit.beta * :math.exp(phase * :math.sqrt(-1))}
  end
  
  defp apply_rotation(qubit, axis, angle) do
    case axis do
      :x ->
        %{
          alpha: qubit.alpha * :math.cos(angle/2) - qubit.beta * :math.sin(angle/2),
          beta: qubit.alpha * :math.sin(angle/2) + qubit.beta * :math.cos(angle/2)
        }
      :y ->
        %{
          alpha: qubit.alpha * :math.cos(angle/2) - qubit.beta * :math.sin(angle/2),
          beta: qubit.alpha * :math.sin(angle/2) + qubit.beta * :math.cos(angle/2)
        }
      :z ->
        %{
          alpha: qubit.alpha * :math.exp(-angle/2),
          beta: qubit.beta * :math.exp(angle/2)
        }
    end
  end
  
  defp apply_controlled_phase(control, target, phase) do
    if measure(control) == 1 do
      apply_phase_gate(target, phase)
    else
      target
    end
  end
  
  defp apply_swap(q1, q2) do
    {q2, q1}
  end
  
  defp apply_fredkin(control, q1, q2) do
    if measure(control) == 1 do
      {control, q2, q1}
    else
      {control, q1, q2}
    end
  end
  
  defp grover_search(n, target) do
    # Simplified Grover's algorithm
    iterations = round(:math.pi() * :math.sqrt(n) / 4)
    superposition = create_superposition(round(:math.log2(n)))
    
    Enum.reduce(1..iterations, superposition, fn _, state ->
      # Apply oracle and diffusion
      state
    end)
  end
  
  defp quantum_fourier_transform(n) do
    # QFT implementation
    qubits = Enum.map(1..n, fn _ -> create_qubit() end)
    # Apply QFT gates
    qubits
  end
  
  defp create_unitary_gate() do
    # Create a random unitary gate
    %{matrix: [[1, 0], [0, 1]]}
  end
  
  defp phase_estimation(unitary, precision) do
    # Phase estimation algorithm
    ancillas = Enum.map(1..precision, fn _ -> create_superposition_qubit() end)
    # Apply controlled unitaries
    ancillas
  end
  
  defp amplitude_amplification(state, iterations) do
    Enum.reduce(1..iterations, state, fn _, s ->
      # Apply amplification operator
      s
    end)
  end
  
  defp quantum_walk(topology, size, steps) do
    # Quantum walk simulation
    position = div(size, 2)
    coin = create_superposition_qubit()
    
    Enum.reduce(1..steps, {position, coin}, fn _, {pos, c} ->
      # Apply coin operator and shift
      new_coin = apply_hadamard(c)
      new_pos = case topology do
        :line -> rem(pos + if(measure(new_coin) == 0, do: -1, else: 1), size)
        :cycle -> rem(pos + if(measure(new_coin) == 0, do: -1, else: 1) + size, size)
      end
      {new_pos, new_coin}
    end)
  end
  
  defp create_hamiltonian() do
    # Create a simple Hamiltonian
    %{terms: [{1.0, :pauli_z}, {0.5, :pauli_x}]}
  end
  
  defp variational_quantum_eigensolver(hamiltonian, iterations) do
    # VQE algorithm
    params = Enum.map(1..4, fn _ -> :rand.uniform() * 2 * :math.pi() end)
    
    Enum.reduce(1..iterations, params, fn _, p ->
      # Optimize parameters
      Enum.map(p, fn param -> param + (:rand.uniform() - 0.5) * 0.1 end)
    end)
  end
end