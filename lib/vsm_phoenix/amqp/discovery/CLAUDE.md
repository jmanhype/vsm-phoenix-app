# Discovery Module

Implements gossip-based agent discovery protocol.

## discovery.ex

### Purpose:
Allows agents to announce their presence, advertise capabilities, and discover peers without central registry.

### Key Features:
- **Gossip propagation** - Agents share knowledge about other agents
- **Capability advertisement** - Agents declare what they can do
- **Heartbeat monitoring** - 2-second heartbeats, 15-second timeout
- **Automatic cleanup** - Removes dead agents

### API:
```elixir
# Announce yourself
Discovery.announce(agent_id, [:telegram_bot, :alert_handler], metadata)

# Find agents
Discovery.query_agents([:database_admin])

# Say goodbye
Discovery.goodbye(agent_id)
```

### Message Types:
- `ANNOUNCE` - Broadcast presence
- `QUERY` - Request agents with capabilities  
- `RESPOND` - Reply to queries
- `HEARTBEAT` - Prove liveness
- `GOODBYE` - Graceful departure