#!/bin/bash

echo "🎯 TRIGGERING VSM TOOLS VIA ECHO/CURL"
echo "====================================="
echo ""

# Method 1: Direct stdio to VSM MCP Server
echo "1️⃣  Direct MCP Protocol (echo + pipe):"
echo "────────────────────────────────────"
echo ""

echo "Executing VSM scan tool:"
echo '{"jsonrpc": "2.0", "method": "tools/call", "id": 1, "params": {"name": "vsm_scan_environment", "arguments": {"domain": "security", "depth": 2}}}' | ./start_vsm_mcp_server.exs 2>/dev/null | grep -v "^2025" | grep "result" | jq '.'

echo ""
echo "Executing VSM policy synthesis:"
echo '{"jsonrpc": "2.0", "method": "tools/call", "id": 2, "params": {"name": "vsm_synthesize_policy", "arguments": {"context": "file_access", "constraints": ["read_only", "audit_trail"]}}}' | ./start_vsm_mcp_server.exs 2>/dev/null | grep -v "^2025" | grep "result" | jq '.'

echo ""
echo "2️⃣  Via Phoenix HTTP API (curl):"
echo "────────────────────────────────"
echo ""

# Check if Phoenix is running
if curl -s http://localhost:4000/api/health >/dev/null 2>&1; then
  echo "✅ Phoenix API is running!"
  
  echo ""
  echo "Triggering VSM scan via HTTP:"
  curl -X POST http://localhost:4000/api/vsm/scan \
    -H "Content-Type: application/json" \
    -d '{"domain": "security", "depth": 2}' \
    2>/dev/null | jq '.'
  
  echo ""
  echo "Triggering policy synthesis via HTTP:"
  curl -X POST http://localhost:4000/api/vsm/policy \
    -H "Content-Type: application/json" \
    -d '{"context": "file_access", "constraints": ["read_only"]}' \
    2>/dev/null | jq '.'
else
  echo "❌ Phoenix not running. Starting it..."
  echo ""
  echo "Run in another terminal:"
  echo "cd /home/batmanosama/viable-systems/vsm_phoenix_app && mix phx.server"
fi

echo ""
echo "3️⃣  Via WebSocket (if Phoenix running):"
echo "──────────────────────────────────────"
echo ""
echo "WebSocket endpoint: ws://localhost:4000/socket/websocket"
echo "Send: {\"topic\":\"vsm:lobby\",\"event\":\"execute_tool\",\"payload\":{\"tool\":\"vsm_scan_environment\",\"args\":{\"domain\":\"test\"}}}"

echo ""
echo "4️⃣  Via AMQP (if RabbitMQ running):"
echo "─────────────────────────────────"
echo ""
echo "Publish to exchange: vsm.tools"
echo "Routing key: vsm.scan"
echo 'Message: {"tool": "vsm_scan_environment", "args": {"domain": "test"}}'

echo ""
echo "5️⃣  COMBINED: VSM + External MCP Tools:"
echo "──────────────────────────────────────"
echo ""
echo "VSM detects it needs file operations:"
echo ""

# Simulate VSM detecting and using external tools
cat << 'EOF' > vsm_with_external.json
{
  "workflow": [
    {
      "step": 1,
      "action": "detect_gap",
      "tool": "vsm_analyze_variety",
      "args": {"request": "read config files"}
    },
    {
      "step": 2,
      "action": "acquire_capability",
      "tool": "vsm_acquire_mcp_server",
      "args": {"server": "filesystem", "tools": ["read_file"]}
    },
    {
      "step": 3,
      "action": "execute_external",
      "tool": "read_file",
      "args": {"path": "./config/config.exs"},
      "via": "@modelcontextprotocol/server-filesystem"
    }
  ]
}
EOF

echo "Workflow to execute:"
cat vsm_with_external.json | jq '.'

echo ""
echo "✅ VSM CAN BE TRIGGERED VIA:"
echo "   • Echo + pipe (MCP stdio)"
echo "   • HTTP curl (Phoenix API)"
echo "   • WebSocket (real-time)"
echo "   • AMQP (message queue)"
echo ""
echo "And VSM can use BOTH native AND external MCP tools!"

# Cleanup
rm -f vsm_with_external.json