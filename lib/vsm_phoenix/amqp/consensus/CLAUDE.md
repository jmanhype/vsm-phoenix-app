# Consensus Module

Implements distributed consensus and coordination protocols.

## consensus.ex

### Purpose:
Enables multiple agents to reach agreement on decisions through voting, with leader election and distributed locking.

### Key Features:
- **Multi-phase commit** - Propose → Vote → Commit/Abort
- **Leader election** - Modified Bully algorithm
- **Distributed locking** - Fair, priority-based locks
- **Attention-based voting** - Uses CorticalAttentionEngine scores

### API:
```elixir
# Propose action requiring consensus
Consensus.propose(agent_id, :restart_service, payload, 
  quorum: :majority,
  timeout: 10_000
)

# Request exclusive lock
Consensus.request_lock(agent_id, "database_migration",
  priority: 0.8,
  timeout: 5_000
)

# Release lock
Consensus.release_lock(agent_id, "database_migration")
```

### Voting Logic:
- Attention score > 0.6 → YES
- High risk (>0.7) → NO
- Low confidence (<0.4) → ABSTAIN

### Quorum Types:
- `:majority` - More than half
- `:all` - Unanimous
- `integer` - Fixed number