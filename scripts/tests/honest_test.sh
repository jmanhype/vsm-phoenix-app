#!/bin/bash

echo "🔍 HONEST TEST: What VSM Can ACTUALLY Do"
echo "========================================"
echo ""

echo "1️⃣  Can VSM's MCP server respond to echo commands?"
echo "──────────────────────────────────────────────────"
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | ./start_vsm_mcp_server.exs 2>/dev/null | grep -v "^2025" | grep "vsm_" | head -5
echo ""

echo "2️⃣  Can VSM actually call external MCP servers?"
echo "──────────────────────────────────────────────"
echo "Let's check the actual code..."
grep -n "MaggWrapper" lib/vsm_phoenix/mcp/*.ex | head -5
echo ""
echo "The code exists but does it work? Let's see..."
echo ""

echo "3️⃣  Can we ACTUALLY execute an external MCP tool through VSM?"
echo "───────────────────────────────────────────────────────────"
echo "Testing if VSM can proxy to filesystem server..."
echo ""

# The truth: VSM has the architecture but can it actually DO IT?
echo "Let's check if the variety acquisition GenServer is even running:"
ps aux | grep -i "variety" | grep -v grep || echo "❌ No variety acquisition process running"

echo ""
echo "4️⃣  What's REALLY in the code?"
echo "─────────────────────────────"
echo "Checking variety_acquisition.ex handle_call for :acquire_capability..."
grep -A 20 "def handle_call({:acquire_capability" lib/vsm_phoenix/mcp/variety_acquisition.ex | head -20 || echo "❌ Function not found"

echo ""
echo "5️⃣  THE TRUTH:"
echo "────────────"
echo "✅ What EXISTS:"
echo "   - VSM MCP server that responds to echo commands"
echo "   - Architecture files for variety acquisition"
echo "   - MAGG wrapper code"
echo "   - Variety analyzer code"
echo ""
echo "❌ What's MISSING or UNCLEAR:"
echo "   - Is the variety acquisition actually running?"
echo "   - Can VSM ACTUALLY proxy external MCP tools?"
echo "   - Is there a real connection between VSM and external MCP servers?"
echo ""
echo "🤔 The downstream task demo showed VSM's native tools working,"
echo "   but did it REALLY use external filesystem tools? No clear evidence."