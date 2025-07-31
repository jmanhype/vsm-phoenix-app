defmodule VsmPhoenix.MCP.VsmServer do
  @moduledoc """
  Real VSM MCP Server using Hermes.Server
  
  Exposes VSM capabilities as proper MCP tools following Hermes.Server pattern.
  
  This server allows other systems (including other VSMs!) to interact
  with this VSM via the Model Context Protocol, enabling:
  
  - Recursive VSM-to-VSM communication
  - External variety sources connecting to S4
  - Policy synthesis requests to S5
  - Meta-system spawning triggers
  - Resource allocation negotiations
  
  THIS IS THE VSMCP PROTOCOL IN ACTION!
  """

  use Hermes.Server,
    name: "vsm-phoenix-server",
    version: "1.0.0",
    capabilities: [:tools]

  require Logger

  # Register MCP tool components
  component VsmPhoenix.MCP.Tools.AnalyzeVariety
  component VsmPhoenix.MCP.Tools.SynthesizePolicy
  component VsmPhoenix.MCP.Tools.CheckMetaSystemNeed

  @impl true
  def init(client_info, frame) do
    Logger.info("🚀 VSM MCP Server initialized with client: #{inspect(client_info)}")
    {:ok, frame}
  end
end

