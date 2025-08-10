# MCP Tools Directory Context

This directory contains Model Context Protocol tools that VSM agents can expose and use.

## Files in this directory:
- `behaviour.ex` - Common behavior for all MCP tools
- `vsm_tool_registry.ex` - Registry of available VSM tools
- `analyze_variety.ex` - Analyzes variety (Ashby's Law) in the system
- `check_meta_system_need.ex` - Determines if meta-system intervention needed
- `synthesize_policy.ex` - Creates policies from patterns and constraints

## Purpose:
These tools extend VSM capabilities by providing standardized interfaces for:
- Variety analysis and management
- Policy synthesis
- Meta-system health checks
- Cross-agent tool discovery

## Quick Start:
```elixir
# Register a tool
VsmToolRegistry.register_tool(:analyze_variety, AnalyzeVariety)

# Use a tool
{:ok, result} = AnalyzeVariety.execute(%{
  system: "s1_operations",
  timeframe: "1h"
})

# Check if meta-system intervention needed
CheckMetaSystemNeed.execute(%{threshold: 0.7})
```

## Integration:
- Tools are exposed via MCP protocol
- Can be invoked by external MCP clients
- Results feed into VSM decision-making
- Integrates with Cortical Attention Engine for priority