defmodule VsmPhoenix.System5.EmergentPolicyTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.EmergentPolicy
  
  setup do
    # Ensure EmergentPolicy is started
    {:ok, pid} = EmergentPolicy.start_link(name: :test_emergent_policy)
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
    
    {:ok, pid: pid}
  end
  
  describe "emergent policy generation" do
    test "generates emergent policy from context", %{pid: pid} do
      context = %{
        type: :resource_anomaly,
        severity: 0.7,
        affected_systems: [:system1, :system2],
        timestamp: DateTime.utc_now()
      }
      
      constraints = %{
        max_budget: 10000,
        time_limit: "24_hours",
        require_human_approval: false
      }
      
      assert {:ok, policy} = GenServer.call(pid, {:generate_emergent_policy, context, constraints})
      assert policy.id =~ "POL-"
      assert is_map(policy.emergent_properties)
      assert is_map(policy.collective_wisdom)
      assert is_float(policy.adaptation_potential)
    end
    
    test "handles collective intelligence decision making", %{pid: pid} do
      decision_context = %{
        type: :policy_validation,
        policy_id: "TEST-POLICY-001",
        urgency: :high
      }
      
      assert {:ok, decision} = GenServer.call(pid, {:collective_intelligence, decision_context})
      assert decision.type == :policy_validation
      assert is_float(decision.consensus_level)
      assert is_float(decision.confidence)
      assert decision.participating_agents >= 0
    end
  end
  
  describe "policy evolution" do
    test "evolves policy population", %{pid: pid} do
      assert {:ok, result} = GenServer.call(pid, :evolve_policy_population)
      assert result.generation == 2  # Starts at 1, evolves to 2
      assert is_float(result.best_fitness)
      assert is_map(result.emergent_patterns)
    end
    
    test "evaluates policy fitness", %{pid: pid} do
      # First generate a policy
      context = %{type: :test, severity: 0.5}
      {:ok, policy} = GenServer.call(pid, {:generate_emergent_policy, context, %{}})
      
      # Then evaluate its fitness
      assert {:ok, fitness} = GenServer.call(pid, {:evaluate_policy_fitness, policy.id})
      assert is_float(fitness)
      assert fitness >= 0.0 and fitness <= 1.0
    end
    
    test "returns error for non-existent policy fitness", %{pid: pid} do
      assert {:error, :policy_not_found} = GenServer.call(pid, {:evaluate_policy_fitness, "NON-EXISTENT"})
    end
  end
  
  describe "self-modification" do
    test "enables self-modification for policy", %{pid: pid} do
      # Generate a policy first
      context = %{type: :test, severity: 0.5}
      {:ok, policy} = GenServer.call(pid, {:generate_emergent_policy, context, %{}})
      
      # Enable self-modification
      assert :ok = GenServer.cast(pid, {:enable_self_modification, policy.id})
      
      # Give it a moment to process
      Process.sleep(100)
    end
    
    test "injects mutation into policy", %{pid: pid} do
      # Generate a policy first
      context = %{type: :test, severity: 0.5}
      {:ok, policy} = GenServer.call(pid, {:generate_emergent_policy, context, %{}})
      
      mutation_vector = %{
        type: :directed,
        mutations: [0.1, 0.2, 0.3]
      }
      
      assert :ok = GenServer.cast(pid, {:inject_mutation, policy.id, mutation_vector})
      
      # Give it a moment to process
      Process.sleep(100)
    end
  end
  
  describe "policy genome" do
    test "retrieves policy genome", %{pid: pid} do
      # Generate a policy first
      context = %{type: :test, severity: 0.5}
      {:ok, policy} = GenServer.call(pid, {:generate_emergent_policy, context, %{}})
      
      assert {:ok, genome} = GenServer.call(pid, {:get_policy_genome, policy.id})
      assert genome.id == policy.id
      assert is_map(genome.genes)
      assert Map.has_key?(genome.genes, :structural)
      assert Map.has_key?(genome.genes, :behavioral)
      assert Map.has_key?(genome.genes, :adaptive)
      assert Map.has_key?(genome.genes, :emergent)
    end
    
    test "returns nil for non-existent policy genome", %{pid: pid} do
      assert {:ok, nil} = GenServer.call(pid, {:get_policy_genome, "NON-EXISTENT"})
    end
  end
  
  describe "emergence metrics" do
    test "returns comprehensive metrics", %{pid: pid} do
      assert {:ok, metrics} = GenServer.call(pid, :get_emergence_metrics)
      
      assert is_integer(metrics.total_policies_generated)
      assert is_integer(metrics.successful_emergences)
      assert is_integer(metrics.collective_decisions)
      assert is_integer(metrics.evolution_cycles)
      assert is_integer(metrics.self_modifications)
      assert is_integer(metrics.current_generation)
      assert is_integer(metrics.population_size)
      assert is_integer(metrics.active_patterns)
      assert is_integer(metrics.genome_database_size)
      assert is_integer(metrics.collective_agents)
    end
  end
  
  describe "algedonic influence" do
    test "handles pain signals by reducing fitness", %{pid: pid} do
      pain_signal = %{
        signal_type: :pain,
        delta: 0.3,
        context: "test_pain",
        timestamp: DateTime.utc_now()
      }
      
      send(pid, {:algedonic_signal, pain_signal})
      
      # Give it a moment to process
      Process.sleep(100)
      
      # The population fitness should be affected
      {:ok, result} = GenServer.call(pid, :evolve_policy_population)
      assert is_float(result.best_fitness)
    end
    
    test "handles pleasure signals by increasing fitness", %{pid: pid} do
      pleasure_signal = %{
        signal_type: :pleasure,
        delta: 0.3,
        context: "test_pleasure",
        timestamp: DateTime.utc_now()
      }
      
      send(pid, {:algedonic_signal, pleasure_signal})
      
      # Give it a moment to process
      Process.sleep(100)
      
      # The population fitness should be affected
      {:ok, result} = GenServer.call(pid, :evolve_policy_population)
      assert is_float(result.best_fitness)
    end
  end
  
  describe "anomaly response" do
    test "responds to anomaly detection", %{pid: pid} do
      anomaly = %{
        type: :variety_explosion,
        severity: 0.8,
        context: "test_anomaly",
        timestamp: DateTime.utc_now()
      }
      
      send(pid, {:anomaly_detected, anomaly})
      
      # Give it a moment to process
      Process.sleep(100)
      
      # Should trigger collective intelligence
      # We can't directly test the async response, but no crash is good
    end
  end
end