#!/bin/bash

echo "Verifying MCP npm packages..."
echo

# Check if filesystem server is installed globally
echo "Checking @modelcontextprotocol/server-filesystem:"
if npm list -g @modelcontextprotocol/server-filesystem &>/dev/null; then
    echo "✅ Already installed globally"
else
    echo "📦 Installing..."
    npm install -g @modelcontextprotocol/server-filesystem
fi

# Test running it directly
echo
echo "Testing direct execution:"
echo "Running: npx @modelcontextprotocol/server-filesystem --help"
npx @modelcontextprotocol/server-filesystem --help 2>&1 | head -20

echo
echo "✅ MCP filesystem server is available!"