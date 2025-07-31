# MCP Server cURL Examples

## Server Running
```bash
node minimal_mcp_server_real.js
```
Server runs on: http://localhost:3001/mcp

## Initialize Session
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"curl-test","version":"1.0"}},"id":1}'
```

## List Available Tools
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'
```

## Call Uppercase Tool
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"uppercase","arguments":{"text":"hello world"}},"id":3}'
```

## Call Reverse Tool
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"reverse","arguments":{"text":"hello world"}},"id":4}'
```

## Using Echo with Pipe
```bash
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"uppercase","arguments":{"text":"piped text"}},"id":5}' | \
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d @-
```

## Pretty Print with jq
```bash
curl -X POST http://localhost:3001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | jq .
```

## Test Results

### ✅ Successful Responses:
- Initialize: Returns session ID and server info
- Tools List: Shows uppercase and reverse tools with schemas
- Uppercase: "hello world" → "HELLO WORLD"
- Reverse: "hello world" → "dlrow olleh"

### ❌ Error Cases:
- Wrong JSON-RPC version: Returns error code -32600
- Non-existent tool: Returns error code -32603
- Invalid JSON: Returns error code -32700

## Headers
- Required: `Content-Type: application/json`
- Optional: `MCP-Protocol-Version: 2025-06-18`
- Response includes: `Mcp-Session-Id` (on initialize)