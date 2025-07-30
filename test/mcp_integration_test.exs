defmodule MCPIntegrationTest do
  use ExUnit.Case
  
  @moduledoc """
  Tests for MCP (Model Context Protocol) integration.
  Focuses on pure functions and data structures.
  """
  
  describe "ServerCatalog" do
    test "official servers are properly defined" do
      official = VsmPhoenix.MCP.ServerCatalog.official_servers()
      
      assert Map.has_key?(official, "filesystem")
      assert Map.has_key?(official, "git")
      assert Map.has_key?(official, "github")
    end
    
    test "server search and filtering works" do
      git_servers = VsmPhoenix.MCP.ServerCatalog.search("git")
      assert is_map(git_servers)
      
      dev_servers = VsmPhoenix.MCP.ServerCatalog.by_category(:development)
      assert is_map(dev_servers)
    end
    
    test "server recommendations work for use cases" do
      basic_recs = VsmPhoenix.MCP.ServerCatalog.recommend_for_use_case(:basic_development)
      assert is_map(basic_recs)
      
      web_recs = VsmPhoenix.MCP.ServerCatalog.recommend_for_use_case(:web_development)
      assert is_map(web_recs)
    end
  end
  
  describe "MCP Tools" do
    test "VsmTools module loads correctly" do
      assert Code.ensure_loaded?(VsmPhoenix.MCP.VsmTools)
      
      exports = VsmPhoenix.MCP.VsmTools.module_info(:exports)
      assert is_list(exports)
    end
  end
end