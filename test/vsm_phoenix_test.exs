defmodule VsmPhoenixTest do
  use ExUnit.Case
  
  @moduledoc """
  Main test suite for VSM Phoenix application.
  Tests core functionality without requiring Phoenix startup.
  """
  
  describe "Core module loading" do
    test "all core modules compile and load" do
      modules = [
        VsmPhoenix.Application,
        VsmPhoenix.Repo,
        VsmPhoenixWeb,
        VsmPhoenixWeb.Endpoint,
        VsmPhoenix.System1.Operations,
        VsmPhoenix.MCP.ServerCatalog
      ]
      
      Enum.each(modules, fn module ->
        assert Code.ensure_loaded?(module)
      end)
    end
  end
  
  describe "Struct definitions" do
    test "MCP structs are properly defined" do
      state = %VsmPhoenix.MCP.ExternalClient.State{
        server_name: "test",
        transport: :stdio,
        status: :connected
      }
      
      assert state.server_name == "test"
      assert state.transport == :stdio
      assert state.status == :connected
    end
  end
  
  describe "Pure functions" do
    test "ServerCatalog functions work correctly" do
      servers = VsmPhoenix.MCP.ServerCatalog.all_servers()
      assert is_map(servers)
      assert map_size(servers) > 0
      
      categories = VsmPhoenix.MCP.ServerCatalog.categories()
      assert is_list(categories)
      assert :core in categories
    end
    
    test "System1.Operations provides capabilities" do
      caps = VsmPhoenix.System1.Operations.capabilities()
      assert is_list(caps)
      
      metrics = VsmPhoenix.System1.Operations.initial_metrics()
      assert is_map(metrics)
    end
  end
end