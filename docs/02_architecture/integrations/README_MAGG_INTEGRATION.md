# MAGG Integration for VSM Phoenix

This document describes the MAGG (MCP AGGregator) integration that enables VSM Phoenix to discover and integrate external MCP servers dynamically.

## Overview

MAGG is a CLI tool that acts as a package manager for MCP servers, similar to how npm manages JavaScript packages. The VSM Phoenix integration provides:

1. **MaggWrapper** - Elixir interface to MAGG CLI commands
2. **ExternalClient** - GenServer for connecting to external MCP servers
3. **MaggIntegrationManager** - High-level orchestration and lifecycle management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     VSM Phoenix Application                  │
├─────────────────────────────────────────────────────────────┤
│                   MaggIntegrationManager                     │
│  - Auto-discovery              - Health monitoring           │
│  - Connection management       - Tool routing                │
├─────────────────────────────────────────────────────────────┤
│        MaggWrapper          │        ExternalClient          │
│  - search_servers()         │  - stdio/HTTP transport       │
│  - add_server()            │  - async tool execution        │
│  - list_servers()          │  - connection resilience       │
│  - get_tools()             │  - request timeout handling    │
│  - enable/disable_server() │                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                      External MCP Servers
                 (weather, filesystem, etc.)
```

## Usage

### 1. Basic Setup

First, ensure MAGG is installed:
```bash
npm install -g magg
```

The integration starts automatically with VSM Phoenix unless disabled.

### 2. Discovering MCP Servers

```elixir
# Search for MCP servers
{:ok, servers} = VsmPhoenix.MCP.MaggWrapper.search_servers(query: "weather")

# Add a server
{:ok, _} = VsmPhoenix.MCP.MaggWrapper.add_server("@modelcontextprotocol/server-weather")

# List configured servers
{:ok, servers} = VsmPhoenix.MCP.MaggWrapper.list_servers()
```

### 3. Managing Server Connections

```elixir
# Using the high-level manager
alias VsmPhoenix.MCP.MaggIntegrationManager

# Discover and connect automatically
{:ok, server_name} = MaggIntegrationManager.discover_and_add_server("weather")

# Connect to a configured server
:ok = MaggIntegrationManager.connect_server(server_name)

# Get status of all servers
status = MaggIntegrationManager.get_status()
```

### 4. Executing Tools

```elixir
# Execute on any server that has the tool
{:ok, result} = MaggIntegrationManager.execute_tool("get_weather", %{
  "location" => "New York"
})

# Execute on a specific server
{:ok, result} = MaggIntegrationManager.execute_tool_on_server(
  "@modelcontextprotocol/server-weather",
  "get_weather",
  %{"location" => "London"}
)
```

### 5. Direct Client Usage

For lower-level control:

```elixir
# Start a client manually
{:ok, _pid} = VsmPhoenix.MCP.ExternalClient.start_link(
  server_name: "@modelcontextprotocol/server-filesystem"
)

# Execute a tool
{:ok, files} = VsmPhoenix.MCP.ExternalClient.execute_tool(
  "@modelcontextprotocol/server-filesystem",
  "list_files",
  %{"path" => "/tmp"}
)

# Get client status
{:ok, status} = VsmPhoenix.MCP.ExternalClient.get_status(server_name)
```

## Configuration

### Application Config

```elixir
# config/config.exs
config :vsm_phoenix,
  mcp: [
    magg: [
      auto_connect: true,          # Auto-connect to servers on startup
      health_check_interval: 60_000 # Health check every 60 seconds
    ]
  ]
```

### Disabling MCP Servers

To disable all MCP server functionality:

```elixir
# config/test.exs or runtime.exs
config :vsm_phoenix, disable_mcp_servers: true
```

## Error Handling

The integration includes comprehensive error handling:

1. **Connection Failures** - Automatic reconnection with exponential backoff
2. **Timeout Handling** - Configurable timeouts with proper cleanup
3. **Process Crashes** - Supervised processes with automatic restart
4. **Invalid Responses** - Graceful degradation and error reporting

## Testing

Run the integration tests:

```bash
# Run all tests
mix test test/vsm_phoenix/mcp/

# Run only MAGG wrapper tests
mix test test/vsm_phoenix/mcp/magg_wrapper_test.exs

# Run with external server tests (requires internet)
mix test --include external
```

Test the integration manually:

```bash
# Run the test script
elixir test_magg_integration.exs
```

## Security Considerations

1. **Command Injection** - All MAGG commands use proper argument escaping
2. **Resource Limits** - Timeouts prevent resource exhaustion
3. **Process Isolation** - Each external client runs in its own supervised process
4. **Error Boundaries** - Failures in one client don't affect others

## Performance

- Connection pooling for HTTP transports
- Async request handling with proper back-pressure
- Efficient JSON parsing with streaming support
- Minimal overhead for stdio transport

## Troubleshooting

### MAGG Not Found

```
** (MatchError) no match of right hand side value: {:error, "MAGG CLI not found. Please install it with: npm install -g magg"}
```

Solution: Install MAGG globally:
```bash
npm install -g magg
```

### Connection Timeouts

If you see timeout errors, check:
1. The MCP server is properly configured
2. Network connectivity to external servers
3. Firewall rules for stdio/HTTP ports

### Tools Not Found

If tools aren't appearing:
1. Verify the server is connected: `MaggIntegrationManager.get_status()`
2. Check server tools directly: `MaggWrapper.get_tools(server: server_name)`
3. Ensure the server is enabled: `MaggWrapper.enable_server(server_name)`

## Future Enhancements

1. **Tool Discovery UI** - Phoenix LiveView interface for browsing tools
2. **Capability Matching** - Automatic tool selection based on requirements
3. **Performance Metrics** - Detailed metrics for each external server
4. **Caching Layer** - Cache tool results with TTL support
5. **WebSocket Transport** - Support for WebSocket-based MCP servers