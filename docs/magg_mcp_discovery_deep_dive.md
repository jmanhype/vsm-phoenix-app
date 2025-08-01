# MAGG MCP Discovery System Deep Dive

## Executive Summary

MAGG (The MCP Aggregator) implements a sophisticated discovery system for Model Context Protocol (MCP) servers. The system uses multiple discovery strategies, dynamic tool aggregation, and namespace management to enable VSM Phoenix to acquire variety from external MCP servers.

## Discovery Architecture

### 1. Discovery Methods

The `VsmPhoenix.MCP.DiscoveryEngine` implements six discovery strategies:

1. **MAGG Kits** (`:magg_kits`)
   - Executes `magg kit list` CLI command
   - Parses output to find available server bundles
   - Kits are pre-configured collections of related servers
   - Install command: `magg kit load [kit-name]`

2. **NPM Registry** (`:npm_registry`)
   - Searches npm with terms: "mcp server", "mcp-server", "Model Context Protocol"
   - Filters packages by keywords and descriptions
   - Extracts capabilities from package metadata
   - Install command: `npm install -g [package-name]`

3. **GitHub Search** (`:github_search`)
   - Scans known repositories:
     - modelcontextprotocol/servers (official)
     - wong2/awesome-mcp-servers
     - punkpeye/awesome-mcp-servers
     - microsoft/mcp
     - docker/mcp-servers
   - Currently returns hardcoded server list (TODO: implement GitHub API)

4. **Local Filesystem** (`:local_filesystem`)
   - Searches standard paths:
     - `~/.mcp/servers`
     - `/usr/local/lib/mcp-servers`
     - `./mcp-servers`
   - Scans directories for server configurations

5. **Network Discovery** (`:network_discovery`)
   - Planned: mDNS/service discovery
   - Currently not implemented

6. **Registry API** (`:registry_api`)
   - Planned: Official MCP registry
   - Currently not implemented

### 2. Kit System

MAGG's kit system bundles related servers for easy installation:

```elixir
# Kit discovery flow
magg kit list → Parse output → Extract kit metadata → Store in catalog

# Kit structure
%{
  id: "example-kit",
  name: "Example Kit",
  description: "Filesystem and memory servers",
  servers: ["filesystem", "memory"],
  install_command: "magg kit load example-kit"
}
```

### 3. Tool Discovery and Aggregation

The tool discovery process follows this flow:

1. **Server Discovery**
   ```elixir
   DiscoveryEngine.discover_all() 
   → Run all strategies in parallel
   → Merge results (deduplication)
   → Return unified server map
   ```

2. **Server Addition**
   ```elixir
   MaggWrapper.add_server(server_name)
   → Execute: magg server add [server-name]
   → Parse response
   → Update local configuration
   ```

3. **Client Connection**
   ```elixir
   ExternalClientSupervisor.start_client(server_name)
   → Spawn ExternalClient GenServer
   → Determine transport (stdio/HTTP)
   → Send MCP initialization
   → Receive tool list in response
   ```

4. **Tool Aggregation**
   ```elixir
   # During client initialization
   ExternalClient connects → Send "initialize" → 
   Server responds with capabilities → Extract tools array →
   Store in client state
   ```

### 4. Registry Integrations

#### NPM Registry
- Direct search using `npm search --json`
- Filters results for MCP-related packages
- Extracts capabilities from keywords/descriptions
- Maps to standard server format

#### GitHub (Planned)
- Use GitHub API to search repositories
- Parse README files for MCP server info
- Extract installation instructions
- Monitor releases for updates

#### Server Catalog
- `VsmPhoenix.MCP.ServerCatalog` maintains curated list
- Categories: core, development, data, productivity, monitoring
- Includes official and community servers
- Provides installation commands and config examples

### 5. Namespace Collision Handling

MAGG uses a sophisticated namespace system to prevent tool conflicts:

1. **Proxy Prefix**
   - ProxyMCP mixin adds `proxy:` prefix to forwarded tools
   - Example: `weather.get` becomes `proxy:weather.get`

2. **Server Namespacing**
   - Each external client maintains its own tool list
   - Tools are executed in context of specific server
   - No global tool registry prevents collisions

3. **Tool Routing**
   ```elixir
   # Tool execution with server context
   ExternalClient.execute_tool(server_name, tool_name, params)
   → Route to specific client
   → Execute in isolated context
   → Return namespaced result
   ```

### 6. Dynamic Tool Loading

