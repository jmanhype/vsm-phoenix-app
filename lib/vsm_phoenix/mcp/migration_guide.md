# VSM Phoenix MCP Migration Guide

## Overview

This guide documents the migration from the current MCP implementation to the new Hermes-compliant MCP layer.

## Migration Steps

### 1. Update Dependencies

Add the MCP application supervisor to your main application:

```elixir
# lib/vsm_phoenix/application.ex
def start(_type, _args) do
  children = [
    # ... existing children ...
    
    # Add MCP Application
    {VsmPhoenix.MCP.Application, []},
    
    # ... rest of children ...
  ]
  
  opts = [strategy: :one_for_one, name: VsmPhoenix.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Configuration

Update your config files to use the new MCP system:

```elixir
# config/config.exs
config :vsm_phoenix, :mcp,
  server_enabled: true,
  server_transport: :stdio,  # or :http
  server_port: 8080,         # for HTTP transport
  client_enabled: true,
  client_transport: :stdio,  # or {:http, "http://localhost:8080"}
  registry_enabled: true

# Disable old MCP servers in dev.exs
config :vsm_phoenix, :mcp_servers_enabled, false
```

### 3. Update Client Usage

Replace old client calls with new Hermes client:

```elixir
# Old way
VsmPhoenix.MCP.HermesClient.analyze_variety(data)

# New way
VsmPhoenix.MCP.Clients.VsmHermesClient.analyze_variety(data)

# Or use the more explicit tool call
VsmPhoenix.MCP.Clients.VsmHermesClient.call_tool(
  "vsm_scan_environment",
  %{
    "scan_type" => "full",
    "depth" => 3,
    "domains" => ["internal", "external"]
  }
)
```

### 4. Update Server References

Replace references to old MCP servers:

```elixir
# Old servers to remove/update:
# - VsmPhoenix.MCP.VsmMcpServer
# - VsmPhoenix.MCP.WorkingMcpServer
# - VsmPhoenix.MCP.VsmServer

# New server:
# - VsmPhoenix.MCP.Servers.VsmHermesServer
```

### 5. Tool Migration

The tool system has been completely redesigned:

```elixir
# Old way - direct tool module calls
VsmPhoenix.MCP.VsmTools.execute("tool_name", params)

# New way - through tool registry
VsmPhoenix.MCP.Tools.VsmToolRegistry.execute("tool_name", params)
```

### 6. Transport Updates

If you have custom stdio handling:

```elixir
# Old way - line-by-line reading
IO.gets("")

# New way - proper Content-Length headers
# Handled automatically by VsmPhoenix.MCP.Transports.StdioTransport
```

### 7. Running Standalone MCP Server

To run the MCP server as a standalone process:

```bash
# Create a new file: start_mcp_server.exs
Mix.install([
  {:vsm_phoenix, path: "."},
  {:hermes_mcp, github: "cloudwalk/hermes-mcp", branch: "main"}
])

# Start the standalone server
{:ok, _} = VsmPhoenix.MCP.Transports.VsmStdioServer.start_server()
Process.sleep(:infinity)
```

Run with:
```bash
elixir start_mcp_server.exs
```

### 8. Testing the Migration

Test the new implementation:

```elixir
# Start a client
{:ok, client} = VsmPhoenix.MCP.Clients.VsmHermesClient.start_link()

# Initialize connection
{:ok, server_info} = VsmPhoenix.MCP.Clients.VsmHermesClient.initialize(client)

# List tools
{:ok, tools} = VsmPhoenix.MCP.Clients.VsmHermesClient.list_tools(client)

# Execute a tool
{:ok, result} = VsmPhoenix.MCP.Clients.VsmHermesClient.call_tool(
  "vsm_scan_environment",
  %{"scan_type" => "full", "depth" => 3},
  client: client
)
```

## Breaking Changes

1. **Protocol Version**: Now using "2024-11-05" instead of "1.0"
2. **Tool Response Format**: All tool responses must use proper content structure
3. **Error Handling**: Errors now use Hermes.MCP.Error format
4. **Transport**: Stdio now requires Content-Length headers
5. **Client API**: Some method signatures have changed

## Benefits of Migration

1. **Standards Compliance**: Full MCP protocol compliance
2. **Better Error Handling**: Structured errors with proper codes
3. **Transport Flexibility**: Easy switching between stdio/HTTP/WebSocket
4. **Performance**: Better message framing and buffering
5. **Debugging**: Comprehensive telemetry and logging
6. **Maintainability**: Clear separation of concerns

## Rollback Plan

If issues arise, you can temporarily run both systems:

1. Keep old MCP servers enabled in config
2. Use feature flags to switch between implementations
3. Gradually migrate components
4. Monitor metrics to ensure stability

## Support

For issues during migration:
1. Check logs for detailed error messages
2. Verify configuration is correct
3. Ensure all dependencies are updated
4. Test with simple tool calls first