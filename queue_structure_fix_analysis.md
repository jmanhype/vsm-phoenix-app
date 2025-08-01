# Queue Structure JSON Encoding Fix Analysis

## Problem Summary
The API endpoint `GET /api/vsm/agents/:id` is failing with:
```
protocol Jason.Encoder not implemented for type Tuple, Got value: {[], []}
```

This `{[], []}` is an Erlang queue structure created by `:queue.new()`.

## Investigation Findings

### 1. Queue Source Located
- **File**: `lib/vsm_phoenix/system1/agents/worker_agent.ex`
- **Line**: 88
- **Code**: `work_queue: :queue.new()`
- The queue is initialized in the agent's metrics during init

### 2. Current Mitigation Attempts
The controller already has queue cleaning logic:
- `clean_queue_structures/1` function (lines 344-373 in agent_controller.ex)
- `get_work_metrics/1` in worker_agent.ex returns clean metrics
- Safe config filtering in the controller

### 3. The Real Problem
Despite these mitigations, the queue is still leaking through. After thorough investigation, the issue appears to be that:

1. The worker agent initializes with a queue in its internal state metrics
2. When `get_work_metrics` is called, it correctly converts the queue length to a number
3. The controller further cleans the metrics with `clean_queue_structures`
4. However, the error persists

## Root Cause Analysis
The most likely cause is that somewhere in the response chain, raw data is being included that bypasses the cleaning functions. Possible sources:

1. The metadata stored in Registry might be getting contaminated
2. There might be a code path that doesn't use the cleaning functions
3. The queue might be nested deeper in the structure than expected

## Recommended Fix

### Option 1: Remove Queue from State (Preferred)
Instead of storing an actual queue structure, store just the queue length:

```elixir
# In worker_agent.ex init function, change:
metrics: %{
  commands_processed: 0,
  commands_failed: 0,
  total_processing_time: 0,
  last_command_at: nil,
  work_queue: :queue.new()  # REMOVE THIS
  work_queue_length: 0       # ADD THIS
}
```

### Option 2: Enhanced Cleaning in Controller
Add more aggressive cleaning that catches all possible queue structures:

```elixir
defp deep_clean_for_json(data) when is_map(data) do
  data
  |> Enum.map(fn {k, v} -> {k, deep_clean_for_json(v)} end)
  |> Map.new()
end

defp deep_clean_for_json({[], []}) do
  0  # Empty queue
end

defp deep_clean_for_json(data) when is_tuple(data) and tuple_size(data) == 2 do
  # Check if it's a queue-like structure
  case data do
    {l1, l2} when is_list(l1) and is_list(l2) -> length(l1) + length(l2)
    _ -> inspect(data)  # Convert other tuples to strings
  end
end

defp deep_clean_for_json(data) when is_list(data) do
  Enum.map(data, &deep_clean_for_json/1)
end

defp deep_clean_for_json(data), do: data
```

### Option 3: Debug and Trace
Add temporary logging to find the exact source:

```elixir
# In agent_controller.ex show method, before json/2 call:
Logger.debug("Raw response before JSON encoding: #{inspect(response, limit: :infinity)}")
```

## Immediate Action Required
The simplest and most effective fix is Option 1 - removing the queue structure from the state entirely since it's only used for counting anyway.