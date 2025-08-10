# Scripts/Tools Directory

Infrastructure and development tooling for VSM Phoenix operations.

## Files in this directory:

### Database Tools
- `create_indexes.sh` - Creates database indexes for performance optimization

### Documentation Tools
- `docs_reorganizer.sh` - Shell script for reorganizing documentation structure
- `document_organizer.py` - Python script for advanced document organization

### MCP Tools
- `mcp_http_proxy.exs` - HTTP proxy for MCP protocol testing
- `mcp_tests.exs` - MCP protocol test suite

### Test Infrastructure
- `test_runner.exs` - Custom test runner with advanced features

## Purpose:
Provides essential infrastructure tooling for:
- Database optimization
- Documentation management
- Protocol testing and debugging
- Test execution and reporting

## Usage Examples:

```bash
# Create database indexes
./create_indexes.sh

# Run MCP tests
elixir mcp_tests.exs

# Start MCP HTTP proxy for debugging
elixir mcp_http_proxy.exs --port 8080

# Run custom test suite
elixir test_runner.exs --pattern "amqp/*"
```

## Integration:
- Database tools ensure optimal query performance
- Documentation tools maintain project clarity
- MCP tools enable protocol debugging
- Test runner provides flexible test execution