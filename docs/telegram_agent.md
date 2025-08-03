# VSM Telegram Agent

The Telegram Agent provides a conversational interface to the VSM system through Telegram messaging.

## Features

- **Webhook and Polling Support**: Can operate in either webhook mode (for production) or polling mode (for development)
- **Command Processing**: Handles various VSM commands through Telegram chat
- **Authorization System**: Supports authorized and admin chat IDs
- **Rate Limiting**: Built-in rate limiting to prevent abuse
- **Metrics Tracking**: Comprehensive metrics for monitoring usage
- **AMQP Integration**: Full integration with VSM message bus
- **Alert Notifications**: Receives and forwards critical system alerts

## Configuration

### Environment Variables

```bash
# Required
TELEGRAM_BOT_TOKEN=your-bot-token-from-botfather

# Optional
TELEGRAM_WEBHOOK_MODE=false  # Use 'true' for webhook mode
TELEGRAM_WEBHOOK_URL=https://yourdomain.com/api/vsm/telegram/webhook/AGENT_ID
TELEGRAM_AUTHORIZED_CHATS=123456789,987654321  # Comma-separated chat IDs
TELEGRAM_ADMIN_CHATS=123456789  # Admin chat IDs (subset of authorized)
TELEGRAM_RATE_LIMIT=30  # Messages per minute per chat
TELEGRAM_COMMAND_TIMEOUT=5000  # Command timeout in ms
```

## Usage

### Starting a Telegram Agent

```elixir
# Via S1 Supervisor
{:ok, agent} = VsmPhoenix.System1.Supervisor.spawn_agent(:telegram, 
  id: "telegram_bot_main",
  config: %{
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
    webhook_mode: false,
    authorized_chats: [123456789],
    admin_chats: [123456789]
  }
)
```

### Available Commands

- `/start` - Initialize bot and show welcome message
- `/help` - Display available commands
- `/status` - Get VSM system status
- `/vsm spawn <config>` - Spawn new VSM instance (admin only)
- `/vsm list` - List active VSM instances
- `/alert <level> <message>` - Broadcast alert (admin only)
- `/authorize <chat_id>` - Authorize new chat (admin only)

### Webhook Setup

For production use with webhooks:

1. Set `TELEGRAM_WEBHOOK_MODE=true`
2. Configure your webhook URL: `https://yourdomain.com/api/vsm/telegram/webhook/YOUR_AGENT_ID`
3. The agent will automatically register the webhook with Telegram

### Polling Mode

For development or when webhooks aren't available:

1. Set `TELEGRAM_WEBHOOK_MODE=false` (default)
2. The agent will automatically start polling for updates

## Integration Points

### AMQP Exchanges

- **Events**: `vsm.s1.{agent_id}.telegram.events`
- **Commands**: `vsm.s1.{agent_id}.telegram.commands`

### PubSub Topics

- `vsm:alerts:critical` - Receives critical system alerts
- `vsm:telegram:{agent_id}` - Agent-specific messages

### Event Types

- `bot_ready` - Bot successfully connected
- `message_received` - Incoming message received
- `message_sent` - Message sent to user
- `command_processed` - Command executed
- `unauthorized_access` - Unauthorized access attempt

## Security

- All chats must be explicitly authorized
- Admin commands require admin chat authorization
- Rate limiting prevents spam and abuse
- All events are logged through AMQP

## Metrics

The agent tracks:
- Total messages received/sent
- Commands processed (by type)
- Error count
- Message rate
- Last activity timestamp

Access metrics via:
```elixir
{:ok, metrics} = VsmPhoenix.System1.Agents.TelegramAgent.get_telegram_metrics("agent_id")
```