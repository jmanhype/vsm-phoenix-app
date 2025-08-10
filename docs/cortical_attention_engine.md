# Cortical Attention-Engine for System 2

## Overview

The Cortical Attention-Engine is a neuroscience-inspired attention mechanism integrated into System 2 (Coordinator) of the VSM Phoenix application. It implements selective attention, priority weighting, and cognitive load management based on cortical attention principles.

## Architecture

### Core Components

1. **CorticalAttentionEngine** (`lib/vsm_phoenix/system2/cortical_attention_engine.ex`)
   - Standalone GenServer managing attention scoring and state
   - Multi-dimensional attention scoring algorithm
   - Temporal attention windows at multiple scales
   - Attention fatigue and recovery mechanisms
   - Pattern learning and recognition

2. **Integration with System2 Coordinator**
   - Attention scoring applied to all messages
   - Attention-aware routing decisions
   - Attention-modulated oscillation dampening
   - Comprehensive attention metrics tracking

## Key Features

### 1. Multi-Dimensional Attention Scoring

Messages are scored across five dimensions:
- **Novelty** (30%): How new/unexpected the message is
- **Urgency** (25%): Time criticality and priority
- **Relevance** (20%): Context relevance to current focus
- **Intensity** (15%): Signal strength and authority
- **Coherence** (10%): Pattern coherence with learned patterns

### 2. Attention States

The system operates in five distinct attention states:
- `:focused` - Enhanced attention on specific context
- `:distributed` - Normal attention across all inputs
- `:shifting` - Transitioning between focus areas
- `:fatigued` - Reduced attention due to overload
- `:recovering` - Gradually improving from fatigue

### 3. Temporal Attention Windows

Four temporal scales for pattern analysis:
- **Immediate** (100ms): Reflexive attention
- **Short-term** (1s): Working memory window
- **Sustained** (10s): Sustained attention
- **Long-term** (60s): Long-term tracking

### 4. Attention-Based Message Routing

- **Low attention messages** (< 0.2): Filtered/blocked
- **Medium attention** (0.2-0.7): Normal routing with delays
- **High attention** (> 0.7): Priority routing, can bypass limits
- **Critical attention** (> 0.9): Immediate synchronization

### 5. Attention-Modulated Oscillation Control

The oscillation dampening system now considers attention:
- High attention oscillations receive less dampening (preserved)
- Severe oscillations trigger attention shifts
- Attention fatigue affects dampening effectiveness

## Implementation Details

### Message Flow

1. Message arrives at System 2 Coordinator
2. CorticalAttentionEngine scores the message
3. Attention score and components added to message
4. Routing decisions based on attention level
5. Metrics updated for monitoring

### Attention Scoring Algorithm

```elixir
score = Σ(component_value × component_weight) × state_multiplier × fatigue_factor
```

Where:
- Component values: 0.0 to 1.0 for each dimension
- State multiplier: 0.6 to 1.2 based on attention state
- Fatigue factor: 0.5 to 1.0 based on fatigue level

### Metrics Tracked

- Total messages scored
- High attention message count
- Low attention filtered count
- Attention-modulated delays
- Attention bypass count
- Attention effectiveness score

## Configuration

The attention engine starts automatically with System 2 and requires no additional configuration. However, the following parameters can be tuned:

- Salience weights for each attention dimension
- Attention state thresholds
- Fatigue and recovery rates
- Temporal window sizes

## Monitoring

Attention metrics are reported every 30 seconds and include:
- Current attention state
- Fatigue level
- Message processing statistics
- Attention effectiveness percentage

Access attention metrics via the coordination status endpoint:
```elixir
VsmPhoenix.System2.Coordinator.get_coordination_status()
```

## Benefits

1. **Improved Message Prioritization**: Critical messages get immediate attention
2. **Resource Efficiency**: Low-importance messages filtered automatically
3. **Adaptive Behavior**: System learns patterns and adjusts attention
4. **Overload Protection**: Fatigue mechanism prevents attention exhaustion
5. **Enhanced Coordination**: Better oscillation control and synchronization

## Future Enhancements

- Integration with System 4 for environmental attention
- Cross-system attention coordination
- Advanced pattern learning with neural networks
- Attention-based resource allocation in System 3
- Visualization of attention patterns in dashboard