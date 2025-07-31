defmodule VsmPhoenix.MCP.Tools.VsmToolRegistry do
  @moduledoc """
  Tool registry that bridges to existing VSM tools implementation.
  
  This provides compatibility while migrating to the new architecture.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.VsmTools
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("📦 VSM Tool Registry started (compatibility mode)")
    {:ok, %{}}
  end
  
  # Public API
  
  def list_tools do
    VsmTools.list_tools()
  end
  
  def get_tool(name) do
    tools = VsmTools.list_tools()
    Enum.find(tools, fn tool -> tool.name == name end)
  end
  
  def execute(tool_name, arguments, _opts \\ []) do
    VsmTools.execute(tool_name, arguments)
  end
  
  def get_stats(_tool_name) do
    # Stats not implemented in compatibility mode
    nil
  end
end