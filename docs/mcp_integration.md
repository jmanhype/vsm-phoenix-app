# MCP (Model Context Protocol) Integration

## Overview

The VSM Phoenix application includes a Model Context Protocol (MCP) server implementation that allows AI models and other clients to interact with the Viable System Model through a standardized JSON-RPC interface.

## Endpoints

### Health Check
- **GET** `/mcp/health`
- Returns the current health status and capabilities of the MCP service

### JSON-RPC Endpoint
- **POST** `/mcp/rpc` or `/mcp/`
- Main endpoint for JSON-RPC 2.0 requests

### CORS Support
- **OPTIONS** `/mcp/*` 
- Handles preflight requests with appropriate CORS headers

## Supported Methods

### 1. `initialize`
Initializes a new MCP session and returns server capabilities.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {}
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "1.0",
    "capabilities": {
      "tools": { "enabled": true },
      "resources": { "enabled": true, "subscribe": false },
      "prompts": { "enabled": false },
      "logging": { "enabled": true }
    },
    "serverInfo": {
      "name": "vsm-phoenix-mcp",
      "version": "1.0.0"
    }
  }
}
```

### 2. `ping`
Simple connectivity test.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "ping",
  "params": {}
}
```

### 3. `list_tools`
Returns available VSM tools.

**Available Tools:**
- `vsm_status` - Get status of a specific VSM system level (1-5)
- `queen_decision` - Request a policy decision from System 5
- `algedonic_signal` - Send pleasure/pain signals through the VSM

### 4. `call_tool`
Execute a specific tool with parameters.

**Example - Get System 5 Status:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "call_tool",
  "params": {
    "name": "vsm_status",
    "arguments": {
      "system_level": 5
    }
  }
}
```

### 5. `list_resources`
Get available VSM resources.

**Available Resources:**
- `vsm://systems/overview` - Overview of all VSM systems
- `vsm://config/current` - Current VSM configuration

### 6. `read_resource`
Read a specific resource.

**Example:**
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "read_resource",
  "params": {
    "uri": "vsm://systems/overview"
  }
}
```

## Error Handling

The MCP controller follows JSON-RPC 2.0 error conventions:

- `-32700` Parse error
- `-32600` Invalid request
- `-32601` Method not found
- `-32602` Invalid params
- `-32603` Internal error

## CORS Configuration

The MCP endpoints include CORS headers to allow cross-origin requests:

- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: content-type, authorization`
- `Access-Control-Max-Age: 86400`

## Integration with Hermes

If the `Hermes.Server.Transport.StreamableHTTP.Plug` module is available, the MCP controller will attempt to forward requests to it for additional functionality like streaming support. If Hermes is not available, the controller handles all requests directly.

## Testing

Run the MCP controller tests:

```bash
mix test test/vsm_phoenix_web/controllers/mcp_controller_test.exs
```

## Example Client Usage

```elixir
# Using HTTPoison
request = %{
  jsonrpc: "2.0",
  id: 1,
  method: "list_tools",
  params: %{}
}

{:ok, response} = HTTPoison.post(
  "http://localhost:4000/mcp/rpc",
  Jason.encode!(request),
  [{"Content-Type", "application/json"}]
)

{:ok, body} = Jason.decode(response.body)
```

## Security Considerations

1. The MCP endpoints bypass CSRF protection to allow API access
2. Consider adding authentication for production use
3. Rate limiting may be necessary for public deployments
4. Monitor for malformed JSON-RPC requests that could impact performance