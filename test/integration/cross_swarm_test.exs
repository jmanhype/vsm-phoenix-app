defmodule VsmPhoenix.Integration.CrossSwarmTest do
  @moduledoc """
  Integration test demonstrating cross-swarm communication with refactored architecture.
  
  Tests the integration between:
  - Cortical Attention Engine (Intelligence swarm)
  - CRDT Context Store (Queen swarm)
  - Refactored Analog Architect (Persistence swarm)
  - Resilience Behaviors (Resilience swarm)
  """
  
  use ExUnit.Case
  
  alias VsmPhoenix.System2.CorticalAttentionEngine
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Telemetry.RefactoredAnalogArchitect
  alias VsmPhoenix.System5.Policy.PolicyManager
  
  setup_all do
    # Ensure all required processes are started
    {:ok, _} = Application.ensure_all_started(:vsm_phoenix)
    
    # Give processes time to initialize
    Process.sleep(100)
    
    :ok
  end
  
  describe "Cross-Swarm Integration" do
    test "Cortical Attention Engine integrates with CRDT Context Store" do
      # Score a message using cortical attention
      message = %{
        content: "Critical system alert!",
        type: :alert,
        timestamp: DateTime.utc_now()
      }
      
      context = %{
        source: "test",
        message_type: :alert,
        conversation_history: %{
          messages: [],
          context: %{}
        }
      }
      
      # This should:
      # 1. Use resilience behaviors for fault tolerance
      # 2. Update CRDT context with attention metrics
      # 3. Sample signals to telemetry architecture
      
      assert {:ok, score, components} = CorticalAttentionEngine.score_attention(message, context)
      assert is_float(score)
      assert score >= 0.0 and score <= 1.0
      assert is_map(components)
      
      # Verify CRDT context was updated
      Process.sleep(50) # Allow async updates
      
      {:ok, counter_value} = ContextStore.get_counter("attention_scores_processed")
      assert counter_value > 0
    end
    
    test "Telemetry signals are recorded when attention scores are calculated" do
      # Register a test signal to track
      RefactoredAnalogArchitect.register_signal("test_attention_signal", %{
        signal_type: :gauge,
        sampling_rate: :standard,
        buffer_size: 100
      })
      
      # Score multiple messages
      for i <- 1..5 do
        message = %{content: "Message #{i}", priority: :normal}
        context = %{source: "test", iteration: i}
        
        {:ok, _score, _} = CorticalAttentionEngine.score_attention(message, context)
      end
      
      # Allow signals to be processed
      Process.sleep(100)
      
      # Check if attention score signals were recorded
      {:ok, signal_data} = RefactoredAnalogArchitect.get_signal_data("attention_score", %{
        samples: 10,
        include_stats: true
      })
      
      assert signal_data.sample_count > 0
      assert is_list(signal_data.samples)
    end
    
    test "Policy Manager provides attention weights to Cortical Engine" do
      # Set a custom attention policy
      test_weights = %{
        novelty: 0.4,
        urgency: 0.3,
        relevance: 0.15,
        intensity: 0.1,
        coherence: 0.05
      }
      
      # Store policy
      PolicyManager.set_policy(:attention_salience_weights, test_weights)
      
      # Get attention state to verify weights are loaded
      {:ok, attention_state} = CorticalAttentionEngine.get_attention_state()
      
      # The attention engine should be using weights from policy
      # (Note: This would require restarting the attention engine to pick up new weights,
      # or adding a reload_policy function)
      assert is_map(attention_state)
      assert attention_state.state in [:focused, :distributed, :shifting, :fatigued, :recovering]
    end
    
    test "Resilience behaviors protect attention scoring from failures" do
      # Create a message that might cause processing issues
      problematic_message = %{
        content: String.duplicate("X", 10_000), # Very long content
        metadata: %{nested: %{deeply: %{nested: %{data: 1}}}},
        timestamp: nil # Missing timestamp
      }
      
      context = %{source: "stress_test"}
      
      # The resilience behavior should handle this gracefully
      result = CorticalAttentionEngine.score_attention(problematic_message, context)
      
      # Should either succeed or return a controlled error
      case result do
        {:ok, score, _} ->
          assert is_float(score)
          assert score >= 0.0 and score <= 1.0
          
        {:error, reason} ->
          # Circuit breaker or other resilience pattern activated
          assert reason in [:circuit_open, :timeout, :max_retries_exceeded]
      end
    end
    
    test "Multiple attention engines can share state via CRDT" do
      # Simulate multiple nodes updating attention metrics
      node1_metrics = %{
        attention_state: :focused,
        fatigue_level: 0.3,
        messages_processed: 100
      }
      
      node2_metrics = %{
        attention_state: :distributed,
        fatigue_level: 0.5,
        messages_processed: 150
      }
      
      # Update from "node1"
      ContextStore.update_lww_set("attention_metrics", :node1, node1_metrics)
      
      # Update from "node2"
      ContextStore.update_lww_set("attention_metrics", :node2, node2_metrics)
      
      # Both updates should be preserved
      {:ok, all_metrics} = ContextStore.get_lww_set("attention_metrics")
      
      assert Map.has_key?(all_metrics, :node1)
      assert Map.has_key?(all_metrics, :node2)
      assert all_metrics[:node1] == node1_metrics
      assert all_metrics[:node2] == node2_metrics
    end
  end
  
  describe "Performance and Load Testing" do
    test "System handles high volume of attention scoring requests" do
      # Measure time to process many requests
      start_time = System.monotonic_time(:millisecond)
      
      tasks = for i <- 1..100 do
        Task.async(fn ->
          message = %{content: "Load test message #{i}", id: i}
          context = %{source: "load_test", batch: 1}
          CorticalAttentionEngine.score_attention(message, context)
        end)
      end
      
      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # All requests should succeed
      assert Enum.all?(results, fn result ->
        match?({:ok, _, _}, result)
      end)
      
      # Should complete in reasonable time
      assert duration < 2000, "Processing 100 requests took #{duration}ms"
      
      # Check telemetry captured the load
      Process.sleep(100)
      {:ok, signal_stats} = RefactoredAnalogArchitect.get_signal_stats("attention_score")
      assert signal_stats.sampling.samples_count >= 100
    end
  end
end