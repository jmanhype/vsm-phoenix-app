# VSM Telegram Bot - Complete Documentation

## Overview

The VSM Telegram Bot provides a sophisticated interface to the Viable Systems Model (VSM) Phoenix application with advanced cortical attention processing, conversation continuity, and intelligent message routing.

## Architecture

### Core Components

1. **TelegramAgent** (`lib/vsm_phoenix/system1/agents/telegram_agent.ex`)
   - Main bot implementation with 3,200+ lines of code
   - Handles all Telegram API interactions
   - Integrates with cortical attention system for intelligent message processing

2. **TelegramContextManager** (`lib/vsm_phoenix/system1/agents/telegram_context_manager.ex`)
   - Enhanced conversation context management
   - Pattern learning and user adaptation
   - Semantic continuity tracking

3. **CorticalAttentionEngine** (`lib/vsm_phoenix/system2/cortical_attention_engine.ex`)
   - 5-dimensional attention scoring (novelty, urgency, relevance, intensity, coherence)
   - Conversation continuity integration
   - Neural-inspired attention processing

## Commands

### Public Commands

#### `/start`
Initializes the bot and provides basic information.

**Response:**
```
🤖 VSM Telegram Bot Active

I'm your interface to the Viable System Model.
Use /help to see available commands.

Chat ID: [chat_id]
Agent: [agent_id]
```

#### `/help`
Shows available commands (varies by user permission level).

**Public Response:**
```
📋 Available Commands:

/start - Initialize bot
/help - Show this help
/status - System status
/vsm - VSM operations
```

**Admin Additional Commands:**
```
Admin Commands:
/alert <level> <message> - Send alert
/authorize <chat_id> - Authorize chat
```

#### `/status`
Fetches comprehensive system status across all VSM systems.

**Usage:** `/status`

**Process:**
1. Publishes AMQP command to gather system status
2. Includes metrics from Systems 1-5
3. Returns formatted status report

#### `/vsm`
VSM instance management operations.

**Subcommands:**

##### `/vsm spawn <config>`
Spawns a new VSM instance with specified configuration.
- **Example:** `/vsm spawn production-config`

##### `/vsm list`
Lists all active VSM instances with their status.

### Admin Commands

Admin commands require authorization and are restricted to users with admin privileges.

#### `/alert <level> <message>`
Broadcasts system-wide alerts.

**Levels:** `info`, `warning`, `critical`

**Usage Examples:**
- `/alert info System maintenance scheduled`
- `/alert warning High memory usage detected`
- `/alert critical Database connection lost`

#### `/authorize <chat_id>`
Authorizes a new chat ID to use the bot.

**Usage:** `/authorize 123456789`

**Effect:**
- Adds chat to authorized users list
- Sends confirmation to both admin and new user

### Critical Commands (Consensus Required)

The following commands require consensus through the protocol integration system:
- `restart` - System restart
- `shutdown` - System shutdown  
- `deploy` - Deployment operations
- `config` - Configuration changes
- `policy` - Policy modifications

These commands use distributed consensus before execution.

## Cortical Attention System

### Attention Scoring

Every message receives a multi-dimensional attention score based on:

1. **Novelty** (0.0-1.0): How new/unique the content is
2. **Urgency** (0.0-1.0): Time-sensitive indicators
3. **Relevance** (0.0-1.0): Context and conversation relevance  
4. **Intensity** (0.0-1.0): Signal strength and complexity
5. **Coherence** (0.0-1.0): Pattern matching with learned behaviors

### Message Prioritization

Messages are automatically prioritized into categories:

- **Critical** (0.9+): Emergency situations, system failures
- **High** (0.7-0.89): Important requests, admin commands
- **Normal** (0.4-0.69): Regular conversation, information requests
- **Low** (0.0-0.39): Social messages, simple acknowledgments

### Conversation Continuity Integration

The attention system now includes conversation continuity in relevance scoring:

- **Semantic Continuity**: Measures topic flow consistency (30% weight)
- **Conversation Coherence**: Evaluates dialog coherence (20% weight) 
- **Continuity Boost**: Messages with good continuity get +20% attention score

## Context Management

### Enhanced Context Features

1. **Pattern Learning**: Learns user communication patterns and preferences
2. **Intent Detection**: Identifies user goals and conversation purpose
3. **Emotional Tone Analysis**: Detects emotional state for appropriate responses
4. **Temporal Patterns**: Tracks communication timing patterns
5. **User Adaptation**: Adapts responses based on historical interactions

### Context Storage

- **ETS Tables**: High-performance in-memory conversation storage
- **Pattern Storage**: Learned user patterns for future adaptation
- **Message History**: Up to 50 messages with enhanced metadata
- **Context Compression**: Automatic history compression when needed

## Natural Language Processing

### LLM Integration

1. **AMQP-based LLM Workers**: Distributed LLM processing via message queues
2. **Context-Rich Requests**: Full conversation history and user patterns sent to LLM
3. **Response Processing**: Intelligent response routing and formatting
4. **Error Handling**: Comprehensive error recovery with user feedback

