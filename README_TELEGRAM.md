# VSM Phoenix Telegram Integration

This document describes how to set up and use the Telegram bot integration with VSM Phoenix.

## Quick Start

1. **Get a Bot Token from BotFather**
   - Open Telegram and search for @BotFather
   - Send `/newbot` and follow the instructions
   - Copy the bot token

2. **Set Environment Variables**
   ```bash
   export TELEGRAM_BOT_TOKEN="your-bot-token-here"
   export TELEGRAM_AUTHORIZED_CHATS=""  # Will be populated after first /start
   export TELEGRAM_ADMIN_CHATS=""       # Subset of authorized chats with admin privileges
   ```

3. **Start the Bot**
   ```bash
   mix run scripts/start_telegram_bot.exs
   ```

4. **Authorize Your Chat**
   - Send `/start` to your bot on Telegram
   - Note the chat ID from the response
   - Restart with authorized chats:
   ```bash
   export TELEGRAM_AUTHORIZED_CHATS="your-chat-id"
   export TELEGRAM_ADMIN_CHATS="your-chat-id"  # If you want admin access
   mix run scripts/start_telegram_bot.exs
   ```

## Available Commands

- `/start` - Initialize bot and get your chat ID
- `/help` - Show available commands
- `/status` - Get VSM system status
- `/vsm spawn <config>` - Spawn new VSM instance (admin only)
- `/vsm list` - List active VSM instances
- `/alert <level> <message>` - Broadcast system alert (admin only)
- `/authorize <chat_id>` - Authorize another chat (admin only)

## Production Deployment

### Using Webhooks

For production, webhooks are more efficient than polling:

1. **Set Webhook URL**
   ```bash
   export TELEGRAM_WEBHOOK_MODE=true
   export TELEGRAM_WEBHOOK_URL="https://yourdomain.com/api/vsm/telegram/webhook/telegram_bot_main"
   ```

2. **Ensure HTTPS**
   - Telegram requires a valid SSL certificate
   - The webhook URL must be publicly accessible

3. **Start with Application**
   Add to your application supervision tree in `lib/vsm_phoenix/application.ex`

### Using Polling (Development)

Polling is the default mode and works well for development:
- No external URL required
- Works behind firewalls
- Slightly higher latency

## Integration with VSM

The Telegram bot integrates with all VSM systems:

- **S1 Operations**: Direct command execution
- **S2 Coordination**: Message routing and synchronization
- **S3 Control**: Resource monitoring and optimization
- **S4 Intelligence**: Environmental scanning and adaptation
- **S5 Queen**: Policy decisions and viability monitoring

## Monitoring

Check bot metrics:
```elixir
{:ok, metrics} = VsmPhoenix.System1.Agents.TelegramAgent.get_telegram_metrics("telegram_bot_main")
```

## Troubleshooting

1. **Bot not responding**
   - Check bot token is correct
   - Ensure chat is authorized
   - Check application logs

2. **Webhook errors**
   - Verify SSL certificate
   - Check webhook URL is accessible
   - Use polling mode for testing

3. **Authorization issues**
   - Ensure chat ID is in TELEGRAM_AUTHORIZED_CHATS
   - Admin commands require TELEGRAM_ADMIN_CHATS

## Security

- All chats must be explicitly authorized
- Admin functions require admin chat authorization
- Rate limiting prevents abuse (30 msg/min default)
- All interactions are logged via AMQP