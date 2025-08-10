# MCP Transports Directory

Transport layer implementations for Model Context Protocol communication.

## Files in this directory:

- `stdio_transport.ex` - Standard input/output transport for MCP

## Purpose:
Implements the transport layer for MCP, enabling VSM Phoenix to communicate with external tools and services using different transport mechanisms.

## STDIO Transport:
The primary transport for MCP communication:
- Uses standard input/output streams
- JSON-RPC 2.0 message format
- Buffered reading for efficiency
- Error handling and recovery

## Key Features:
- Asynchronous message handling
- Request/response correlation
- Notification support
- Stream-based communication
- Compatible with standard MCP clients

## Message Flow:
```
External Tool → STDIN → stdio_transport → MCP Protocol Handler
                                              ↓
External Tool ← STDOUT ← stdio_transport ← Response
```

## Integration:
- Used by HiveMindServer for VSM-to-VSM communication
- Enables HermesStdioClient to connect to external servers
- Standard transport for all MCP tools

## Future Transports:
- WebSocket transport (for web clients)
- TCP transport (for network services)
- IPC transport (for local processes)