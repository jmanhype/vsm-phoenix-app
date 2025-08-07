# VSM Phoenix Resilience - Production Deployment Guide

This guide covers deploying the VSM Phoenix resilience patterns in production environments.

## Pre-Deployment Checklist

### 1. Configuration Review

Ensure `config/resilience.exs` is properly configured for your environment:

```elixir
# Import resilience config in your main config file
import_config "resilience.exs"
```

### 2. Dependencies

Add required dependencies to `mix.exs`:

```elixir
{:telemetry, "~> 1.0"},
{:telemetry_metrics, "~> 0.6"},
{:amqp, "~> 3.0"},
{:httpoison, "~> 2.0"}  # Or your preferred HTTP client
```

### 3. Environment Variables

Set the following environment variables:

```bash
# AMQP/RabbitMQ
RABBITMQ_HOST=your-rabbitmq-host
RABBITMQ_PORT=5672
RABBITMQ_USER=your-user
RABBITMQ_PASS=your-password
RABBITMQ_VHOST=/

# API Keys
ANTHROPIC_API_KEY=your-claude-key
TELEGRAM_BOT_TOKEN=your-bot-token

# Azure Service Bus (if used)
AZURE_SERVICE_BUS_NAMESPACE=your-namespace
AZURE_SERVICE_BUS_KEY_NAME=RootManageSharedAccessKey
AZURE_SERVICE_BUS_KEY=your-key
```

## Deployment Steps

### 1. Enable Resilience Supervisor

Ensure the resilience supervisor is started in your application:

```elixir
# lib/vsm_phoenix/application.ex
children = [
  # ... other children
  VsmPhoenix.Resilience.Supervisor,  # Add this line
  # ... rest of children
]
```

### 2. Update Existing Code

Replace direct AMQP/HTTP calls with resilient versions:

```elixir
# Before
{:ok, channel} = VsmPhoenix.AMQP.ConnectionManager.get_channel()

# After  
{:ok, channel} = VsmPhoenix.Resilience.IntegrationAdapter.get_amqp_channel()

# Before
HTTPClient.post(:api, "/endpoint", data)

# After
VsmPhoenix.Resilience.IntegrationAdapter.resilient_http_request(
  :external_api_client, :post, "https://api.example.com/endpoint", data
)
```

### 3. Add Dashboard Route

Ensure the resilience dashboard is accessible:

```elixir
# lib/vsm_phoenix_web/router.ex
scope "/", VsmPhoenixWeb do
  pipe_through :browser
  
  live "/resilience", ResilienceDashboardLive, :index
end
```

## Monitoring and Alerting

### 1. Telemetry Integration

The resilience module emits telemetry events that can be consumed by monitoring systems:

```elixir
# Attach to resilience events
:telemetry.attach_many(
  "production-resilience-handler",
  [
    [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
    [:vsm_phoenix, :resilience, :health_check]
  ],
  &YourApp.Monitoring.handle_resilience_event/4,
  nil
)
```

### 2. Prometheus Metrics

Export metrics for Prometheus scraping:

```elixir
# Add to your metrics endpoint
def metrics(conn, _params) do
  resilience_metrics = VsmPhoenix.Resilience.Telemetry.export_prometheus_metrics()
  
  conn
  |> put_resp_content_type("text/plain")
  |> send_resp(200, resilience_metrics)
end
```

### 3. Alerting Rules

Set up alerts for critical resilience events:

```yaml
# Prometheus alerting rules
groups:
  - name: vsm_resilience
    rules:
      - alert: CircuitBreakerOpen
        expr: circuit_breaker_state{state="open"} == 1
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Circuit breaker {{ $labels.name }} is open"
          
      - alert: BulkheadHighUtilization
        expr: bulkhead_utilization_percent > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Bulkhead {{ $labels.bulkhead }} is {{ $value }}% utilized"
          
      - alert: HealthCheckFailing
        expr: health_check_status{status!="healthy"} == 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "VSM system health is {{ $labels.status }}"
```

## Performance Tuning

### 1. Circuit Breaker Tuning

Monitor circuit breaker behavior and adjust thresholds:

```bash
# Check circuit breaker metrics
curl -s http://localhost:4000/api/resilience/metrics | grep circuit_breaker
```

Common adjustments:
- **Too sensitive**: Increase `failure_threshold`
- **Too slow to recover**: Decrease `timeout`
- **Flapping**: Increase `success_threshold`

### 2. Bulkhead Sizing

Monitor bulkhead utilization and queue depth:

```elixir
# Get bulkhead metrics
metrics = VsmPhoenix.Resilience.Bulkhead.get_metrics(:bulkhead_http_connections)

# Key metrics to watch:
# - utilization_percent (target: < 70%)
# - rejected_checkouts (minimize)
# - peak_queue_size (should be < max_waiting)
```

### 3. Retry Optimization

Adjust retry settings based on error patterns:

```elixir
# Custom retry for specific operations
VsmPhoenix.Resilience.Retry.with_retry(
  fn -> expensive_operation() end,
  max_attempts: 3,
  base_backoff: 2_000,
  retry_on: [:error, :timeout]  # Don't retry on authentication errors
)
```

