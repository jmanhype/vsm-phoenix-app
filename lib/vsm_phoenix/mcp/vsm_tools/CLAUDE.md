# VSM Tools Directory

VSM-specific tools exposed via MCP protocol.

## Files in this directory:

- `hive_coordination.ex` - Tool for coordinating hive collective intelligence

## Purpose:
These tools extend VSM capabilities by providing MCP-accessible interfaces for:
- Hive mind coordination
- Collective intelligence operations
- Distributed decision making
- Swarm management

## Quick Start:
```elixir
# Use hive coordination tool
{:ok, result} = HiveCoordination.coordinate(%{
  action: "consensus",
  topic: "resource_allocation",
  participants: ["agent1", "agent2", "agent3"]
})
```

## Integration:
- Exposed via MCP protocol for external access
- Works with Phase 2 CRDT for distributed state
- Integrates with security layer for authenticated operations
- Feeds into Cortical Attention Engine