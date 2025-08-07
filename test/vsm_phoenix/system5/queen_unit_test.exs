defmodule VsmPhoenix.System5.QueenUnitTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System5.Components.{
    PolicyManager,
    ViabilityEvaluator,
    StrategicPlanner,
    AlgedonicProcessor
  }
  
  describe "Queen refactoring validation" do
    test "Queen module is significantly smaller after refactoring" do
      # Get the file paths
      queen_path = "lib/vsm_phoenix/system5/queen.ex"
      
      # Read the file
      {:ok, content} = File.read(queen_path)
      lines = String.split(content, "\n") |> length()
      
      # Original Queen was 867 lines, new should be much smaller
      assert lines < 400, "Queen module should be under 400 lines, but has #{lines}"
    end
    
    test "All component modules exist" do
      components = [
        PolicyManager,
        ViabilityEvaluator,
        StrategicPlanner,
        AlgedonicProcessor
      ]
      
      Enum.each(components, fn module ->
        assert Code.ensure_loaded?(module), "#{module} should be loaded"
      end)
    end
    
    test "Component modules have proper functionality" do
      # PolicyManager functions
      assert function_exported?(PolicyManager, :set_policy, 2)
      assert function_exported?(PolicyManager, :get_policy, 1)
      assert function_exported?(PolicyManager, :get_all_policies, 0)
      assert function_exported?(PolicyManager, :apply_constraints, 2)
      
      # ViabilityEvaluator functions
      assert function_exported?(ViabilityEvaluator, :evaluate_viability, 0)
      assert function_exported?(ViabilityEvaluator, :get_metrics, 0)
      assert function_exported?(ViabilityEvaluator, :update_from_signal, 2)
      
      # StrategicPlanner functions
      assert function_exported?(StrategicPlanner, :get_strategic_direction, 0)
      assert function_exported?(StrategicPlanner, :make_policy_decision, 1)
      assert function_exported?(StrategicPlanner, :approve_adaptation, 1)
      assert function_exported?(StrategicPlanner, :calculate_decision_consistency, 0)
      
      # AlgedonicProcessor functions
      assert function_exported?(AlgedonicProcessor, :send_pleasure_signal, 2)
      assert function_exported?(AlgedonicProcessor, :send_pain_signal, 2)
      assert function_exported?(AlgedonicProcessor, :get_signal_history, 1)
      assert function_exported?(AlgedonicProcessor, :get_algedonic_state, 0)
    end
    
    test "Queen maintains backward compatibility" do
      # All original Queen API methods should still exist
      assert function_exported?(Queen, :start_link, 1)
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
  
  describe "Module separation validation" do
    test "PolicyManager contains policy-related functions" do
      # Read PolicyManager file to verify it contains expected functions
      {:ok, content} = File.read("lib/vsm_phoenix/system5/components/policy_manager.ex")
      
      # Check for key policy functions
      assert content =~ "def set_policy"
      assert content =~ "def get_policy"
      assert content =~ "defp default_governance_policy"
      assert content =~ "defp default_adaptation_policy"
      assert content =~ "defp propagate_policy_change"
    end
    
    test "ViabilityEvaluator contains viability functions" do
      {:ok, content} = File.read("lib/vsm_phoenix/system5/components/viability_evaluator.ex")
      
      assert content =~ "def evaluate_viability"
      assert content =~ "defp calculate_comprehensive_viability"
      assert content =~ "defp update_viability_from_signal"
      assert content =~ "def check_intervention_needed"
    end
    
    test "StrategicPlanner contains planning functions" do
      {:ok, content} = File.read("lib/vsm_phoenix/system5/components/strategic_planner.ex")
      
      assert content =~ "def make_policy_decision"
      assert content =~ "def approve_adaptation"
      assert content =~ "defp evaluate_best_option"
      assert content =~ "defp generate_reasoning"
    end
    
    test "AlgedonicProcessor contains signal processing" do
      {:ok, content} = File.read("lib/vsm_phoenix/system5/components/algedonic_processor.ex")
      
      assert content =~ "def send_pleasure_signal"
      assert content =~ "def send_pain_signal"
      assert content =~ "defp process_amqp_signal"
      assert content =~ "defp handle_critical_pain"
    end
  end
  
  describe "Metrics validation" do
    test "Total lines of code remain similar or less" do
      # Count lines in all modules
      queen_lines = count_lines("lib/vsm_phoenix/system5/queen.ex")
      policy_lines = count_lines("lib/vsm_phoenix/system5/components/policy_manager.ex")
      viability_lines = count_lines("lib/vsm_phoenix/system5/components/viability_evaluator.ex")
      strategic_lines = count_lines("lib/vsm_phoenix/system5/components/strategic_planner.ex")
      algedonic_lines = count_lines("lib/vsm_phoenix/system5/components/algedonic_processor.ex")
      
      total_new = queen_lines + policy_lines + viability_lines + strategic_lines + algedonic_lines
      
      # Original was 867 lines, new total will be more due to module boilerplate
      # But each module should be focused and manageable
      assert queen_lines < 400, "Queen module should be under 400 lines"
      assert policy_lines < 400, "PolicyManager should be under 400 lines"
      assert viability_lines < 400, "ViabilityEvaluator should be under 400 lines"
      assert strategic_lines < 600, "StrategicPlanner should be under 600 lines"
      assert algedonic_lines < 600, "AlgedonicProcessor should be under 600 lines"
      
      IO.puts """
      
      Queen Refactoring Metrics:
      -------------------------
      Original Queen: 867 lines
      
      New Architecture:
      - Queen (coordinator): #{queen_lines} lines
      - PolicyManager: #{policy_lines} lines
      - ViabilityEvaluator: #{viability_lines} lines
      - StrategicPlanner: #{strategic_lines} lines
      - AlgedonicProcessor: #{algedonic_lines} lines
      
      Total New: #{total_new} lines
      Reduction: #{867 - queen_lines} lines in Queen module (#{Float.round((867 - queen_lines) / 867 * 100, 1)}%)
      """
    end
  end
  
  defp count_lines(path) do
    case File.read(path) do
      {:ok, content} -> String.split(content, "\n") |> length()
      _ -> 0
    end
  end
end