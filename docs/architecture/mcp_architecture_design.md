# MCP Architecture Design - Clean Implementation

## Overview

This document outlines a clean MCP (Model Context Protocol) architecture following Hermes patterns with proper separation of concerns, protocol abstraction, and extensibility.

## Core Design Principles

1. **Protocol Agnostic**: Support stdio, TCP, WebSocket transparently
2. **Clean Separation**: Distinct layers for protocol, message handling, and business logic
3. **Tool Discovery**: Dynamic tool registration and discovery
4. **State Management**: Centralized state with proper isolation
5. **Error Recovery**: Robust error handling and recovery mechanisms
6. **Hermes Patterns**: Follow established Hermes architectural patterns

## Architecture Layers

### 1. Transport Layer

Handles low-level protocol communication:

```
lib/vsm_phoenix/mcp/transport/
├── behaviour.ex          # Transport behaviour definition
├── stdio_transport.ex     # STDIO implementation
├── tcp_transport.ex       # TCP socket implementation
└── websocket_transport.ex # WebSocket implementation
```

### 2. Protocol Layer

Manages JSON-RPC protocol handling:

```
lib/vsm_phoenix/mcp/protocol/
├── json_rpc.ex           # JSON-RPC 2.0 implementation
├── message_handler.ex    # Message routing and handling
├── request_validator.ex  # Request validation
└── response_builder.ex   # Response construction
```

### 3. Core Layer

Central MCP server logic:

```
lib/vsm_phoenix/mcp/core/
├── server.ex            # Main GenServer
├── registry.ex          # Tool registry
├── dispatcher.ex        # Request dispatcher
├── state_manager.ex     # State management
└── capability_manager.ex # Capability negotiation
```

### 4. Tool Layer

Tool implementations and management:

```
lib/vsm_phoenix/mcp/tools/
├── behaviour.ex         # Tool behaviour
├── registry.ex          # Tool registration
├── discovery.ex         # Tool discovery
├── validator.ex         # Input validation
└── implementations/     # Actual tool implementations
```

### 5. Integration Layer

External system integrations:

```
lib/vsm_phoenix/mcp/integration/
├── vsm_bridge.ex        # VSM system integration
├── hive_bridge.ex       # Hive Mind integration
├── external_bridge.ex   # External MCP servers
└── event_bus.ex         # Event broadcasting
```

## Component Specifications

### Transport Behaviour

```elixir
defmodule VsmPhoenix.MCP.Transport.Behaviour do
  @callback start_link(opts :: keyword()) :: GenServer.on_start()
  @callback send(transport :: pid(), message :: binary()) :: :ok | {:error, term()}
  @callback receive_loop(handler :: function()) :: no_return()
  @callback close(transport :: pid()) :: :ok
end
```

### Core Server Architecture

```elixir
defmodule VsmPhoenix.MCP.Core.Server do
  use GenServer
  
  defstruct [
    :transport,
    :protocol_handler,
    :tool_registry,
    :state_manager,
    :capabilities,
    :session_id,
    :metadata
  ]
  
  # Clean separation of concerns
  def handle_info({:transport, :message, data}, state) do
    with {:ok, request} <- Protocol.parse(data),
         {:ok, validated} <- Protocol.validate(request),
         {:ok, result} <- Dispatcher.dispatch(validated, state),
         {:ok, response} <- Protocol.build_response(result) do
      Transport.send(state.transport, response)
    else
      {:error, reason} -> handle_error(reason, state)
    end
  end
end
```

### Tool Registry Pattern

```elixir
defmodule VsmPhoenix.MCP.Tools.Registry do
  use GenServer
  
  # Dynamic tool registration
  def register_tool(name, module, schema) do
    GenServer.call(__MODULE__, {:register, name, module, schema})
  end
  
  # Tool discovery
  def list_tools do
    GenServer.call(__MODULE__, :list)
  end
  
  # Tool execution with validation
  def execute(tool_name, params) do
    with {:ok, tool} <- get_tool(tool_name),
         {:ok, validated} <- validate_params(tool.schema, params) do
      tool.module.execute(validated)
    end
  end
end
```

## Message Flow

1. **Incoming Request**
   ```
   Transport → Protocol Parser → Validator → Dispatcher → Tool/Handler
   ```

2. **Outgoing Response**
   ```
   Tool/Handler → Response Builder → Protocol Formatter → Transport
   ```

3. **Error Handling**
   ```
   Any Layer → Error Handler → Error Response → Transport
   ```

## State Management

Centralized state management with proper isolation:

```elixir
defmodule VsmPhoenix.MCP.Core.StateManager do
  # Isolated state buckets
  defstruct [
    session: %{},      # Session-specific state
    tools: %{},        # Tool-specific state
    integrations: %{}, # Integration state
    metadata: %{}      # Server metadata
  ]
  
  # State access with isolation
  def get_state(bucket, key)
  def put_state(bucket, key, value)
  def update_state(bucket, key, fun)
end
```

## Error Recovery Mechanisms

1. **Transport Recovery**
   - Automatic reconnection
   - Backoff strategies
   - Circuit breaker pattern

2. **Protocol Recovery**
   - Request retry with idempotency
   - Partial failure handling
   - Graceful degradation

3. **Tool Recovery**
   - Tool health checks
   - Fallback mechanisms
   - Error boundaries

## Configuration

Flexible configuration system:

```elixir
config :vsm_phoenix, VsmPhoenix.MCP,
  transport: :stdio,
  transport_opts: [],
  tools: [
    {VsmPhoenix.MCP.Tools.VsmQuery, []},
    {VsmPhoenix.MCP.Tools.HiveCoordination, []},
    {VsmPhoenix.MCP.Tools.PolicySynthesis, []}
  ],
  capabilities: %{
    experimental: true,
    tool_discovery: true,
    streaming: false
  },
  error_recovery: %{
    max_retries: 3,
    backoff_ms: 1000,
    circuit_breaker: true
  }
```

## Testing Strategy

1. **Unit Tests**: Each component in isolation
2. **Integration Tests**: Component interactions
3. **Protocol Tests**: JSON-RPC compliance
4. **Transport Tests**: Multi-transport scenarios
5. **Tool Tests**: Tool registration and execution
6. **Error Tests**: Failure scenarios and recovery

## Migration Path

1. **Phase 1**: Implement core architecture
2. **Phase 2**: Migrate existing tools
3. **Phase 3**: Add new transports
4. **Phase 4**: Enhanced capabilities
5. **Phase 5**: Full production deployment

## Benefits

1. **Modularity**: Easy to extend and maintain
2. **Protocol Agnostic**: Support multiple transports
3. **Tool Ecosystem**: Dynamic tool registration
4. **Error Resilient**: Robust error handling
5. **Performance**: Efficient message routing
6. **Testability**: Clean boundaries for testing