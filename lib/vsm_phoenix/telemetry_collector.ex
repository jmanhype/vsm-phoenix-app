defmodule VsmPhoenix.TelemetryCollector do
  @moduledoc """
  Telemetry collection for VSM system insights
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Telemetry Collector initializing...")
    
    # Attach telemetry handlers
    attach_telemetry_handlers()
    
    state = %{
      events: [],
      metrics: %{}
    }
    
    {:ok, state}
  end
  
  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "vsm-telemetry",
      [
        [:vsm, :system, :operation],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :stop]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end
  
  defp handle_telemetry_event(event, measurements, metadata, _config) do
    Logger.debug("Telemetry event: #{inspect(event)} - #{inspect(measurements)}")
  end
end