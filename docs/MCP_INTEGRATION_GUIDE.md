# VSM Phoenix MCP Integration Guide

## Overview

The VSM Phoenix application uses the Model Context Protocol (MCP) to expose its Viable Systems Model functionality as tools that can be accessed by AI assistants and other MCP clients.

## Architecture

### Current Implementation: HiveMindServer

The primary MCP implementation is the **HiveMindServer**, which provides:
- VSM-to-VSM communication capabilities
- Bulletproof stdio transport
- Hive mind coordination for distributed VSM systems
- MCP tool exposure for VSM operations

### Integration Approach

The MCP integration follows a **single-port architecture**:
- Phoenix web server runs on port **4000**
- MCP endpoints are available at `/mcp/*`
- HTTP/JSON-RPC requests are handled by the MCPController
- No separate MCP server port is required

## Available MCP Tools

### 1. vsm_status
Get the status of any VSM system level (1-5).

**Parameters:**
- `system_level` (integer, 1-5): The VSM system level to query

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mcp/call_tool",
  "params": {
    "name": "vsm_status",
    "arguments": {"system_level": 5}
  },
  "id": 1
}
```

### 2. queen_decision
Request a policy decision from System 5 (Queen).

**Parameters:**
- `decision_type` (string): Type of decision needed
- `context` (object): Context information for the decision

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mcp/call_tool",
  "params": {
    "name": "queen_decision",
    "arguments": {
      "decision_type": "strategic",
      "context": {
        "topic": "resource_allocation",
        "urgency": "medium"
      }
    }
  },
  "id": 2
}
```

### 3. algedonic_signal
Send pleasure/pain signals through the VSM.

**Parameters:**
- `signal` (string): "pleasure" or "pain"
- `intensity` (number, 0-1): Signal intensity
- `context` (string): Context information

**Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mcp/call_tool",
  "params": {
    "name": "algedonic_signal",
    "arguments": {
      "signal": "pleasure",
      "intensity": 0.8,
      "context": "Successful operation"
    }
  },
  "id": 3
}
```

## Usage Examples

### Starting the Server
```bash
mix phx.server
```

### Testing with curl
```bash
# List available tools
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"mcp/list_tools","params":{},"id":1}'

# Check System 5 status
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"mcp/call_tool","params":{"name":"vsm_status","arguments":{"system_level":5}},"id":2}'

# Send pleasure signal
curl -X POST http://localhost:4000/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"mcp/call_tool","params":{"name":"algedonic_signal","arguments":{"signal":"pleasure","intensity":0.8,"context":"Success"}},"id":3}'
```

### Using echo and pipes
```bash
# List tools with echo
echo '{"jsonrpc":"2.0","method":"mcp/list_tools","params":{},"id":1}' | \
  curl -s -X POST http://localhost:4000/mcp -H "Content-Type: application/json" -d @- | jq

# Get formatted tool list
echo '{"jsonrpc":"2.0","method":"mcp/list_tools","params":{},"id":1}' | \
  curl -s -X POST http://localhost:4000/mcp -H "Content-Type: application/json" -d @- | \
  jq '.result.tools[] | {name, description}'
```

## Configuration

### Application Configuration
The MCP components are configured in `lib/vsm_phoenix/application.ex`:
- HiveMindServer starts with discovery enabled
- MCPController handles HTTP/JSON-RPC requests
- No separate MCP port configuration needed

### Disabling MCP
To disable MCP servers (useful for testing):
```bash
MIX_ENV=no_mcp mix phx.server
```

Or set in config:
```elixir
config :vsm_phoenix, :disable_mcp_servers, true
```

## Architecture Details

### Request Flow
1. Client sends JSON-RPC request to `http://localhost:4000/mcp`
2. Phoenix router forwards to MCPController
3. MCPController parses JSON-RPC and routes to appropriate handler
4. Handler interacts with VSM systems via GenServer calls
5. Response formatted as JSON-RPC and returned to client

### VSM System Integration
- **System 5 (Queen)**: Policy decisions and algedonic signals
- **System 4 (Intelligence)**: Environmental scanning (future tools)
- **System 3 (Control)**: Resource allocation (future tools)
- **System 2 (Coordinator)**: Anti-oscillation (internal use)
- **System 1 (Operations)**: Operational contexts (future tools)

## Testing

Run the validation test:
```bash
mix test test/test_mcp_validation.exs
```

Check health endpoint:
```bash
curl http://localhost:4000/mcp/health
```

## Troubleshooting

### Port Already in Use
If port 4000 is already in use:
```bash
# Find process using port 4000
lsof -i :4000

# Or change Phoenix port
PORT=4001 mix phx.server
```

### JSON Parse Errors
- Ensure JSON is properly formatted
- Avoid special characters in string values without proper escaping
- Use tools like `jq` to validate JSON before sending

### No Response
- Check Phoenix server is running
- Verify no firewall blocking port 4000
- Check logs for errors: `tail -f log/dev.log`

## Future Enhancements

1. **Additional VSM Tools**
   - System 4 environmental scanning
   - System 3 resource allocation
   - System 1 operational metrics

2. **Streaming Support**
   - Real-time algedonic signal streams
   - Live VSM status updates
   - Event subscriptions

3. **Authentication**
   - API key support
   - OAuth integration
   - Role-based access control

## References

- [Model Context Protocol Specification](https://github.com/anthropics/model-context-protocol)
- [Viable Systems Model](https://en.wikipedia.org/wiki/Viable_system_model)
- [Phoenix Framework](https://www.phoenixframework.org/)