# AMQP Test Directory

Tests for Advanced Message Queuing Protocol integration.

## Files in this directory:

- `protocol_integration_test.exs` - AMQP protocol integration tests

## Purpose:
Validates AMQP functionality including:
- Connection management
- Channel lifecycle
- Message publishing/consuming
- Exchange and queue configuration
- Error handling and recovery

## Test Scenarios:
- Connection establishment with RabbitMQ
- Automatic reconnection on failure
- Message routing through exchanges
- Queue binding and unbinding
- Consumer registration and cancellation
- Transaction support
- Message acknowledgment patterns

## Running AMQP Tests:
```bash
# Requires RabbitMQ running
mix test test/vsm_phoenix/amqp

# With custom RabbitMQ host
RABBITMQ_HOST=localhost mix test test/vsm_phoenix/amqp
```

## Phase 2 Integration:
- Tests distributed coordination via AMQP
- Validates consensus protocol messaging
- Ensures proper message ordering
- Verifies dead letter handling