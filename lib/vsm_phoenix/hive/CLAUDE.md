# Hive Directory

Hive mind coordination for distributed VSM instances.

## Files in this directory:

- `spawner.ex` - Spawn new VSM instances dynamically
- `discovery.ex` - Discover other VSM nodes in the hive

## Purpose:
Enables multiple VSM instances to work together as a coordinated hive mind, sharing knowledge and distributing work.

## Key Features:
- Dynamic VSM spawning
- Inter-VSM discovery
- Hive coordination protocols
- Distributed decision making

## Integration:
- Works with MCP HiveMindServer for protocol support
- Uses Advanced aMCP Protocol Extensions for coordination
- Leverages Discovery protocol for finding peers