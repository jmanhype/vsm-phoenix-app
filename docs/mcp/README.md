# VSM Phoenix MCP Architecture

## Current State

The VSM Phoenix MCP implementation exists in two forms:

### 1. Original Implementation (Currently Active)
- **Working MCP Server**: `WorkingMcpServer` - Simple stdio-based JSON-RPC server
- **VSM Tools**: `VsmTools` - Implements actual VSM functionality
- **Hermes Clients**: `HermesClient` and `HermesStdioClient` - External integrations

### 2. New Hermes-Compliant Layer (Migration Path)
- **Servers**: `VsmHermesServer` - Wraps existing functionality
- **Clients**: `VsmHermesClient` - Provides new interface
- **Registry**: `VsmToolRegistry` - Bridges to existing tools
- **Transport**: `StdioTransport` - Compatibility wrapper

## Architecture Status

✅ **What Works:**
- Original MCP implementation is functional
- Tools execute VSM operations correctly
- Stdio communication works (line-by-line)
- Integration with VSM systems (S1-S5)

⚠️ **Migration Considerations:**
- New modules provide compatibility wrappers
- Gradual migration path available
- No breaking changes to existing code

## Running the System

The MCP system starts automatically with the VSM Phoenix application unless disabled:

```elixir
# In config/dev.exs
config :vsm_phoenix, :disable_mcp_servers, false  # Set to true to disable
```

## Key Components

1. **MCP Application Supervisor** (`MCP.Application`)
   - Manages all MCP processes
   - Configurable transport options

2. **Tool System**
   - `AnalyzeVariety` - Environmental scanning
   - `SynthesizePolicy` - Policy generation
   - `CheckMetaSystemNeed` - Viability checking
   - Plus 20+ other VSM-specific tools

3. **Integration Points**
   - MAGG integration for external AI
   - Hermes MCP for Claude integration
   - Autonomous acquisition system

## Next Steps

To complete the Hermes migration:

1. Update tool implementations to use new behaviour
2. Implement proper Content-Length headers in stdio
3. Add request tracking and timeouts
4. Enhance error handling

The system is **ready to run** in its current state!