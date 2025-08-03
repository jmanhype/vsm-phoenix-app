# Telegram Integration Guide

## Overview

The VSM Phoenix application includes a powerful Telegram bot integration that allows you to monitor and control your Viable System Model through Telegram. The integration is implemented as a System 1 (S1) agent that communicates with other VSM components through AMQP messaging.

## Features

- **Real-time Monitoring**: Receive system status updates and alerts directly in Telegram
- **Command Execution**: Control VSM operations through bot commands
- **Alert Broadcasting**: Critical system alerts are automatically sent to admin chats
- **Flexible Deployment**: Supports both webhook and polling modes
- **Multi-chat Support**: Authorize multiple users and admin chats
- **Secure Access**: Built-in authorization and admin role management

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Telegram API  │────▶│ TelegramAgent   │────▶│   AMQP Bus      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │                          │
                               ▼                          ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │  S1 Registry    │     │  Other Agents   │
                        └─────────────────┘     └─────────────────┘
```

The TelegramAgent:
- Registers with the S1 Registry as a `:telegram` type agent
- Subscribes to critical alerts via Phoenix.PubSub
- Publishes events and commands through AMQP
- Handles incoming updates via webhook or polling

## Setup

### 1. Create a Telegram Bot

1. Open Telegram and search for [@BotFather](https://t.me/botfather)
2. Send `/newbot` and follow the instructions
3. Save the bot token provided by BotFather

### 2. Configure Environment Variables

```bash
# Required: Your bot token from BotFather
export TELEGRAM_BOT_TOKEN="your_bot_token_here"

# Optional: Webhook URL (for production)
export TELEGRAM_WEBHOOK_URL="https://your-domain.com/api/vsm/telegram/webhook/your_bot_token_here"

# Optional: Pre-authorized chat IDs (comma-separated)
export TELEGRAM_AUTHORIZED_CHATS="123456789,987654321"

# Optional: Admin chat IDs (comma-separated)
export TELEGRAM_ADMIN_CHATS="123456789"
```

### 3. Find Your Chat ID

To find your Telegram chat ID:
1. Start the bot with minimal config: `TELEGRAM_BOT_TOKEN=token mix run examples/telegram_integration_demo.exs`
2. Send `/start` to your bot in Telegram
3. The chat ID will appear in the logs
4. Add it to `TELEGRAM_AUTHORIZED_CHATS` or `TELEGRAM_ADMIN_CHATS`

## Deployment Modes

### Polling Mode (Development)

Perfect for development and testing. The bot actively polls Telegram for updates.

```elixir
config = %{
  bot_token: "your_token",
  webhook_mode: false
}

S1Supervisor.spawn_agent(:telegram, config: config)
```

### Webhook Mode (Production)

More efficient for production. Telegram sends updates to your webhook endpoint.

```elixir
config = %{
  bot_token: "your_token",
  webhook_mode: true,
  webhook_url: "https://your-domain.com/api/vsm/telegram/webhook/your_token"
}

S1Supervisor.spawn_agent(:telegram, config: config)
```

**Note**: Webhooks require:
- HTTPS with valid SSL certificate
- Publicly accessible URL
- Port 443, 80, 88, or 8443

## Bot Commands

### User Commands

- `/start` - Initialize the bot and get your chat ID
- `/help` - Show available commands
- `/status` - Get current system status
- `/vsm list` - List active VSM instances
- `/vsm spawn <config>` - Spawn a new VSM instance

### Admin Commands

Admin commands are only available to chats listed in `admin_chats`:

- `/alert <level> <message>` - Broadcast an alert (levels: info, warning, critical)
- `/authorize <chat_id>` - Authorize a new chat to use the bot

## Integration with VSM

### Receiving Alerts

The TelegramAgent automatically subscribes to critical alerts:

```elixir
# From anywhere in your VSM system:
Phoenix.PubSub.broadcast(
  VsmPhoenix.PubSub,
  "vsm:alerts:critical",
  {:pubsub, :alert, %{
    level: "critical",
    source: "s4_intelligence",
    message: "Variety detected exceeds threshold!",
    timestamp: DateTime.utc_now()
  }}
)
```

### Sending Messages Programmatically

```elixir
# Direct message sending
TelegramAgent.send_message(agent_id, chat_id, "Hello from VSM!")

