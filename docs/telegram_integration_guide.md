# Telegram Integration Guide

This guide covers how to integrate Telegram bots with the VSM Phoenix application, enabling communication between Telegram users and the Viable Systems Model hierarchy.

## Overview

The Telegram integration allows:
- Creating bot agents that operate at System 1 level
- Receiving and processing Telegram messages through VSM hierarchy
- Monitoring variety engineering metrics via bot commands
- Sending algedonic signals from Telegram
- Real-time system status updates

## Architecture

```
Telegram User
    ↓
Telegram Bot API
    ↓
Webhook Endpoint (/api/vsm/telegram/webhook/:bot_token)
    ↓
TelegramController
    ↓
TelegramAgent (S1)
    ↓
VSM Hierarchy (S2-S5)
```

## Quick Start

### 1. Create a Telegram Bot

First, create a bot on Telegram:
1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot` and follow instructions
3. Save your bot token

### 2. Create Bot Agent in VSM

Use the setup script to create a bot agent:

```bash
mix run scripts/setup_telegram_bot.exs create "YOUR_BOT_TOKEN" "MyVSMBot"
```

### 3. Set Webhook (Production)

For production deployment with a public URL:

```bash
mix run scripts/setup_telegram_bot.exs webhook "YOUR_BOT_TOKEN" "https://your-domain.com"
```

For local development with ngrok:

```bash
# Terminal 1: Start ngrok
ngrok http 4000

# Terminal 2: Set webhook with ngrok URL
mix run scripts/setup_telegram_bot.exs webhook "YOUR_BOT_TOKEN" "https://abc123.ngrok.io"
```

## Available Bot Commands

Default commands available to Telegram users:

- `/start` - Initialize interaction with VSM
- `/status` - Get current VSM system status
- `/variety` - Check variety engineering metrics
- `/policy` - Request policy decision from System 5
- `/alert` - Send algedonic signal
- `/help` - Show available commands

## Configuration

Telegram integration settings in `config/config.exs`:

```elixir
config :vsm_phoenix, :telegram,
  webhook_timeout: 30_000,           # Webhook response timeout
  max_message_length: 4096,          # Max message length
  rate_limit: %{
    messages_per_minute: 30,         # Rate limiting
    commands_per_minute: 20
  },
  default_features: %{
    variety_monitoring: true,        # Enable variety metrics
    vsm_status: true,               # Enable status queries
    algedonic_signals: true,        # Enable alert signals
    auto_responses: true            # Auto-respond to commands
  }
```

## Variety Engineering Integration

The Telegram bot integrates with variety engineering to:

1. **Monitor Message Variety**: Track diversity of incoming messages
2. **Apply Filters**: Reduce variety as messages move up VSM hierarchy
3. **Amplify Responses**: Expand single policies into multiple operational responses
4. **Balance Check**: Ensure Ashby's Law compliance

### Example Variety Flow

```
Telegram Message (S1) → High Variety (1000 bits)
    ↓ Filter (70% reduction)
Coordination (S2) → Medium Variety (300 bits)
    ↓ Filter (60% reduction)
Control (S3) → Lower Variety (120 bits)
    ↓ Filter (65% reduction)
Intelligence (S4) → Low Variety (42 bits)
    ↓ Filter (75% reduction)
Policy (S5) → Minimal Variety (10 bits)
```

## API Endpoints

### Webhook Endpoint
```
POST /api/vsm/telegram/webhook/:bot_token
```

Receives Telegram updates. The bot token in the URL is used to route to the correct agent.

### Health Check
```
GET /api/vsm/telegram/health
```

Returns status of all Telegram agents:
```json
{
  "healthy": true,
  "telegram_agents": 2,
  "agents": [
    {
      "id": "agent_123",
      "status": "active",
      "metadata": {...}
    }
  ],
  "timestamp": "2024-01-20T10:30:00Z"
}
```

## Testing

### Run Integration Demo

Test both Telegram and variety engineering:

```bash
# Basic demo
mix run examples/integration_showcase_demo.exs "YOUR_BOT_TOKEN"

# With webhook testing
mix run examples/integration_showcase_demo.exs "YOUR_BOT_TOKEN" "https://your-ngrok-url"
```

### Manual Testing

1. List all Telegram agents:
   ```bash
   mix run scripts/setup_telegram_bot.exs list
   ```

2. Test bot connectivity:
   ```bash
   mix run scripts/setup_telegram_bot.exs test "YOUR_BOT_TOKEN"
   ```

3. Send test message via curl:
   ```bash
   curl -X POST http://localhost:4000/api/vsm/telegram/webhook/YOUR_BOT_TOKEN \
     -H "Content-Type: application/json" \
     -d '{
       "update_id": 1,
       "message": {
         "message_id": 1,
         "from": {"id": 12345, "first_name": "Test"},
         "chat": {"id": 12345, "type": "private"},
         "text": "/status"
       }
     }'
   ```

## Security Considerations

1. **Bot Token Security**: Never commit bot tokens to version control
2. **Webhook Validation**: The system validates bot tokens before processing
3. **Rate Limiting**: Built-in rate limiting prevents abuse
4. **Message Filtering**: Variety engineering naturally filters malicious patterns

## Troubleshooting

### Bot Not Responding

1. Check agent is created: `mix run scripts/setup_telegram_bot.exs list`
2. Verify webhook URL is correct and accessible
3. Check application logs for errors

### Webhook Errors

1. Ensure public URL is accessible (use ngrok for local testing)
2. Verify bot token matches in URL and agent config
3. Check firewall settings

### Variety Imbalance

1. Monitor variety metrics in logs
2. Adjust filter thresholds in `config/variety_engineering.exs`
3. Check amplifier factors are appropriate

## Advanced Usage

### Custom Commands

Add custom commands when creating the agent:

```elixir
config = %{
  bot_token: token,
  commands: [
    %{command: "custom", description: "Custom VSM command"},
    # ... more commands
  ]
}
```

### Message Handlers

Implement custom message handling in TelegramAgent:

```elixir
def handle_message(%{"text" => "/custom"}, state) do
  # Custom logic here
  reply = "Custom response from VSM"
  {:reply, reply, state}
end
```

### Variety Monitoring

Subscribe to variety metrics:

```elixir
Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "variety:metrics")
```

## Next Steps

1. Implement persistent message storage
2. Add inline keyboard support
3. Create bot analytics dashboard
4. Implement multi-language support
5. Add voice message processing