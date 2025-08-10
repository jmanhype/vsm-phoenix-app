# VSM Phoenix Test Directory

Core test suite for the VSM Phoenix application, organized by system and component.

## Test Organization

### System Tests
- **system1/** - Tests for operational agents and workers
- **system2/** - Tests for coordination and attention engine
- **system3/** - Tests for control and resource management
- **system4/** - Tests for intelligence and environmental scanning
- **system5/** - Tests for policy and governance

### Infrastructure Tests
- **amqp/** - Message queue protocol tests
- **crdt/** - Distributed state synchronization tests
- **infrastructure/** - Core service tests
- **resilience/** - Fault tolerance pattern tests
- **security/** - Cryptographic operation tests
- **variety_engineering/** - Variety management tests

## Testing Patterns

### Unit Tests
Focus on individual module behavior:
```elixir
test "calculates attention score correctly" do
  message = %{type: :alert, priority: :high}
  assert {:ok, score, _} = CorticalAttentionEngine.score_attention(message)
  assert score > 0.7
end
```

### Integration Tests
Test component interactions:
```elixir
test "routes messages through attention filtering" do
  # Tests multiple systems working together
end
```

### Contract Tests
Verify API contracts between systems:
```elixir
test "S1 messages conform to expected schema" do
  # Validates message structure
end
```

## Intelligence-Specific Tests

The test suite includes sophisticated tests for:
- Pattern recognition algorithms
- Adaptation engine effectiveness
- Environmental scanning accuracy
- Decision-making quality metrics