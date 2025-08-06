# VSM Phoenix Infrastructure Configuration Guide

This guide explains how to configure the VSM Phoenix infrastructure abstraction layer, which provides centralized management of AMQP exchanges and HTTP endpoints.

## Overview

The infrastructure abstraction layer allows you to:
- Configure AMQP exchange names per environment
- Manage HTTP service endpoints centrally
- Switch between different environments without code changes
- Add circuit breakers and retry logic to HTTP requests

## Configuration Methods

### 1. Environment Variables

The recommended way to configure the infrastructure layer is through environment variables:

#### AMQP Exchange Configuration

```bash
# Override default exchange names
export VSM_EXCHANGE_ALGEDONIC=prod.vsm.algedonic
export VSM_EXCHANGE_COMMANDS=prod.vsm.commands
export VSM_EXCHANGE_CONTROL=prod.vsm.control
export VSM_EXCHANGE_INTELLIGENCE=prod.vsm.intelligence
export VSM_EXCHANGE_POLICY=prod.vsm.policy
export VSM_EXCHANGE_AUDIT=prod.vsm.audit
export VSM_EXCHANGE_SWARM=prod.vsm.swarm

# Set environment prefix for all resources
export VSM_ENV_PREFIX=prod
```

#### HTTP Service Configuration

```bash
# Configure Anthropic API
export ANTHROPIC_API_KEY=your-api-key
export VSM_SERVICE_ANTHROPIC_URL=https://api.anthropic.com
export ANTHROPIC_VERSION=2023-06-01

# Configure Telegram Bot
export TELEGRAM_BOT_TOKEN=your-bot-token
export VSM_SERVICE_TELEGRAM_URL=https://api.telegram.org

# Configure MCP Registry
export VSM_SERVICE_MCP_REGISTRY_URL=https://mcp-registry.anthropic.com
```

#### HTTP Client Settings

```bash
# Timeout and retry configuration
export VSM_HTTP_TIMEOUT=30000          # 30 seconds
export VSM_HTTP_MAX_RETRIES=3
export VSM_HTTP_RETRY_DELAY=1000       # 1 second

# Circuit breaker configuration
export VSM_HTTP_CIRCUIT_BREAKER_ENABLED=true
export VSM_HTTP_CIRCUIT_BREAKER_THRESHOLD=5
export VSM_HTTP_CIRCUIT_BREAKER_RESET=60000    # 1 minute
export VSM_HTTP_CIRCUIT_BREAKER_HALF_OPEN=3
```

#### AMQP Connection Settings

```bash
# RabbitMQ connection
export RABBITMQ_HOST=localhost
export RABBITMQ_PORT=5672
export RABBITMQ_USER=guest
export RABBITMQ_PASS=guest
export RABBITMQ_VHOST=/

# Connection pool settings
export VSM_AMQP_POOL_SIZE=10
export VSM_AMQP_RECONNECT_INTERVAL=5000
```

### 2. Configuration Files

You can also configure the infrastructure in your config files:

```elixir
# config/runtime.exs or config/prod.exs
import Config

# Import infrastructure configuration
import_config "infrastructure.exs"

# Override specific settings
config :vsm_phoenix, :amqp_exchanges,
  algedonic: "production.vsm.algedonic",
  commands: "production.vsm.commands"

config :vsm_phoenix, :http_services,
  anthropic: %{
    url: "https://api.anthropic.com",
    api_key: System.fetch_env!("ANTHROPIC_API_KEY")
  }
```

## Usage Examples

### Using the AMQP Abstraction

```elixir
# Instead of hardcoding exchange names:
# AMQP.Basic.publish(channel, "vsm.algedonic", "", message)

# Use the abstraction:
alias VsmPhoenix.Infrastructure.{AMQPClient, ExchangeConfig}

exchange_name = ExchangeConfig.get_exchange_name(:algedonic)
AMQPClient.publish(:algedonic, "", message)
```

### Using the HTTP Abstraction

```elixir
# Instead of hardcoding URLs:
# :hackney.post("https://api.anthropic.com/v1/messages", headers, body)

# Use the abstraction:
alias VsmPhoenix.Infrastructure.HTTPClient

HTTPClient.post(:anthropic, "/v1/messages", body)
```