## Troubleshooting

### Common Issues

#### Circuit Breakers Opening Frequently

**Symptoms**: Services marked as unavailable, circuit breaker state = "open"

**Diagnosis**:
1. Check downstream service health
2. Review error logs for root cause
3. Verify timeout settings aren't too aggressive

**Solutions**:
- Increase failure threshold if errors are transient
- Fix underlying service issues
- Adjust timeout values

#### Bulkhead Rejections

**Symptoms**: "bulkhead_full" errors, high rejection rates

**Diagnosis**:
1. Check resource utilization trends
2. Identify slow operations holding resources
3. Review concurrent operation patterns

**Solutions**:
- Increase bulkhead size if justified by capacity
- Optimize slow operations
- Add caching to reduce load
- Implement request coalescing

#### Health Checks Failing

**Symptoms**: System status "degraded" or "unhealthy"

**Diagnosis**:
1. Check individual component health
2. Review error logs from health checks
3. Verify network connectivity

**Solutions**:
- Fix failing components
- Adjust health check timeouts
- Review health check logic

### Debugging Commands

```bash
# Check overall system health
curl -s http://localhost:4000/api/vsm/status

# Get detailed resilience metrics  
curl -s http://localhost:4000/api/resilience/detailed

# View circuit breaker states
curl -s http://localhost:4000/api/resilience/circuit-breakers

# Check bulkhead utilization
curl -s http://localhost:4000/api/resilience/bulkheads
```

## Scaling Considerations

### 1. Horizontal Scaling

When running multiple instances:

- Circuit breaker state is per-instance (consider distributed state for critical services)
- Bulkheads are per-instance (scale based on per-instance capacity)
- Health monitoring is per-instance

### 2. Load Balancer Configuration

Configure load balancers to:
- Respect circuit breaker states (health check endpoints)
- Distribute load evenly across instances
- Handle graceful shutdowns

### 3. Database Connections

If using databases, ensure resilience patterns don't overwhelm connection pools:

```elixir
# Coordinate with Ecto pool size
config :vsm_phoenix, VsmPhoenix.Repo,
  pool_size: 15  # Should be > bulkhead max_concurrent for DB operations
```

## Security Considerations

### 1. API Keys and Secrets

Never log sensitive information in resilience error messages:

```elixir
# Good: Generic error
Logger.error("External API request failed")

# Bad: Exposes API key
Logger.error("Request to #{url} with key #{api_key} failed")
```

### 2. Rate Limiting

Resilience patterns provide protection but don't replace proper rate limiting:

```elixir
# Combine with rate limiting
|> Plug.RateLimiter.ip(max_requests: 100, interval: :minute)
|> VsmPhoenix.Resilience.Middleware.circuit_breaker()
```

### 3. Input Validation

Resilience patterns should not bypass input validation:

```elixir
def handle_request(data) do
  with {:ok, validated_data} <- validate_input(data),
       {:ok, result} <- resilient_operation(validated_data) do
    {:ok, result}
  end
end
```

## Maintenance

### 1. Regular Health Checks

Schedule regular health assessments:

```bash
# Weekly resilience health report
mix run -e "VsmPhoenix.Resilience.HealthMonitor.get_health() |> IO.inspect()"
```

### 2. Metrics Review

Weekly review of:
- Circuit breaker trip frequency
- Bulkhead utilization trends  
- Retry success rates
- Overall system health trends

### 3. Configuration Updates

Adjust configuration based on production behavior:
- Tune thresholds based on actual error rates
- Adjust timeouts based on measured response times
- Scale bulkheads based on traffic patterns

## Emergency Procedures

### 1. Circuit Breaker Override

In emergencies, reset circuit breakers manually:

```elixir
# Reset specific circuit breaker
VsmPhoenix.Resilience.CircuitBreaker.reset(:your_breaker_name)

# Or via IEx in production
iex> VsmPhoenix.Resilience.CircuitBreaker.reset(VsmPhoenix.AMQP.ConnectionManager_CircuitBreaker)
```

### 2. Bulkhead Scaling

Temporarily increase bulkhead capacity:

```elixir
# This would require implementing dynamic scaling
# For now, restart with updated configuration
```

### 3. Disable Resilience

If resilience patterns cause issues, they can be bypassed:

```elixir
# config/prod.exs - Emergency bypass
config :vsm_phoenix, :resilience,
  circuit_breakers_enabled: false,
  bulkheads_enabled: false,
  retry_enabled: false
```

**⚠️ Warning**: Only use emergency bypass as a last resort. Address root causes instead.

## Success Metrics

Track these KPIs to measure resilience effectiveness:

1. **Mean Time to Recovery (MTTR)**: Time to recover from failures
2. **Error Rate Reduction**: Decrease in user-facing errors
3. **Service Availability**: Overall uptime improvement
4. **Resource Utilization**: Efficient use of compute/network resources
5. **Operational Overhead**: Minimal impact on normal operations

Target improvements with resilience patterns:
- 50% reduction in cascading failures
- 30% improvement in MTTR
- 99.9% service availability
- < 5% performance overhead