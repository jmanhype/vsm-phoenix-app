# Causality Tracking Guide

## Overview

The VSM Phoenix application now includes an event causality tracking system that automatically tracks parent-child relationships between events, enabling reconstruction of event lineages and calculation of chain depths.

## Components

### 1. CausalityTracker GenServer

The core tracking system that:
- Maintains event relationships in ETS for high performance
- Tracks parent-child event chains
- Calculates chain depths
- Provides lineage reconstruction
- Integrates with telemetry system

### 2. CausalityAMQP Module

A wrapper around AMQP.Basic.publish that:
- Automatically adds `event_id` and `parent_event_id` to messages
- Tracks events when publishing
- Extracts causality info when receiving messages
- Maintains event context in process dictionary

## Migration Guide

### Basic Publishing

**Before:**
```elixir
AMQP.Basic.publish(channel, "vsm.events", "system.alert", Jason.encode!(message))
```

**After:**
```elixir
alias VsmPhoenix.Infrastructure.CausalityAMQP

# Message will automatically get event_id and parent_event_id
CausalityAMQP.publish(channel, "vsm.events", "system.alert", Jason.encode!(message))
```

### Publishing with Parent Event

**Before:**
```elixir
AMQP.Basic.publish(channel, exchange, routing_key, Jason.encode!(response))
```

**After:**
```elixir
# Option 1: Explicit parent
CausalityAMQP.publish(channel, exchange, routing_key, Jason.encode!(response), 
  parent_event_id: original_event_id)

# Option 2: Automatic from process context
# (if you previously called receive_message or set_current_event)
CausalityAMQP.publish(channel, exchange, routing_key, Jason.encode!(response))
```

### Receiving Messages

**Before:**
```elixir
def handle_info({:basic_deliver, payload, meta}, state) do
  message = Jason.decode!(payload)
  # Process message
  {:noreply, state}
end
```

**After:**
```elixir
alias VsmPhoenix.Infrastructure.CausalityAMQP

def handle_info({:basic_deliver, payload, meta}, state) do
  {message, causality_info} = CausalityAMQP.receive_message(payload, meta)
  
  # causality_info contains:
  # - event_id: The ID of this event
  # - parent_event_id: The ID of the parent event (if any)
  # - chain_depth: How deep this event is in the causal chain
  
  # Process message (event context is automatically set for child events)
  
  {:noreply, state}
end
```

### RPC Pattern

**Before:**
```elixir
# Client side
correlation_id = generate_id()
{:ok, %{queue: reply_queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
AMQP.Basic.publish(channel, "", target_queue, message, 
  reply_to: reply_queue, correlation_id: correlation_id)
# Wait for response...

# Server side
AMQP.Basic.publish(channel, "", meta.reply_to, response, 
  correlation_id: meta.correlation_id)
```

**After:**
```elixir
# Client side
response = CausalityAMQP.publish_and_wait(channel, "", target_queue, message)

# Server side (in message handler)
{request, causality_info} = CausalityAMQP.receive_message(payload, meta)
# Process request...
CausalityAMQP.publish(channel, "", meta.reply_to, response,
  correlation_id: meta.correlation_id,
  parent_event_id: causality_info.event_id)
```

## Usage Examples

### Starting a New Event Chain

```elixir
# Clear any existing context
CausalityAMQP.clear_current_event()

# Publish root event
CausalityAMQP.publish(channel, "vsm.commands", "system.initialize", %{
  type: "system_start",
  timestamp: DateTime.utc_now()
})
```

### Continuing an Event Chain

```elixir
# In a message handler
def handle_command(command, event_id) do
  # Set current event context
  CausalityAMQP.set_current_event(event_id)
  
  # All subsequent publishes will use this as parent
  CausalityAMQP.publish(channel, "vsm.events", "command.acknowledged", %{
    command_id: command.id,
    status: "processing"
  })
  
  # Process command...
  
  CausalityAMQP.publish(channel, "vsm.events", "command.completed", %{
    command_id: command.id,
    status: "success"
  })
end
```

### Querying Event Lineage

```elixir
# Get complete lineage of an event
{:ok, lineage} = CausalityTracker.get_event_lineage(event_id)

# lineage is a list of events from root to leaf:
# [
#   %{event_id: "EVT-123", depth: 0, timestamp: ..., child_count: 2},
#   %{event_id: "EVT-456", depth: 1, timestamp: ..., child_count: 1},
#   %{event_id: "EVT-789", depth: 2, timestamp: ..., child_count: 0}
# ]

# Get chain depth
{:ok, depth} = CausalityTracker.get_chain_depth(event_id)

# Get all children of an event
{:ok, children} = CausalityTracker.get_child_events(parent_id)
# Returns:
# %{
#   immediate: ["EVT-456", "EVT-457"],
#   all_descendants: ["EVT-456", "EVT-457", "EVT-789"],
#   total_count: 3
# }
```

## Message Format

Messages published through CausalityAMQP will have these additional fields:

```json
{
  "event_id": "EVT-1234567890-123456",
  "parent_event_id": "EVT-1234567889-654321",
  "causality_timestamp": "2024-01-08T12:34:56.789Z",
  // ... your original message fields
}
```

## Best Practices

1. **Use CausalityAMQP everywhere**: Replace all direct AMQP.Basic.publish calls to ensure complete tracking.

2. **Preserve event context**: When handling messages that will trigger other events, use the causality info to maintain the chain.

3. **Clear context when needed**: Use `clear_current_event()` when starting truly independent event chains.

4. **Monitor chain depths**: Very deep chains might indicate recursive issues or design problems.

5. **Use telemetry**: The system emits telemetry events for all message sends/receives:
   - `[:vsm, :amqp, :message, :sent]`
   - `[:vsm, :amqp, :message, :received]`

## Troubleshooting

### Missing Parent Events

Parent events might be missing if:
- They were published before causality tracking was enabled
- They expired from the ETS cache (1 hour TTL by default)
- The parent was published by a system not using CausalityAMQP

### Broken Chains

If event chains appear broken:
1. Check that all publishers use CausalityAMQP
2. Verify parent_event_id is being passed correctly
3. Look for clear_current_event() calls that might be breaking chains

### Performance

The causality tracker uses ETS for high performance:
- Lookups are O(1)
- Automatic cleanup prevents unbounded growth
- Chain depth calculations are limited to prevent infinite loops