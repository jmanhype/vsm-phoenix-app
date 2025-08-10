# Variety Metrics Directory

This directory contains the core metrics calculation and monitoring components for variety engineering.

## Files in this directory:

### variety_calculator.ex
Core variety measurement engine that:
- Calculates input/output variety for each system level
- Computes variety ratios and imbalances
- Tracks variety flow between systems
- Provides entropy-based variety metrics
- Generates variety velocity measurements

### balance_monitor.ex
Real-time variety balance monitoring that:
- Detects variety imbalances across systems
- Triggers automatic adjustments
- Monitors critical thresholds
- Generates alerts for dangerous imbalances
- Tracks balance trends over time

## Key Metrics Calculated:

### Variety Metrics
- **Input Variety**: Incoming complexity/states
- **Output Variety**: Outgoing complexity/states
- **Variety Ratio**: Output/Input efficiency
- **Entropy**: Information-theoretic variety measure
- **Velocity**: Rate of variety change

### Balance Indicators
- **Imbalance Score**: Deviation from ideal ratio
- **Critical Level**: Boolean danger indicator
- **Trend Direction**: Increasing/decreasing/stable
- **System Load**: Percentage of capacity

## Storage & Persistence

These metrics integrate with:
- **Telemetry System**: All metrics are signals
- **CRDT Storage**: Distributed metric aggregation
- **ETS Tables**: High-performance local storage
- **System 5 Persistence**: Historical tracking

## Usage Example:
```elixir
# Calculate variety for a system
{:ok, metrics} = VarietyCalculator.calculate_metrics("system1", events)

# Monitor balance
BalanceMonitor.check_balance(:s1_s2_boundary)
```