# MCP Test Directory

Model Context Protocol specific test suites.

## Files in this directory:

- `hermes_integration_test.exs` - Tests for Hermes MCP client integration

## Purpose:
Contains specialized tests for MCP protocol implementation and integration with external MCP servers. These tests validate:
- Protocol compliance
- Message formatting
- Transport layer functionality
- External server communication
- Tool discovery and execution

## Test Coverage:
- Hermes client connection lifecycle
- Message serialization/deserialization
- Error handling and recovery
- Tool invocation patterns
- Capability matching

## Running MCP Tests:
```bash
# Run all MCP tests
mix test test/mcp

# Run with MCP server mocking
MIX_ENV=test mix test test/mcp --only mcp
```

## Integration Points:
- Tests interaction with stdio transport
- Validates external client connections
- Verifies tool registration and discovery
- Ensures proper error propagation