## Environment-Specific Configuration

### Development

```bash
# .env.development
VSM_ENV_PREFIX=dev
RABBITMQ_HOST=localhost
VSM_HTTP_TIMEOUT=60000
VSM_HTTP_CIRCUIT_BREAKER_ENABLED=false
```

### Staging

```bash
# .env.staging
VSM_ENV_PREFIX=staging
RABBITMQ_HOST=rabbitmq.staging.internal
VSM_HTTP_TIMEOUT=45000
VSM_HTTP_CIRCUIT_BREAKER_ENABLED=true
VSM_HTTP_CIRCUIT_BREAKER_THRESHOLD=10
```

### Production

```bash
# .env.production
VSM_ENV_PREFIX=prod
RABBITMQ_HOST=rabbitmq-cluster.prod.internal
VSM_HTTP_TIMEOUT=30000
VSM_HTTP_CIRCUIT_BREAKER_ENABLED=true
VSM_HTTP_CIRCUIT_BREAKER_THRESHOLD=5
VSM_HTTP_MAX_RETRIES=5
```

## Adding New Services

To add a new HTTP service:

1. Register it with the ServiceRegistry:

```elixir
VsmPhoenix.Infrastructure.ServiceRegistry.register_service(:my_service, %{
  url: "https://api.myservice.com",
  paths: %{
    users: "/v1/users",
    orders: "/v1/orders"
  }
})
```

2. Configure authentication:

```elixir
# Via environment variables
export VSM_SERVICE_MY_SERVICE_API_KEY=your-api-key
export VSM_SERVICE_MY_SERVICE_API_KEY_HEADER=x-api-key

# Or in code
config :vsm_phoenix, :http_services,
  my_service: %{
    url: "https://api.myservice.com",
    auth: {:api_key, "x-api-key", System.get_env("MY_SERVICE_API_KEY")}
  }
```

3. Use the service:

```elixir
HTTPClient.get(:my_service, "/v1/users")
HTTPClient.post(:my_service, "/v1/orders", order_data)
```

## Monitoring and Debugging

### Enable Request Logging

```bash
export VSM_HTTP_LOG_REQUESTS=true
export VSM_HTTP_LOG_RESPONSES=true
```

### Check Service Configuration

```elixir
# In IEx console
VsmPhoenix.Infrastructure.ServiceRegistry.list_services()
VsmPhoenix.Infrastructure.ExchangeConfig.all_exchanges()
```

### Monitor Circuit Breaker Status

```elixir
# Check if a service is available
HTTPClient.circuit_breaker_status(:anthropic)
```

## Best Practices

1. **Use Environment Variables**: Keep sensitive configuration like API keys in environment variables, not in code.

2. **Environment Prefixes**: Use `VSM_ENV_PREFIX` to automatically namespace all resources per environment.

3. **Circuit Breakers**: Enable circuit breakers in production to prevent cascading failures.

4. **Retry Logic**: Configure appropriate retry counts and delays based on your service SLAs.

5. **Timeouts**: Set realistic timeouts - shorter for user-facing operations, longer for background jobs.

6. **Monitoring**: Enable telemetry and logging in production for debugging issues.

## Migration from Hardcoded Values

If you're migrating from hardcoded values:

1. **Identify all hardcoded exchanges and URLs** (already done in Phase 1)
2. **Update code to use abstractions** (already done in Phase 5)
3. **Set environment variables** for your deployment
4. **Test in staging** before production deployment
5. **Monitor for any issues** after deployment

## Troubleshooting

### AMQP Exchange Not Found

If you get "exchange not found" errors:
- Check that `VSM_EXCHANGE_*` variables are set correctly
- Verify RabbitMQ has the exchanges declared
- Check for typos in exchange keys

### HTTP Service Unreachable

If HTTP requests fail:
- Verify `VSM_SERVICE_*_URL` is set correctly
- Check API keys are configured
- Look at circuit breaker status
- Enable request logging for debugging

### Configuration Not Loading

If configuration seems incorrect:
- Check environment variable names (case-sensitive)
- Verify config files are imported in the right order
- Use `Application.get_env(:vsm_phoenix, :key)` to debug