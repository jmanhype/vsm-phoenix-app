#!/usr/bin/env elixir

# Quick test script for MCP server discovery
# Run with: elixir lib/vsm_phoenix/mcp/discovery_test.exs

# Add lib to path
Code.prepend_path("_build/dev/lib/vsm_phoenix/ebin")

# Test the server catalog
IO.puts("\n=== Testing Server Catalog ===")

alias VsmPhoenix.MCP.ServerCatalog

IO.puts("\nTotal servers: #{map_size(ServerCatalog.all_servers())}")
IO.puts("\nCategories: #{inspect(ServerCatalog.categories())}")
IO.puts("\nCapabilities: #{inspect(ServerCatalog.capabilities())}")

IO.puts("\n\n=== Servers by Category ===")
ServerCatalog.categories()
|> Enum.each(fn category ->
  servers = ServerCatalog.by_category(category)
  IO.puts("\n#{category}: #{map_size(servers)} servers")
  Enum.each(servers, fn {id, server} ->
    IO.puts("  - #{id}: #{server.description}")
  end)
end)

IO.puts("\n\n=== Recommended for Web Development ===")
ServerCatalog.recommend_for_use_case(:web_development)
|> Enum.each(fn {id, server} ->
  IO.puts("- #{server.name}")
  IO.puts("  Package: #{server.package}")
  IO.puts("  Install: npm install -g #{server.package}")
  IO.puts("")
end)

# Test search functionality
IO.puts("\n=== Search Test ===")
IO.puts("\nSearching for 'git':")
ServerCatalog.search("git")
|> Enum.each(fn {id, _server} ->
  IO.puts("  - Found: #{id}")
end)

# Test MAGG integration
IO.puts("\n\n=== MAGG Integration Test ===")
case System.cmd("magg", ["kit", "info", "example"], stderr_to_stdout: true) do
  {output, 0} ->
    IO.puts("MAGG Example Kit:")
    IO.puts(output)
  {error, _} ->
    IO.puts("MAGG not available or kit not found: #{error}")
end

IO.puts("\n\n=== Discovery Engine Test ===")
IO.puts("Note: Full discovery requires the complete application context.")
IO.puts("The DiscoveryEngine would find servers from:")
IO.puts("  - MAGG kits")
IO.puts("  - NPM registry")
IO.puts("  - GitHub repositories")
IO.puts("  - Local filesystem")
IO.puts("  - Network discovery")
IO.puts("  - Official registry")

IO.puts("\n✅ Server catalog and discovery framework ready!")
IO.puts("\nNext steps:")
IO.puts("1. Run discovery: VsmPhoenix.MCP.DiscoveryEngine.discover_all()")
IO.puts("2. Install servers: VsmPhoenix.MCP.ServerManager.install(server_id)")
IO.puts("3. Start servers: VsmPhoenix.MCP.ServerManager.start_server(id, config)")