# With formatting
TelegramAgent.send_message(agent_id, chat_id, "*Bold* _italic_ `code`", 
  parse_mode: "Markdown"
)

# With keyboard
TelegramAgent.send_message(agent_id, chat_id, "Choose an option:",
  reply_markup: %{
    inline_keyboard: [
      [%{text: "Status", callback_data: "status"}],
      [%{text: "Restart", callback_data: "restart"}]
    ]
  }
)
```

### AMQP Integration

The TelegramAgent publishes events to AMQP:

```
Exchange: vsm.s1.{agent_id}.telegram.events
Routing Keys:
- telegram.event.message_received
- telegram.event.command_processed
- telegram.event.unauthorized_access
```

And listens for commands on:
```
Queue: vsm.s1.{agent_id}.telegram.commands
```

## Security Considerations

1. **Token Security**: Never commit your bot token to version control
2. **Chat Authorization**: Always use the authorization system
3. **Admin Privileges**: Limit admin chats to trusted users only
4. **Webhook Security**: Use HTTPS with valid certificates
5. **Rate Limiting**: The bot includes built-in rate limiting per chat

## Monitoring

Check bot health and metrics:

```bash
# Via HTTP API
curl http://localhost:4000/api/vsm/telegram/health

# Via Elixir console
{:ok, metrics} = TelegramAgent.get_telegram_metrics("agent_id")
```

Metrics include:
- Total messages sent/received
- Commands processed
- Command breakdown
- Error count
- Message rate per minute

## Troubleshooting

### Bot Not Responding

1. Check bot token is correct
2. Verify bot is not already running elsewhere
3. Check logs for initialization errors
4. Ensure network connectivity to Telegram API

### Webhook Issues

1. Verify SSL certificate is valid
2. Check webhook URL is publicly accessible
3. Test with: `curl https://api.telegram.org/bot{token}/getWebhookInfo`
4. Fall back to polling mode if needed

### Authorization Problems

1. Ensure chat ID is in authorized_chats
2. Check logs for unauthorized access attempts
3. Use admin command to authorize: `/authorize <chat_id>`

## Example: Complete Integration

```elixir
# In your application supervisor
children = [
  # ... other children ...
  
  # Telegram bot with full config
  {VsmPhoenix.System1.Agents.TelegramAgent, [
    id: "telegram_primary",
    config: %{
      bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
      webhook_mode: Mix.env() == :prod,
      webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL"),
      authorized_chats: [123456789, 987654321],
      admin_chats: [123456789],
      rate_limit: 60,  # messages per minute
      rate_window: 60_000  # 1 minute
    }
  ]}
]

# Handle VSM events
def handle_info({:vsm_event, event}, state) do
  # Forward interesting events to Telegram
  if event.severity == :critical do
    TelegramAgent.send_message(
      "telegram_primary",
      admin_chat_id,
      format_event(event)
    )
  end
  
  {:noreply, state}
end
```

## Running the Demo

```bash
# Basic demo (polling mode)
TELEGRAM_BOT_TOKEN=your_token mix run examples/telegram_integration_demo.exs

# With authorized chats
TELEGRAM_BOT_TOKEN=your_token \
TELEGRAM_AUTHORIZED_CHATS=123456789 \
TELEGRAM_ADMIN_CHATS=123456789 \
mix run examples/telegram_integration_demo.exs

# Webhook mode
TELEGRAM_BOT_TOKEN=your_token \
TELEGRAM_WEBHOOK_URL=https://your-domain.com/api/vsm/telegram/webhook/your_token \
mix run examples/telegram_integration_demo.exs
```

## Next Steps

1. Customize commands for your specific VSM use cases
2. Add inline keyboards for complex interactions
3. Implement custom alerts for your monitoring needs
4. Create scheduled reports sent via Telegram
5. Build interactive VSM control panels with callback queries