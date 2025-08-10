# Protocol Integration Layer

Unified interface that combines all protocol components with VSM infrastructure.

## protocol_integration.ex

### Purpose:
Provides a single API for distributed coordination, integrating discovery, consensus, and optimization with security and state management.

### Key Features:
- **Unified coordination** - Single interface for all protocols
- **Security integration** - Automatic HMAC signing
- **CRDT synchronization** - Distributed state consistency
- **Attention scoring** - All operations prioritized

### API:
```elixir
# Discover agents securely
ProtocolIntegration.discover_agents([:database_admin])

# Coordinate action with consensus
ProtocolIntegration.coordinate_action(
  agent_id, 
  :critical_operation,
  payload,
  quorum: :majority,
  urgency: :high
)

# Sync CRDT state
ProtocolIntegration.sync_crdt_state(agent_id, "global_config")

# Request secure lock
ProtocolIntegration.request_secure_lock(agent_id, resource)
```

### Integration Flow:
1. Calculate attention score (CorticalAttentionEngine)
2. Wrap with security (HMAC + nonce)
3. Discover capable agents
4. Initiate consensus if needed
5. Optimize network delivery
6. Update CRDT state