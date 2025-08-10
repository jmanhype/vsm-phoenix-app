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
      # Core telemetry components
      VsmPhoenix.Telemetry.AnalogArchitect,
      VsmPhoenix.Telemetry.SignalProcessor,
      VsmPhoenix.Telemetry.PatternDetector,
      VsmPhoenix.Telemetry.SignalAggregator,
      VsmPhoenix.Telemetry.AdaptiveController,
      VsmPhoenix.Telemetry.SignalVisualizer,
      
      # Integration components
      VsmPhoenix.Telemetry.TelegramIntegration
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end