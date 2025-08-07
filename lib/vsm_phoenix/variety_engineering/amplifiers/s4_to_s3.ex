defmodule VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3 do
  @moduledoc """
  Adaptation Amplification: S4 → S3
  
  Converts adaptation proposals from System 4 into
  resource allocation plans for System 3.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def increase_amplification do
    GenServer.cast(@name, :increase_amplification)
  end
  
  def set_factor(factor) do
    GenServer.call(@name, {:set_factor, factor})
  end

  def adjust_amplification(factor) do
    GenServer.call(@name, {:set_factor, factor})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔼 Starting S4→S3 Adaptation Amplifier...")
    
    # Subscribe to S4 adaptation proposals
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system4")
    
    {:ok, %{amplification_factor: 2}}
  end
  
  @impl true
  def handle_call({:set_factor, factor}, _from, state) do
    {:reply, :ok, %{state | amplification_factor: factor}}
  end
  
  @impl true
  def handle_cast(:increase_amplification, state) do
    {:noreply, %{state | amplification_factor: min(state.amplification_factor * 1.5, 8)}}
  end
  
  @impl true
  def handle_info({:adaptation_proposal, proposal}, state) do
    # Amplify adaptation into resource plans
    resource_plans = amplify_adaptation(proposal, state.amplification_factor)
    
    Enum.each(resource_plans, fn plan ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:system3",
        {:resource_allocation_plan, plan}
      )
      
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s3, :inbound, :allocation_plan)
    end)
    
    {:noreply, state}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp amplify_adaptation(proposal, factor) do
    # Generate multiple resource allocation plans
    1..round(factor)
    |> Enum.map(fn i ->
      %{
        source: :s4_adaptation,
        proposal_id: proposal[:id],
        variant: i,
        resources_needed: expand_resource_requirements(proposal, i),
        timeline: generate_timeline(proposal, i),
        priority: proposal[:priority] || :normal
      }
    end)
  end
  
  defp expand_resource_requirements(proposal, variant) do
    base_resources = proposal[:resources] || %{}
    
    %{
      compute: Map.get(base_resources, :compute, 0.1) * variant,
      memory: Map.get(base_resources, :memory, 0.1) * variant,
      human: Map.get(base_resources, :human, 1) * variant,
      financial: Map.get(base_resources, :financial, 1000) * variant
    }
  end
  
  defp generate_timeline(proposal, variant) do
    base_duration = proposal[:duration] || 7
    %{
      phase: variant,
      start_day: (variant - 1) * base_duration,
      duration_days: base_duration
    }
  end
end