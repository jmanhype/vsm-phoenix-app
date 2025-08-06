# VSM Phoenix Infrastructure Abstraction Layer Migration Guide

This guide helps you migrate from hardcoded AMQP exchanges and HTTP URLs to the new infrastructure abstraction layer.

## Overview

The infrastructure abstraction layer provides:
- Centralized configuration for AMQP exchanges
- Unified HTTP client with retry and circuit breaker support
- Environment-based configuration without code changes
- Better testability and maintainability

## Breaking Changes

### AMQP Changes

1. **Exchange Names**: All hardcoded exchange names must be replaced with configuration keys
2. **Queue Names**: Dynamic queue names now use helper functions
3. **Exchange Declaration**: Now handled centrally by ConnectionManager

### HTTP Changes

1. **Direct HTTP Calls**: Replace `:hackney`, `HTTPoison`, etc. with `HTTPClient`
2. **URL Construction**: URLs are now managed by `ServiceRegistry`
3. **Headers**: Authentication headers are managed centrally

## Migration Steps

### Step 1: Update Dependencies

Add the infrastructure supervisor to your application:

```elixir
# lib/vsm_phoenix/application.ex
children = [
  # ... existing children ...
  VsmPhoenix.AMQP.Supervisor,
  VsmPhoenix.Infrastructure.Supervisor,  # Add this
  # ... rest of children ...
]
```

### Step 2: Update AMQP Code

#### Before:
```elixir
# Hardcoded exchange names
exchange = "vsm.s1.#{agent_id}.telemetry"
AMQP.Exchange.declare(channel, exchange, :topic, durable: true)
AMQP.Basic.publish(channel, exchange, routing_key, message)
```

#### After:
```elixir
# Using infrastructure abstraction
alias VsmPhoenix.Infrastructure.{AMQPClient, ExchangeConfig}

exchange = ExchangeConfig.agent_exchange(agent_id, "telemetry")
# Exchange declaration handled by infrastructure
AMQPClient.publish(:agent_telemetry, routing_key, message, agent_id: agent_id)
```

### Step 3: Update HTTP Code

#### Before:
```elixir
# Direct HTTP calls
url = "https://api.anthropic.com/v1/messages"
headers = [
  {"x-api-key", System.get_env("ANTHROPIC_API_KEY")},
  {"anthropic-version", "2023-06-01"},
  {"content-type", "application/json"}
]
body = Jason.encode!(params)
:hackney.post(url, headers, body, [])
```

#### After:
```elixir
# Using infrastructure abstraction
alias VsmPhoenix.Infrastructure.HTTPClient

HTTPClient.post(:anthropic, "/v1/messages", params)
# Headers and authentication handled automatically
```

### Step 4: Add Configuration

Create infrastructure configuration:

```elixir
# config/infrastructure.exs
import Config

config :vsm_phoenix, :amqp_exchanges, %{
  algedonic: System.get_env("VSM_EXCHANGE_ALGEDONIC", "vsm.algedonic"),
  commands: System.get_env("VSM_EXCHANGE_COMMANDS", "vsm.commands"),
  # ... other exchanges
}

config :vsm_phoenix, :http_services, %{
  anthropic: %{
    url: System.get_env("VSM_SERVICE_ANTHROPIC_URL", "https://api.anthropic.com"),
    api_key: System.get_env("ANTHROPIC_API_KEY")
  },
  # ... other services
}
```

### Step 5: Update Agent Code

For each agent file, add the infrastructure aliases:

```elixir
alias VsmPhoenix.Infrastructure.{AMQPClient, ExchangeConfig, AMQPRoutes}
```

Then update:
1. Exchange declarations to use `ExchangeConfig`
2. Queue names to use `AMQPRoutes`
3. HTTP calls to use `HTTPClient`

### Step 6: Environment Variables

Set environment-specific variables:

```bash
# Development
export VSM_ENV_PREFIX=dev
export RABBITMQ_HOST=localhost

# Production
export VSM_ENV_PREFIX=prod
export RABBITMQ_HOST=rabbitmq.prod.example.com
export VSM_EXCHANGE_ALGEDONIC=prod.vsm.algedonic
```

## Common Patterns

### Pattern 1: Agent Exchange Names

Before:
```elixir
exchange = "vsm.s1.#{agent_id}.#{type}"
```

After:
```elixir
exchange = ExchangeConfig.agent_exchange(agent_id, type)
```

### Pattern 2: System Queue Names

Before:
```elixir
queue = "vsm.system#{n}.commands"
```

After:
```elixir
queue = AMQPRoutes.get_queue_name(:"system#{n}_commands")
```

### Pattern 3: HTTP API Calls

Before:
```elixir
HTTPoison.post(url, Jason.encode!(body), headers)
```

After:
```elixir
HTTPClient.post(:service_name, path, body)
```

## Testing the Migration

### 1. Unit Tests

Update your tests to mock the infrastructure:

```elixir
# In your test
defmodule MyModuleTest do
  use ExUnit.Case
  
  setup do
    # Mock the infrastructure
    :meck.new(VsmPhoenix.Infrastructure.HTTPClient, [:passthrough])
    :meck.expect(VsmPhoenix.Infrastructure.HTTPClient, :post, fn _, _, _ ->
      {:ok, %{status: 200, body: %{"result" => "success"}}}
    end)
    
    on_exit(fn -> :meck.unload() end)
    :ok
  end
end
```

### 2. Integration Tests

Test with real services but different exchanges:

```bash
# Test environment
export VSM_ENV_PREFIX=test
export VSM_EXCHANGE_ALGEDONIC=test.vsm.algedonic
mix test
```

### 3. Staging Validation

Deploy to staging with production-like configuration:

```bash
export VSM_ENV_PREFIX=staging
export RABBITMQ_HOST=rabbitmq.staging.example.com
# ... deploy and test
```

## Rollback Plan

If you need to rollback:

1. **Keep Old Code**: The abstraction layer is additive, old code paths still work
2. **Feature Flag**: Use a feature flag to switch between old and new implementations
3. **Gradual Migration**: Migrate one service/agent at a time

```elixir
# Feature flag approach
if Application.get_env(:vsm_phoenix, :use_infrastructure_abstraction, true) do
  HTTPClient.post(:anthropic, "/v1/messages", body)
else
  # Old implementation
  :hackney.post(url, headers, Jason.encode!(body), [])
end
```

## Troubleshooting

### Issue: Exchange Not Found

**Symptom**: `NOT_FOUND - no exchange 'vsm.algedonic' in vhost '/'`

**Solution**: 
1. Check exchange configuration in `ExchangeConfig`
2. Verify environment variables are set
3. Ensure ConnectionManager has started and declared exchanges

### Issue: HTTP Request Fails

**Symptom**: `{:error, :unknown_service}`

**Solution**:
1. Check service is registered in `ServiceRegistry`
2. Verify service URL configuration
3. Check API key is set in environment

### Issue: Queue Binding Fails

**Symptom**: Queue not receiving messages

**Solution**:
1. Verify queue name matches routing key pattern
2. Check exchange type (fanout vs topic)
3. Ensure queue is bound to correct exchange

## Performance Considerations

The abstraction layer adds minimal overhead:
- Exchange name lookups are compile-time where possible
- HTTP client adds ~1-2ms for retry logic
- Circuit breakers prevent cascading failures

## Next Steps

After migration:
1. Enable telemetry for monitoring
2. Configure alerts for circuit breaker trips
3. Set up environment-specific dashboards
4. Document your specific configuration

## Support

For issues or questions:
1. Check the configuration guide
2. Review error logs for specific issues
3. Test with minimal configuration first
4. Gradually add complexity