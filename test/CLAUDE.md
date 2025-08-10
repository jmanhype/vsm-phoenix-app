# Test Directory

Comprehensive test suites validating VSM Phoenix functionality and integration.

## Files in this directory:

### Core Tests
- `test_helper.exs` - Test environment setup and helpers
- `vsm_phoenix_test.exs` - Main VSM Phoenix test suite
- `vsm_phase1_test.exs` - Phase 1 implementation tests

### MCP Tests
- `mcp_implementation_test.exs` - MCP protocol implementation
- `mcp_integration_test.exs` - MCP integration tests
- `vsm_mcp_integration_test.exs` - VSM-specific MCP tests
- `server_catalog_test.exs` - MCP server catalog tests
- `test_mcp_validation.exs` - MCP validation suite

### AMQP & Telemetry
- `amqp_otp27_test.exs` - AMQP compatibility with OTP 27
- `telemetry_functions_test.exs` - Telemetry event tests
- `web_functions_test.exs` - Web layer function tests

## Subdirectories:

### patterns/
Test patterns and templates for consistent testing:
- Integration testing guides
- Test templates for agents, filters, aggregators
- Testing best practices

### mcp/
MCP-specific test suites:
- Hermes integration tests

### vsm_phoenix/
Component-specific test suites organized by system:
- `amqp/` - AMQP protocol tests
- `crdt/` - CRDT state synchronization tests
- `infrastructure/` - Core infrastructure tests
- `resilience/` - Circuit breaker and fault tolerance tests
- `security/` - Cryptographic security layer tests
- `system1/` - Operations layer tests
- `system4/` - Intelligence layer tests
- `system5/` - Queen/Policy layer tests
- `variety_engineering/` - Variety management tests

### vsm_phoenix_web/
Web layer tests:
- Controller tests including MCP endpoints

## Quick Start:
```bash
# Run all tests
mix test

# Run specific test file
mix test test/vsm_phoenix/crdt/context_store_test.exs

# Run with coverage
mix test --cover

# Run only tagged tests
mix test --only integration
```

## Test Categories:
- Unit tests - Individual component validation
- Integration tests - Multi-component interaction
- System tests - End-to-end functionality
- Performance tests - Load and stress testing

## Phase 2 Test Coverage:
- CRDT synchronization scenarios
- Cryptographic security validation
- Distributed consensus testing
- Telemetry DSP/FFT verification
- Circuit breaker behavior
- Cortical Attention Engine scoring