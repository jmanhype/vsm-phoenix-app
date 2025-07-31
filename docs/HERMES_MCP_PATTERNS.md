# Hermes MCP Patterns Guide

## Overview

This document outlines the proper patterns for implementing MCP (Model Context Protocol) clients and servers using the Hermes library in Elixir. These patterns are based on the actual implementation found in the `hermes_mcp` dependency.

## Core Architecture Patterns

### 1. GenServer-Based Architecture

Both client and server implementations use GenServer as the foundation:

```elixir
defmodule MyMCPClient do
  use GenServer
  alias Hermes.Client.Base
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
```

### 2. Transport Layer Abstraction

Hermes supports multiple transport layers:
- **STDIO** - Standard input/output communication
- **SSE** - Server-Sent Events
- **StreamableHTTP** - HTTP streaming
- **WebSocket** - WebSocket connections (client only)

```elixir
# Transport configuration
transport: [
  layer: Hermes.Transport.STDIO,  # or SSE, StreamableHTTP
  name: MyTransport
]
```

### 3. Message Encoding/Decoding

All messages follow the JSON-RPC 2.0 specification:

```elixir
# Encoding a request
{:ok, encoded} = Hermes.MCP.Message.encode_request(%{
  "method" => "tools/call",
  "params" => %{"name" => "my_tool", "arguments" => %{}}
}, request_id)

# Decoding a response
{:ok, [message]} = Hermes.MCP.Message.decode(response_data)
```

## Client Implementation Patterns

### 1. Client Initialization

```elixir
defmodule VsmPhoenix.MCP.HermesClient do
  use GenServer
  
  def start_link(opts) do
    config = %{
      transport: Keyword.get(opts, :transport, :stdio),
      client_info: %{
        "name" => "vsm-client",
        "version" => "1.0.0"
      },
      capabilities: %{
        "roots" => %{"listChanged" => true},
        "sampling" => %{}
      },
      protocol_version: "2024-11-05"
    }
    
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
end
```

### 2. Tool Execution Pattern

```elixir
def handle_call({:execute_tool, tool_name, params}, _from, state) do
  operation = %{
    method: "tools/call",
    params: %{
      "name" => tool_name,
      "arguments" => params
    },
    timeout: 30_000
  }
  
  case execute_mcp_operation(state.client, operation) do
    {:ok, result} ->
      {:reply, {:ok, parse_result(result)}, state}
    {:error, reason} ->
      {:reply, {:error, reason}, state}
  end
end
```

### 3. Error Handling Pattern

```elixir
defp handle_mcp_error({:error, %Hermes.MCP.Error{} = error}) do
  Logger.error("MCP Error: #{error.message} (code: #{error.code})")
  {:error, format_error(error)}
end

defp handle_mcp_error({:error, reason}) do
  Logger.error("MCP Transport Error: #{inspect(reason)}")
  {:error, "Transport error: #{reason}"}
end
```

## Server Implementation Patterns

### 1. Server Setup

```elixir
defmodule MyMCPServer do
  use Hermes.Server.Base
  
  @impl true
  def server_info do
    %{
      "name" => "my-mcp-server",
      "version" => "1.0.0"
    }
  end
  
  @impl true
  def server_capabilities do
    %{
      "tools" => %{},
      "resources" => %{},
      "prompts" => %{}
    }
  end
  
  @impl true
  def supported_protocol_versions do
    ["2024-11-05"]
  end
end
```

### 2. Tool Registration Pattern

```elixir
defmodule MyMCPServer.Tools do
  use Hermes.Server.Component.Tool
  
  @impl true
  def list_tools do
    [
      %{
        name: "analyze_variety",
        description: "Analyze data for variety patterns",
        inputSchema: %{
          type: "object",
          properties: %{
            data: %{type: "string"},
            analysis_type: %{type: "string"}
          },
          required: ["data"]
        }
      }
    ]
  end
  
  @impl true
  def call_tool("analyze_variety", arguments) do
    # Tool implementation
    {:ok, %{"result" => analyze(arguments)}}
  end
end
```

### 3. Session Management Pattern

