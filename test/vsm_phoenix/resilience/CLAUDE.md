# Resilience Test Directory

Circuit breaker and fault tolerance test suites.

## Files in this directory:

- `circuit_breaker_test.exs` - Circuit breaker behavior tests
- `bulkhead_test.exs` - Bulkhead isolation tests
- `retry_test.exs` - Retry mechanism tests
- `integration_test.exs` - Resilience pattern integration

## Purpose:
Validates fault tolerance mechanisms:
- Circuit breaker state transitions
- Failure detection and recovery
- Resource isolation (bulkheads)
- Retry strategies
- Timeout handling

## Test Scenarios:

### Circuit Breaker Tests
- Closed → Open transition on failures
- Open → Half-Open after timeout
- Half-Open → Closed on success
- Half-Open → Open on failure
- Custom failure thresholds

### Bulkhead Tests
- Concurrent request limiting
- Queue overflow handling
- Resource pool isolation
- Timeout behavior

### Retry Tests
- Exponential backoff
- Max retry limits
- Jittered retries
- Conditional retry logic

## Running Tests:
```bash
# All resilience tests
mix test test/vsm_phoenix/resilience

# With detailed output
mix test test/vsm_phoenix/resilience --trace
```

## Integration with Phase 2:
- Tests resilience with CRDT synchronization
- Validates security layer under failure
- Ensures telemetry continues during outages
- Verifies distributed consensus resilience