The system supports dynamic tool loading through:

1. **Hot-Reload Architecture**
   - MAGG watches configuration files
   - Detects changes and reloads servers
   - Updates tool lists without restart

2. **Dynamic Client Management**
   ```elixir
   # On-demand client spawning
   ExternalClientSupervisor (DynamicSupervisor)
   → start_client/1 spawns new process
   → stop_client/1 terminates process
   → restart_client/1 for recovery
   ```

3. **Tool List Updates**
   - Clients listen for `tools/list_changed` notifications
   - Refresh tool list when notified
   - Update internal state without reconnection

## Complete Discovery Flow

### Step 1: Initial Discovery
```elixir
VsmPhoenix.MCP.MaggIntegration.discover_servers("weather API")
→ DiscoveryEngine.run_strategy(:magg_kits)
→ DiscoveryEngine.run_strategy(:npm_registry)
→ DiscoveryEngine.run_strategy(:github_search)
→ Merge and deduplicate results
```

### Step 2: Server Selection
```elixir
MaggIntegration.select_best_server(servers, capability)
→ Score by: description match, tool count, official status
→ Return highest scoring server
```

### Step 3: Server Addition
```elixir
MaggWrapper.add_server(selected_server)
→ Execute: magg server add [server-name]
→ MAGG downloads and configures server
→ Returns server configuration
```

### Step 4: Client Connection
```elixir
ExternalClientSupervisor.start_client(server_name)
→ ExternalClient.init/1
→ Get config from MaggWrapper
→ Open stdio port or HTTP connection
→ Send MCP initialize request
```

### Step 5: Tool Discovery
```elixir
# In MCP initialize response:
{
  "capabilities": {
    "tools": [
      {
        "name": "get_weather",
        "description": "Get weather for location",
        "parameters": {...}
      }
    ]
  }
}
→ Extract and store tool list
```

### Step 6: Tool Availability
```elixir
MaggIntegration.list_connected_servers()
→ Query all ExternalClient processes
→ Aggregate tool lists
→ Return unified tool catalog

# Tool execution
MaggIntegration.execute_tool("get_weather", params)
→ Find server with tool
→ Route to ExternalClient
→ Execute via MCP protocol
→ Return result
```

## MAGG CLI Integration

Key MAGG commands used by the system:

```bash
# Kit management
magg kit list           # List available kits
magg kit load [name]    # Install kit servers
magg kit info [name]    # Get kit details

# Server management  
magg server list        # List configured servers
magg server add [pkg]   # Add npm package as server
magg server remove [id] # Remove server
magg server enable [id] # Enable server
magg server disable [id]# Disable server

# Configuration
magg config show        # Display current config
magg config export      # Export config as JSON
```

## Performance Optimizations

1. **Parallel Discovery**
   - All strategies run concurrently
   - Results merged efficiently
   - Deduplication prevents redundant work

2. **Connection Pooling**
   - ExternalClient processes reused
   - Persistent connections for stdio
   - HTTP client pooling for HTTP transport

3. **Caching**
   - Discovery results cached temporarily
   - Tool lists cached per session
   - Server configurations cached

4. **Lazy Loading**
   - Clients started on-demand
   - Tools fetched when needed
   - Connections established lazily

## Security Considerations

1. **Process Isolation**
   - Each external server runs in separate process
   - Stdio communication prevents direct access
   - Supervised processes for fault tolerance

2. **Input Validation**
   - All MCP messages validated
   - Tool parameters type-checked
   - Command injection prevention in CLI calls

3. **Capability Restrictions**
   - Servers declare capabilities explicitly
   - VSM only uses declared tools
   - No arbitrary code execution

## Future Enhancements

1. **Registry API Integration**
   - Connect to official MCP registry
   - Real-time server updates
   - Version management

2. **Enhanced Discovery**
   - GitHub API integration
   - mDNS/Bonjour support
   - Custom registry support

3. **Advanced Features**
   - Server health monitoring
   - Automatic failover
   - Load balancing for popular tools
   - Tool result caching

## Conclusion

MAGG's discovery system provides a robust foundation for VSM Phoenix's variety acquisition. The multi-strategy approach ensures comprehensive server discovery, while the dynamic client architecture enables flexible tool integration. The namespace management prevents conflicts, and the hot-reload capability ensures the system can adapt without downtime.

The combination of curated catalogs, package registry searches, and kit bundles provides multiple paths to capability expansion, making VSM Phoenix highly adaptable to changing requirements.