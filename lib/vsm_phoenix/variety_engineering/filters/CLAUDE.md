# Variety Engineering Filters Directory Context

This directory implements Ashby's Law of Requisite Variety by filtering information between VSM levels.

## Files in this directory:
- `s1_to_s2.ex` - Filters operational events up to coordination level
- `s2_to_s3.ex` - Filters coordination patterns up to control level
- `s3_to_s4.ex` - Filters control metrics up to intelligence level
- `s4_to_s5.ex` - Filters environmental insights up to policy level

## Purpose:
Each filter reduces variety (information overload) by:
- Aggregating similar events
- Extracting patterns from noise
- Summarizing for higher abstraction
- Preventing information overflow between levels

## Filter Pipeline:
```
S1 (High Variety/Detail)
    ↓ s1_to_s2 filter (aggregate events)
S2 (Patterns)
    ↓ s2_to_s3 filter (extract trends)
S3 (Metrics)
    ↓ s3_to_s4 filter (identify anomalies)
S4 (Insights)
    ↓ s4_to_s5 filter (strategic signals)
S5 (Low Variety/High Abstraction)
```

## Quick Start:
```elixir
# Filter S1 events for S2
filtered = S1ToS2Filter.filter(events, %{
  threshold: 0.7,
  aggregation_window: "5m"
})

# Check filter effectiveness
{:ok, metrics} = S1ToS2Filter.get_metrics()
# Returns: {events_in: 1000, events_out: 50, reduction_ratio: 0.95}
```

## Integration:
- Works with Cortical Attention Engine for priority filtering
- Uses telemetry to track filter performance
- Can be tuned via DynamicConfig