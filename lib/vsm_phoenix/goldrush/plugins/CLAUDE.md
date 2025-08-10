# Goldrush Plugins Directory

Event processing plugins that extend Goldrush telemetry with intelligent analysis capabilities.

## Files in this directory:

- `policy_learner.ex` - Learns patterns to suggest policy changes
- `variety_detector.ex` - Detects variety imbalances across VSM levels

## Purpose:

These plugins analyze event streams in real-time to provide intelligent insights for VSM adaptation and policy refinement.

## Plugin Architecture:

```elixir
# Each plugin implements the Goldrush.Plugin behaviour
defmodule MyPlugin do
  use Goldrush.Plugin
  
  def handle_event(event, state) do
    # Process event and update state
    {:ok, new_state}
  end
end
```

## Policy Learner Plugin

Monitors event patterns to identify:
- Recurring issues that need policy intervention
- Successful patterns that should become policy
- Policy violations and their frequency
- Effectiveness of current policies

## Variety Detector Plugin

Tracks variety metrics to detect:
- Variety overload at any VSM level
- Insufficient variety for environmental demands
- Imbalances between levels
- Need for filter/amplifier adjustments

## Integration Points:

- **Telemetry**: Receives all system events via Goldrush
- **System5**: Sends policy recommendations to Queen
- **Variety Engineering**: Triggers filter/amplifier adjustments
- **Resilience**: Protected by circuit breakers for stability

## Usage:

Plugins are automatically loaded by Goldrush.Manager on startup. They process events continuously and emit insights via PubSub.

## Resilience Considerations:

Both plugins should be protected with:
```elixir
# Wrap plugin processing in resilience patterns
Integration.with_bulkhead(:plugin_processing, fn _resource ->
  Integration.with_circuit_breaker(:plugin_analysis, fn ->
    process_events(events)
  end)
end)
```

This prevents plugin failures from affecting core telemetry.