# Integration Testing Guide for VSM Phoenix

## Overview
This guide provides patterns and templates for testing GenServer agents and variety engineering components in the VSM Phoenix application.

## Testing Patterns Summary

### 1. GenServer Agent Testing Pattern

#### Key Testing Areas:
- **Initialization & Lifecycle**: Test start_link, configuration validation, registration
- **Message Handling**: Test handle_call, handle_cast, handle_info patterns
- **State Management**: Verify state transitions and persistence
- **Fault Tolerance**: Test crash recovery, supervision, and cleanup
- **Integration Points**: AMQP, Registry, System coordination

#### Test Structure:
```elixir
use ExUnit.Case, async: false  # For stateful tests
import ExUnit.CaptureLog      # For log verification

setup do
  Application.ensure_all_started(:vsm_phoenix)
  Process.sleep(200)  # Allow initialization
  
  on_exit(fn ->
    # Cleanup resources
  end)
  
  {:ok, config: %{...}}
end
```

### 2. Variety Engineering Testing Pattern

#### Filter Testing:
- Basic predicate filtering
- Filter chain composition
- Pattern matching filters
- Statistical filters (outliers, thresholds)
- Performance and scaling

#### Aggregator Testing:
- Time-window aggregation
- Count-based batching
- Statistical operations (avg, min, max, percentiles)
- Multi-dimensional aggregation
- Streaming with state management

### 3. Integration Testing Requirements

#### AMQP Integration:
- Channel creation and management
- Exchange/queue declaration
- Message publishing verification
- Connection failure recovery

#### System Coordination:
- S1 → S2 message flow testing
- S3 control bypass scenarios
- S4 monitoring and alerts
- S5 policy enforcement

### 4. Performance Testing

#### Metrics to Track:
- Message throughput
- Processing latency (T-90ms target)
- Memory usage
- CPU utilization
- Variety reduction percentage

#### Load Testing:
- Spawn multiple agents concurrently
- Generate high-volume message streams
- Measure system behavior under stress
- Verify 100% agent reachability during chaos

## Test Implementation Guide

### For TelegramAgent:

1. **Basic Functionality**:
   - Test agent spawning with Telegram config
   - Verify webhook registration
   - Test message reception and parsing
   - Verify command handling (/start, /help, etc.)

2. **Message Flow**:
   - Test incoming Telegram → AMQP publishing
   - Verify message transformation
   - Test response formatting
   - Verify rate limiting

3. **Error Scenarios**:
   - Malformed message handling
   - API connection failures
   - Rate limit enforcement
   - Graceful shutdown

### For Variety Filters:

1. **Filter Operations**:
   - Test individual filter predicates
   - Verify filter chain execution order
   - Test short-circuit optimization
   - Measure filtering performance

2. **Variety Measurement**:
   - Calculate variety before filtering
   - Apply filter chains
   - Measure variety reduction
   - Verify reduction targets (>50%)

### For Aggregators:

1. **Aggregation Logic**:
   - Test window-based grouping
   - Verify statistical calculations
   - Test partial batch handling
   - Verify memory efficiency

2. **State Management**:
   - Test streaming aggregation
   - Verify batch emission
   - Test state persistence
   - Measure memory usage

## Testing Tools & Helpers

### Recommended Libraries:
- **ExUnit**: Core testing framework
- **Mox**: For mocking external dependencies
- **StreamData**: Property-based testing
- **Telemetry**: Performance monitoring

### Test Helpers to Create:
```elixir
defmodule TestHelpers do
  def spawn_test_agent(type, config)
  def generate_messages(count, pattern)
  def setup_amqp_test_channel()
  def measure_performance(fun)
  def calculate_variety(messages)
end
```

## CI/CD Integration

### Test Categories:
1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Multi-component testing
3. **System Tests**: Full VSM behavior
4. **Performance Tests**: Load and stress testing
5. **Chaos Tests**: Failure scenario testing

### Test Execution Order:
1. Unit tests (parallel)
2. Integration tests (sequential)
3. System tests (isolated environment)
4. Performance tests (dedicated resources)
5. Chaos tests (separate run)

## Best Practices

1. **Isolation**: Each test should be independent
2. **Determinism**: Avoid random failures
3. **Speed**: Keep tests fast (<100ms each)
4. **Coverage**: Aim for >80% code coverage
5. **Documentation**: Clear test descriptions
6. **Maintenance**: Regular test refactoring

## Common Pitfalls to Avoid

1. **Race Conditions**: Use proper synchronization
2. **Process Leaks**: Always cleanup spawned processes
3. **AMQP Connections**: Properly close channels
4. **Timing Issues**: Use explicit waits, not sleep
5. **Global State**: Avoid modifying shared state

## References

- Test templates located in: `/test/patterns/`
- Example tests: `vsm_phase1_test.exs`
- Coverage report: `mix test --cover`
- Performance profiling: `:fprof`, `:eprof`

## Next Steps for Integration Tester

1. Review all test templates in `/test/patterns/`
2. Implement tests following the patterns
3. Ensure AMQP mock setup for isolated testing
4. Create performance benchmarks
5. Set up continuous integration pipeline
6. Document any new patterns discovered