# Telegram Bot Integration with Cortical Attention-Engine

## Overview

The Telegram bot, when running, integrates with the new Cortical Attention-Engine through the System 2 Coordinator. This document explains how Telegram messages flow through the attention scoring system.

## Message Flow

### 1. Telegram Message Reception
- User sends message to Telegram bot
- TelegramAgent receives via webhook or polling
- Message processed in `process_natural_language/3`

### 2. AMQP Message to LLM Worker
- TelegramAgent publishes to `vsm.llm.requests` exchange
- Message includes context and conversation history
- LLMWorkerAgent processes the request

### 3. Coordination Through System 2
When messages flow between agents (e.g., responses back to Telegram):
- Messages pass through System 2 Coordinator
- **Cortical Attention-Engine scores each message**
- Attention scoring considers:
  - **Urgency**: User messages get higher urgency scores
  - **Relevance**: Based on conversation context
  - **Novelty**: New topics score higher
  - **Intensity**: Based on message length and complexity
  - **Coherence**: Matches with conversation patterns

### 4. Attention-Based Routing

#### High Attention Messages (> 0.7)
- User questions marked as urgent/important
- System alerts sent to users
- Error messages
- **These bypass normal frequency limits**
- **Get priority routing to ensure quick responses**

#### Medium Attention (0.2 - 0.7)
- Normal conversational messages
- Status updates
- Standard routing with possible delays

#### Low Attention (< 0.2)
- Repetitive acknowledgments
- Debug messages
- **These may be filtered out**

## Integration Benefits

### 1. Improved User Experience
- Important user messages get faster responses
- System doesn't get overwhelmed by chat flood
- Critical alerts reach users immediately

### 2. Smart Message Prioritization
- Urgent user questions bypass queues
- System errors get immediate attention
- Routine messages don't clog the system

### 3. Conversation Context Awareness
- Attention engine tracks conversation patterns
- Related messages maintain higher attention
- Context switching detected and managed

### 4. Overload Protection
- Attention fatigue prevents chat spam overwhelming system
- Automatic filtering of low-importance messages
- Graceful degradation under heavy load

## Configuration Requirements

To enable the Telegram bot with Cortical Attention integration:

```bash
# Set Telegram bot token
export TELEGRAM_BOT_TOKEN="your_bot_token_here"

# Configure in config/dev.exs or runtime.exs
config :vsm_phoenix, :vsm,
  telegram: [
    bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
    webhook_mode: false,
    authorized_chats: [],  # Add authorized chat IDs
    admin_chats: []        # Add admin chat IDs
  ]
```

## Example Attention Scoring

### High Attention Telegram Message:
```elixir
%{
  type: :telegram_message,
  source: "telegram_agent",
  target: "llm_worker",
  priority: :high,
  content: "URGENT: System is down!",
  from_user: true
}
# Attention Score: 0.85
```

### Medium Attention:
```elixir
%{
  type: :telegram_message,
  source: "telegram_agent", 
  target: "llm_worker",
  content: "What is the system status?",
  from_user: true
}
# Attention Score: 0.65
```

### Low Attention:
```elixir
%{
  type: :telegram_ack,
  source: "telegram_agent",
  target: "system",
  content: "Message delivered",
  from_user: false
}
# Attention Score: 0.15 (would be filtered)
```

## Monitoring

To see how Telegram messages are being scored:

```elixir
# Get coordination status including attention metrics
VsmPhoenix.System2.Coordinator.get_coordination_status()

# Check attention state
VsmPhoenix.System2.CorticalAttentionEngine.get_attention_state()

# View attention metrics
VsmPhoenix.System2.CorticalAttentionEngine.get_attention_metrics()
```

## Current Status

- **Telegram Bot**: Not running (no TELEGRAM_BOT_TOKEN configured)
- **Cortical Attention-Engine**: Running and integrated with System 2
- **Integration**: Ready - will activate when Telegram bot is configured

When the Telegram bot is configured and running, all messages flowing through the system will benefit from intelligent attention-based routing and prioritization.