defmodule VsmPhoenix.System5.QueenIntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System5.Components.{
    PolicyManager,
    ViabilityEvaluator,
    StrategicPlanner,
    AlgedonicProcessor
  }
  
  setup do
    # Ensure components are stopped before each test
    Enum.each([PolicyManager, ViabilityEvaluator, StrategicPlanner, AlgedonicProcessor], fn module ->
      case Process.whereis(module) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end
    end)
    
    # Start Queen which should start all components
    {:ok, queen_pid} = Queen.start_link()
    
    # Give components time to initialize
    Process.sleep(100)
    
    on_exit(fn ->
      if Process.alive?(queen_pid), do: GenServer.stop(queen_pid)
    end)
    
    {:ok, queen_pid: queen_pid}
  end
  
  describe "component initialization" do
    test "all components are started when Queen starts" do
      assert Process.whereis(PolicyManager) != nil
      assert Process.whereis(ViabilityEvaluator) != nil
      assert Process.whereis(StrategicPlanner) != nil
      assert Process.whereis(AlgedonicProcessor) != nil
    end
  end
  
  describe "policy management" do
    test "set_policy delegates to PolicyManager" do
      assert :ok = Queen.set_policy(:test_policy, %{rule: "test"})
      
      # Verify through PolicyManager directly
      {:ok, policies} = PolicyManager.get_all_policies()
      assert Map.has_key?(policies, :test_policy)
      assert policies.test_policy == %{rule: "test"}
    end
  end
  
  describe "viability evaluation" do
    test "evaluate_viability returns viability metrics" do
      {:ok, viability} = Queen.evaluate_viability()
      
      assert is_map(viability)
      assert Map.has_key?(viability, :system_health)
      assert Map.has_key?(viability, :adaptation_capacity)
      assert Map.has_key?(viability, :resource_efficiency)
      assert Map.has_key?(viability, :identity_coherence)
    end
  end
  
  describe "strategic planning" do
    test "get_strategic_direction returns direction data" do
      {:ok, direction} = Queen.get_strategic_direction()
      
      assert is_map(direction)
      assert Map.has_key?(direction, :mission)
      assert Map.has_key?(direction, :vision)
      assert Map.has_key?(direction, :values)
    end
    
    test "make_policy_decision creates a decision" do
      params = %{
        "decision_type" => "resource_allocation",
        "options" => ["increase_budget", "maintain_budget", "reduce_budget"],
        "constraints" => %{"budget" => "limited", "time" => "48 hours"}
      }
      
      {:ok, decision} = Queen.make_policy_decision(params)
      
      assert is_map(decision)
      assert decision.decision_type == "resource_allocation"
      assert decision.selected_option in params["options"]
      assert is_binary(decision.reasoning)
      assert is_float(decision.confidence)
      assert is_list(decision.implementation_steps)
      assert is_map(decision.expected_outcomes)
    end
  end
  
  describe "algedonic processing" do
    test "send_pleasure_signal is processed" do
      # This is async, so we just ensure it doesn't crash
      assert :ok = Queen.send_pleasure_signal(0.8, %{source: "test", reason: "success"})
      
      # Give time for async processing
      Process.sleep(50)
      
      # Check signal was recorded
      {:ok, history} = AlgedonicProcessor.get_signal_history(10)
      assert length(history) > 0
      assert List.first(history).type == :pleasure
    end
    
    test "send_pain_signal is processed" do
      assert :ok = Queen.send_pain_signal(0.6, %{source: "test", reason: "failure"})
      
      # Give time for async processing
      Process.sleep(50)
      
      # Check signal was recorded
      {:ok, history} = AlgedonicProcessor.get_signal_history(10)
      assert length(history) > 0
      assert List.first(history).type == :pain
    end
  end
  
  describe "governance state" do
    test "get_governance_state aggregates all component states" do
      {:ok, state} = Queen.get_governance_state()
      
      assert is_map(state)
      assert Map.has_key?(state, :policies)
      assert Map.has_key?(state, :strategic_direction)
      assert Map.has_key?(state, :viability_metrics)
      assert Map.has_key?(state, :identity)
      assert Map.has_key?(state, :algedonic_state)
      assert Map.has_key?(state, :components_status)
      
      # Check component status
      assert state.components_status.policy_manager == :running
      assert state.components_status.viability_evaluator == :running
      assert state.components_status.strategic_planner == :running
      assert state.components_status.algedonic_processor == :running
    end
  end
  
  describe "identity metrics" do
    test "get_identity_metrics returns comprehensive metrics" do
      metrics = Queen.get_identity_metrics()
      
      assert is_map(metrics)
      assert Map.has_key?(metrics, :coherence)
      assert Map.has_key?(metrics, :policies)
      assert Map.has_key?(metrics, :strategic_alignment)
      assert Map.has_key?(metrics, :decision_consistency)
      assert Map.has_key?(metrics, :identity)
      
      assert is_list(metrics.policies)
      assert is_float(metrics.coherence)
      assert is_float(metrics.strategic_alignment)
      assert is_float(metrics.decision_consistency)
    end
  end
  
  describe "adaptation approval" do
    test "approve_adaptation evaluates and processes proposals" do
      proposal = %{
        type: :process_optimization,
        impact: 0.2,
        urgency: :medium,
        expected_benefit: 0.7,
        cost: 0.3,
        preserves_identity: true
      }
      
      {:ok, decision} = Queen.approve_adaptation(proposal)
      
      assert is_map(decision)
      assert Map.has_key?(decision, :approved)
      assert Map.has_key?(decision, :status)
      assert Map.has_key?(decision, :scores)
      assert Map.has_key?(decision, :conditions)
      assert Map.has_key?(decision, :reasoning)
    end
  end
  
  describe "backward compatibility" do
    test "all original Queen API methods are available" do
      # Test that all public functions exist and work
      assert function_exported?(Queen, :set_policy, 2)
      assert function_exported?(Queen, :evaluate_viability, 0)
      assert function_exported?(Queen, :get_strategic_direction, 0)
      assert function_exported?(Queen, :approve_adaptation, 1)
      assert function_exported?(Queen, :get_identity_metrics, 0)
      assert function_exported?(Queen, :make_policy_decision, 1)
      assert function_exported?(Queen, :send_pleasure_signal, 2)
      assert function_exported?(Queen, :send_pain_signal, 2)
      assert function_exported?(Queen, :get_governance_state, 0)
      assert function_exported?(Queen, :synthesize_adaptive_policy, 2)
    end
  end
end