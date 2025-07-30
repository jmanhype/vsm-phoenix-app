defmodule ServerCatalogTest do
  use ExUnit.Case
  alias VsmPhoenix.MCP.ServerCatalog
  
  describe "all_servers/0" do
    test "returns all servers from catalog" do
      servers = ServerCatalog.all_servers()
      
      assert is_map(servers)
      assert Map.has_key?(servers, "filesystem")
      assert Map.has_key?(servers, "git")
      assert Map.has_key?(servers, "memory")
      assert Map.has_key?(servers, "sqlite")
    end
  end
  
  describe "official_servers/0" do
    test "returns only official MCP servers" do
      servers = ServerCatalog.official_servers()
      
      assert is_map(servers)
      assert Map.has_key?(servers, "filesystem")
      assert servers["filesystem"].package == "@modelcontextprotocol/server-filesystem"
    end
  end
  
  describe "community_servers/0" do
    test "returns community contributed servers" do
      servers = ServerCatalog.community_servers()
      
      assert is_map(servers)
      # Check if we have any community servers
      assert map_size(servers) > 0
    end
  end
  
  describe "get server by ID" do
    test "retrieves server from all_servers" do
      servers = ServerCatalog.all_servers()
      filesystem = servers["filesystem"]
      
      assert filesystem.id == "filesystem"
      assert filesystem.name == "Filesystem MCP Server"
      assert filesystem.category == :core
      assert "file_read" in filesystem.capabilities
    end
    
    test "returns nil for unknown server" do
      servers = ServerCatalog.all_servers()
      assert servers["nonexistent"] == nil
    end
  end
  
  describe "by_category/1" do
    test "filters servers by category" do
      core_servers = ServerCatalog.by_category(:core)
      
      assert is_map(core_servers)
      assert Map.has_key?(core_servers, "filesystem")
      assert Map.has_key?(core_servers, "memory")
      
      Enum.each(core_servers, fn {_id, server} ->
        assert server.category == :core
      end)
    end
    
    test "returns empty map for unknown category" do
      assert ServerCatalog.by_category(:unknown) == %{}
    end
  end
  
  describe "by_capability/1" do
    test "filters servers by capability" do
      file_servers = ServerCatalog.by_capability("file_read")
      
      assert is_map(file_servers)
      assert Map.has_key?(file_servers, "filesystem")
      
      Enum.each(file_servers, fn {_id, server} ->
        assert "file_read" in server.capabilities
      end)
    end
    
    test "returns empty map for unknown capability" do
      assert ServerCatalog.by_capability("teleportation") == %{}
    end
  end
  
  describe "find by package" do
    test "finds server by npm package name" do
      servers = ServerCatalog.all_servers()
      git_server = Enum.find_value(servers, fn {_id, server} ->
        if server.package == "@modelcontextprotocol/server-git", do: server
      end)
      
      assert git_server.id == "git"
      assert git_server.package == "@modelcontextprotocol/server-git"
    end
    
    test "returns nil for unknown package" do
      servers = ServerCatalog.all_servers()
      unknown = Enum.find_value(servers, fn {_id, server} ->
        if server.package == "@unknown/package", do: server
      end)
      
      assert unknown == nil
    end
  end
  
  describe "categories/0" do
    test "returns all unique categories" do
      categories = ServerCatalog.categories()
      
      assert is_list(categories)
      assert :core in categories
      assert :development in categories
      assert :data in categories
      assert categories == Enum.sort(categories)  # Should be sorted
    end
  end
  
  describe "capabilities/0" do
    test "returns all unique capabilities" do
      capabilities = ServerCatalog.capabilities()
      
      assert is_list(capabilities)
      assert "file_read" in capabilities
      assert "git_log" in capabilities
      assert capabilities == Enum.sort(capabilities)  # Should be sorted
    end
  end
  
  describe "search/1" do
    test "searches by server ID" do
      results = ServerCatalog.search("git")
      
      assert Map.has_key?(results, "git")
      assert Map.has_key?(results, "github")  # Should also match github
    end
    
    test "searches by server name" do
      results = ServerCatalog.search("filesystem")
      
      assert Map.has_key?(results, "filesystem")
    end
    
    test "searches by description" do
      results = ServerCatalog.search("repository")
      
      # Should find servers with "repository" in description
      assert map_size(results) > 0
    end
    
    test "search is case insensitive" do
      results1 = ServerCatalog.search("GIT")
      results2 = ServerCatalog.search("git")
      
      assert results1 == results2
    end
  end
  
  describe "recommend_for_use_case/1" do
    test "recommends servers for basic development" do
      recommendations = ServerCatalog.recommend_for_use_case(:basic_development)
      
      assert Map.has_key?(recommendations, "filesystem")
      assert Map.has_key?(recommendations, "git")
      assert Map.has_key?(recommendations, "memory")
      assert Map.has_key?(recommendations, "sqlite")
    end
    
    test "recommends servers for web development" do
      recommendations = ServerCatalog.recommend_for_use_case(:web_development)
      
      assert Map.has_key?(recommendations, "filesystem")
      assert Map.has_key?(recommendations, "git")
      assert Map.has_key?(recommendations, "github")
    end
    
    test "recommends servers for data analysis" do
      recommendations = ServerCatalog.recommend_for_use_case(:data_analysis)
      
      assert Map.has_key?(recommendations, "sqlite")
      assert Map.has_key?(recommendations, "memory")
    end
    
    test "returns default servers for unknown use case" do
      recommendations = ServerCatalog.recommend_for_use_case(:unknown_use_case)
      
      assert Map.has_key?(recommendations, "filesystem")
      assert Map.has_key?(recommendations, "memory")
    end
  end
end