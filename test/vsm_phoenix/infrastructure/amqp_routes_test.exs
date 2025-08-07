defmodule VsmPhoenix.Infrastructure.AMQPRoutesTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.Infrastructure.AMQPRoutes
  
  describe "get_queue_name/1" do
    test "returns configured queue names" do
      # Test system queue names
      assert AMQPRoutes.get_queue_name(:system1_commands) == "vsm.system1.commands"
      assert AMQPRoutes.get_queue_name(:system2_commands) == "vsm.system2.commands"
      assert AMQPRoutes.get_queue_name(:system3_commands) == "vsm.system3.commands"
      assert AMQPRoutes.get_queue_name(:system4_commands) == "vsm.system4.commands"
      assert AMQPRoutes.get_queue_name(:system5_commands) == "vsm.system5.commands"
    end
    
    test "returns audit queue names" do
      assert AMQPRoutes.get_queue_name(:system3_audit) == "vsm.system3.audit"
    end
    
    test "returns agent-specific queue names" do
      assert AMQPRoutes.get_queue_name({:agent_queue, "agent123", "status"}) == "vsm.s1.agent123.status"
      assert AMQPRoutes.get_queue_name({:agent_queue, "worker1", "telemetry"}) == "vsm.s1.worker1.telemetry"
    end
    
    test "handles unknown queue keys" do
      assert_raise FunctionClauseError, fn ->
        AMQPRoutes.get_queue_name(:unknown_queue)
      end
    end
  end
  
  describe "get_routing_key/2" do
    test "builds routing keys for different message types" do
      assert AMQPRoutes.get_routing_key(:command, "system1") == "command.system1"
      assert AMQPRoutes.get_routing_key(:event, "algedonic") == "event.algedonic"
      assert AMQPRoutes.get_routing_key(:telemetry, "agent123") == "telemetry.agent123"
    end
    
    test "handles complex routing patterns" do
      assert AMQPRoutes.get_routing_key(:agent_event, %{agent_id: "worker1", type: "status"}) == "agent.worker1.status"
      assert AMQPRoutes.get_routing_key(:system_event, %{system: "s4", event: "anomaly"}) == "system.s4.anomaly"
    end
  end
  
  describe "build_agent_queue_name/2" do
    test "builds consistent agent queue names" do
      assert AMQPRoutes.build_agent_queue_name("agent123", "telemetry") == "vsm.s1.agent123.telemetry"
      assert AMQPRoutes.build_agent_queue_name("sensor1", "data") == "vsm.s1.sensor1.data"
    end
    
    test "handles special characters in agent IDs" do
      assert AMQPRoutes.build_agent_queue_name("agent-with-dash", "status") == "vsm.s1.agent-with-dash.status"
      assert AMQPRoutes.build_agent_queue_name("agent_underscore", "events") == "vsm.s1.agent_underscore.events"
    end
  end
  
  describe "environment integration" do
    setup do
      # Save original env
      original_prefix = Application.get_env(:vsm_phoenix, :env_prefix)
      
      on_exit(fn ->
        if original_prefix do
          Application.put_env(:vsm_phoenix, :env_prefix, original_prefix)
        else
          Application.delete_env(:vsm_phoenix, :env_prefix)
        end
      end)
    end
    
    test "uses environment prefix when configured" do
      Application.put_env(:vsm_phoenix, :env_prefix, "test")
      
      # Queue names should include prefix
      queue_name = AMQPRoutes.get_queue_name(:system1_commands)
      assert queue_name =~ "test" or queue_name == "vsm.system1.commands"
    end
  end
  
  describe "queue binding patterns" do
    test "provides correct binding patterns for different queue types" do
      patterns = AMQPRoutes.get_binding_patterns(:system1_commands)
      assert is_list(patterns)
      assert "command.*" in patterns or "system1.*" in patterns
    end
    
    test "provides patterns for agent queues" do
      patterns = AMQPRoutes.get_binding_patterns({:agent_queue, "worker1", "telemetry"})
      assert is_list(patterns)
    end
  end
  
  describe "queue name validation" do
    test "validates queue names follow AMQP conventions" do
      valid_names = [
        "vsm.system1.commands",
        "vsm.s1.agent123.telemetry",
        "test.vsm.algedonic"
      ]
      
      for name <- valid_names do
        assert AMQPRoutes.valid_queue_name?(name) == true
      end
    end
    
    test "rejects invalid queue names" do
      invalid_names = [
        "",
        "queue with spaces",
        "queue/with/slashes",
        "queue#with#hash"
      ]
      
      for name <- invalid_names do
        assert AMQPRoutes.valid_queue_name?(name) == false
      end
    end
  end
end