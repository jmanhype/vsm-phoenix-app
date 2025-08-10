# System 1 Agents Directory

This directory contains all agent implementations for System 1 operational units.

## Files in this directory:

### Core Agents
- `worker_agent.ex` - Basic worker for general tasks
- `llm_worker_agent.ex` - Specialized worker for LLM API calls
- `sensor_agent.ex` - Data collection and monitoring
- `api_agent.ex` - External API interaction agent

### Protocol Integrations
- `telegram_agent.ex` - Telegram bot integration
- `telegram_protocol_integration.ex` - Advanced protocol features for Telegram

## Agent Types

### Worker Agent
Basic task execution with:
- Message handling
- State management
- Error recovery

### LLM Worker Agent
Specialized for AI operations:
- OpenAI API integration
- Token management
- Response caching

### Sensor Agent
Continuous monitoring:
- Data collection
- Threshold detection
- Alert generation

### API Agent
External integrations:
- HTTP requests
- Authentication
- Rate limiting

### Telegram Agent
Bot functionality:
- Command parsing
- User interaction
- Webhook/polling support

## Common Pattern

All agents follow GenServer pattern:
```elixir
def start_link(config) do
  GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
end

def handle_call({:process, data}, _from, state) do
  # Process and return
end
```