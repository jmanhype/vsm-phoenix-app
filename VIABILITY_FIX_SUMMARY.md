# VSM Phoenix Viability Update Fix Summary

## Problem
The dashboard was showing static viability values that didn't change when algedonic signals (pleasure/pain) were sent via the API.

## Root Causes Identified

1. **Algedonic signals weren't updating internal viability metrics** - The signal handlers in Queen were not modifying the viability_metrics state
2. **evaluate_viability was overwriting internal metrics** - It was calculating fresh values from other systems instead of using the stored metrics
3. **Dashboard wasn't handling viability broadcasts** - The LiveView didn't have a handler for :viability_update messages

## Fixes Applied

### 1. Added viability metric updates in Queen signal handlers
```elixir
# In handle_cast for pleasure/pain signals
updated_viability = update_viability_from_signal(state.viability_metrics, :pleasure, intensity)
new_state = %{state | viability_metrics: updated_viability}
Phoenix.PubSub.broadcast(VsmPhoenix.PubSub, "vsm:health", {:viability_update, updated_viability})
```

### 2. Fixed evaluate_viability to merge internal and external metrics
```elixir
# In handle_call(:evaluate_viability)
external_viability = calculate_viability(intelligence_health, control_metrics, coordination_status)
viability = Map.merge(external_viability, state.viability_metrics)
{:reply, viability, state}  # Don't overwrite internal metrics
```

### 3. Added viability update handler in Dashboard LiveView
```elixir
def handle_info({:viability_update, viability_metrics}, socket) do
  Logger.info("Dashboard: Received viability update - system_health: #{viability_metrics.system_health}")
  socket = assign(socket, :viability_score, viability_metrics.system_health)
  {:noreply, socket}
end
```

## Testing

Use the API endpoints to send signals and observe dashboard changes:

```bash
# Send pleasure signal (increases viability)
curl -X POST http://localhost:4000/api/vsm/algedonic/pleasure \
  -H "Content-Type: application/json" \
  -d '{"intensity": 0.9, "context": "Great performance"}'

# Send pain signal (decreases viability)
curl -X POST http://localhost:4000/api/vsm/algedonic/pain \
  -H "Content-Type: application/json" \
  -d '{"intensity": 0.6, "context": "Resource issue"}'
```

## Expected Behavior

- Pleasure signals increase system_health, adaptation_capacity, and identity_coherence
- Pain signals decrease system_health, adaptation_capacity, and resource_efficiency
- The dashboard viability score updates in real-time when signals are received
- Values persist until changed by new signals or system restart

## Current Status

The fixes have been implemented and compiled. The system is now properly updating viability metrics based on algedonic signals and broadcasting changes to the dashboard.