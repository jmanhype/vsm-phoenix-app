# Resilience Directory

This directory contains fault tolerance patterns that prevent cascade failures and ensure system stability across VSM Phoenix.

## Files in this Directory

### Core Patterns
- `circuit_breaker.ex` - Prevents cascade failures by detecting unhealthy services
- `bulkhead.ex` - Isolates resources into pools to prevent exhaustion
- `retry.ex` - Handles transient failures with exponential backoff and jitter

### Configuration & Integration
- `config.ex` - Centralized configuration for all resilience components
- `integration.ex` - Easy-to-use helper functions for common patterns
- `integration_adapter.ex` - Compatibility layer for gradual migration

### Monitoring & Health
- `health_monitor.ex` - Periodic health checks with algedonic signals
- `metrics_reporter.ex` - Live metrics broadcasting via PubSub
- `telemetry.ex` - Comprehensive telemetry event handling

### Specialized Clients
- `resilient_amqp_connection.ex` - Protected RabbitMQ connections
- `resilient_http_client.ex` - HTTP client with circuit breakers
- `telegram_resilient_client.ex` - Telegram API specific resilience

### Supervision
- `supervisor.ex` - Manages all resilience components with rest_for_one strategy

## Quick Start

```elixir
# Use circuit breaker
Integration.with_llm_circuit_breaker(fn ->
  call_openai_api(prompt)
end)

# Use bulkhead for resource isolation
Integration.with_worker_pool(fn resource ->
  process_heavy_task(data)
end)

# Combine patterns
Integration.with_backoff(fn ->
  external_api_call()
end, :external_api, max_retries: 3)
```

## Key Concepts

1. **Circuit Breaker States**: `:closed` (normal) → `:open` (failing) → `:half_open` (testing)
2. **Bulkhead Pools**: Fixed resources with queuing and overflow
3. **Exponential Backoff**: Prevents thundering herd with jitter
4. **Health Monitoring**: Continuous health checks with status aggregation

## Integration with Phase 2 Components

- **SecureContextRouter**: Protects crypto operations and CRDT sync
- **CorticalAttentionEngine**: Prevents attention overload with bulkheads
- **Consensus Protocol**: Ensures reliable distributed decisions
- **Telemetry DSP**: Safeguards CPU-intensive signal processing

See `INTEGRATION_CLAUDE.md` for detailed integration examples.