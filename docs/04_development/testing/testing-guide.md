# VSM Phoenix Testing Guide

## Running Tests

To run the test suite without starting the Phoenix application:

```bash
mix test --no-start
```

To run tests with code coverage:

```bash
mix test --no-start --cover
```

## Test Structure

- `test/vsm_phoenix_test.exs` - Core functionality tests
- `test/mcp_integration_test.exs` - MCP integration tests
- `test/server_catalog_test.exs` - Comprehensive ServerCatalog tests
- `test/telemetry_functions_test.exs` - Telemetry emission tests
- `test/web_functions_test.exs` - Web module tests

Additional coverage-focused tests are available for increasing code coverage metrics.

## Why --no-start?

The `--no-start` flag prevents the Phoenix application and GenServers from starting, which:
- Avoids test hanging issues
- Allows testing of pure functions and data structures
- Provides faster test execution
- Enables reliable CI/CD integration

## Coverage

Current test suite achieves approximately 1% total coverage, with specific modules reaching:
- VsmPhoenix.MCP.ServerCatalog: ~90%
- Various struct modules: 100%
- Pure function modules: 3-6%