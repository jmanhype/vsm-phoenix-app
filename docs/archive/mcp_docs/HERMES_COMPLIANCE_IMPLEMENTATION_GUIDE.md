# Hermes MCP Compliance Implementation Guide

## Quick Reference: Hermes MCP Standards

### 1. Correct Message Format (JSON-RPC 2.0)

```json
// Request
{
  "jsonrpc": "2.0",
  "id": "unique-id-123",
  "method": "tools/call",
  "params": {
    "name": "tool_name",
    "arguments": {}
  }
}

// Response
{
  "jsonrpc": "2.0",
  "id": "unique-id-123",
  "result": {
    "content": [
      {"type": "text", "text": "response text"}
    ]
  }
}

// Error
{
  "jsonrpc": "2.0",
  "id": "unique-id-123",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": {"details": "additional context"}
  }
}
```

### 2. Proper Tool Definition

```elixir
defmodule MyMcpServer do
  use Hermes.Server,
    name: "my-mcp-server",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  # Register tool components
  component MyApp.Tools.ExampleTool
end

defmodule MyApp.Tools.ExampleTool do
  use Hermes.Tool

  @impl true
  def definition do
    %{
      name: "example_tool",
      description: "Does something useful",
      inputSchema: %{
        type: "object",
        properties: %{
          required_param: %{
            type: "string",
            description: "A required parameter"
          },
          optional_param: %{
            type: "number",
            description: "An optional parameter",
            minimum: 0,
            maximum: 100
          }
        },
        required: ["required_param"],
        additionalProperties: false
      }
    }
  end

  @impl true
  def execute(arguments, context) do
    # Tool implementation
    {:ok, %{
      content: [
        %{type: "text", text: "Tool execution result"}
      ]
    }}
  end
end
```

### 3. Initialization Sequence

```elixir
# Correct initialization response
%{
  "jsonrpc" => "2.0",
  "id" => request_id,
  "result" => %{
    "protocolVersion" => "2024-11-05",  # Date format!
    "capabilities" => %{
      "tools" => %{
        "listChanged" => true  # Optional
      },
      "resources" => %{
        "subscribe" => true,  # Optional
        "listChanged" => true  # Optional
      }
    },
    "serverInfo" => %{
      "name" => "vsm-phoenix-mcp",
      "version" => "2.0.0"
    }
  }
}
```

### 4. Capability Negotiation Pattern

```elixir
def handle_initialize(params, state) do
  client_capabilities = params["capabilities"] || %{}
  
  # Negotiate capabilities based on what client supports
  server_capabilities = %{
    "tools" => %{},
    "resources" => if client_capabilities["resources"], do: %{}, else: nil
  }
  
  # Return only mutually supported capabilities
  {:ok, negotiated_capabilities, state}
end
```

### 5. Resource Implementation

```elixir
defmodule MyApp.Resources.VsmState do
  use Hermes.Resource

  @impl true
  def list(_context) do
    {:ok, [
      %{
        uri: "vsm://state/current",
        name: "Current VSM State",
        description: "Real-time VSM system state",
        mimeType: "application/json"
      }
    ]}
  end

  @impl true
  def read(uri, _context) do
    case uri do
      "vsm://state/current" ->
        state = get_current_state()
        {:ok, %{
          content: [
            %{
              type: "text",
              text: Jason.encode!(state, pretty: true)
            }
          ]
        }}
      _ ->
        {:error, :not_found}
    end
  end
end
```

### 6. Notification Support

```elixir
defmodule MyMcpServer do
  # Send notifications to client
  def send_notification(method, params) do
    message = %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
      # Note: notifications have no id field
    }
    
    send_to_client(message)
  end
  
  # Example: Progress notification
  def notify_progress(operation, progress) do
    send_notification("notifications/progress", %{
      "operation" => operation,
      "progress" => progress,
      "total" => 100
    })
  end
end
```

### 7. Batch Request Handling

```elixir
def handle_json_rpc(requests) when is_list(requests) do
  # Handle batch requests
  responses = Enum.map(requests, &process_single_request/1)
  
  # Filter out notifications (no id = no response)
  responses
  |> Enum.reject(&is_nil/1)
  |> send_batch_response()
end
```

### 8. Error Codes Reference

```elixir
@error_codes %{
  parse_error: -32700,
  invalid_request: -32600,
  method_not_found: -32601,
  invalid_params: -32602,
  internal_error: -32603,
  
  # Custom VSM errors (must be -32000 to -32099)
  vsm_not_viable: -32000,
  vsm_overloaded: -32001,
  vsm_policy_conflict: -32002
}
```

## Migration Path

### Step 1: Update Protocol Version
```diff
- protocol_version: "1.0"
+ protocolVersion: "2024-11-05"
```

### Step 2: Fix Tool Response Format
```diff
- {:ok, content}
+ {:ok, %{content: [%{type: "text", text: content}]}}
```

### Step 3: Implement Proper Hermes.Server
```elixir
defmodule VsmPhoenix.MCP.HermesMcpServer do
  use Hermes.Server,
    name: "vsm-phoenix-mcp",
    version: "2.0.0",
    capabilities: [:tools, :resources, :notifications]

  # Components
  component VsmPhoenix.MCP.Tools.QueryState
  component VsmPhoenix.MCP.Tools.SendSignal
  component VsmPhoenix.MCP.Tools.SynthesizePolicy
  component VsmPhoenix.MCP.Resources.SystemState
  
  @impl true
  def init(client_info, initial_state) do
    Logger.info("MCP client connected: #{inspect(client_info)}")
    {:ok, Map.put(initial_state, :client_info, client_info)}
  end
end
```

### Step 4: Add Session Management
```elixir
defmodule VsmPhoenix.MCP.SessionManager do
  use GenServer
  
  defstruct [:session_id, :client_info, :state, :created_at]
  
  def start_session(client_info) do
    session = %__MODULE__{
      session_id: generate_session_id(),
      client_info: client_info,
      state: %{},
      created_at: DateTime.utc_now()
    }
    
    # Persist session
    :ets.insert(:mcp_sessions, {session.session_id, session})
    
    {:ok, session}
  end
end
```

## Testing Compliance

### 1. Protocol Test
```bash
# Test initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | \
  your_mcp_server

# Expected: protocolVersion in date format
```

### 2. Tool Test
```bash
# List tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | \
  your_mcp_server

# Call tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"vsm_query_state","arguments":{}}}' | \
  your_mcp_server
```

### 3. Batch Test
```bash
# Send batch request
echo '[
  {"jsonrpc":"2.0","id":1,"method":"tools/list"},
  {"jsonrpc":"2.0","id":2,"method":"resources/list"}
]' | your_mcp_server
```

## Common Pitfalls to Avoid

1. **Don't use version numbers for protocolVersion** - Always use date format
2. **Don't return raw strings** - Always wrap in proper content structure
3. **Don't ignore client capabilities** - Negotiate based on what client supports
4. **Don't forget error data field** - Include additional context in errors
5. **Don't mix notifications and requests** - Notifications have no id field

## Resources

- [Hermes.ex Documentation](https://hexdocs.pm/hermes)
- [MCP Specification](https://modelcontextprotocol.io/docs)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)