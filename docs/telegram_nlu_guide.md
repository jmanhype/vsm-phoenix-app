# Telegram Bot Natural Language Understanding Guide

## Overview

The VSM Telegram bot now supports natural language understanding (NLU), allowing users to interact with the system using conversational language instead of rigid commands.

## Features

### 1. Intent Recognition

The bot can understand various ways of expressing the same intent:

- **Status Requests**
  - "What's the system status?"
  - "How is the VSM doing?"
  - "Show me the health of S1"
  - "Is everything running smoothly?"

- **VSM Creation**
  - "Create a new VSM with 5 agents"
  - "Spawn a recursive VSM"
  - "I need a new federated system with 10 agents"
  - "Start a standard VSM"

- **Listing VSMs**
  - "Show me all VSMs"
  - "What systems are running?"
  - "List active instances"
  - "How many VSMs do we have?"

- **Alerts**
  - "Send a critical alert about database issues"
  - "Notify everyone about the deployment"
  - "Warning: high memory usage"

### 2. Entity Extraction

The NLU system extracts relevant information from natural language:

- **VSM Configuration**
  - Type: standard, recursive, federated
  - Agent count: numeric values
  - Configuration parameters

- **Alert Details**
  - Level: info, warning, critical
  - Message content
  - Target recipients

- **Time Ranges**
  - "last hour", "past day", "previous week"
  - Specific durations

### 3. Conversation Context

The bot maintains conversation context for more natural interactions:

```
User: "What's the status?"
Bot: "All systems are healthy. S1-S5 are operating normally."
User: "What about the last hour?"
Bot: "In the last hour, S1 processed 1,234 messages with 99.9% success rate..."
```

### 4. Multi-Step Flows

For complex operations, the bot guides users through conversational flows:

```
User: "Create a new VSM"
Bot: "What type of VSM would you like to create? (standard/recursive/federated)"
User: "recursive"
Bot: "How many agents should the VSM have? (1-20)"
User: "5"
Bot: "Which subsystems should be enabled? (s1,s2,s3,s4,s5 or 'all')"
User: "all"
Bot: "Great! I've created a recursive VSM with 5 agents and all subsystems enabled."
```

### 5. Confidence Handling

The bot handles uncertainty gracefully:

- **High Confidence (≥70%)**: Executes the intent directly
- **Medium Confidence (50-70%)**: Asks for confirmation
- **Low Confidence (<50%)**: Provides suggestions

Example:
```
User: "spawn vsm maybe?"
Bot: "I think you want to create a new VSM instance. Did you mean: `/vsm spawn`?"
User: "yes"
Bot: "Creating a new VSM instance..."
```

## Configuration

### Enabling/Disabling NLU

NLU is enabled by default. To disable:

```elixir
config :vsm_phoenix, :telegram,
  nlu_enabled: false,
  conversation_tracking: false
```

### Adjusting Confidence Threshold

```elixir
# In runtime
VsmPhoenix.Telegram.NLUService.set_confidence_threshold(0.8)
```

### LLM Provider Configuration

The NLU service can use different LLM providers:

```elixir
config :vsm_phoenix, :llm,
  provider: :openai,  # :openai, :anthropic, or :ollama
  model: "gpt-4",
  api_key: System.get_env("OPENAI_API_KEY")
```

## User Preferences

The bot learns from user interactions and adapts:

- **Frequently Used Commands**: Prioritizes suggestions based on usage
- **Response Format**: Adjusts detail level (brief/standard/detailed)
- **Notification Preferences**: Remembers alert preferences

## Fallback Behavior

When the bot doesn't understand:

1. **Command Suggestions**: Shows similar commands
2. **Natural Language Help**: Provides examples of valid requests
3. **Traditional Commands**: Always available as fallback

## Examples

### Natural Language Interactions

```
User: "How's everything going?"
Bot: "Based on my analysis, here's the current system status:
     ✅ System 1 (Operations): healthy
     ✅ System 2 (Coordination): healthy
     ..."

User: "Create a powerful VSM with lots of agents"
Bot: "I'll help you create a VSM. What type would you like? (standard/recursive/federated)"

User: "Explain how VSM recursion works"
Bot: "🏗️ Understanding VSM Recursion
     
     The Viable System Model supports recursion, meaning each system can contain
     other complete VSMs. This creates a fractal-like structure where..."

User: "Something is wrong with the database!"
Bot: "I'll send out a critical alert. The message will be:
     'Something is wrong with the database!'
     
     ✅ I've sent out a critical alert with your message."
```

### Mixed Mode (Commands + Natural Language)

```
User: /status
Bot: [Shows status]

User: "What about just S1?"
Bot: "Here's the detailed status for System 1 (Operations):
     ✅ Health: Healthy
     📊 Messages: 1,234 processed
     ⚡ Performance: 99.9% success rate"
```

## Error Handling

The bot provides helpful error messages:

```
User: "Create a VSM with 100 agents"
Bot: "I couldn't create the VSM instance. Error: Agent count must be between 1-20.
     Would you like me to try with different parameters?"
```

## Privacy and Security

- Conversations are isolated per chat
- Admin commands still require authorization
- No persistent storage of sensitive data
- LLM requests are anonymized

## Troubleshooting

### Bot doesn't understand natural language

1. Check if NLU is enabled in config
2. Verify LLM service is configured
3. Check logs for NLU service errors

### Confidence too low

1. Be more specific in requests
2. Use keywords related to the action
3. Fall back to traditional commands

### Conversation context lost

1. Conversation timeout may have expired (30 minutes)
2. Bot may have restarted
3. Start a new conversation with `/start`

## Future Enhancements

- Voice message support
- Multilingual understanding
- Custom intent training
- Advanced entity recognition
- Sentiment analysis for alerts