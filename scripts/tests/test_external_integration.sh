#!/bin/bash

# External MCP Integration Test Suite
# Tests integration with external MCP servers (filesystem, sqlite, etc.)
# Consolidated from: validate_mcp_integration.sh, verify_mcp_npm.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔌 External MCP Integration Tests"
echo "================================="
echo ""

# Test NPM package availability
echo "📦 Testing NPM MCP packages..."
if npm search @modelcontextprotocol 2>/dev/null | grep -q "@modelcontextprotocol"; then
    echo -e "${GREEN}✅ MCP packages available on NPM${NC}"
else
    echo -e "${YELLOW}⚠️  MCP packages not found on NPM${NC}"
fi

# Test filesystem MCP server
echo ""
echo "📁 Testing filesystem MCP server..."
if command -v npx &> /dev/null; then
    if npx @modelcontextprotocol/server-filesystem --help 2>&1 | grep -q "filesystem"; then
        echo -e "${GREEN}✅ Filesystem MCP server available${NC}"
    else
        echo -e "${YELLOW}⚠️  Filesystem MCP server not available${NC}"
    fi
else
    echo -e "${RED}❌ npx not found${NC}"
fi

# Test SQLite MCP server
echo ""
echo "🗄️  Testing SQLite MCP server..."
if command -v npx &> /dev/null; then
    if npx @modelcontextprotocol/server-sqlite --help 2>&1 | grep -q "sqlite"; then
        echo -e "${GREEN}✅ SQLite MCP server available${NC}"
    else
        echo -e "${YELLOW}⚠️  SQLite MCP server not available${NC}"
    fi
else
    echo -e "${RED}❌ npx not found${NC}"
fi

# Test variety acquisition
echo ""
echo "🎯 Testing variety acquisition..."
ACQUISITION_TEST=$(cat << 'EOF'
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "id": 1,
  "params": {
    "name": "vsm_scan_environment",
    "arguments": {
      "scope": "variety_acquisition",
      "include_external": true
    }
  }
}
EOF
)

if echo "$ACQUISITION_TEST" | ../start_vsm_mcp_server.exs 2>/dev/null | grep -q "variety"; then
    echo -e "${GREEN}✅ Variety acquisition working${NC}"
else
    echo -e "${YELLOW}⚠️  Variety acquisition not configured${NC}"
fi

echo ""
echo "✅ External integration tests complete"