# Resilience Patterns Guide

## Overview

The VSM Phoenix resilience module implements Circuit Breaker and Bulkhead patterns to prevent cascade failures and isolate system components. This guide covers usage, configuration, and integration with existing VSM systems.

## Architecture

```
VsmPhoenix.Resilience.Supervisor
├── Circuit Breakers
│   ├── :llm_api_breaker
│   ├── :amqp_breaker
│   ├── :external_api_breaker
│   └── :database_breaker
├── Bulkhead Pools
│   ├── :worker_agent_pool
│   ├── :llm_worker_pool
│   ├── :sensor_agent_pool
│   ├── :api_agent_pool
│   └── :telegram_bot_pool
├── MetricsAggregator
└── HealthMonitor
```

## Circuit Breaker Pattern

### States

1. **Closed** - Normal operation, calls pass through
2. **Open** - Failures exceeded threshold, calls are rejected
3. **Half-Open** - Testing if service has recovered

### Usage

```elixir
# Using the integration module
alias VsmPhoenix.Resilience.Integration

# LLM API calls
result = Integration.with_llm_circuit_breaker(fn ->
  # Your LLM API call here
  OpenAI.completions(%{prompt: "Hello", model: "gpt-3.5-turbo"})
end)

# AMQP operations
result = Integration.with_amqp_circuit_breaker(fn ->
  AMQP.Basic.publish(channel, exchange, routing_key, message)
end)

# External API calls
result = Integration.with_external_api_circuit_breaker(fn ->
  HTTPoison.get("https://api.example.com/data")
end)
```

### Direct Circuit Breaker Usage

```elixir
alias VsmPhoenix.Resilience.CircuitBreaker

# Call through circuit breaker
case CircuitBreaker.call(:llm_api_breaker, fn -> do_work() end) do
  {:ok, result} -> 
    # Success
  {:error, :circuit_open} -> 
    # Circuit is open, service unavailable
  {:error, reason} -> 
    # Function failed
end

# Check circuit breaker state
state = CircuitBreaker.get_state(:llm_api_breaker)
# Returns: %{state: :closed, failure_count: 0, success_count: 0, ...}

# Manual reset (use with caution)
CircuitBreaker.reset(:llm_api_breaker)
```

### Configuration

Circuit breakers are configured in `VsmPhoenix.Resilience.Config`:

```elixir
# Default configuration
%{
  failure_threshold: 5,      # Failures before opening
  success_threshold: 3,      # Successes to close from half_open
  reset_timeout: 60_000,     # Ms before attempting recovery
  half_open_timeout: 30_000, # Ms for half_open test period
  window_size: 60_000        # Ms for failure counting window
}

# Component-specific configurations
:llm_api -> %{
  failure_threshold: 3,    # More sensitive for expensive calls
  reset_timeout: 120_000,  # Longer reset for API rate limits
  timeout: 30_000         # Longer timeout for LLM responses
}
```

## Bulkhead Pattern

### Purpose

Isolates resources into separate pools to prevent failures in one component from affecting others.

### Usage

```elixir
# Using integration helpers
alias VsmPhoenix.Resilience.Integration

# Worker pool for general tasks
result = Integration.with_worker_pool(fn _resource ->
  # Your work here
  process_data()
end)

# LLM worker pool with rate limiting
result = Integration.with_llm_worker_pool(fn _resource ->
  # LLM processing
  generate_response(prompt)
end)

# Sensor operations
result = Integration.with_sensor_pool(fn _resource ->
  read_sensor_data()
end)
```

### Direct Bulkhead Usage

```elixir
alias VsmPhoenix.Resilience.Bulkhead

# Check out a resource
case Bulkhead.checkout(:worker_agent_pool) do
  {:ok, resource} ->
    try do
      # Use resource
      do_work()
    after
      # Always return resource
      Bulkhead.checkin(:worker_agent_pool, resource)
    end
  
  {:error, :bulkhead_full} ->
    # Pool and queue are full
  
  {:error, :timeout} ->
    # Timed out waiting for resource
end

# Or use with_resource helper
Bulkhead.with_resource(:worker_agent_pool, fn resource ->
  # Resource automatically returned after function
  do_work_with(resource)
end)
```

### Pool Configuration

```elixir
# Default pools configured in Config module
:worker_agent -> %{
  size: 20,        # Pool size
  overflow: 10,    # Extra resources when busy
  timeout: 5000    # Checkout timeout
}

:llm_worker -> %{
  size: 5,         # Limited for API rate limits
  overflow: 2,
  timeout: 30_000,
  rate_limit: 10   # Requests per second
}
```

## Integration with VSM Systems

### System 1 - Operations

