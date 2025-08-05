# Phase 2 VSM Cybernetics - Quick Start Guide

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- PostgreSQL 14+ (optional, for persistence)
- RabbitMQ 3.11+ (for AMQP features)
- OpenAI or Anthropic API keys (for LLM features)
- Telegram Bot Token (for NLU features)

## Environment Setup

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Configure essential Phase 2 variables:
```bash
# LLM Configuration
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
ENABLE_LLM_VARIETY=true
DEFAULT_LLM_PROVIDER=openai

# Telegram Bot
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_WEBHOOK_URL=https://yourdomain.com/api/telegram/webhook

# Security
AMQP_ENCRYPTION_KEY=generate_32_byte_key
AMQP_SIGNING_KEY=generate_32_byte_key
```

## Quick Start

### 1. Install Dependencies
```bash
mix deps.get
npm install --prefix assets
```

### 2. Start Services
```bash
# Start RabbitMQ (if using Docker)
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3-management

# Start Phoenix with Phase 2 enabled
mix phx.server
```

### 3. Verify Phase 2 Components

Check that all components are running:
```bash
curl http://localhost:4000/api/vsm/status | jq .phase2
```

Expected output:
```json
{
  "phase2": {
    "goldrush": "active",
    "telegram_nlu": "active",
    "amqp_security": "active",
    "llm_integration": "active"
  }
}
```

## Quick Examples

### 1. Create Your First Pattern

```bash
# Create a simple CPU monitoring pattern
curl -X POST http://localhost:4000/api/goldrush/patterns \
  -H "Content-Type: application/json" \
  -d '{
    "name": "high_cpu_alert",
    "expressions": [
      {"field": "cpu_usage", "operator": "greater_than", "value": 80}
    ],
    "actions": ["notify_telegram"]
  }'
```

### 2. Test Pattern Matching

```bash
# Submit an event that matches the pattern
curl -X POST http://localhost:4000/api/goldrush/events \
  -H "Content-Type: application/json" \
  -d '{
    "type": "system_metrics",
    "cpu_usage": 85,
    "timestamp": "2024-01-15T10:30:00Z"
  }'
```

### 3. Natural Language Query via API

```bash
# Send a natural language query
curl -X POST http://localhost:4000/api/telegram/nlu \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Show me system health for the last hour",
    "user_id": "test_user"
  }'
```

### 4. Test LLM Variety Analysis

```bash
# Request variety analysis
curl -X POST http://localhost:4000/api/vsm/system4/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "system": "system3",
    "current_variety": 0.65,
    "required_variety": 0.85
  }'
```

## Interactive Testing

### Using IEx Console

```elixir
# Start interactive console
iex -S mix

# Test GoldRush patterns
alias VsmPhoenix.Goldrush.PatternEngine

{:ok, pattern_id} = PatternEngine.create_pattern(%{
  name: "test_pattern",
  expressions: [%{field: "value", operator: "greater_than", value: 100}]
})

PatternEngine.process_event(%{value: 150})

# Test Telegram NLU
alias VsmPhoenix.Telegram.NLUIntegration

{:ok, result} = NLUIntegration.process_command(
  "What's the variety level in System 4?",
  user_id: "test"
)

# Test LLM Integration
alias VsmPhoenix.LLM.Client

{:ok, response} = Client.chat_completion(%{
  messages: [%{role: "user", content: "Analyze system variety"}],
  model: "gpt-4-turbo"
})
```

## Common Use Cases

### 1. Real-time Monitoring Dashboard

```elixir
# Subscribe to pattern matches in your LiveView
def mount(_params, _session, socket) do
  VsmPhoenix.Goldrush.EventBus.subscribe("high_cpu_alert")
  {:ok, assign(socket, alerts: [])}
end

def handle_info({:pattern_match, alert}, socket) do
  {:noreply, update(socket, :alerts, &[alert | &1])}
end
```

### 2. Telegram Bot Commands

Configure your bot to handle natural language:
```elixir
# In your Telegram bot handler
def handle_update(%{"message" => %{"text" => "/natural " <> command}}) do
  {:ok, response} = VsmPhoenix.Telegram.NLUIntegration.process_command(command)
  send_message(response.formatted_response)
end
```

### 3. Secure Inter-System Messages

```elixir
# Send encrypted message between VSM systems
alias VsmPhoenix.AMQP.SecurityProtocol

message = %{
  from: "system1",
  to: "system4",
  type: "variety_request",
  data: %{metric: "current_variety"}
}

{:ok, encrypted} = SecurityProtocol.encrypt_and_sign(message)
VsmPhoenix.AMQP.Publisher.publish("vsm.system4", encrypted)
```

## Troubleshooting

### Component Not Starting

1. Check logs: `tail -f log/dev.log`
2. Verify configuration: `mix phx.config.check`
3. Test individual components: `mix test test/vsm_phoenix/phase2_integration_test.exs`

### Pattern Not Matching

```elixir
# Debug pattern matching
VsmPhoenix.Goldrush.PatternEngine.debug_mode(true)
VsmPhoenix.Goldrush.PatternEngine.test_pattern(pattern, event)
```

### LLM Timeout

```elixir
# Adjust timeout in config
config :vsm_phoenix, :llm,
  timeout: 30_000,  # 30 seconds
  max_retries: 3
```

## Next Steps

1. Read the full [Phase 2 Usage Guide](PHASE2_USAGE.md)
2. Explore [Pattern Examples](../examples/patterns/)
3. Check [API Documentation](api.md#phase-2-endpoints)
4. Join our Discord for support

## Performance Tips

- Use pattern aggregations for high-volume events
- Enable caching for LLM responses
- Configure message batching for AMQP
- Use connection pooling for external services

Happy coding with VSM Phase 2! 🚀