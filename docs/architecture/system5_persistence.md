# System5 Persistence Layer

The System5 persistence layer provides high-performance, ETS-based storage for policies, adaptations, and variety metrics in the VSM Phoenix application.

## Architecture

The persistence layer consists of three main components:

1. **PolicyStore** - Manages policy storage with versioning
2. **AdaptationStore** - Tracks adaptation patterns and learning
3. **VarietyMetricsStore** - Records variety measurements and trends

All components are supervised by `VsmPhoenix.System5.Persistence.Supervisor`.

## PolicyStore

Stores and manages System5 policies with full versioning support.

### Key Features
- Versioned policy storage
- Policy effectiveness tracking
- Search and filtering capabilities
- Soft delete with recovery options

### API Usage

```elixir
# Store a new policy
{:ok, policy} = PolicyStore.store_policy("budget_policy", %{
  type: :resource_allocation,
  rules: ["max_spend: 10000", "approval_required: true"],
  constraints: %{department: "engineering"}
}, %{source: "manual", priority: :high})

# Get current version
{:ok, policy} = PolicyStore.get_policy("budget_policy")

# Update policy (creates new version)
{:ok, updated} = PolicyStore.update_policy("budget_policy", %{
  rules: ["max_spend: 15000", "approval_required: true"]
}, %{updated_by: "admin"})

# Get policy history
{:ok, versions} = PolicyStore.get_policy_history("budget_policy")

# Search policies
{:ok, results} = PolicyStore.search_policies("budget")

# Record effectiveness
PolicyStore.record_policy_effectiveness("budget_policy", %{
  usage_count: 10,
  success_count: 9,
  failure_count: 1
})
```

## AdaptationStore

Tracks adaptation patterns and learning from system responses.

### Key Features
- Pattern extraction from recurring adaptations
- Similarity-based adaptation retrieval
- Cross-domain knowledge transfer
- Learning metrics tracking

### API Usage

```elixir
# Store an adaptation
{:ok, adaptation} = AdaptationStore.store_adaptation("adapt_001", %{
  anomaly_context: %{
    type: :performance_degradation,
    metric: :response_time,
    severity: 0.8
  },
  policy_changes: ["scale_up", "cache_optimization"],
  domain: :web_api
})

# Record outcome
:ok = AdaptationStore.record_outcome("adapt_001", %{
  success: true,
  performance_impact: 0.85,
  stability_impact: 0.90
})

# Find similar adaptations
{:ok, similar} = AdaptationStore.find_similar_adaptations(%{
  type: :performance_degradation,
  metric: :response_time
}, 10)

# Extract patterns
{:ok, patterns} = AdaptationStore.extract_patterns(min_occurrences: 3)

# Transfer knowledge between domains
{:ok, transferred} = AdaptationStore.transfer_knowledge(:web_api, :mobile_api)

# Get successful adaptations
{:ok, successful} = AdaptationStore.get_successful_adaptations(threshold: 0.7)
```

## VarietyMetricsStore

Records and analyzes variety metrics based on Ashby's Law of Requisite Variety.

### Key Features
- Time-series variety measurements
- Variety gap analysis
- Amplification/attenuation tracking
- Trend analysis and alerting

### API Usage

```elixir
# Record variety measurements
:ok = VarietyMetricsStore.record_variety_measurement(:system, %{
  variety: 150.0,
  capacity: 200.0,
  metadata: %{subsystems: 10, active_agents: 25}
})

:ok = VarietyMetricsStore.record_variety_measurement(:environment, %{
  variety: 180.0,
  metadata: %{external_events: 50, complexity_score: 0.8}
})

# Calculate variety gap
{:ok, gap_analysis} = VarietyMetricsStore.calculate_variety_gap(
  environmental_variety: 180.0,
  system_variety: 150.0
)
# Returns: %{variety_gap: 30.0, requisite_variety_met: false, ...}

# Record amplification
{:ok, factor} = VarietyMetricsStore.record_amplification(
  "policy_amplifier",
  input_variety: 100.0,
  output_variety: 250.0
)
# Returns: 2.5

# Analyze trends
{:ok, trends} = VarietyMetricsStore.analyze_variety_trends(:day)

# Get requisite variety status
{:ok, status} = VarietyMetricsStore.get_requisite_variety_status()

# Set threshold alerts
:ok = VarietyMetricsStore.set_variety_threshold(:environment, 200.0)
```

## Integration with System5

The persistence layer integrates seamlessly with other System5 components:

### In the Queen module:
```elixir
# Policies are automatically persisted when synthesized
def synthesize_adaptive_policy(anomaly_data, constraints) do
  case PolicySynthesizer.synthesize_policy_from_anomaly(anomaly_data) do
    {:ok, policy} ->
      # Automatically stored in PolicyStore
      PolicyStore.store_policy(policy.id, policy, %{source: "synthesis"})
      
      # Record as adaptation
      AdaptationStore.store_adaptation(...)
  end
end
```

### Variety metrics are recorded periodically:
```elixir
# Queen measures and records variety every 30 seconds
def handle_info(:measure_variety, state) do
  VarietyMetricsStore.record_variety_measurement(:system, %{
    variety: calculate_system_variety(state),
    capacity: state.adaptation_capacity
  })
end
```

## Performance Considerations

### ETS Configuration
- Tables use `:read_concurrency` for high-read scenarios
- PolicyStore uses `:set` table (one entry per key)
- AdaptationStore uses `:bag` table for version history
- VarietyMetricsStore uses `:bag` for time-series data

### Cleanup and Maintenance
- Old policy versions are automatically pruned (keeps last 10)
- Time-series data older than 7 days is cleaned up
- Pattern extraction runs every 30 minutes

### Memory Usage
- Monitor with: `VsmPhoenix.System5.Persistence.Supervisor.get_statistics()`
- Typical memory usage:
  - PolicyStore: ~1KB per policy + versions
  - AdaptationStore: ~500B per adaptation
  - VarietyMetricsStore: ~200B per measurement

## Monitoring

Check persistence layer health:
```elixir
VsmPhoenix.System5.Persistence.Supervisor.health_check()
# => %{
#   policy_store: :healthy,
#   adaptation_store: :healthy,
#   variety_metrics_store: :healthy
# }

VsmPhoenix.System5.Persistence.Supervisor.get_statistics()
# => %{
#   policy_count: 42,
#   adaptation_count: 156,
#   pattern_count: 12,
#   variety_gap: 25.0,
#   requisite_variety_met: false
# }
```

## Testing

Run persistence layer tests:
```bash
mix test test/vsm_phoenix/system5/persistence/
```

## Future Enhancements

1. **Distributed Storage**: Move to distributed ETS or Mnesia for multi-node deployments
2. **Machine Learning**: Integrate with ML models for better pattern extraction
3. **Visualization**: Add Phoenix LiveView dashboards for metrics
4. **Export/Import**: Add backup and restore capabilities
5. **Event Sourcing**: Track all changes as events for audit trails