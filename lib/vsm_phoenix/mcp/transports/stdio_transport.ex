defmodule VsmPhoenix.MCP.Transports.StdioTransport do
  @moduledoc """
  STDIO transport compatibility wrapper.
  
  This module provides the expected interface while using the existing
  WorkingMcpServer stdio implementation.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def send_message(transport, message) when is_binary(message) do
    # The WorkingMcpServer handles its own stdio
    Logger.debug("StdioTransport: Message would be sent: #{byte_size(message)} bytes")
    :ok
  end
  
  def shutdown(transport) do
    GenServer.stop(transport)
  end
  
  @impl true
  def init(opts) do
    {:ok, %{opts: opts}}
  end
  
  @impl true
  def handle_call({:send_message, _message}, _from, state) do
    {:reply, :ok, state}
  end
end