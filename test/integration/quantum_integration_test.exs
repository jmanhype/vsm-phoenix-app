defmodule VsmPhoenix.Integration.QuantumIntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.QuantumVariety.QuantumVarietyManager
  alias VsmPhoenix.QuantumVariety.EntanglementManager
  alias VsmPhoenix.QuantumVariety.QuantumState
  alias VsmPhoenix.QuantumVariety.QuantumTunnel
  
  @moduletag :integration
  
  setup_all do
    # Initialize quantum subsystem
    {:ok, _} = QuantumVarietyManager.start_link()
    {:ok, _} = EntanglementManager.start_link()
    
    on_exit(fn ->
      # Cleanup quantum states
      QuantumVarietyManager.reset()
      EntanglementManager.clear_all()
    end)
    
    :ok
  end
  
  describe "Quantum State Management" do
    test "create and manage quantum states" do
      # Create initial quantum state
      {:ok, state_id} = QuantumState.create(%{
        system_id: "system1",
        amplitude: 0.8,
        phase: 0.0,
        coherence: 0.9
      })
      
      assert state_id
      
      # Verify state creation
      {:ok, state} = QuantumState.get(state_id)
      assert state.system_id == "system1"
      assert state.amplitude == 0.8
      assert state.coherence == 0.9
      
      # Test state evolution
      {:ok, evolved_state} = QuantumState.evolve(state_id, %{
        time_step: 1.0,
        hamiltonian: "variety_flow"
      })
      
      assert evolved_state.amplitude != 0.8  # Should have evolved
      assert evolved_state.coherence <= 0.9  # May have decreased due to decoherence
    end
    
    test "quantum superposition creation and collapse" do
      # Create superposition of multiple system states
      {:ok, superposition_id} = QuantumState.create_superposition([
        %{system_id: "system1", amplitude: 0.6, phase: 0.0},
        %{system_id: "system4", amplitude: 0.8, phase: 1.57}
      ])
      
      {:ok, superposition} = QuantumState.get(superposition_id)
      
      # Verify normalization
      total_probability = superposition.components
      |> Enum.map(&(&1.amplitude * &1.amplitude))
      |> Enum.sum()
      
      assert_in_delta total_probability, 1.0, 0.001
      
      # Test measurement and collapse
      {:ok, measurement} = QuantumState.measure(superposition_id, "variety_magnitude")
      
      assert measurement.result
      assert measurement.collapsed_state
      assert measurement.measurement_probability >= 0.0
      assert measurement.measurement_probability <= 1.0
      
      # Verify state collapsed
      {:ok, post_measurement_state} = QuantumState.get(superposition_id)
      assert length(post_measurement_state.components) == 1
    end
    
    test "quantum decoherence over time" do
      {:ok, state_id} = QuantumState.create(%{
        system_id: "system1",
        amplitude: 1.0,
        phase: 0.0,
        coherence: 1.0
      })
      
      initial_coherence = 1.0
      
      # Simulate decoherence over multiple time steps
      final_coherence = Enum.reduce(1..10, initial_coherence, fn step, coherence ->
        {:ok, state} = QuantumState.apply_decoherence(state_id, %{
          decoherence_rate: 0.05,
          time_step: 1.0,
          environment_coupling: 0.1
        })
        state.coherence
      end)
      
      assert final_coherence < initial_coherence
      assert final_coherence >= 0.0
    end
  end
  
  describe "Quantum Entanglement" do
    test "create and verify entanglement" do
      # Create entanglement between systems
      {:ok, entanglement_id} = EntanglementManager.create_entanglement([
        "system1", "system4", "system5"
      ], %{
        entanglement_type: "variety_coupling",
        strength: 0.8
      })
      
      assert entanglement_id
      
      # Verify entanglement exists
      {:ok, entanglement} = EntanglementManager.get_entanglement(entanglement_id)
      assert entanglement.systems == ["system1", "system4", "system5"]
      assert entanglement.strength == 0.8
      
      # Test entanglement strength over distance
      entanglement_strength = EntanglementManager.calculate_strength(
        "system1", "system5", entanglement_id
      )
      assert entanglement_strength >= 0.0
      assert entanglement_strength <= 1.0
    end
    
    test "quantum correlation verification" do
      # Create entangled states
      {:ok, entanglement_id} = EntanglementManager.create_entanglement([
        "system1", "system4"
      ], %{entanglement_type: "bell_state", strength: 0.9})
      
      # Measure correlation
      {:ok, correlation} = EntanglementManager.measure_correlation(
        "system1", "system4", "variety_spin"
      )
      
      assert correlation.correlation_coefficient >= -1.0
      assert correlation.correlation_coefficient <= 1.0
      assert correlation.statistical_significance >= 0.0
      
      # For Bell state, should show strong correlation
      if correlation.correlation_coefficient > 0.7 do
        assert correlation.entanglement_verified == true
      end
    end
    
    test "entanglement breaking and restoration" do
      {:ok, entanglement_id} = EntanglementManager.create_entanglement([
        "system1", "system4"
      ], %{entanglement_type: "variety_coupling", strength: 0.8})
      
      # Break entanglement
      {:ok, _} = EntanglementManager.break_entanglement(entanglement_id)
      
      # Verify entanglement is broken
      {:error, :not_found} = EntanglementManager.get_entanglement(entanglement_id)
      
      # Test restoration
      {:ok, new_entanglement_id} = EntanglementManager.restore_entanglement(
        ["system1", "system4"], %{strength: 0.7}
      )
      
      {:ok, restored} = EntanglementManager.get_entanglement(new_entanglement_id)
      assert restored.systems == ["system1", "system4"]
      assert restored.strength == 0.7
    end
  end
  
  describe "Quantum Tunneling" do
    test "variety tunneling between systems" do
      variety_data = %{
        complexity: 0.8,
        entropy: 2.1,
        patterns: ["cyclic", "emergent"],
        energy_level: 5.5
      }
      
      {:ok, tunnel_result} = QuantumTunnel.tunnel_variety(
        "system1", "system5", variety_data
      )
      
      assert tunnel_result.tunnel_id
      assert tunnel_result.transmission_probability >= 0.0
      assert tunnel_result.transmission_probability <= 1.0
      assert tunnel_result.variety_preserved >= 0.0
      assert tunnel_result.variety_preserved <= 1.0
      
      # Verify variety conservation
      input_variety = calculate_variety_measure(variety_data)
      output_variety = calculate_variety_measure(tunnel_result.transmitted_variety)
      
      variety_loss = input_variety - output_variety
      assert variety_loss >= 0.0  # Some loss is expected in tunneling
      assert variety_loss <= input_variety * 0.5  # But not more than 50%
    end
    
    test "quantum barrier penetration" do
      barrier_config = %{
        height: 10.0,
        width: 2.0,
        shape: "rectangular"
      }
      
      particle_config = %{
        energy: 8.0,  # Less than barrier height
        mass: 1.0,
        momentum: 4.0
      }
      
      {:ok, penetration_result} = QuantumTunnel.calculate_penetration(
        barrier_config, particle_config
      )
      
      assert penetration_result.transmission_coefficient >= 0.0
      assert penetration_result.transmission_coefficient <= 1.0
      assert penetration_result.reflection_coefficient >= 0.0
      assert penetration_result.reflection_coefficient <= 1.0
      
      # Conservation: T + R = 1
      total = penetration_result.transmission_coefficient + 
              penetration_result.reflection_coefficient
      assert_in_delta total, 1.0, 0.001
    end
    
    test "multi-dimensional quantum tunneling" do
      # Test tunneling in multi-dimensional variety space
      variety_vector = [0.8, 0.6, 0.9, 0.4]  # 4D variety space
      
      barrier_matrix = [
        [10.0, 2.0, 1.0, 0.5],
        [2.0, 12.0, 1.5, 1.0],
        [1.0, 1.5, 8.0, 2.0],
        [0.5, 1.0, 2.0, 15.0]
      ]
      
      {:ok, tunneling_result} = QuantumTunnel.multi_dimensional_tunnel(
        "system1", "system5", variety_vector, barrier_matrix
      )
      
      assert tunneling_result.transmission_probabilities
      assert length(tunneling_result.transmission_probabilities) == 4
      assert tunneling_result.overall_transmission >= 0.0
      assert tunneling_result.overall_transmission <= 1.0
      
      # Verify each dimension
      Enum.each(tunneling_result.transmission_probabilities, fn prob ->
        assert prob >= 0.0 and prob <= 1.0
      end)
    end
  end
  
  describe "Quantum-Classical Interface" do
    test "quantum state to classical mapping" do
      {:ok, quantum_state_id} = QuantumState.create(%{
        system_id: "system1",
        amplitude: 0.8,
        phase: 1.57,
        coherence: 0.9
      })
      
      {:ok, classical_representation} = QuantumVarietyManager.to_classical(
        quantum_state_id
      )
      
      assert classical_representation.variety_magnitude
      assert classical_representation.variety_phase
      assert classical_representation.certainty_level
      assert classical_representation.complexity_measure
      
      # Verify mapping preserves information
      assert classical_representation.variety_magnitude >= 0.0
      assert classical_representation.certainty_level >= 0.0
      assert classical_representation.certainty_level <= 1.0
    end
    
    test "classical to quantum state promotion" do
      classical_variety = %{
        magnitude: 0.7,
        direction: 2.1,  # Phase equivalent
        uncertainty: 0.1,
        complexity: 0.8
      }
      
      {:ok, quantum_state_id} = QuantumVarietyManager.from_classical(
        "system4", classical_variety
      )
      
      {:ok, quantum_state} = QuantumState.get(quantum_state_id)
      
      assert quantum_state.amplitude == 0.7
      assert_in_delta quantum_state.phase, 2.1, 0.1
      assert quantum_state.coherence >= 0.8  # Should reflect low uncertainty
    end
    
    test "quantum decoherence to classical limit" do
      {:ok, quantum_state_id} = QuantumState.create(%{
        system_id: "system1",
        amplitude: 0.8,
        phase: 1.0,
        coherence: 0.95
      })
      
      # Apply strong decoherence
      {:ok, _} = QuantumState.apply_decoherence(quantum_state_id, %{
        decoherence_rate: 0.9,
        time_step: 10.0,
        environment_coupling: 0.8
      })
      
      # Check if state approaches classical limit
      {:ok, final_state} = QuantumState.get(quantum_state_id)
      
      assert final_state.coherence < 0.1  # Nearly classical
      
      # Convert to classical and verify consistency
      {:ok, classical} = QuantumVarietyManager.to_classical(quantum_state_id)
      assert classical.certainty_level > 0.9  # High certainty in classical limit
    end
  end
  
  describe "Quantum Error Correction" do
    test "detect and correct quantum errors" do
      # Create quantum state with intentional errors
      {:ok, state_id} = QuantumState.create(%{
        system_id: "system1",
        amplitude: 0.8,
        phase: 0.0,
        coherence: 0.9
      })
      
      # Introduce errors
      {:ok, _} = QuantumState.introduce_error(state_id, %{
        error_type: "bit_flip",
        error_probability: 0.1
      })
      
      # Detect errors
      {:ok, error_detection} = QuantumState.detect_errors(state_id)
      
      if error_detection.errors_found do
        assert error_detection.error_types
        assert error_detection.error_locations
        
        # Correct errors
        {:ok, corrected_state} = QuantumState.correct_errors(state_id, error_detection)
        
        assert corrected_state.amplitude
        assert corrected_state.phase
        assert corrected_state.coherence > error_detection.pre_correction_coherence
      end
    end
  end
  
  # Helper functions
  defp calculate_variety_measure(variety_data) do
    # Simple variety measure calculation
    base_measure = variety_data[:complexity] || 0.0
    entropy_contribution = (variety_data[:entropy] || 0.0) / 10.0
    pattern_contribution = length(variety_data[:patterns] || []) * 0.1
    
    base_measure + entropy_contribution + pattern_contribution
  end
end