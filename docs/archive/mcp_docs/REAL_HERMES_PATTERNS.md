# Real Hermes MCP Patterns - Truth Architecture

## 🔍 Verified Patterns with Proof

### 1. Server Architecture Pattern
**Truth**: The real MCP server is `WorkingMcpServer` using stdio transport

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/working_mcp_server.ex
defp stdio_reader_loop do
  case IO.gets("") do  # Read from stdin
    data when is_binary(data) ->
      data
      |> String.trim()
      |> handle_json_rpc()  # Process JSON-RPC
      
defp send_response(response) do
  json = Jason.encode!(response)
  IO.puts(json)  # Write to stdout
```

**Pattern**: Simple stdio loop reading JSON-RPC from stdin, writing to stdout

### 2. Tool Registration Pattern
**Truth**: Tools are statically defined in module attributes

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/working_mcp_server.ex
@tools %{
  "vsm_query_state" => %{
    name: "vsm_query_state",
    description: "Query the current VSM system state",
    inputSchema: %{...}
  },
  "vsm_send_signal" => %{...},
  "vsm_synthesize_policy" => %{...}
}
```

**Pattern**: No dynamic registration - tools are hardcoded maps

### 3. Delegation Pattern
**Truth**: VsmHermesServer is just a wrapper delegating to WorkingMcpServer

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/servers/vsm_hermes_server.ex
def start_link(opts) do
  # Start the existing working server
  WorkingMcpServer.start_link(name: name)
end

def handle_request(method, params, from) do
  GenServer.call(WorkingMcpServer, {:handle_request, ...})
end
```

**Pattern**: Compatibility layer for gradual migration

### 4. Client Layering Pattern
**Truth**: Multiple delegation layers in client architecture

**Proof**:
```elixir
# Flow: VsmHermesClient -> HermesClient -> execute_mcp_tool -> call_vsm_mcp_tool -> VsmTools.execute

# lib/vsm_phoenix/mcp/clients/vsm_hermes_client.ex
defdelegate execute_tool(tool_name, arguments), to: HermesClient

# lib/vsm_phoenix/mcp/hermes_client.ex
case execute_mcp_tool(state.client, tool_name, tool_params) do

# Later in same file:
defp call_vsm_mcp_tool(tool_name, params) do
  VsmPhoenix.MCP.VsmTools.execute(tool_name, params)
```

**Pattern**: 4-layer delegation chain for compatibility

### 5. Tool Execution Pattern
**Truth**: Direct pattern matching on tool names

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/vsm_tools.ex
def execute(tool_name, params) do
  case tool_name do
    "vsm_scan_environment" -> scan_environment(params)
    "vsm_synthesize_policy" -> synthesize_policy(params)
    "vsm_spawn_meta_system" -> spawn_meta_system(params)
    "hive_" <> _ -> HiveCoordination.execute_hive_tool(tool_name, params)
```

**Pattern**: Simple case statement dispatching to functions

### 6. Supervision Pattern
**Truth**: Application supervisor starts components based on config

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/application.ex
defp build_children(config, _opts) do
  # Tool Registry (always started)
  children = [{VsmPhoenix.MCP.Tools.VsmToolRegistry, []} | children]
  
  # MCP Server (if enabled)
  children = if Keyword.get(config, :server_enabled, true) do
    case Keyword.get(config, :server_transport, :stdio) do
      :stdio ->
        [{VsmPhoenix.MCP.Transports.StdioTransport, [...]},
         {VsmPhoenix.MCP.Servers.VsmHermesServer, [...]}]
```

**Pattern**: Conditional child specs based on configuration

### 7. Transport Pattern
**Truth**: StdioTransport is a no-op wrapper

**Proof**:
```elixir
# lib/vsm_phoenix/mcp/transports/stdio_transport.ex
def send_message(transport, message) when is_binary(message) do
  # The WorkingMcpServer handles its own stdio
  Logger.debug("StdioTransport: Message would be sent: #{byte_size(message)} bytes")
  :ok
end
```

**Pattern**: Transport layer exists but doesn't actually transport - WorkingMcpServer handles stdio directly

### 8. Integration Test Pattern
**Truth**: Tests use real GenServer start_link with test names

**Proof**:
```elixir
# test/mcp/hermes_integration_test.exs
setup do
  {:ok, server} = VsmHermesServer.start_link([
    transport: [layer: Hermes.Transport.STDIO, name: :test_transport],
    name: :test_server
  ])
  
  {:ok, client} = VsmHermesClient.start_link([
    transport: :stdio,
    name: :test_client
  ])
```

**Pattern**: Named processes for test isolation

### 9. External Client Pattern
**Truth**: ExternalClient manages stdio subprocess communication

**Proof**:
```elixir
# From grep results:
def execute_tool(server_name, tool_name, params \\ %{}) do
  GenServer.call(via_tuple(server_name), {:execute_tool, tool_name, params}, @stdio_timeout)
```

**Pattern**: Registry-based process lookup with timeouts

### 10. Real MCP Integration Pattern
**Truth**: No actual Hermes library - just naming convention

**Proof**:
- No imports of HermesMCP modules found
- @behaviour HermesMCP.Tool appears but no implementation
- All "Hermes" modules are internal compatibility wrappers

**Pattern**: "Hermes" is branding, not an external dependency

## Summary of Real Architecture

1. **Stdio Communication**: Simple IO.gets/IO.puts JSON-RPC loop
2. **Static Tools**: Hardcoded tool definitions in module attributes  
3. **Layered Compatibility**: Multiple delegation layers for migration
4. **Direct Execution**: Pattern matching on tool names to call functions
5. **Supervised Components**: Application supervisor with conditional children
6. **No External Hermes**: Internal implementation with Hermes naming
7. **Registry-Based Clients**: Process registry for dynamic client lookup
8. **Test Isolation**: Named processes for concurrent test execution

## Key Insight

The "Hermes MCP" is actually a homegrown MCP implementation with:
- Simple stdio JSON-RPC server (WorkingMcpServer)
- Compatibility wrappers (VsmHermesServer/Client)  
- Direct tool execution (VsmTools.execute)
- No external Hermes library dependency

The architecture prioritizes simplicity and gradual migration over complex abstractions.