```elixir
defmodule VsmPhoenix.System1.ExampleAgent do
  use VsmPhoenix.System1.AgentBehaviour
  alias VsmPhoenix.Resilience.Integration
  
  def handle_task(task, state) do
    # Use bulkhead for isolation
    result = Integration.with_worker_pool(fn _resource ->
      # Protected work
      process_task(task)
    end)
    
    case result do
      {:ok, data} -> {:ok, data, state}
      {:error, :bulkhead_full} -> {:error, :overloaded, state}
      {:error, reason} -> {:error, reason, state}
    end
  end
  
  defp call_external_api(url) do
    # Use circuit breaker for external calls
    Integration.with_external_api_circuit_breaker(fn ->
      HTTPoison.get(url)
    end)
  end
end
```

### System 4 - Intelligence

```elixir
defmodule VsmPhoenix.System4.Intelligence do
  alias VsmPhoenix.Resilience.Integration
  
  def generate_insights(data) do
    # Protected LLM call
    Integration.with_llm_circuit_breaker(fn ->
      Integration.with_llm_worker_pool(fn _resource ->
        # Double protection: circuit breaker + bulkhead
        call_llm_api(data)
      end)
    end)
  end
end
```

### AMQP Operations

```elixir
# In any VSM component
alias VsmPhoenix.Resilience.Integration

def publish_message(channel, exchange, routing_key, message) do
  Integration.with_amqp_circuit_breaker(fn ->
    CausalityAMQP.publish(channel, exchange, routing_key, message)
  end)
end
```

## Monitoring and Telemetry

### Telemetry Events

The resilience module emits various telemetry events:

```elixir
# Circuit breaker events
[:vsm, :circuit_breaker, :call]         # Each call attempt
[:vsm, :circuit_breaker, :state_change] # State transitions
[:vsm, :circuit_breaker, :rejected]     # Rejected calls
[:vsm, :circuit_breaker, :failure]      # Failed calls

# Bulkhead events
[:vsm, :bulkhead, :checkout]    # Resource checkout attempts
[:vsm, :bulkhead, :rejected]    # Rejected due to full pool
[:vsm, :bulkhead, :timeout]     # Checkout timeouts
[:vsm, :bulkhead, :metrics]     # Periodic metrics

# Health events
[:vsm, :resilience, :health]    # Health check results
[:vsm, :resilience, :metrics]   # Aggregated metrics
```

### Algedonic Signals

The resilience module integrates with the VSM algedonic system:

- **Pain signals** sent when:
  - Circuit breakers open
  - Bulkhead pools reject requests
  - Health degrades below thresholds
  
- **Pleasure signals** sent when:
  - Circuit breakers recover and close
  - System health is restored

### Health Monitoring

```elixir
# Check overall resilience health
health = VsmPhoenix.Resilience.Integration.check_resilience_health()
# Returns:
%{
  circuit_breakers: %{
    llm_api_breaker: %{state: :closed, ...},
    amqp_breaker: %{state: :closed, ...}
  },
  bulkheads: %{
    worker_agent_pool: %{available: 15, busy: 5, waiting: 0},
    ...
  },
  overall: :healthy  # :healthy | :degraded | :unhealthy
}
```

## Exponential Backoff

For transient failures, use exponential backoff with jitter:

```elixir
alias VsmPhoenix.Resilience.Integration

# With default backoff
result = Integration.with_backoff(fn ->
  # Operation that might fail transiently
  fetch_data()
end)

# With specific service configuration
result = Integration.with_backoff(
  fn -> call_api() end,
  :external_api,
  max_retries: 5
)
```

## Best Practices

1. **Layer Protection**: Combine circuit breakers and bulkheads for critical services
2. **Monitor Metrics**: Watch for patterns in failures and adjust thresholds
3. **Test Failure Scenarios**: Regularly test how your system handles failures
4. **Gradual Degradation**: Design fallback behaviors when protection activates
5. **Tune Configuration**: Adjust thresholds based on actual usage patterns

## Troubleshooting

### Circuit Breaker Won't Close

1. Check if service is actually healthy
2. Verify success threshold is achievable
3. Look for continuous failures in half_open state
4. Check reset timeout isn't too short

### Bulkhead Always Full

1. Increase pool size if load is legitimate
2. Check for resource leaks (not returning resources)
3. Verify timeout settings are appropriate
4. Look for slow operations holding resources

### High Rejection Rate

1. Monitor metrics to identify bottlenecks
2. Consider increasing pool sizes or circuit breaker thresholds
3. Implement caching to reduce load
4. Add more specific circuit breakers for granular control

## Configuration Reference

See `lib/vsm_phoenix/resilience/config.ex` for all configuration options.

## Testing

The resilience patterns include comprehensive test suites:

```bash
# Run resilience tests
mix test test/vsm_phoenix/resilience/

# Run specific test
mix test test/vsm_phoenix/resilience/circuit_breaker_test.exs
```