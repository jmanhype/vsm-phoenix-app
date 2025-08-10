# Telemetry Directory

This directory contains the Analog-Signal-Inspired Telemetry Architecture that treats all metrics as continuous signals.

## Files in this Directory

### Core System
- `analog_architect.ex` - Main telemetry engine that manages signal registration, sampling, and analysis
- `supervisor.ex` - Supervises all telemetry components with one-for-one strategy

### Signal Processing
- `signal_processor.ex` - DSP operations: FFT, filters, wavelets, convolution
- `pattern_detector.ex` - Pattern recognition: periodicity, trends, anomalies, chaos
- `signal_aggregator.ex` - Multi-signal fusion and hierarchical aggregation

### Control & Visualization
- `adaptive_controller.ex` - Dynamic thresholds and auto-scaling
- `signal_visualizer.ex` - Real-time visualization with 9 display modes

### Integration
- `telegram_integration.ex` - Bridges Telegram bot with analog telemetry

## Quick Start

```elixir
# Register a signal
AnalogArchitect.register_signal("my_metric", %{
  sampling_rate: :standard,  # 10Hz
  buffer_size: 1000,
  analysis_modes: [:basic, :anomaly]
})

# Sample data
AnalogArchitect.sample_signal("my_metric", 42.5, %{source: "api"})

# Analyze
{:ok, analysis} = AnalogArchitect.analyze_waveform("my_metric", :basic)
```

## Key Concepts

1. **Signals as First-Class Citizens**: Every metric is a continuous signal
2. **Circular Buffers**: Fixed-size ETS-based buffers prevent memory growth
3. **Multi-Modal Analysis**: Each signal can have multiple analysis modes
4. **Real-Time Processing**: Automatic processing every 100ms

## Integration Points

- Uses ETS tables for high-performance storage
- Emits `:telemetry` events for all analyses
- Integrates with Phoenix.PubSub for real-time updates
- Protected by circuit breakers (see resilience integration)