```elixir
# Sessions are managed automatically by Hermes
# Each client connection gets a unique session
def handle_session_event(session_id, event, state) do
  case event do
    :initialized ->
      Logger.info("Session #{session_id} initialized")
    :terminated ->
      Logger.info("Session #{session_id} terminated")
  end
  
  {:ok, state}
end
```

## Communication Patterns

### 1. Request-Response Pattern

```elixir
# Client side
def execute_tool(tool_name, params) do
  GenServer.call(__MODULE__, {:execute_tool, tool_name, params}, 30_000)
end

# Server side handles the request and sends response automatically
```

### 2. Progress Notification Pattern

```elixir
# Client registers progress callback
Hermes.Client.Base.register_progress_callback(
  client,
  progress_token,
  fn token, progress, total ->
    Logger.info("Progress: #{progress}/#{total}")
  end
)

# Server sends progress updates
send_progress_notification(session_id, %{
  "progressToken" => token,
  "progress" => current,
  "total" => total
})
```

### 3. Cancellation Pattern

```elixir
# Client cancels a request
Hermes.Client.Base.cancel_request(client, request_id, "user_cancelled")

# Server handles cancellation
def handle_cancellation(request_id, reason, state) do
  # Clean up any ongoing operations
  {:ok, state}
end
```

## Best Practices

### 1. Always Use Proper Timeouts

```elixir
# Set appropriate timeouts for operations
operation = %{
  method: "tools/call",
  params: params,
  timeout: 30_000  # 30 seconds
}
```

### 2. Handle All Error Cases

```elixir
case result do
  {:ok, response} -> 
    process_response(response)
  {:error, %Hermes.MCP.Error{code: -32601}} ->
    # Method not found
    handle_method_not_found()
  {:error, %Hermes.MCP.Error{}} = error ->
    # Other MCP errors
    handle_mcp_error(error)
  {:error, reason} ->
    # Transport errors
    handle_transport_error(reason)
end
```

### 3. Use Telemetry for Monitoring

```elixir
# Hermes emits telemetry events
:telemetry.attach(
  "mcp-client-events",
  [:hermes, :client, :request],
  &handle_telemetry_event/4,
  nil
)
```

### 4. Implement Proper Logging

```elixir
# Use the Hermes.Logging behavior
use Hermes.Logging

# Log at appropriate levels
Logging.client_event("tool_executed", %{tool: tool_name})
Logging.server_event("request_received", %{method: method})
```

## Common Pitfalls to Avoid

1. **Don't bypass the Hermes message encoding** - Always use the provided Message module
2. **Don't ignore transport errors** - They indicate connection issues
3. **Don't skip capability validation** - Check server capabilities before using features
4. **Don't forget to handle session termination** - Clean up resources properly
5. **Don't mix transport types** - Stick to one transport per client/server pair

## Integration with VSM

The VSM Phoenix app uses Hermes MCP for:
1. **External variety analysis** via Claude API
2. **Policy synthesis** for System 5
3. **Meta-system spawning** decisions
4. **Tool-based VSM operations**

The key is to maintain clear separation between:
- **Transport concerns** (handled by Hermes)
- **Protocol concerns** (JSON-RPC, MCP spec)
- **Business logic** (VSM operations)

## Example: Complete Client Implementation

```elixir
defmodule VsmPhoenix.MCP.ProperHermesClient do
  use GenServer
  use Hermes.Logging
  
  alias Hermes.Client.Base
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def analyze_variety(data) do
    GenServer.call(@name, {:execute_tool, "analyze_variety", %{"data" => data}})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Start Hermes client
    client_opts = [
      transport: [layer: Hermes.Transport.STDIO],
      client_info: %{"name" => "vsm-client", "version" => "1.0.0"},
      capabilities: %{"tools" => %{}},
      protocol_version: "2024-11-05"
    ]
    
    case Base.start_link(client_opts) do
      {:ok, client} ->
        state = %{
          client: client,
          tools: %{}
        }
        {:ok, state}
        
      {:error, reason} ->
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:execute_tool, tool_name, params}, _from, state) do
    case Base.call_tool(state.client, tool_name, params) do
      {:ok, response} ->
        result = response.result
        {:reply, {:ok, result}, state}
        
      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end
end
```

This pattern ensures proper MCP compliance while maintaining clean separation of concerns.