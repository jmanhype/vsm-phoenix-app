# Infrastructure Test Directory

Core infrastructure component tests.

## Files in this directory:

- `test_helpers.exs` - Shared test utilities
- `amqp_client_test.exs` - AMQP client functionality
- `amqp_routes_test.exs` - Message routing tests
- `contract_test.exs` - Service contract validation
- `exchange_config_test.exs` - Exchange configuration tests
- `http_client_test.exs` - HTTP client tests
- `integration_test.exs` - Infrastructure integration tests
- `security_test.exs` - Security infrastructure tests
- `service_registry_test.exs` - Service discovery tests

## Purpose:
Validates core infrastructure components that other VSM systems depend on:
- Message broker connectivity
- Service discovery and registration
- HTTP communication
- Security infrastructure
- Configuration management

## Test Categories:

### Messaging Tests
- AMQP connection pooling
- Exchange/queue creation
- Message routing rules
- Dead letter handling

### Service Tests
- Service registration/deregistration
- Health check mechanisms
- Load balancing
- Circuit breaker integration

### Security Tests
- Authentication flows
- Authorization checks
- Encryption/decryption
- Key management

## Running Tests:
```bash
# All infrastructure tests
mix test test/vsm_phoenix/infrastructure

# Only integration tests
mix test test/vsm_phoenix/infrastructure/integration_test.exs
```

## Test Helpers:
Provides utilities for:
- Mock service creation
- Test data factories
- AMQP test setup/teardown
- Security context setup