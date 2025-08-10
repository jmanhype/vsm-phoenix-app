# CRDT Directory Context

This directory contains Conflict-free Replicated Data Types for distributed state synchronization.

## Files in this directory:
- `supervisor.ex` - Supervises the ContextStore
- `context_store.ex` - Main CRDT manager, handles all operations and AMQP sync
- `g_counter.ex` - Grow-only counter (increments only)
- `pn_counter.ex` - Positive-Negative counter (inc/dec)
- `or_set.ex` - Observed-Remove Set
- `lww_element_set.ex` - Last-Write-Wins Element Set

## Quick Start:
```elixir
# Increment a counter
ContextStore.increment_counter("visits", 1)

# Add to a set
ContextStore.add_to_set("active_users", user_id)

# Update config (last write wins)
ContextStore.update_lww_set("config", "theme", "dark")
```

## Key Concepts:
- CRDTs automatically resolve conflicts when merged
- State syncs via AMQP every 5 seconds
- Vector clocks track causality
- ETS tables store state for performance

## Integration Points:
- Cortical Attention Engine can trigger immediate sync for high-priority updates
- Consensus module coordinates critical CRDT operations
- Telemetry monitors CRDT performance and convergence
- Circuit breakers protect sync operations (needs wider adoption)