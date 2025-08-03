# Variety Engineering Integration Guide

## Overview

The Variety Engineering module is fully integrated into the VSM Phoenix application and implements Ashby's Law of Requisite Variety by managing information flow between system levels.

## Architecture

### Components

1. **Supervisor** (`variety_engineering/supervisor.ex`)
   - Manages all variety engineering components
   - Provides API for metrics and balance adjustments
   - Integrated into main application supervision tree

2. **Filters** (Upward Variety Attenuation)
   - `S1ToS2`: Event aggregation into coordination patterns
   - `S2ToS3`: Pattern to resource needs transformation
   - `S3ToS4`: Resource trends to strategic insights
   - `S4ToS5`: Strategic filtering for policy relevance

3. **Amplifiers** (Downward Variety Expansion)
   - `S5ToS4`: Policy to intelligence directives
   - `S4ToS3`: Adaptation to resource planning
   - `S3ToS2`: Resource allocation to coordination rules
   - `S2ToS1`: Coordination to operational tasks

4. **Metrics**
   - `VarietyCalculator`: Tracks message variety at each level
   - `BalanceMonitor`: Ensures requisite variety balance

### Integration Points

1. **PubSub Channels**
   - Filters subscribe to: `vsm:system1-5`, `vsm:operations`, `vsm:coordination`, `vsm:policy`
   - Amplifiers subscribe to: `vsm:system2-5`, `vsm:policy`, `vsm:coordination`
   - Metrics broadcast to: `vsm:variety_metrics`, `vsm:variety_balance`

2. **Message Flow**
   ```
   S1 Events → Filter → S2 Patterns → Filter → S3 Resources → Filter → S4 Strategy → Filter → S5 Policy
                                                                                                    ↓
   S1 Tasks ← Amplify ← S2 Rules ← Amplify ← S3 Plans ← Amplify ← S4 Directives ← Amplify ← S5 Policy
   ```

3. **Automatic Rebalancing**
   - Balance Monitor detects variety imbalances
   - Automatically adjusts filter thresholds and amplification factors
   - Maintains requisite variety (Ashby's Law)

## Configuration

Configuration is in `config/variety_engineering.exs`:

```elixir
config :vsm_phoenix, :variety_engineering,
  filters: %{
    s1_to_s2: %{aggregation_window: 5_000, pattern_threshold: 0.7},
    # ... other filter configs
  },
  amplifiers: %{
    s5_to_s4: %{initial_factor: 3, max_factor: 10},
    # ... other amplifier configs
  },
  balance_monitor: %{
    check_interval: 10_000,
    imbalance_threshold: 0.3,
    auto_rebalance: true
  }
```

## Usage Examples

### Checking Variety Metrics
```elixir
# Get all variety metrics
metrics = VsmPhoenix.VarietyEngineering.Supervisor.get_variety_metrics()

# Get balance status
balance = VsmPhoenix.VarietyEngineering.Supervisor.get_balance_status()
```

### Manual Adjustments
```elixir
# Adjust filter threshold
VsmPhoenix.VarietyEngineering.Supervisor.adjust_filter_threshold(:s1_to_s2, 0.8)

# Adjust amplification factor
VsmPhoenix.VarietyEngineering.Supervisor.adjust_amplification_factor(:s5_to_s4, 5)
```

### Running the Example
```elixir
# In iex -S mix
VsmPhoenix.VarietyEngineering.Example.demonstrate_variety_flow()
```

## Integration with Other VSM Components

1. **System 1 Agents**: Generate operational events that are filtered upward
2. **System 2 Coordinator**: Receives aggregated patterns, sends coordination rules
3. **System 3 Control**: Manages resource allocation based on filtered needs
4. **System 4 Intelligence**: Scans environment based on amplified directives
5. **System 5 Queen**: Sets policies that are amplified throughout the hierarchy

## Monitoring

The variety engineering system provides real-time monitoring through:
- Phoenix LiveDashboard integration (planned)
- Telemetry events for metrics collection
- Balance alerts via PubSub

## Testing

Test templates are provided in:
- `test/patterns/variety_filter_test_template.exs`
- `test/patterns/variety_aggregator_test_template.exs`