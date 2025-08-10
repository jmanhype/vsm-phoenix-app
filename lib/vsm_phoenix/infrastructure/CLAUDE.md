# Infrastructure Directory Context

This directory contains core infrastructure components that support the entire VSM system.

## Key Files:
- `security.ex` - Base security infrastructure (extended by Security Layer)
- `dynamic_config.ex` - Runtime configuration management
- `operations_metrics.ex` - System-wide metrics collection
- `coordination_metrics.ex` - S2 coordination tracking
- `causality_tracker.ex` - Event chain tracking
- `similarity_threshold.ex` - Pattern matching thresholds

## Purpose:
Provides foundational services that all VSM components depend on, including security primitives, configuration, metrics, and event tracking.

## Integration with Phase 2:
- Security.ex is extended by the CryptoLayer for advanced features
- Metrics feed into the Telemetry system for analysis
- CausalityTracker works with CRDTs for distributed causality
- DynamicConfig enables runtime tuning of all components

## Quick Start:
```elixir
# Get configuration
config = DynamicConfig.get_component(:crdt)

# Track causality
CausalityTracker.track_event(event_id, parent_ids)

# Report metrics
OperationsMetrics.record_event(:crdt_sync, %{duration: 100})
```