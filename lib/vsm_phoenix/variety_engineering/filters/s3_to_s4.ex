defmodule VsmPhoenix.VarietyEngineering.Filters.S3ToS4 do
  @moduledoc """
  Metrics to Trends Filter: S3 → S4
  
  Aggregates resource metrics from System 3 into
  environmental trends for System 4 intelligence.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def increase_filtering do
    GenServer.cast(@name, :increase_filtering)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔽 Starting S3→S4 Metrics Filter...")
    
    # Subscribe to S3 resource metrics
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system3")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:resources")
    
    {:ok, %{
      filtering_level: 1.0,
      metric_buffer: [],
      trend_window: 60_000  # 1 minute
    }}
  end
  
  @impl true
  def handle_cast(:increase_filtering, state) do
    {:noreply, %{state | filtering_level: min(state.filtering_level * 1.2, 2.0)}}
  end
  
  @impl true
  def handle_info({:resource_metrics, metrics}, state) do
    # Buffer metrics for trend analysis
    new_buffer = [{System.monotonic_time(:millisecond), metrics} | state.metric_buffer]
                 |> clean_old_metrics(state.trend_window)
    
    # Extract trends if enough data
    if length(new_buffer) > 5 do
      trends = analyze_trends(new_buffer, state.filtering_level)
      
      Enum.each(trends, fn trend ->
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "vsm:system4",
          {:environmental_trend, trend}
        )
        
        VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s4, :inbound, :trend)
      end)
    end
    
    {:noreply, %{state | metric_buffer: new_buffer}}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp clean_old_metrics(buffer, window) do
    cutoff = System.monotonic_time(:millisecond) - window
    Enum.filter(buffer, fn {ts, _} -> ts > cutoff end)
  end
  
  defp analyze_trends(buffer, filtering_level) do
    # Extract significant trends from metrics
    []  # Simplified - would implement trend detection
  end
end