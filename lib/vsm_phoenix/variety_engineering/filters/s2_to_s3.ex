defmodule VsmPhoenix.VarietyEngineering.Filters.S2ToS3 do
  @moduledoc """
  Pattern to Resource Filter: S2 → S3
  
  Transforms coordination patterns from System 2 into
  resource allocation needs for System 3.
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
    Logger.info("🔽 Starting S2→S3 Pattern Filter...")
    
    # Subscribe to S2 coordination patterns
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:coordination")
    
    {:ok, %{filtering_level: 1.0}}
  end
  
  @impl true
  def handle_cast(:increase_filtering, state) do
    {:noreply, %{state | filtering_level: min(state.filtering_level * 1.2, 2.0)}}
  end
  
  @impl true
  def handle_info({:coordination_pattern, pattern}, state) do
    # Transform coordination pattern to resource need
    if should_forward?(pattern, state.filtering_level) do
      resource_request = transform_to_resource_request(pattern)
      
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:system3",
        {:resource_need, resource_request}
      )
      
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s3, :inbound, :resource_request)
    end
    
    {:noreply, state}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp should_forward?(pattern, filtering_level) do
    pattern[:significance] >= (0.5 * filtering_level)
  end
  
  defp transform_to_resource_request(pattern) do
    %{
      source: :s2_coordination,
      pattern_type: pattern.pattern_type,
      resource_type: infer_resource_type(pattern),
      urgency: infer_urgency(pattern),
      context: pattern.context
    }
  end
  
  defp infer_resource_type(%{pattern_type: :resource_pattern}), do: :compute
  defp infer_resource_type(%{pattern_type: :oscillation_pattern}), do: :coordination
  defp infer_resource_type(_), do: :general
  
  defp infer_urgency(%{pattern_type: :anomaly_pattern}), do: :high
  defp infer_urgency(%{pattern_type: :oscillation_pattern}), do: :high
  defp infer_urgency(_), do: :normal
end