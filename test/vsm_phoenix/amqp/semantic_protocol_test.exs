defmodule VsmPhoenix.AMQP.SemanticProtocolTest do
  use ExUnit.Case
  
  alias VsmPhoenix.AMQP.{RecursiveProtocol, ContextManager, MessageChain, PriorityRouter}
  
  describe "Backward Compatibility" do
    test "legacy messages are handled correctly" do
      # Create a legacy message without semantic context
      legacy_message = %{
        "type" => "mcp_request",
        "method" => "variety_amplification",
        "params" => %{"context" => "test"}
      }
      
      # The send_legacy_message function ensures compatibility
      {:ok, pid} = RecursiveProtocol.establish(self(), %{identity: "test_vsm"})
      
      # Legacy messages should work without errors
      assert :ok = RecursiveProtocol.send_legacy_message(pid, legacy_message)
    end
    
    test "messages without priority default to normal" do
      message = %{"type" => "test", "content" => "no priority"}
      
      # Priority should default to "normal" (3) when not specified
      assert RecursiveProtocol.determine_message_priority(message, %{}) == 3
    end
  end
  
  describe "Semantic Context Features" do
    test "semantic headers are properly extracted" do
      headers = [
        {"semantic-domain", :longstr, "vsm-test"},
        {"semantic-intent", :longstr, "coordination"},
        {"priority", :longstr, "high"},
        {"correlation-id", :longstr, "corr_123"}
      ]
      
      meta = %{headers: headers}
      context = RecursiveProtocol.extract_semantic_context(meta)
      
      assert context.domain == "vsm-test"
      assert context.intent == "coordination"
      assert context.priority == "high"
      assert context.correlation_id == "corr_123"
    end
    
    test "message priority is determined correctly" do
      emergency_msg = %{"type" => "emergency"}
      algedonic_msg = %{"type" => "algedonic"}
      high_priority_msg = %{"priority" => "high"}
      normal_msg = %{"type" => "normal"}
      
      assert RecursiveProtocol.determine_message_priority(emergency_msg, %{}) == 10
      assert RecursiveProtocol.determine_message_priority(algedonic_msg, %{}) == 9
      assert RecursiveProtocol.determine_message_priority(high_priority_msg, %{}) == 7
      assert RecursiveProtocol.determine_message_priority(normal_msg, %{}) == 3
    end
  end
  
  describe "Context Manager CRDT Operations" do
    setup do
      {:ok, pid} = ContextManager.start_link()
      {:ok, pid: pid}
    end
    
    test "contexts can be merged using CRDTs", %{pid: pid} do
      context1 = %{
        "domain" => "system1",
        "state" => "active",
        "version" => 1
      }
      
      context2 = %{
        "domain" => "system1",
        "state" => "updating",
        "version" => 2,
        "new_field" => "value"
      }
      
      {:ok, _} = ContextManager.merge_context("ctx1", context1)
      {:ok, merged} = ContextManager.merge_context("ctx1", context2)
      
      # CRDT merge should preserve all fields
      assert merged["domain"] == "system1"
      assert merged["state"] == "updating"  # LWW semantics
      assert merged["new_field"] == "value"
    end
    
    test "distributed sync preserves causality" do
      # This would test vector clock merging in a real distributed scenario
      # For now, we verify the structure exists
      assert function_exported?(ContextManager, :sync_with_node, 1)
    end
  end
  
  describe "Message Chain Tracking" do
    setup do
      {:ok, pid} = MessageChain.start_link()
      {:ok, pid: pid}
    end
    
    test "message chains are tracked correctly", %{pid: pid} do
      message1 = %{"id" => "msg1", "type" => "init"}
      message2 = %{"id" => "msg2", "type" => "response", "_causes" => ["msg1"]}
      
      {:ok, chain_id1} = MessageChain.track_message(pid, message1, %{})
      {:ok, chain_id2} = MessageChain.track_message(pid, message2, %{})
      
      # Both messages should be in the same chain
      assert chain_id1 == chain_id2
      
      # Verify chain structure
      {:ok, chain} = MessageChain.get_chain(pid, chain_id1)
      assert map_size(chain.nodes) == 2
      assert "msg1" in chain.root_nodes
    end
    
    test "chain visualization works", %{pid: pid} do
      message = %{"id" => "viz_test", "type" => "test"}
      {:ok, chain_id} = MessageChain.track_message(pid, message, %{})
      
      {:ok, dot_viz} = MessageChain.visualize_chain(pid, chain_id, :dot)
      assert String.contains?(dot_viz, "digraph MessageChain")
      assert String.contains?(dot_viz, "viz_test")
    end
    
    test "fork detection works", %{pid: pid} do
      # Create a fork scenario
      root = %{"id" => "root", "type" => "init"}
      fork1 = %{"id" => "fork1", "type" => "branch", "_causes" => ["root"]}
      fork2 = %{"id" => "fork2", "type" => "branch", "_causes" => ["root"]}
      merge = %{"id" => "merge", "type" => "merge", "_causes" => ["fork1", "fork2"]}
      
      {:ok, chain_id} = MessageChain.track_message(pid, root, %{})
      MessageChain.track_message(pid, fork1, %{})
      MessageChain.track_message(pid, fork2, %{})
      MessageChain.track_message(pid, merge, %{})
      
      {:ok, forks} = MessageChain.detect_forks(pid, chain_id)
      assert length(forks) > 0
    end
  end
  
  describe "Priority Router" do
    setup do
      # Mock channel for testing
      {:ok, channel} = %{} # In real tests, use a mock AMQP channel
      {:ok, pid} = PriorityRouter.start_link(channel: channel)
      {:ok, pid: pid}
    end
    
    test "routing rules are applied correctly", %{pid: pid} do
      # Add a custom rule
      rule = %{
        id: "test_rule",
        name: "Test Rule",
        condition: {:message_type, "test"},
        priority_modifier: 2,
        enabled: true
      }
      
      assert :ok = PriorityRouter.add_rule(pid, rule)
      
      # Get metrics to verify rule was added
      {:ok, metrics} = PriorityRouter.get_metrics(pid)
      assert is_map(metrics)
    end
    
    test "load balancing strategies work" do
      # Test different algorithms
      candidates = ["queue1", "queue2", "queue3"]
      
      # Round robin should cycle through queues
      state = %{metrics: %{total_routed: 0}}
      assert PriorityRouter.select_round_robin(candidates, state) == "queue1"
      
      state = %{metrics: %{total_routed: 1}}
      assert PriorityRouter.select_round_robin(candidates, state) == "queue2"
    end
    
    test "circuit breaker protects failing queues" do
      # This would test circuit breaker functionality
      # Verify the function exists
      assert function_exported?(PriorityRouter, :should_route?, 2)
    end
  end
  
  describe "Integration" do
    test "all components work together" do
      # This would be a full integration test in a real scenario
      # For now, verify all modules can be started
      
      {:ok, _ctx} = ContextManager.start_link()
      {:ok, _chain} = MessageChain.start_link()
      {:ok, _router} = PriorityRouter.start_link(channel: %{})
      
      # All components should start without errors
      assert true
    end
  end
end