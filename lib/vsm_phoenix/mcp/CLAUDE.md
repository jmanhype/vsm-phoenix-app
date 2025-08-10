# MCP Directory

Model Context Protocol implementation for VSM Phoenix.

## Files in this directory:

### Core Protocol
- `protocol.ex` - MCP protocol implementation
- `hive_mind_server.ex` - Main MCP server for VSM coordination
- `stdio_transport.ex` - STDIO transport layer

### Client Management
- `hermes_client.ex` - Legacy Hermes client
- `hermes_stdio_client.ex` - Working STDIO client
- `external_client.ex` - External MCP client connections
- `external_client_supervisor.ex` - Supervises external clients

### Integration
- `magg_integration_manager.ex` - MAGG server integration
- `llm_bridge.ex` - LLM API bridging
- `mcp_registry.ex` - MCP server registry

### Autonomous Features
- `autonomous_acquisition.ex` - Auto-discover MCP servers
- `capability_matcher.ex` - Match capabilities to needs
- `discovery_engine.ex` - Discover available tools
- `variety_analyzer.ex` - Analyze system variety

### VSM Tools
- `vsm_tools.ex` - VSM-specific MCP tools
- `tools/` - Individual tool implementations

## Purpose:
Enables VSM Phoenix to communicate with external MCP servers and provide MCP tools to other systems.