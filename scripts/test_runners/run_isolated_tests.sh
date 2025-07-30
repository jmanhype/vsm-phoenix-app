#!/bin/bash

# Run isolated MCP tests without Phoenix application

echo "Running isolated MCP tests..."
echo "============================="
echo ""

# Run each test file with the isolated helper
MIX_ENV=test elixir -r test/mcp_test_helper.exs \
  test/vsm_phoenix/mcp/isolated/autonomous_acquisition_test.exs \
  test/vsm_phoenix/mcp/isolated/external_client_test.exs \
  test/vsm_phoenix/mcp/isolated/magg_integration_test.exs \
  test/vsm_phoenix/mcp/isolated/magg_wrapper_test.exs \
  test/vsm_phoenix/mcp/isolated/variety_acquisition_test.exs

echo ""
echo "Test run completed!"