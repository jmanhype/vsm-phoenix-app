defmodule VsmPhoenixWeb.GoldrushController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.Goldrush.{Manager, PatternEngine, EventAggregator, PatternStore}
  
  require Logger
  
  @doc """
  Register a new pattern
  
  POST /api/goldrush/patterns
  
  Body:
  {
    "id": "pattern_id",
    "name": "Pattern Name",
    "conditions": [
      {"field": "cpu_usage", "operator": ">", "value": 80}
    ],
    "time_window": {"duration": 300, "unit": "seconds"},
    "logic": "AND",
    "actions": ["trigger_algedonic", "scale_resources"]
  }
  """
  def create_pattern(conn, params) do
    # Convert string keys to atoms for internal use
    pattern = atomize_pattern(params)
    
    case PatternEngine.register_pattern(pattern) do
      {:ok, pattern_id} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          pattern_id: pattern_id,
          message: "Pattern registered successfully"
        })
        
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: "Failed to register pattern",
          error: inspect(reason)
        })
    end
  end
  
  @doc """
  List all patterns
  
  GET /api/goldrush/patterns
  """
  def list_patterns(conn, _params) do
    patterns = PatternEngine.list_patterns()
    
    json(conn, %{
      status: "success",
      count: length(patterns),
      patterns: patterns
    })
  end
  
  @doc """
  Delete a pattern
  
  DELETE /api/goldrush/patterns/:id
  """
  def delete_pattern(conn, %{"id" => pattern_id}) do
    PatternEngine.unregister_pattern(pattern_id)
    
    json(conn, %{
      status: "success",
      message: "Pattern deleted",
      pattern_id: pattern_id
    })
  end
  
  @doc """
  Submit an event
  
  POST /api/goldrush/events
  
  Body:
  {
    "type": "system_metrics",
    "cpu_usage": 85,
    "memory_usage": 70,
    "custom_field": "value"
  }
  """
  def submit_event(conn, params) do
    event = atomize_keys(params)
    Manager.submit_event(event)
    
    json(conn, %{
      status: "success",
      message: "Event submitted",
      event_type: Map.get(event, :type, "unknown")
    })
  end
  
  @doc """
  Get pattern statistics
  
  GET /api/goldrush/statistics
  """
  def get_statistics(conn, _params) do
    pattern_stats = PatternEngine.get_statistics()
    stream_stats = EventAggregator.get_stream_stats()
    
    json(conn, %{
      status: "success",
      pattern_statistics: pattern_stats,
      stream_statistics: elem(stream_stats, 1)
    })
  end
  
  @doc """
  Get event aggregates
  
  GET /api/goldrush/aggregates?event_type=TYPE&window_size=60
  """
  def get_aggregates(conn, params) do
    opts = [
      event_type: atomize_string(params["event_type"]),
      window_size: String.to_integer(params["window_size"] || "60"),
      aggregations: [:count, :avg, :min, :max, :percentiles]
    ]
    
    case EventAggregator.get_window_aggregates(opts) do
      {:ok, aggregates} ->
        json(conn, %{
          status: "success",
          aggregates: aggregates,
          window_size: opts[:window_size]
        })
        
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: inspect(reason)
        })
    end
  end
  
  @doc """
  Execute a complex query
  
  POST /api/goldrush/query
  
  Body:
  {
    "query_type": "variety_correlation"
  }
  """
  def complex_query(conn, %{"query_type" => query_type}) do
    query_spec = String.to_atom(query_type)
    result = Manager.complex_query({query_spec})
    
    json(conn, %{
      status: "success",
      query_type: query_type,
      result: result
    })
  end
  
  @doc """
  Import patterns from file
  
  POST /api/goldrush/patterns/import
  
  Body:
  {
    "file_path": "/path/to/patterns.json"
  }
  """
  def import_patterns(conn, %{"file_path" => file_path}) do
    case PatternStore.import_patterns_from_file(file_path) do
      {:ok, count} ->
        json(conn, %{
          status: "success",
          message: "Patterns imported successfully",
          count: count
        })
        
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: "Failed to import patterns",
          error: inspect(reason)
        })
    end
  end
  
  @doc """
  Export patterns to file
  
  POST /api/goldrush/patterns/export
  
  Body:
  {
    "file_path": "/path/to/export.json",
    "format": "json"
  }
  """
  def export_patterns(conn, params) do
    file_path = params["file_path"]
    format = String.to_atom(params["format"] || "json")
    
    case PatternStore.export_patterns_to_file(file_path, format) do
      {:ok, count} ->
        json(conn, %{
          status: "success",
          message: "Patterns exported successfully",
          count: count,
          file_path: file_path
        })
        
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: "Failed to export patterns",
          error: inspect(reason)
        })
    end
  end
  
  @doc """
  Test pattern matching with sample event
  
  POST /api/goldrush/test
  
  Body:
  {
    "pattern": {
      "conditions": [...],
      "logic": "AND"
    },
    "event": {
      "cpu_usage": 85,
      ...
    }
  }
  """
  def test_pattern(conn, %{"pattern" => pattern_params, "event" => event_params}) do
    # This is a test endpoint - doesn't save the pattern
    pattern = atomize_pattern(pattern_params)
    |> Map.put(:id, "test_pattern_#{:rand.uniform(1000)}")
    |> Map.put(:name, "Test Pattern")
    |> Map.put(:actions, ["log_event"])
    
    event = atomize_keys(event_params)
    
    # Temporarily register pattern
    case PatternEngine.register_pattern(pattern) do
      {:ok, pattern_id} ->
        # Process event
        PatternEngine.process_event(event)
        
        # Wait a bit for processing
        Process.sleep(100)
        
        # Get statistics to see if it matched
        stats = PatternEngine.get_statistics()
        
        # Clean up
        PatternEngine.unregister_pattern(pattern_id)
        
        json(conn, %{
          status: "success",
          pattern_would_match: Map.get(stats.pattern_hits, pattern_id, 0) > 0,
          test_results: %{
            pattern: pattern,
            event: event,
            matched: Map.get(stats.pattern_hits, pattern_id, 0) > 0
          }
        })
        
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: "Invalid pattern",
          error: inspect(reason)
        })
    end
  end
  
  # Helper functions
  
  defp atomize_pattern(params) do
    %{
      id: params["id"],
      name: params["name"],
      conditions: Enum.map(params["conditions"] || [], &atomize_condition/1),
      logic: params["logic"],
      actions: params["actions"] || [],
      time_window: atomize_time_window(params["time_window"]),
      critical: params["critical"] || false,
      priority: params["priority"] || "normal"
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
  
  defp atomize_condition(condition) do
    %{
      field: condition["field"],
      operator: condition["operator"],
      value: condition["value"],
      unit: condition["unit"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
  
  defp atomize_time_window(nil), do: nil
  defp atomize_time_window(window) do
    %{
      duration: window["duration"],
      unit: String.to_atom(window["unit"])
    }
  end
  
  defp atomize_keys(map) do
    map
    |> Enum.map(fn {k, v} -> 
      {atomize_string(k), atomize_value(v)}
    end)
    |> Map.new()
  end
  
  defp atomize_string(string) when is_binary(string) do
    String.to_atom(string)
  end
  defp atomize_string(value), do: value
  
  defp atomize_value(value) when is_map(value), do: atomize_keys(value)
  defp atomize_value(value), do: value
end