# VSM Phoenix Resilience Patterns

This module implements comprehensive resilience patterns for the VSM Phoenix application following Elixir/OTP best practices.

## Overview

The resilience module provides fault-tolerant communication and resource management through:

- **Circuit Breakers** - Prevent cascading failures
- **Retry Logic** - Exponential backoff with jitter
- **Bulkhead Pattern** - Resource isolation
- **Health Monitoring** - Real-time system health tracking
- **Telemetry Integration** - Metrics and observability

## Architecture

```
VsmPhoenix.Resilience.Supervisor
├── HealthMonitor          # System-wide health checks
├── MetricsReporter        # Real-time metrics via PubSub
├── Bulkheads
│   ├── :amqp_channels     # AMQP channel pooling
│   ├── :http_connections  # HTTP connection pooling
│   └── :llm_requests      # LLM request rate limiting
├── HTTP Clients
│   ├── :hermes_client     # Resilient Hermes MCP client
│   └── :external_api_client # External API client
└── ResilientAMQPConnection # Replaces standard ConnectionManager
```

## Components

### Circuit Breaker

Implements the circuit breaker pattern with three states:
- **Closed** - Normal operation, requests pass through
- **Open** - Circuit open, requests fail immediately
- **Half-Open** - Testing if service has recovered

```elixir
# Using circuit breaker directly
{:ok, result} = CircuitBreaker.call(breaker, fn ->
  # Potentially failing operation
  make_api_call()
end)

# Circuit breaker configuration
config :vsm_phoenix, :circuit_breaker,
  failure_threshold: 5,      # Failures before opening
  success_threshold: 3,      # Successes to close from half-open
  timeout: 30_000,          # Time before half-open (ms)
  reset_timeout: 60_000     # Time to reset failure count
```

### Retry Logic

Exponential backoff with configurable options:

```elixir
result = Retry.with_retry(fn ->
  # Operation that might fail
  fetch_data()
end, 
  max_attempts: 5,
  base_backoff: 100,       # Initial wait time (ms)
  max_backoff: 30_000,     # Maximum wait time (ms)
  backoff_multiplier: 2,
  jitter: true            # Add randomness to prevent thundering herd
)
```

### Bulkhead Pattern

Resource pooling with queue management:

```elixir
# Check out a resource
{:ok, resource} = Bulkhead.checkout(:http_connections)

# Use and return resource
try do
  use_resource(resource)
after
  Bulkhead.checkin(:http_connections, resource)
end

# Or use the helper
Bulkhead.with_resource(:http_connections, fn resource ->
  # Resource automatically returned after use
  make_request(resource)
end)
```

### Resilient AMQP Connection

Drop-in replacement for the standard AMQP ConnectionManager with added resilience:

```elixir
# Get a channel with circuit breaker protection
{:ok, channel} = VsmPhoenix.AMQP.ConnectionManager.get_channel(:commands)

# Connection automatically retries with exponential backoff
# Circuit breaker prevents excessive reconnection attempts
# Health checks ensure connection vitality
```

### Resilient HTTP Client

HTTP client with built-in resilience patterns:

```elixir
# Make resilient HTTP requests
{:ok, response} = ResilientHTTPClient.get(
  :hermes_client,
  "https://api.example.com/data",
  [{"Authorization", "Bearer token"}],
  timeout: 5000
)

# Automatic retry on failure
# Circuit breaker protection
# Configurable timeouts
```

### Health Monitoring

Real-time health monitoring of all resilience components:

```elixir
# Get current health status
health = HealthMonitor.get_health()
# => %{
#   status: :healthy,
#   components: %{
#     amqp_connection: %{status: :healthy, ...},
#     circuit_breakers: %{status: :healthy, ...},
#     bulkheads: %{status: :healthy, ...}
#   }
# }

# Register custom health checks
HealthMonitor.register_component(:my_service, fn ->
  case check_my_service() do
    :ok -> :ok
    :degraded -> {:degraded, %{reason: "high latency"}}
    :error -> {:error, %{reason: "connection failed"}}
  end
end)
```

## Configuration

Add to your `config/config.exs`:

```elixir
config :vsm_phoenix, :resilience,
  # Circuit breaker defaults
  circuit_breaker: [
    failure_threshold: 5,
    success_threshold: 3,
    timeout: 30_000,
    reset_timeout: 60_000
  ],
  
  # Retry defaults
  retry: [
    max_attempts: 5,
    base_backoff: 100,
    max_backoff: 30_000,
    backoff_multiplier: 2,
    jitter: true
  ],
  
  # Bulkhead configurations
  bulkheads: [
    amqp_channels: [
      max_concurrent: 20,
      max_waiting: 100,
      checkout_timeout: 5_000
    ],
    http_connections: [
      max_concurrent: 50,
      max_waiting: 200,
      checkout_timeout: 5_000
    ],
    llm_requests: [
      max_concurrent: 10,
      max_waiting: 50,
      checkout_timeout: 30_000
    ]
  ]
```

## Monitoring

### Live Dashboard

Access the resilience dashboard at `/resilience` to monitor:
- Circuit breaker states
- Bulkhead utilization
- Connection health
- Request metrics

### Telemetry Events

The resilience module emits telemetry events for integration with monitoring tools:

```elixir
# Attach to telemetry events
:telemetry.attach(
  "my-handler",
  [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
  &handle_circuit_breaker_change/4,
  nil
)

# Available events:
# [:vsm_phoenix, :resilience, :circuit_breaker, :state_change]
# [:vsm_phoenix, :resilience, :retry]
# [:vsm_phoenix, :resilience, :bulkhead, :checkout]
# [:vsm_phoenix, :resilience, :health_check]
# [:vsm_phoenix, :resilience, :http_client, :request]
```

### Prometheus Metrics

Export metrics in Prometheus format:

```elixir
metrics = VsmPhoenix.Resilience.Telemetry.export_prometheus_metrics()
```

## Integration Guide

### Migrating Existing Code

The resilience patterns are designed as drop-in replacements:

1. **AMQP Connections** - The ResilientAMQPConnection is registered as `VsmPhoenix.AMQP.ConnectionManager`, so existing code continues to work.

2. **HTTP Requests** - Use the IntegrationAdapter for gradual migration:

```elixir
# Old code
{:ok, response} = HTTPoison.get(url)

# New code with resilience
{:ok, response} = VsmPhoenix.Resilience.IntegrationAdapter.resilient_http_request(
  :hermes_client,
  :get,
  url
)
```

3. **Resource Protection** - Wrap resource-intensive operations:

```elixir
# Protect LLM calls
VsmPhoenix.Resilience.IntegrationAdapter.with_llm_request(fn ->
  # Make LLM API call
  call_llm_api(prompt)
end)
```

## Testing

Run the resilience pattern tests:

```bash
mix test test/vsm_phoenix/resilience/
```

### Simulating Failures

The tests include failure simulation:

```elixir
# Test circuit breaker behavior
test "opens after reaching failure threshold" do
  # Fail 3 times to open the circuit
  for _ <- 1..3 do
    CircuitBreaker.call(breaker, fn -> raise "boom" end)
  end
  
  # Circuit should now be open
  assert {:error, :circuit_open} = CircuitBreaker.call(breaker, fn -> :ok end)
end
```

## Best Practices

1. **Circuit Breaker Placement** - Place circuit breakers at integration points (databases, APIs, message queues)

2. **Bulkhead Sizing** - Size bulkheads based on expected load and downstream capacity

3. **Timeout Configuration** - Set timeouts slightly higher than expected response times

4. **Monitoring** - Always monitor circuit breaker trips and bulkhead rejections

5. **Graceful Degradation** - Design fallback behaviors for when services are unavailable

## Troubleshooting

### Circuit Breaker Keeps Opening

Check:
- Downstream service health
- Timeout settings (too aggressive?)
- Network connectivity
- Error threshold settings

### Bulkhead Full Errors

Solutions:
- Increase bulkhead size
- Investigate slow operations holding resources
- Add caching to reduce load
- Implement request coalescing

### High Retry Rates

Consider:
- Is the service actually available?
- Are retries causing more harm than good?
- Should some errors not be retried?

## Future Enhancements

- [ ] Adaptive circuit breakers that learn from patterns
- [ ] Dynamic bulkhead sizing based on load
- [ ] Distributed circuit breaker state
- [ ] Request hedging for critical paths
- [ ] Chaos engineering tools