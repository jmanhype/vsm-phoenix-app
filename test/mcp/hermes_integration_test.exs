defmodule VsmPhoenix.MCP.HermesIntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.MCP.Servers.VsmHermesServer
  alias VsmPhoenix.MCP.Clients.VsmHermesClient
  alias VsmPhoenix.MCP.Tools.VsmToolRegistry
  
  setup do
    # Start tool registry
    {:ok, _registry} = VsmToolRegistry.start_link()
    
    # Start server with test transport
    {:ok, server} = VsmHermesServer.start_link([
      transport: [
        layer: Hermes.Transport.STDIO,
        name: :test_transport
      ],
      name: :test_server
    ])
    
    # Start client
    {:ok, client} = VsmHermesClient.start_link([
      transport: :stdio,
      name: :test_client
    ])
    
    on_exit(fn ->
      Process.exit(server, :normal)
      Process.exit(client, :normal)
    end)
    
    {:ok, server: server, client: client}
  end
  
  describe "MCP Protocol Compliance" do
    test "initialize handshake", %{client: client} do
      {:ok, response} = VsmHermesClient.initialize(client)
      
      assert response["protocolVersion"] == "2024-11-05"
      assert response["serverInfo"]["name"] == "VSM Phoenix MCP Server"
      assert response["serverInfo"]["version"] == "2.0.0"
      assert is_map(response["capabilities"])
    end
    
    test "list tools", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      {:ok, response} = VsmHermesClient.list_tools(client)
      
      assert is_list(response)
      assert length(response) > 0
      
      # Check tool structure
      tool = List.first(response)
      assert tool["name"]
      assert tool["description"]
      assert tool["inputSchema"]
    end
    
    test "execute tool - analyze variety", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      {:ok, result} = VsmHermesClient.analyze_variety(%{
        "test_data" => "variety analysis"
      })
      
      assert result["variety_score"]
      assert result["patterns"]
      assert result["recommendations"]
    end
    
    test "execute tool - synthesize policy", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      anomaly_data = %{
        "type" => "resource_spike",
        "severity" => 0.8,
        "affected_systems" => ["System3"],
        "description" => "Unusual resource allocation detected"
      }
      
      {:ok, result} = VsmHermesClient.synthesize_policy(anomaly_data)
      
      assert result["id"]
      assert result["type"] == "adaptive"
      assert result["sop"]
      assert result["mitigation_steps"]
      assert result["confidence"]
    end
    
    test "list resources", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      {:ok, resources} = VsmHermesClient.list_resources(client)
      
      assert is_list(resources)
      assert length(resources) > 0
      
      # Check resource structure
      resource = List.first(resources)
      assert resource["uri"]
      assert resource["name"]
      assert resource["description"]
      assert resource["mimeType"]
    end
    
    test "read resource", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      # Mock System5 for testing
      {:ok, _pid} = Agent.start_link(fn -> 
        %{
          active_policies: ["POL-001", "POL-002"],
          governance_mode: "adaptive",
          vsm_identity: "test-vsm"
        } 
      end, name: VsmPhoenix.System5.Queen)
      
      {:ok, content} = VsmHermesClient.read_resource("vsm://system5/policies", client)
      
      assert content["active_policies"]
      assert content["policy_count"]
    end
    
    test "get prompt", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      {:ok, prompt} = VsmHermesClient.get_prompt("vsm_analyze_variety", %{
        "scan_data" => "test data"
      }, client)
      
      assert prompt["prompt"]
      assert prompt["messages"]
    end
  end
  
  describe "Error Handling" do
    test "unknown tool returns proper error", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      result = VsmHermesClient.call_tool("unknown_tool", %{}, client: client)
      
      assert {:error, error} = result
      assert error =~ "Unknown tool"
    end
    
    test "invalid arguments return validation error", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      # Missing required "anomaly" field
      result = VsmHermesClient.call_tool(
        "vsm_synthesize_policy",
        %{},
        client: client
      )
      
      assert {:error, error} = result
      assert error =~ "Missing required"
    end
  end
  
  describe "Transport Features" do
    test "handles large messages", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      # Create large data
      large_data = %{
        "patterns" => Enum.map(1..1000, fn i ->
          %{"id" => i, "data" => String.duplicate("x", 100)}
        end)
      }
      
      {:ok, result} = VsmHermesClient.call_tool(
        "vsm_scan_environment",
        %{
          "scan_type" => "full",
          "domains" => Jason.encode!(large_data)
        },
        client: client
      )
      
      assert result
    end
    
    test "concurrent requests", %{client: client} do
      {:ok, _} = VsmHermesClient.initialize(client)
      
      # Launch concurrent requests
      tasks = Enum.map(1..10, fn i ->
        Task.async(fn ->
          VsmHermesClient.call_tool(
            "vsm_scan_environment",
            %{"scan_type" => "incremental", "depth" => i},
            client: client
          )
        end)
      end)
      
      # Collect results
      results = Enum.map(tasks, &Task.await/1)
      
      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)
    end
  end
  
  describe "Telemetry Integration" do
    test "emits telemetry events" do
      {:ok, _registry} = VsmToolRegistry.start_link()
      
      # Attach telemetry handler
      events_received = :ets.new(:test_events, [:set, :public])
      
      :telemetry.attach(
        "test-handler",
        [:vsm, :tool, :start],
        fn event, measurements, metadata, _config ->
          :ets.insert(events_received, {event, measurements, metadata})
        end,
        nil
      )
      
      # Execute tool
      {:ok, _} = VsmToolRegistry.execute("vsm_scan_environment", %{
        "scan_type" => "full"
      })
      
      # Check events were emitted
      assert :ets.info(events_received, :size) > 0
      
      :telemetry.detach("test-handler")
    end
  end
end