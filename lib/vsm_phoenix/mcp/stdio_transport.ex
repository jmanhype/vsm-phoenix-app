defmodule VsmPhoenix.MCP.StdioTransport do
  @moduledoc """
  Real stdio transport for MCP. Spawns external processes and communicates via JSON-RPC.
  """
  
  use GenServer
  require Logger
  
  defmodule State do
    defstruct [:port, :command, :pending_requests, :buffer]
  end
  
  def start_link(command) do
    GenServer.start_link(__MODULE__, command)
  end
  
  def send(pid, request) do
    GenServer.call(pid, {:send_request, request}, 30_000)
  end
  
  @impl true
  def init(command) when is_binary(command) do
    Logger.info("🚀 Starting MCP server: #{command}")
    
    port = Port.open({:spawn, command}, [
      :binary,
      :use_stdio,
      {:line, 65536},
      :exit_status
    ])
    
    state = %State{
      port: port,
      command: command,
      pending_requests: %{},
      buffer: ""
    }
    
    {:ok, state}
  end
  
  def init(_) do
    {:stop, "StdioTransport requires a command string"}
  end
  
  @impl true
  def handle_call({:send_request, request}, from, state) do
    json = Jason.encode!(request)
    message = json <> "\n"
    
    Port.command(state.port, message)
    
    new_pending = Map.put(state.pending_requests, request.id, from)
    {:noreply, %{state | pending_requests: new_pending}}
  end
  
  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    # Handle line-based data from MCP server
    complete_line = state.buffer <> line
    case Jason.decode(complete_line) do
      {:ok, message} ->
        state = handle_message(message, %{state | buffer: ""})
        {:noreply, state}
        
      {:error, reason} ->
        Logger.error("Failed to decode MCP message: #{inspect(reason)}")
        Logger.error("Message was: #{inspect(complete_line)}")
        {:noreply, %{state | buffer: ""}}
    end
  end
  
  @impl true
  def handle_info({port, {:data, {:noeol, partial}}}, %{port: port} = state) do
    # Handle partial line - accumulate in buffer
    {:noreply, %{state | buffer: state.buffer <> partial}}
  end
  
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) when is_binary(data) do
    # Handle raw binary data
    buffer = state.buffer <> data
    
    case process_buffer(buffer) do
      {:ok, messages, remaining} ->
        state = Enum.reduce(messages, state, &handle_message/2)
        {:noreply, %{state | buffer: remaining}}
        
      {:error, _} ->
        {:noreply, %{state | buffer: buffer}}
    end
  end
  
  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("MCP server exited with status: #{status}")
    {:stop, {:server_exited, status}, state}
  end
  
  defp process_buffer(buffer) do
    lines = String.split(buffer, "\n", trim: false)
    
    {messages, [remaining]} = Enum.split(lines, -1)
    
    decoded = Enum.reduce_while(messages, {:ok, []}, fn line, {:ok, acc} ->
      if String.trim(line) == "" do
        {:cont, {:ok, acc}}
      else
        case Jason.decode(line) do
          {:ok, msg} -> {:cont, {:ok, acc ++ [msg]}}
          {:error, _} = err -> {:halt, err}
        end
      end
    end)
    
    case decoded do
      {:ok, msgs} -> {:ok, msgs, remaining}
      error -> error
    end
  end
  
  defp handle_message(message, state) do
    case Map.get(message, "id") do
      nil ->
        # Notification
        handle_notification(message, state)
        
      id ->
        # Response to our request
        case Map.pop(state.pending_requests, id) do
          {nil, _} ->
            Logger.warning("Received response for unknown request: #{id}")
            state
            
          {from, new_pending} ->
            # Log the full response for debugging
            Logger.debug("📨 MCP Response for request #{id}: #{inspect(message, pretty: true)}")
            GenServer.reply(from, {:ok, message})
            %{state | pending_requests: new_pending}
        end
    end
  end
  
  defp handle_notification(%{"method" => method} = notification, state) do
    Logger.info("MCP notification: #{method}")
    # Could emit telemetry or handle specific notifications
    state
  end
end