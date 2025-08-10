# CRDT Test Directory

Tests for Conflict-free Replicated Data Type implementations and persistence mechanisms.

## Files in this directory:

### context_store_test.exs
Comprehensive test suite for the CRDT-based ContextStore:
- Basic CRDT operations (add/remove/merge)
- Multi-node synchronization
- Conflict resolution scenarios
- Persistence and recovery
- Performance under concurrent updates
- Network partition handling

## Test Patterns:

### Persistence Testing
```elixir
test "persists state across restarts" do
  # Add data to CRDT
  ContextStore.add_to_set("test", "value1")
  
  # Simulate restart
  restart_context_store()
  
  # Verify persistence
  assert "value1" in ContextStore.get_set("test")
end
```

### Conflict Resolution
```elixir
test "resolves concurrent updates" do
  # Simulate updates from multiple nodes
  spawn_link(fn -> ContextStore.add_to_set("key", "A") end)
  spawn_link(fn -> ContextStore.add_to_set("key", "B") end)
  
  # Both values should be present
  Process.sleep(100)
  values = ContextStore.get_set("key")
  assert "A" in values and "B" in values
end
```

### Sync Testing
```elixir
test "syncs between nodes" do
  # Start two nodes
  node1 = start_crdt_node(:node1)
  node2 = start_crdt_node(:node2)
  
  # Add on node1
  rpc(node1, ContextStore, :add_to_set, ["sync", "data"])
  
  # Should appear on node2
  eventually(fn ->
    assert "data" in rpc(node2, ContextStore, :get_set, ["sync"])
  end)
end
```

## Key Test Scenarios:

### Data Integrity
- Verify no data loss during merges
- Ensure idempotent operations
- Test tombstone cleanup
- Validate causal consistency

### Performance
- Measure sync latency
- Test large dataset handling
- Benchmark merge operations
- Memory usage under load

### Fault Tolerance
- Network partition recovery
- Node failure handling
- Split-brain resolution
- Byzantine fault detection

## Test Helpers:
- `restart_context_store/0` - Simulates process restart
- `start_crdt_node/1` - Starts isolated CRDT node
- `eventually/1` - Waits for eventual consistency
- `rpc/4` - Remote procedure call to node