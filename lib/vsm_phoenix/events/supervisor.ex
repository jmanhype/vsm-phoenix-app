defmodule VsmPhoenix.Events.Supervisor do
  @moduledoc """
  Event Processing Supervisor
  
  Supervises the complete event processing pipeline:
  - Event Store
  - Event Producer (GenStage)
  - Event Processor (Broadway)
  - Pattern Matcher
  - Analytics Engine
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    Logger.info("🚀 Starting Event Processing Supervisor")
    
    children = [
      # Event Store - foundational storage layer
      {VsmPhoenix.Events.Store, []},
      
      # Event Producer - GenStage producer for Broadway
      {VsmPhoenix.Events.EventProducer, []},
      
      # Pattern Matcher - real-time CEP
      {VsmPhoenix.Events.PatternMatcher, []},
      
      # Analytics Engine - metrics and insights
      {VsmPhoenix.Events.Analytics, []},
      
      # Event Processor - Broadway pipeline (depends on producer)
      {VsmPhoenix.Events.EventProcessor, []}
    ]
    
    # Use one_for_one strategy with restart intensity
    opts = [
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 60
    ]
    
    Supervisor.init(children, opts)
  end
end