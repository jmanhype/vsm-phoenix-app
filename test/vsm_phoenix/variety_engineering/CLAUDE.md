# Variety Engineering Test Directory

Tests for Ashby's Law implementation across VSM hierarchy.

## Subdirectories:

### aggregators/
Tests for variety aggregation components:
- `executive_aggregator_test.exs` - Executive level aggregation
- `pattern_aggregator_test.exs` - Pattern detection aggregation
- `strategic_aggregator_test.exs` - Strategic level aggregation
- `temporal_aggregator_test.exs` - Time-based aggregation

### filters/
Tests for variety filtering components:
- `anomaly_filter_test.exs` - Anomaly detection filtering
- `priority_filter_test.exs` - Priority-based filtering
- `semantic_filter_test.exs` - Semantic analysis filtering
- `threshold_filter_test.exs` - Threshold-based filtering

### integration/
Integration tests for variety engineering:
- `system_resilience_test.exs` - System-wide resilience tests
- `telegram_variety_integration_test.exs` - Telegram bot variety handling

## Purpose:
Validates that variety is properly managed between VSM levels:
- Sufficient variety for environmental complexity
- Proper filtering to prevent overload
- Correct aggregation for higher abstractions
- Maintains system balance

## Test Patterns:

### Aggregator Tests
- Input variety measurement
- Aggregation effectiveness
- Pattern preservation
- Information loss metrics

### Filter Tests
- Variety reduction ratios
- Important signal preservation
- Noise elimination
- Adaptive threshold behavior

### Integration Tests
- End-to-end variety flow
- Multi-level interactions
- System stability under load
- Telegram bot variety handling

## Running Tests:
```bash
# All variety engineering tests
mix test test/vsm_phoenix/variety_engineering

# Only filter tests
mix test test/vsm_phoenix/variety_engineering/filters

# Integration tests with tags
mix test test/vsm_phoenix/variety_engineering/integration --only integration
```