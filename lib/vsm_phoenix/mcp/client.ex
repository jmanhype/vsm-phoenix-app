defmodule VsmPhoenix.MCP.Client do
  @moduledoc """
  Real MCP client. No hardcoding. Connects to any MCP server.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{Protocol, StdioTransport}
  
  defmodule State do
    defstruct [:transport, :server_info, :tools, :resources]
  end
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def connect(pid, server_command) do
    GenServer.call(pid, {:connect, server_command})
  end
  
  def list_tools(pid) do
    GenServer.call(pid, :list_tools)
  end
  
  def execute_tool(pid, tool_name, arguments) do
    GenServer.call(pid, {:execute_tool, tool_name, arguments})
  end
  
  @impl true
  def init(_opts) do
    {:ok, %State{}}
  end
  
  @impl true
  def handle_call({:connect, server_command}, _from, state) when is_binary(server_command) do
    Logger.info("🔌 Connecting to MCP server: #{server_command}")
    case StdioTransport.start_link(server_command) do
      {:ok, transport} ->
        # Initialize connection
        case Protocol.initialize(transport) do
          {:ok, %{"result" => result}} ->
            # Get tools
            case Protocol.list_tools(transport) do
              {:ok, %{"result" => %{"tools" => tools}}} ->
                new_state = %{state | 
                  transport: transport,
                  server_info: result["serverInfo"],
                  tools: tools
                }
                {:reply, {:ok, result}, new_state}
                
              error ->
                {:reply, {:error, "Failed to list tools: #{inspect(error)}"}, state}
            end
            
          error ->
            {:reply, {:error, "Failed to initialize: #{inspect(error)}"}, state}
        end
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:list_tools, _from, state) do
    {:reply, {:ok, state.tools || []}, state}
  end
  
  @impl true
  def handle_call({:execute_tool, tool_name, arguments}, _from, state) do
    if state.transport do
      Logger.info("🔨 Calling tool: #{tool_name} with args: #{inspect(arguments)}")
      
      # Find the tool in our tools list to verify it exists
      tool_exists = Enum.any?(state.tools || [], fn tool ->
        tool["name"] == tool_name
      end)
      
      if tool_exists do
        result = Protocol.call_tool(state.transport, tool_name, arguments)
        Logger.info("🔨 Protocol response: #{inspect(result, pretty: true)}")
        {:reply, result, state}
      else
        Logger.error("❌ Tool #{tool_name} not found in available tools")
        {:reply, {:error, "Tool not found: #{tool_name}"}, state}
      end
    else
      {:reply, {:error, "Not connected"}, state}
    end
  end
end