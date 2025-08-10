# System 5 Persistence Tests Directory

Test suites for System 5's persistence layer, ensuring reliable storage of policies, adaptations, and variety metrics.

## Files in this directory:

### policy_store_test.exs
Tests for policy persistence:
- Policy creation and versioning
- Policy activation and deactivation
- Historical policy retrieval
- Rollback functionality
- Performance metrics tracking
- Concurrent policy updates

### adaptation_store_test.exs
Tests for adaptation history:
- Adaptation proposal storage
- Implementation status tracking
- Success/failure recording
- Learning data persistence
- Adaptation pattern analysis
- Time-series retrieval

### variety_metrics_store_test.exs
Tests for variety measurements:
- Metric recording and retrieval
- Time-series data handling
- Aggregation calculations
- Anomaly detection storage
- Trend analysis persistence
- Historical data compression

## Test Patterns:

### ETS Persistence
```elixir
test "persists to ETS tables" do
  # Store policy
  {:ok, id} = PolicyStore.store(policy)
  
  # Verify in ETS
  assert [{^id, stored_policy}] = :ets.lookup(:s5_policies, id)
  assert stored_policy.content == policy.content
end
```

### Historical Queries
```elixir
test "retrieves historical data" do
  # Store multiple versions
  times = for i <- 1..10 do
    {:ok, _} = VarietyMetricsStore.record(metrics(i))
    Process.sleep(10)
  end
  
  # Query time range
  history = VarietyMetricsStore.get_range(start_time, end_time)
  assert length(history) == 10
end
```

### Concurrent Operations
```elixir
test "handles concurrent writes" do
  # Spawn multiple writers
  tasks = for i <- 1..100 do
    Task.async(fn ->
      AdaptationStore.record(adaptation(i))
    end)
  end
  
  # All should succeed
  results = Task.await_many(tasks)
  assert Enum.all?(results, &match?({:ok, _}, &1))
end
```

## Key Test Scenarios:

### Data Integrity
- Verify no data corruption
- Test atomic operations
- Validate referential integrity
- Ensure idempotency

### Performance
- Measure write throughput
- Test query performance
- Benchmark under load
- Memory usage limits

### Recovery
- Process crash recovery
- Data restoration
- Backup/restore cycles
- Migration testing

### Integration
- Cross-store consistency
- Event emission verification
- Telemetry integration
- CRDT synchronization

## Test Helpers:
- `with_clean_store/1` - Ensures clean ETS state
- `generate_metrics/1` - Creates test metrics
- `wait_for_persistence/0` - Ensures writes complete
- `measure_performance/1` - Benchmarking helper