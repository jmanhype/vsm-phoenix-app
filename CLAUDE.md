# VSM Phoenix Application Guide

## Overview

VSM Phoenix is a comprehensive implementation of Stafford Beer's Viable System Model (VSM) with advanced cybernetic features including recursive spawning, MCP integration, AMQP messaging, real-time monitoring, and intelligent coordination.

## Key Features

### Analog-Signal-Inspired Telemetry Architecture (Phase 2)

The system now includes a comprehensive telemetry system that treats metrics as continuous analog signals:

- **Signal Processing**: FFT, digital filters, convolution, wavelets
- **Pattern Detection**: Periodicity, trends, anomalies, chaos analysis
- **Real-time Visualization**: 9 visualization types with adaptive rendering
- **Adaptive Control**: Self-adjusting thresholds and auto-scaling
- **Telegram Integration**: 5 monitored signals for bot activity

See `/lib/vsm_phoenix/telemetry/CLAUDE.md` for architecture details.

### Cortical Attention-Engine (Phase 2 Enhancement)

System 2 now includes a neuroscience-inspired attention mechanism that intelligently prioritizes and routes messages:

- **Multi-dimensional scoring**: Evaluates novelty, urgency, relevance, intensity, and coherence
- **Attention states**: Focused, distributed, shifting, fatigued, recovering
- **Smart routing**: High attention messages bypass limits, low attention messages filtered
- **Fatigue modeling**: Prevents system overload with recovery cycles

See `/lib/vsm_phoenix/system2/CLAUDE.md` for details.

## System Architecture

### System Hierarchy

1. **System 5 (Queen)**: Policy governance and identity
   - Algedonic signal processing
   - LLM-based policy synthesis
   - Strategic direction

2. **System 4 (Intelligence)**: Environmental scanning and adaptation
   - Anomaly detection
   - Variety amplification via LLM
   - Adaptation proposals

3. **System 3 (Control)**: Resource management
   - Dynamic allocation
   - Optimization
   - Audit capabilities (3*)

4. **System 2 (Coordinator)**: Anti-oscillation and coordination
   - **NEW: Cortical Attention-Engine**
   - Message routing with attention scoring
   - Oscillation dampening
   - Synchronization

5. **System 1 (Operations)**: Autonomous operational units
   - Agent registry
   - Multiple agent types
   - AMQP integration

## Common Tasks

### Check System Status

```elixir
# Overall coordination status (includes attention metrics)
VsmPhoenix.System2.Coordinator.get_coordination_status()

# Attention engine state
VsmPhoenix.System2.CorticalAttentionEngine.get_attention_state()

# Analog telemetry signals
VsmPhoenix.Telemetry.AnalogArchitect.get_signal_data("telegram_message_rate", %{})
```

### Monitor Telemetry Signals

```elixir
# Register a custom signal
VsmPhoenix.Telemetry.AnalogArchitect.register_signal("my_metric", %{
  sampling_rate: :standard,
  buffer_size: 1000,
  analysis_modes: [:basic, :anomaly]
})

# Sample data
VsmPhoenix.Telemetry.AnalogArchitect.sample_signal("my_metric", 42.5, %{})

# Analyze waveform
VsmPhoenix.Telemetry.AnalogArchitect.analyze_waveform("my_metric", :frequency_spectrum)
```

### Test Analog Telemetry

```bash
# Run simple test
mix run test_telemetry_simple.exs

# Run comprehensive test
mix run test_analog_telemetry_direct.exs
```

### Monitor Attention Metrics

Attention metrics are reported every 30 seconds in logs. Look for:
- High attention message rate
- Filter efficiency
- Attention effectiveness percentage

### Debug Message Routing

Messages now include attention scores:

```elixir
# High attention: > 0.7 (priority routing)
# Medium attention: 0.2-0.7 (normal routing)
# Low attention: < 0.2 (filtered)
```

## Key Directories

- `/lib/vsm_phoenix/system1/` - Operational agents
- `/lib/vsm_phoenix/system2/` - Coordination & attention
- `/lib/vsm_phoenix/system3/` - Resource control
- `/lib/vsm_phoenix/system4/` - Intelligence
- `/lib/vsm_phoenix/system5/` - Policy & governance
- `/lib/vsm_phoenix/telemetry/` - Analog signal processing & visualization

## Testing

```bash
# Run all tests
mix test

# Compile and check
mix compile

# Start server
mix phx.server
```

## Configuration

### Enable Telegram Bot

```bash
export TELEGRAM_BOT_TOKEN="your_token"
```

Telegram messages automatically get high attention scores for responsive user interaction.

### Attention Engine Config

Currently hardcoded in `cortical_attention_engine.ex`:
- Fatigue threshold: 0.7
- Recovery rate: 0.01/second
- Filter threshold: 0.2

## Important Commands

When working on coordination or attention:

```bash
# Check attention effectiveness
mix run -e 'IO.inspect(VsmPhoenix.System2.Coordinator.get_coordination_status())'

# Monitor live metrics
tail -f logs/dev.log | grep "Cortical Attention"
```

## Architecture Principles

1. **Attention-Aware Routing**: All messages scored for importance
2. **Neuroscience-Inspired**: Based on cortical attention research
3. **Fail-Fast Design**: No fallbacks, clear error messages
4. **Observable**: Comprehensive metrics and logging
5. **Distributed**: AMQP-based communication between systems

## Current State

- ✅ Analog-Signal Telemetry Architecture operational
- ✅ 7 telemetry components integrated (AnalogArchitect, SignalProcessor, etc.)
- ✅ Telegram bot telemetry integration ready (5 signals)
- ✅ Real-time signal visualization with 9 display modes
- ✅ Cortical Attention-Engine integrated and running
- ✅ Attention-based message filtering active
- ✅ Priority routing for high-attention messages
- ❌ Telegram bot not configured (needs token)
- ✅ All VSM systems operational

## Files to Know

- `analog_architect.ex` - Core telemetry signal management
- `signal_processor.ex` - DSP operations and transformations
- `pattern_detector.ex` - Pattern recognition and anomaly detection
- `signal_visualizer.ex` - Real-time visualization engine
- `telegram_integration.ex` - Telegram-telemetry bridge
- `coordinator.ex` - Main coordination logic with attention integration
- `cortical_attention_engine.ex` - Attention scoring and state management
- `telegram_agent.ex` - Telegram bot integration (ready for attention routing)

## Debugging Tips

### If messages aren't flowing:
1. Check attention state isn't fatigued
2. Verify message includes priority/urgency
3. Look at attention score breakdown
4. Check filter metrics

### If telemetry crashes:
1. Check for empty signal buffers (division by zero)
2. Verify ETS tables are initialized
3. Look for pattern matching errors in analysis modes
4. Check visualization cache table exists

### Common fixes:
```bash
# Recompile with warnings
mix compile --warnings-as-errors

# Test telemetry directly
mix run test_telemetry_simple.exs
```

See individual CLAUDE.md files in each system directory for detailed component guides.