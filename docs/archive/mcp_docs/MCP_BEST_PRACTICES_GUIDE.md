# MCP Best Practices Guide for VSM Phoenix

## Executive Summary

This guide documents the best practices established by the swarm for implementing MCP (Model Context Protocol) in the VSM Phoenix application. After extensive analysis and implementation, we have chosen a **hybrid approach** that combines the best of both HTTP integration and native transports.

## 🎯 Chosen Architecture: Hybrid Integration

### Why Hybrid?

Based on the swarm's collective analysis stored in memory, the hybrid approach was selected for these reasons:

1. **Maximum Flexibility**: Supports all client types (browsers, CLI tools, IDEs, mobile apps)
2. **Progressive Enhancement**: HTTP for discovery/simple operations, native transports for performance
3. **Phoenix Integration**: Leverages existing Phoenix infrastructure
4. **Easy Migration Path**: Gradual transition from current setup
5. **Production Ready**: Battle-tested HTTP/SSE with optional WebSocket upgrade

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Phoenix Application                   │
├─────────────────────────────────────────────────────────┤
│                    MCP Controller                        │
│                  (HTTP Entry Point)                      │
├─────────────────────────────────────────────────────────┤
│   Discovery    │   Simple Ops   │   Transport Upgrade   │
│  /mcp/discover │  /mcp/rpc      │  /mcp/transport       │
├────────────────┴────────────────┴───────────────────────┤
│                  MCP Supervisor                          │
├─────────────────────────────────────────────────────────┤
│  Hermes Servers │  Native Transports │  Tool Registry   │
│  - VsmServer    │  - STDIO           │  - VSM Tools     │
│  - HiveMind     │  - SSE             │  - Hive Tools   │
│                 │  - WebSocket       │                  │
└─────────────────────────────────────────────────────────┘
```

## 🏗️ Implementation Best Practices

### 1. Supervision Tree Structure

**Current Implementation (Good):**
```elixir
# MCP components are isolated in their own supervisor
defmodule VsmPhoenix.MCP.MCPSupervisor do
  use Supervisor
  
  # rest_for_one strategy - correct choice!
  # If a component fails, restart it and everything after
  opts = [
    strategy: :rest_for_one,
    max_restarts: 10,
    max_seconds: 60
  ]
end
```

**Best Practices:**
- ✅ Isolate MCP components in dedicated supervisor
- ✅ Use `rest_for_one` strategy for dependent components
- ✅ Implement graceful degradation when external services fail
- ✅ Registry pattern for dynamic client management

### 2. Transport Layer Implementation

**HTTP Routes (Primary External Interface):**
```elixir
# Phoenix Router - Clean separation of concerns
pipeline :mcp do
  plug :accepts, ["json", "application/msgpack"]
  plug :fetch_session
  plug :put_secure_browser_headers
  # Note: CSRF protection deliberately skipped for API compatibility
end

scope "/mcp", VsmPhoenixWeb do
  pipe_through :mcp
  
  get "/health", MCPController, :health
  post "/rpc", MCPController, :handle
  options "/*path", MCPController, :options  # CORS support
end
```

**Native Transports (Performance Critical):**
```elixir
# STDIO for CLI tools
{VsmPhoenix.MCP.HermesStdioClient, []}

# StreamableHTTP for web integration
{VsmPhoenix.MCP.VsmServer, [
  port: 4001,
  transport: :streamable_http,
  auto_register: true,
  discovery: true
]}
```

### 3. Protocol Handling

**Best Practice: Layer Separation**

1. **Transport Layer**: Handles HTTP/WebSocket/STDIO communication
2. **Protocol Layer**: JSON-RPC 2.0 parsing and validation
3. **Handler Layer**: Business logic and tool execution
4. **Tool Layer**: Actual VSM functionality

```elixir
# Good: Clean separation in MCPController
defp process_request(%{id: id, method: method, params: params}) do
  if Code.ensure_loaded?(Hermes.Server.Transport.StreamableHTTP.Plug) do
    forward_to_hermes(id, method, params)  # Delegate to Hermes
  else
    handle_mcp_request(id, method, params)  # Fallback handling
  end
end
```

### 4. Error Handling

**Structured Error Response:**
```elixir
# JSON-RPC 2.0 compliant error codes
@parse_error -32700
@invalid_request -32600
@method_not_found -32601
@invalid_params -32602
@internal_error -32603

# Always return structured errors
defp send_json_rpc_error(conn, id, code, message) do
  error = %{
    jsonrpc: "2.0",
    id: id,
    error: %{
      code: code,
      message: message
    }
  }
  # ...
end
```

### 5. Security Considerations

**Current Gaps (From Memory Analysis):**
- ❌ No proper authentication for MCP connections
- ❌ Missing authorization layer
- ❌ No rate limiting implemented
- ❌ Input validation needs strengthening

**Recommended Implementations:**

```elixir
# Add authentication plug
defmodule VsmPhoenixWeb.MCPAuth do
  def init(opts), do: opts
  
  def call(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, claims} <- verify_jwt(token) do
      assign(conn, :mcp_claims, claims)
    else
      _ -> 
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end

