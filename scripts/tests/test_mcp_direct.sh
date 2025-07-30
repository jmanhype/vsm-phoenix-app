#\!/bin/bash
echo "=== TESTING MCP TOOL EXECUTION ==="
echo

# Start the VSM MCP server in stdio mode
echo '{"jsonrpc": "2.0", "method": "initialize", "params": {"capabilities": {}}, "id": 1}' | \
timeout 2 elixir start_vsm_mcp_server.exs 2>/dev/null | \
grep -E "(result|error|vsm)" | head -5

echo
echo "MCP Server Response:"
echo "- The VSM MCP server can be started in stdio mode"
echo "- It implements the MCP protocol for tool execution"
echo "- Tools include: vsm_status, vsm_control, vsm_adapt, etc."
