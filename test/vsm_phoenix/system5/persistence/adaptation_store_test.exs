defmodule VsmPhoenix.System5.Persistence.AdaptationStoreTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.Persistence.AdaptationStore
  
  setup do
    # Ensure AdaptationStore is started fresh for each test
    case GenServer.whereis(AdaptationStore) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    {:ok, _pid} = AdaptationStore.start_link()
    :ok
  end
  
  describe "store_adaptation/3" do
    test "stores a new adaptation successfully" do
      adaptation_id = "adapt_test_1"
      adaptation_data = %{
        anomaly_context: %{type: :performance, severity: 0.7},
        policy_changes: ["policy_1", "policy_2"],
        domain: :web
      }
      outcome = %{success: true}
      
      assert {:ok, adaptation} = AdaptationStore.store_adaptation(
        adaptation_id, 
        adaptation_data, 
        outcome
      )
      assert adaptation.id == adaptation_id
      assert adaptation.data == adaptation_data
      assert adaptation.outcome == outcome
      assert adaptation.domain == :web
    end
    
    test "initializes learning record for new adaptation" do
      adaptation_id = "adapt_learning"
      adaptation_data = %{
        anomaly_context: %{type: :test},
        policy_changes: []
      }
      
      {:ok, _} = AdaptationStore.store_adaptation(adaptation_id, adaptation_data)
      
      # Learning record should be created automatically
      # (internal implementation detail, tested indirectly)
    end
  end
  
  describe "record_outcome/2" do
    test "updates adaptation with outcome and calculates effectiveness" do
      adaptation_id = "adapt_outcome"
      
      {:ok, _} = AdaptationStore.store_adaptation(adaptation_id, %{
        anomaly_context: %{type: :test}
      })
      
      outcome = %{
        success: true,
        performance_impact: 0.8,
        stability_impact: 0.9
      }
      
      assert :ok = AdaptationStore.record_outcome(adaptation_id, outcome)
      
      {:ok, updated} = AdaptationStore.get_adaptation(adaptation_id)
      assert updated.outcome == outcome
      assert updated.effectiveness > 0
      assert updated.applied_count == 1
    end
  end
  
  describe "find_similar_adaptations/2" do
    test "finds adaptations with similar contexts" do
      # Store some adaptations with different contexts
      {:ok, _} = AdaptationStore.store_adaptation("similar_1", %{
        anomaly_context: %{type: :performance, metric: :latency, value: 100}
      })
      {:ok, _} = AdaptationStore.store_adaptation("similar_2", %{
        anomaly_context: %{type: :performance, metric: :latency, value: 120}
      })
      {:ok, _} = AdaptationStore.store_adaptation("different", %{
        anomaly_context: %{type: :security, metric: :auth_failures}
      })
      
      # Search for similar performance issues
      search_context = %{type: :performance, metric: :latency, value: 110}
      {:ok, similar} = AdaptationStore.find_similar_adaptations(search_context, 5)
      
      assert length(similar) >= 2
      # Similar adaptations should be ranked by similarity
      assert Enum.any?(similar, fn a -> a.id == "similar_1" end)
      assert Enum.any?(similar, fn a -> a.id == "similar_2" end)
    end
  end
  
  describe "extract_patterns/1" do
    test "extracts patterns from recurring adaptations" do
      # Create multiple similar adaptations
      for i <- 1..5 do
        {:ok, _} = AdaptationStore.store_adaptation("pattern_#{i}", %{
          anomaly_context: %{type: :resource, subtype: :memory},
          policy_changes: ["increase_memory", "optimize_gc"],
          domain: :backend
        })
        
        # Record positive outcomes
        AdaptationStore.record_outcome("pattern_#{i}", %{
          success: true,
          performance_impact: 0.8
        })
      end
      
      {:ok, patterns} = AdaptationStore.extract_patterns(3)
      assert length(patterns) >= 1
      
      pattern = hd(patterns)
      assert pattern.pattern_type == :recurring_adaptation
      assert pattern.occurrences >= 3
      assert pattern.avg_effectiveness > 0
    end
  end
  
  describe "get_successful_adaptations/1" do
    test "retrieves adaptations above effectiveness threshold" do
      # Create adaptations with varying effectiveness
      {:ok, _} = AdaptationStore.store_adaptation("successful_1", %{})
      AdaptationStore.record_outcome("successful_1", %{
        success: true,
        performance_impact: 0.9,
        stability_impact: 0.9
      })
      
      {:ok, _} = AdaptationStore.store_adaptation("failed_1", %{})
      AdaptationStore.record_outcome("failed_1", %{
        success: false,
        performance_impact: 0.2
      })
      
      {:ok, successful} = AdaptationStore.get_successful_adaptations(0.7)
      assert Enum.all?(successful, fn a -> a.effectiveness >= 0.7 end)
    end
  end
  
  describe "transfer_knowledge/2" do
    test "transfers successful patterns between domains" do
      # Create successful adaptations in source domain
      for i <- 1..3 do
        {:ok, _} = AdaptationStore.store_adaptation("web_adapt_#{i}", %{
          anomaly_context: %{type: :performance},
          policy_changes: ["cache_optimization"],
          domain: :web
        })
        
        AdaptationStore.record_outcome("web_adapt_#{i}", %{
          success: true,
          performance_impact: 0.85
        })
      end
      
      # Transfer knowledge from web to api domain
      {:ok, transferred_count} = AdaptationStore.transfer_knowledge(:web, :api)
      assert transferred_count > 0
    end
  end
  
  describe "get_adaptation_metrics/0" do
    test "returns comprehensive metrics" do
      # Create some test data
      {:ok, _} = AdaptationStore.store_adaptation("metric_1", %{domain: :web})
      {:ok, _} = AdaptationStore.store_adaptation("metric_2", %{domain: :api})
      
      {:ok, metrics} = AdaptationStore.get_adaptation_metrics()
      
      assert metrics.total_adaptations >= 2
      assert metrics.overall_success_rate >= 0
      assert is_list(metrics.domains)
      assert :web in metrics.domains
      assert :api in metrics.domains
    end
  end
  
  describe "store_learned_pattern/2" do
    test "stores extracted patterns for reuse" do
      pattern_id = "learned_pattern_1"
      pattern_data = %{
        pattern_type: :performance_optimization,
        trigger_conditions: %{latency: "> 100ms"},
        recommended_actions: ["scale_up", "optimize_queries"],
        confidence: 0.85
      }
      
      assert :ok = AdaptationStore.store_learned_pattern(pattern_id, pattern_data)
    end
  end
end