# System 5 Persistence Directory

This directory contains the Phase 3 persistence layer for storing policies, adaptations, and variety metrics.

## Files in this directory:
- `supervisor.ex` - Supervises all persistence stores
- `policy_store.ex` - ETS-based policy storage
- `adaptation_store.ex` - Stores adaptation history
- `variety_metrics_store.ex` - Tracks variety metrics over time

## Stores:

### Policy Store
Persists policies:
- Policy versions
- Activation history
- Performance metrics
- Rollback capability

### Adaptation Store
Tracks adaptations:
- Proposed adaptations
- Implementation status
- Success metrics
- Learning data

### Variety Metrics Store
Historical metrics:
- Variety measurements
- Balance indicators
- Trend analysis
- Anomaly records

## Implementation:
All stores use ETS tables for:
- High-performance access
- Concurrent operations
- In-memory persistence
- Optional disk backup

## Integration:
- Used by System 5 for decision history
- Feeds telemetry system with historical data
- Supports CRDT synchronization for distributed state