# Add rate limiting
defmodule VsmPhoenixWeb.MCPRateLimit do
  use PlugAttack
  
  rule "MCP rate limit", conn do
    if conn.request_path =~ ~r{^/mcp} do
      throttle(conn.remote_ip,
        period: 60_000,  # 1 minute
        limit: 60,       # 60 requests
        storage: {PlugAttack.Storage.Ets, VsmPhoenix.RateLimitStorage}
      )
    end
  end
end
```

### 6. Discovery and Manifest

**Key Endpoints (From Memory):**
```
GET /mcp/discover     - Returns available servers and transports
GET /mcp/manifest.json - MCP capability manifest
POST /mcp/connect     - Get transport connection details
```

**Manifest Format:**
```json
{
  "servers": ["filesystem", "vsm", "hive_mind"],
  "transports": ["http", "websocket", "sse"],
  "capabilities": ["tools", "resources", "prompts"],
  "version": "1.0.0"
}
```

### 7. Performance Optimization

**From Production Analysis in Memory:**

1. **Connection Pooling**: Essential for external MCP clients
2. **Async Execution**: Use Task.Supervisor for tool execution
3. **Caching**: ETS tables for capability lookups
4. **Circuit Breakers**: Prevent cascading failures
5. **Backpressure**: GenStage for request queuing

```elixir
# Example: Circuit breaker for external calls
defmodule VsmPhoenix.MCP.CircuitBreaker do
  use GenServer
  
  @failure_threshold 5
  @timeout 30_000  # 30 seconds
  
  def call(fun) do
    case get_state() do
      :closed -> execute_with_breaker(fun)
      :open -> {:error, :circuit_open}
      :half_open -> test_with_breaker(fun)
    end
  end
end
```

## 🚀 Production Deployment

### Container Configuration

```dockerfile
FROM elixir:1.15-alpine as builder

# Build stage
RUN apk add --no-cache build-base git
WORKDIR /app
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY . .
RUN MIX_ENV=prod mix release

# Runtime stage
FROM alpine:3.18
RUN apk add --no-cache libstdc++ openssl ncurses-libs
WORKDIR /app
COPY --from=builder /app/_build/prod/rel/vsm_phoenix ./

# Health checks
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD /app/bin/vsm_phoenix rpc "VsmPhoenix.MCP.MCPSupervisor.healthy?()"

EXPOSE 4000 4001
CMD ["bin/vsm_phoenix", "start"]
```

### Monitoring and Observability

**Essential Metrics:**
- MCP request latency by method
- Tool execution success/failure rates
- Active connections by transport type
- Circuit breaker state changes
- Memory usage per component

**Implementation:**
```elixir
# Telemetry integration
:telemetry.execute(
  [:vsm_phoenix, :mcp, :request],
  %{duration: duration},
  %{method: method, transport: transport, status: status}
)
```

## 🔄 Migration Strategy

### Phase 1: Current State ✅
- Basic HTTP endpoints via Phoenix
- STDIO transport for CLI
- Hermes servers configured

### Phase 2: Security Hardening (Immediate)
1. Add JWT authentication
2. Implement rate limiting
3. Add input validation
4. Enable TLS for all transports

### Phase 3: Performance Enhancement (Short-term)
1. Connection pooling
2. Async tool execution
3. Caching layer
4. Circuit breakers

### Phase 4: Full Production (Long-term)
1. Distributed deployment
2. Load balancing
3. Monitoring dashboard
4. Self-healing capabilities

## 📋 Implementation Checklist

### Immediate Actions
- [ ] Add authentication to MCP endpoints
- [ ] Implement rate limiting
- [ ] Add structured logging with correlation IDs
- [ ] Create health check endpoints
- [ ] Document API with OpenAPI spec

### Short-term Improvements
- [ ] Connection pooling for external clients
- [ ] Async tool execution with timeouts
- [ ] ETS-based caching
- [ ] Circuit breakers for external calls
- [ ] Basic monitoring metrics

### Long-term Goals
- [ ] Full RBAC implementation
- [ ] Distributed tracing
- [ ] Advanced load balancing
- [ ] Chaos engineering tests
- [ ] Self-healing mechanisms

## 🎓 Key Learnings

1. **Hybrid > Pure**: Don't force everything through one transport
2. **Gradual Migration**: Keep existing functionality while adding new
3. **Supervision Matters**: Proper OTP structure prevents cascading failures
4. **Security First**: Authentication and rate limiting are not optional
5. **Monitor Everything**: You can't improve what you don't measure

## 🔗 References

- [MCP Specification](https://github.com/modelcontextprotocol/specification)
- [Hermes Documentation](https://github.com/colinmarc/hermes)
- [Phoenix Framework](https://www.phoenixframework.org/)
- [OTP Design Principles](https://www.erlang.org/doc/design_principles/des_princ.html)

---

*This document represents the collective intelligence of the MCP implementation swarm and should be treated as the authoritative guide for MCP best practices in the VSM Phoenix project.*