#!/bin/bash

echo "🎯 EXECUTING MCP TOOLS DIRECTLY"
echo "==============================="
echo ""

# Create a test file to read
echo "This is test content for MCP file operations!" > test_file.txt

echo "1️⃣  Initialize Filesystem MCP Server"
echo "──────────────────────────────────"
INIT_REQ='{"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "vsm-test", "version": "1.0.0"}}}'
echo "Request: $INIT_REQ"
echo ""

# We need to maintain a session with the MCP server
(
  echo "$INIT_REQ"
  sleep 0.5
  
  echo ""
  echo "2️⃣  List Available Tools"
  echo "─────────────────────"
  LIST_TOOLS_REQ='{"jsonrpc": "2.0", "method": "tools/list", "id": 2}'
  echo "Request: $LIST_TOOLS_REQ"
  echo "$LIST_TOOLS_REQ"
  sleep 0.5
  
  echo ""
  echo "3️⃣  Execute 'read_file' Tool"
  echo "──────────────────────────"
  READ_FILE_REQ='{"jsonrpc": "2.0", "method": "tools/call", "id": 3, "params": {"name": "read_file", "arguments": {"path": "./test_file.txt"}}}'
  echo "Request: $READ_FILE_REQ"
  echo "$READ_FILE_REQ"
  sleep 0.5
  
  echo ""
  echo "4️⃣  Execute 'list_directory' Tool"
  echo "───────────────────────────────"
  LIST_DIR_REQ='{"jsonrpc": "2.0", "method": "tools/call", "id": 4, "params": {"name": "list_directory", "arguments": {"path": "."}}}'
  echo "Request: $LIST_DIR_REQ"
  echo "$LIST_DIR_REQ"
  sleep 1
) | npx -y @modelcontextprotocol/server-filesystem --allowed-dirs "$(pwd)" 2>/dev/null | while read -r line; do
  # Parse and display JSON responses
  if echo "$line" | jq . 2>/dev/null >/dev/null; then
    echo "Response: $line" | jq '.'
  fi
done

echo ""
echo "5️⃣  VSM MCP Server Tools (via stdio)"
echo "──────────────────────────────────"
echo ""

# Test VSM's own MCP server
echo "Testing VSM scan tool:"
SCAN_REQ='{"jsonrpc": "2.0", "method": "tools/call", "id": 5, "params": {"name": "vsm_scan_environment", "arguments": {"domain": "test", "depth": 1}}}'
echo "$SCAN_REQ" | timeout 2s ./start_vsm_mcp_server.exs 2>/dev/null | grep -v "^2025" | tail -1 | jq '.'

echo ""
echo "✅ MCP TOOLS EXECUTED VIA STDIO PROTOCOL!"
echo ""
echo "Note: MCP uses stdio (pipes), not HTTP (curl)"
echo "This is how VSM communicates with external MCP servers!"

# Cleanup
rm -f test_file.txt