### Response Types

- **Direct Answers**: Information responses
- **System Status**: Real-time system information
- **Command Execution**: Action confirmations and results
- **Conversational**: Natural dialog responses

## Security & Authorization

### Access Control

1. **Authorized Chats**: Whitelist-based access control
2. **Admin Privileges**: Elevated permissions for system commands
3. **Command Filtering**: Critical commands require special authorization
4. **Consensus Protocol**: Multi-agent approval for critical operations

### Security Features

- **Message Validation**: Input sanitization and validation
- **Rate Limiting**: Protection against message spam
- **Secure Communication**: AMQP message encryption
- **Audit Logging**: Complete interaction logging

## Performance & Monitoring

### Metrics Collection

The bot tracks comprehensive metrics:

- **Message Processing**: Volume, response times, error rates
- **Command Usage**: Frequency analysis of different commands
- **User Engagement**: Interaction patterns and session lengths
- **System Health**: Memory usage, connection status, queue depths
- **Attention Metrics**: Scoring distributions, filtering effectiveness

### Resilience Features

1. **Circuit Breakers**: Automatic failure recovery
2. **Connection Pooling**: Efficient AMQP channel management  
3. **Graceful Degradation**: Fallback modes during system stress
4. **Health Monitoring**: Continuous system health assessment
5. **Load Management**: Adaptive load balancing based on system state

## Integration Points

### VSM System Integration

- **System 1**: Direct operational agent integration
- **System 2**: Cortical attention and coordination
- **System 3**: Resource management and control
- **System 4**: Environmental intelligence
- **System 5**: Policy and governance

### AMQP Message Routing

- **Command Routing**: Commands routed to appropriate system handlers
- **Event Publishing**: User interactions published as system events
- **Response Handling**: Asynchronous response processing
- **Queue Management**: Dedicated queues for different message types

### Protocol Integration

Advanced protocol features for multi-agent coordination:
- **Consensus Commands**: Distributed decision making
- **Agent Discovery**: Dynamic agent discovery and routing
- **State Synchronization**: CRDT-based state management
- **Security Protocols**: Encrypted inter-agent communication

## Configuration

### Environment Variables

- `TELEGRAM_BOT_TOKEN`: Telegram bot API token
- `AMQP_URL`: RabbitMQ connection string
- `AUTHORIZED_CHATS`: Initial authorized chat IDs
- `ADMIN_CHATS`: Administrative chat IDs

### State Management

The bot maintains several state components:

```elixir
%{
  bot_token: "bot_token",
  agent_id: "telegram_agent_1", 
  authorized_chats: #MapSet<[chat_ids]>,
  conversation_table: :ets_table_ref,
  amqp_connection: connection_pid,
  metrics: %{...},
  neural_intelligence: %{...},
  resilience: %{...}
}
```

## Development & Extension

### Adding New Commands

1. Add command case to `process_command/3`
2. Implement handler function following pattern `handle_[command]_command/3`
3. Update help text in `handle_help_command/2`
4. Add appropriate authorization checks if needed

### Extending Context Management

Enhance the `TelegramContextManager` for additional context features:
- Add new pattern detection functions
- Extend user profiling capabilities  
- Implement additional learning mechanisms

### Performance Optimization

- **Connection Pooling**: Use AMQP connection pools for high throughput
- **Caching**: Implement response caching for common queries
- **Batch Processing**: Group similar operations for efficiency
- **Memory Management**: Optimize ETS table usage and cleanup

## Troubleshooting

### Common Issues

1. **Bot Not Responding**: Check AMQP connection and LLM worker availability
2. **Authorization Errors**: Verify chat ID is in authorized list
3. **Command Failures**: Check system status and AMQP queue health
4. **Context Loss**: Verify ETS table initialization and TelegramContextManager

### Debug Commands

Use system status and logging to diagnose issues:
- `/status` - Overall system health
- Check AMQP queue depths
- Monitor attention scoring metrics
- Review conversation context storage

### Log Analysis

Key log patterns to monitor:
- `🎯 Processing command:` - Command execution
- `🧠 Processing natural language` - NLP requests
- `⚡ Attention Score:` - Attention system activity
- `📤 Published LLM request` - LLM worker communication

## Best Practices

### User Interaction

1. **Clear Commands**: Use descriptive command syntax
2. **Helpful Errors**: Provide actionable error messages  
3. **Status Updates**: Keep users informed of processing status
4. **Context Awareness**: Maintain conversation context for natural flow

### System Integration

1. **Graceful Failures**: Handle system outages gracefully
2. **Resource Management**: Monitor and manage resource usage
3. **Security First**: Validate all inputs and maintain access controls
4. **Performance Monitoring**: Continuously monitor system performance

This comprehensive documentation covers all aspects of the VSM Telegram Bot implementation, from basic usage to advanced system integration features.