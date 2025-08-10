# MCP Archive Directory

This directory contains archived MCP server implementations that served as development milestones and reference implementations.

## Files in this directory:

### vsm_server.ex
Original VSM-aware MCP server implementation that:
- First attempt at VSM tool integration
- Demonstrated stdio transport basics
- Included early tool definitions
- Served as proof-of-concept
- **Status**: Superseded by HiveMindServer

### working_mcp_server.ex
Functional MCP server that achieved:
- Working stdio communication
- Proper JSON-RPC handling
- Tool execution framework
- Basic error handling
- **Status**: Reference implementation

## Purpose of Archive:

### Historical Reference
- Shows evolution of MCP implementation
- Documents design decisions
- Preserves working patterns
- Enables rollback if needed

### Learning Resource
- Examples of stdio handling
- JSON-RPC message patterns
- Tool registration approaches
- Error handling strategies

## Relationship to Current System:

These archived servers evolved into:
- `hive_mind_server.ex` - Current production server
- `hermes_stdio_client.ex` - Modern client implementation
- `protocol.ex` - Extracted protocol definitions

## Storage Patterns Preserved:

Key patterns from these archives:
```elixir
# Message buffering
defp buffer_message(state, message)

# State persistence
defp save_server_state(state)

# Tool result caching
defp cache_tool_result(tool, params, result)
```

## Note:
These files are kept for reference only. Do not use in production. See parent directory for current implementations.