defmodule VsmPhoenix.Telemetry.Supervisor do
  @moduledoc """
  Supervisor for Analog-Signal Telemetry Architecture components
  """
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # NEW: Refactored SOLID architecture components
      
      # Registries needed by processors and pipelines
      {Registry, keys: :duplicate, name: VsmPhoenix.Telemetry.ProcessorRegistry},
      {Registry, keys: :duplicate, name: VsmPhoenix.Telemetry.PipelineRegistry},
      
      # Data stores must be started first
      VsmPhoenix.Telemetry.DataStores.ETSDataStore,
      
      # Core components (extracted from god objects)
      VsmPhoenix.Telemetry.Core.SignalRegistry,
      VsmPhoenix.Telemetry.Core.SignalSampler,
      
      # Main orchestrators (using SOLID principles)
      VsmPhoenix.Telemetry.RefactoredAnalogArchitect,
      VsmPhoenix.Telemetry.RefactoredSemanticBlockProcessor,
      
      # Legacy components still in use
      # SignalProcessor and PatternDetector are created by the factory inside RefactoredAnalogArchitect
      # VsmPhoenix.Telemetry.SignalProcessor,
      # VsmPhoenix.Telemetry.PatternDetector,
      VsmPhoenix.Telemetry.SignalAggregator,
      VsmPhoenix.Telemetry.AdaptiveController,
      VsmPhoenix.Telemetry.SignalVisualizer,
      
      # Integration components
      VsmPhoenix.Telemetry.TelegramIntegration,
      
      # Context fusion for semantic processing - DISABLED (file not available)
      # {VsmPhoenix.Telemetry.ContextFusionEngine, [
      #   integration_modules: [
      #     VsmPhoenix.CRDT.ContextStore,
      #     VsmPhoenix.System2.CorticalAttentionEngine
      #   ]
      # ]},
      
      # NEW: Integration bridges with other swarms
      VsmPhoenix.Telemetry.Integrations.AmcpTelemetryBridge
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end