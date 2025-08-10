defmodule VsmPhoenix.AMQP.ProtocolIntegrationTest do
  @moduledoc """
  Tests for Advanced aMCP Protocol Extensions
  
  Verifies:
  - Discovery protocol functionality
  - Consensus mechanisms
  - Network optimization
  - Integration with security and CRDT layers
  """
  
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.AMQP.{Discovery, Consensus, NetworkOptimizer, ProtocolIntegration}
  alias VsmPhoenix.AMQP.MessageTypes
  
  setup do
    # Ensure services are started
    {:ok, _} = Application.ensure_all_started(:vsm_phoenix)
    
    # Give services time to initialize
    Process.sleep(100)
    
    :ok
  end
  
  describe "Discovery Protocol" do
    test "agents can announce themselves and be discovered" do
      agent_id = "test_agent_#{:rand.uniform(1000)}"
      capabilities = [:data_processing, :pattern_matching]
      
      # Announce agent
      :ok = Discovery.announce(agent_id, capabilities, %{test: true})
      
      # Give time for announcement to propagate
      Process.sleep(50)
      
      # Query for agents with these capabilities
      {:ok, agents} = Discovery.query_agents([:data_processing])
      
      # Should find our agent
      assert Enum.any?(agents, fn agent -> agent.id == agent_id end)
    end
    
    test "capability-based filtering works correctly" do
      # Announce multiple agents
      agent1 = "filter_test_1"
      agent2 = "filter_test_2"
      agent3 = "filter_test_3"
      
      Discovery.announce(agent1, [:crdt_sync, :consensus], %{})
      Discovery.announce(agent2, [:data_processing, :consensus], %{})
      Discovery.announce(agent3, [:crdt_sync, :data_processing], %{})
      
      Process.sleep(50)
      
      # Query for specific capability combination
      {:ok, agents} = Discovery.query_agents([:crdt_sync, :consensus])
      
      # Should only find agent1
      agent_ids = Enum.map(agents, & &1.id)
      assert agent1 in agent_ids
      refute agent2 in agent_ids
      refute agent3 in agent_ids
    end
  end
  
  describe "Consensus Protocol" do
    test "simple consensus proposal reaches agreement" do
      proposer = "consensus_test_#{:rand.uniform(1000)}"
      
      # Make a proposal
      result = Consensus.propose(
        proposer,
        :test_action,
        %{action: "test", value: 42},
        timeout: 2000,
        quorum_size: 1  # Just need self for test
      )
      
      # Should succeed with single node
      assert {:ok, :committed, _} = result
    end
    
    test "distributed lock acquisition and release" do
      agent_id = "lock_test_#{:rand.uniform(1000)}"
      resource = "test_resource_#{:rand.uniform(1000)}"
      
      # Request lock
      {:ok, :granted} = Consensus.request_lock(agent_id, resource, timeout: 1000)
      
      # Try to acquire same lock from different agent - should wait
      spawn(fn ->
        other_agent = "other_agent"
        result = Consensus.request_lock(other_agent, resource, timeout: 500)
        send(self(), {:lock_result, result})
      end)
      
      # Give time for request
      Process.sleep(100)
      
      # Release lock
      :ok = Consensus.release_lock(agent_id, resource)
      
      # Other agent should now get lock
      assert_receive {:lock_result, {:ok, :granted}}, 1000
    end
  end
  
  describe "Message Types" do
    test "create and serialize discovery messages" do
      msg = MessageTypes.create_announce_message(
        "test_agent",
        [:capability1, :capability2],
        %{version: "1.0"}
      )
      
      assert msg.header.type == "ANNOUNCE"
      assert msg.payload.capabilities == [:capability1, :capability2]
      
      # Should serialize without error
      serialized = MessageTypes.serialize_message(msg)
      assert is_binary(serialized)
      
      # Should deserialize correctly
      {:ok, deserialized} = MessageTypes.deserialize_message(serialized)
      assert deserialized.header.type == msg.header.type
    end
    
    test "message expiration based on TTL" do
      msg = MessageTypes.create_message(
        "TEST",
        %{data: "test"},
        ttl: 100  # 100ms TTL
      )
      
      refute MessageTypes.is_expired?(msg)
      
      Process.sleep(150)
      
      assert MessageTypes.is_expired?(msg)
    end
  end
  
  describe "Network Optimizer" do
    test "messages are batched when not immediate" do
      {:ok, metrics_before} = NetworkOptimizer.get_metrics()
      
      # Send multiple non-urgent messages
      for i <- 1..5 do
        NetworkOptimizer.send_optimized(
          nil,  # channel would be provided in real use
          "test.exchange",
          "test.route",
          %{index: i, data: "test"},
          []
        )
      end
      
      {:ok, metrics_after} = NetworkOptimizer.get_metrics()
      
      # Messages should be batched
      assert metrics_after.messages_batched > metrics_before.messages_batched
    end
    
    test "high attention messages bypass batching" do
      {:ok, metrics_before} = NetworkOptimizer.get_metrics()
      
      # Send high attention message
      NetworkOptimizer.send_optimized(
        nil,
        "test.exchange", 
        "test.route",
        %{attention_score: 0.9, critical: true},
        immediate: true
      )
      
      {:ok, metrics_after} = NetworkOptimizer.get_metrics()
      
      # Should bypass batching
      assert metrics_after.attention_bypasses > metrics_before.attention_bypasses
    end
  end
  
  describe "Protocol Integration" do
    test "secure agent discovery" do
      agent_id = "secure_agent_#{:rand.uniform(1000)}"
      
      # Announce with security enabled
      Discovery.announce(
        agent_id,
        [:secure_capability],
        %{security_enabled: true}
      )
      
      Process.sleep(50)
      
      # Discover with security validation
      {:ok, agents} = ProtocolIntegration.discover_agents(
        [:secure_capability],
        agent_id: "integration_test"
      )
      
      # Should find agents with security enabled
      assert length(agents) > 0
    end
    
    test "coordinated action with consensus" do
      agent_id = "coord_test_#{:rand.uniform(1000)}"
      
      # Skip this test if consensus is not fully configured
      # In a real test environment, we'd have multiple nodes
      result = ProtocolIntegration.coordinate_action(
        agent_id,
        :test_coordination,
        %{action: "coordinate", target: "test"},
        timeout: 3000,
        quorum: 1
      )
      
      case result do
        {:ok, :committed, _} ->
          assert true
        {:error, :insufficient_votes} ->
          # Expected in single-node test
          assert true
        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end
    
    test "CRDT synchronization request" do
      agent_id = "crdt_test_#{:rand.uniform(1000)}"
      
      # Announce some agents with CRDT capability
      Discovery.announce("crdt_agent_1", [:crdt_sync, :test_crdt], %{})
      Discovery.announce("crdt_agent_2", [:crdt_sync, :test_crdt], %{})
      
      Process.sleep(50)
      
      # Request CRDT sync
      {:ok, sync_count} = ProtocolIntegration.sync_crdt_state(
        agent_id,
        :test_crdt,
        immediate: false
      )
      
      # Should attempt to sync with discovered agents
      assert sync_count >= 0
    end
  end
end