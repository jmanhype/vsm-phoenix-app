defmodule VsmPhoenix.MCP.ExternalClient do
  @moduledoc """
  Client for connecting to external MCP servers discovered via MAGG.
  
  Supports both stdio and HTTP transports for MCP protocol communication.
  Handles tool execution proxying and maintains connection state.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.MCP.MaggWrapper

  @stdio_timeout 30_000
  @http_timeout 30_000
  @reconnect_delay 5_000
  @max_reconnect_attempts 3

  defmodule State do
    @moduledoc false
    defstruct [
      :server_name,
      :transport,
      :config,
      :port,
      :http_client,
      :status,
      :tools,
      :reconnect_attempts,
      :request_id,
      :pending_requests  # Map of request_id => {from, timer_ref}
    ]
  end

  # Client API

  @doc """
  Start an external MCP client for a specific server.
  """
  def start_link(opts) do
    server_name = Keyword.fetch!(opts, :server_name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(server_name))
  end

  @doc """
  Execute a tool on the external MCP server.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.ExternalClient.execute_tool("@server/weather", "get_weather", %{"location" => "New York"})
      {:ok, %{"temperature" => 72, "conditions" => "sunny"}}
  """
  def execute_tool(server_name, tool_name, params \\ %{}) do
    GenServer.call(via_tuple(server_name), {:execute_tool, tool_name, params}, @stdio_timeout)
  catch
    :exit, {:noproc, _} ->
      {:error, :client_not_started}
    :exit, {:timeout, _} ->
      {:error, :execution_timeout}
    :exit, reason ->
      Logger.error("Tool execution failed: #{inspect(reason)}")
      {:error, {:execution_failed, reason}}
  end

  @doc """
  List available tools from the external server.
  """
  def list_tools(server_name) do
    GenServer.call(via_tuple(server_name), :list_tools)
  catch
    :exit, {:noproc, _} ->
      {:error, :client_not_started}
  end

  @doc """
  Get the current status of the external client.
  """
  def get_status(server_name) do
    GenServer.call(via_tuple(server_name), :get_status)
  catch
    :exit, {:noproc, _} ->
      {:error, :client_not_started}
  end

  @doc """
  Reconnect to the external server.
  """
  def reconnect(server_name) do
    GenServer.cast(via_tuple(server_name), :reconnect)
  end

  @doc """
  Stop the external client gracefully.
  """
  def stop(server_name, reason \\ :normal) do
    GenServer.stop(via_tuple(server_name), reason)
  catch
    :exit, {:noproc, _} ->
      :ok
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    server_name = Keyword.fetch!(opts, :server_name)
    
    # Get server configuration from MAGG
    case MaggWrapper.get_server_config(server_name) do
      {:ok, config} ->
        state = %State{
          server_name: server_name,
          transport: determine_transport(config),
          config: config,
          status: :initializing,
          reconnect_attempts: 0,
          request_id: 0,
          pending_requests: %{}
        }
        
        # Start connection process
        send(self(), :connect)
        
        {:ok, state}
      
      {:error, reason} ->
        {:stop, {:error, :config_not_found, reason}}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    case connect_to_server(state) do
      {:ok, new_state} ->
        Logger.info("Connected to external MCP server: #{state.server_name}")
        {:noreply, %{new_state | status: :connected, reconnect_attempts: 0}}
      
      {:error, reason} ->
        Logger.error("Failed to connect to #{state.server_name}: #{inspect(reason)}")
        schedule_reconnect(state)
    end
  end

  @impl true
  def handle_info(:reconnect, state) do
    if state.reconnect_attempts < @max_reconnect_attempts do
      Logger.info("Attempting to reconnect to #{state.server_name} (attempt #{state.reconnect_attempts + 1})")
      send(self(), :connect)
      {:noreply, %{state | reconnect_attempts: state.reconnect_attempts + 1}}
    else
      Logger.error("Max reconnection attempts reached for #{state.server_name}")
      {:noreply, %{state | status: :disconnected}}
    end
  end

  @impl true
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    Logger.warning("Stdio port closed for #{state.server_name}: #{inspect(reason)}")
    schedule_reconnect(%{state | port: nil, status: :disconnected})
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Handle incoming data from stdio transport
    case parse_stdio_data(data) do
      {:ok, response} ->
        handle_mcp_response(response, state)
      
      {:error, reason} ->
        Logger.error("Failed to parse stdio data: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:request_timeout, request_id}, state) do
    case Map.pop(state.pending_requests, request_id) do
      {{from, _timer_ref}, new_pending} ->
        GenServer.reply(from, {:error, :timeout})
        {:noreply, %{state | pending_requests: new_pending}}
      
      {nil, _} ->
        # Request already handled
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call({:execute_tool, tool_name, params}, from, state) do
    case state.status do
      :connected ->
        request_id = state.request_id + 1
        request = build_tool_request(request_id, tool_name, params)
        
        case send_request(request, state) do
          :ok ->
            # Set up timeout for this request
            timer_ref = Process.send_after(self(), {:request_timeout, request_id}, @stdio_timeout)
            
            # Store the pending request with caller info
            pending = Map.put(state.pending_requests, request_id, {from, timer_ref})
            new_state = %{state | request_id: request_id, pending_requests: pending}
            
            # Don't reply yet - we'll reply when we get the response
            {:noreply, new_state}
          
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      
      status ->
        {:reply, {:error, {:not_connected, status}}, state}
    end
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    {:reply, {:ok, state.tools || []}, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status_info = %{
      server_name: state.server_name,
      transport: state.transport,
      status: state.status,
      tools_count: length(state.tools || []),
      reconnect_attempts: state.reconnect_attempts
    }
    
    {:reply, {:ok, status_info}, state}
  end

  @impl true
  def handle_cast(:reconnect, state) do
    send(self(), :connect)
    {:noreply, %{state | reconnect_attempts: 0}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating external client for #{state.server_name}: #{inspect(reason)}")
    
    # Clean up port if stdio
    if state.port do
      Port.close(state.port)
    end
    
    # Reply to any pending requests
    for {_id, {from, timer_ref}} <- state.pending_requests do
      Process.cancel_timer(timer_ref)
      GenServer.reply(from, {:error, :client_terminated})
    end
    
    :ok
  end

  # Private functions

  defp via_tuple(server_name) do
    {:via, Registry, {VsmPhoenix.MCP.ExternalClientRegistry, server_name}}
  end

  defp determine_transport(config) do
    cond do
      config["transport"] == "http" -> :http
      config["transport"] == "stdio" -> :stdio
      true -> :stdio  # Default to stdio
    end
  end

  defp connect_to_server(%{transport: :stdio} = state) do
    connect_stdio(state)
  end

  defp connect_to_server(%{transport: :http} = state) do
    connect_http(state)
  end

  defp connect_stdio(state) do
    command = state.config["command"] || "npx"
    args = state.config["args"] || [state.server_name]
    
    port_opts = [
      :binary,
      :exit_status,
      {:line, 4096},
      {:env, [{"NODE_ENV", "production"}]}
    ]
    
    try do
      port = Port.open({:spawn_executable, System.find_executable(command)}, 
                      [{:args, args} | port_opts])
      
      # Send initialization message
      init_message = build_init_message()
      send_stdio_message(port, init_message)
      
      # Wait for capabilities response
      receive do
        {^port, {:data, data}} ->
          case parse_stdio_data(data) do
            {:ok, %{"method" => "initialize", "result" => result}} ->
              tools = extract_tools(result)
              {:ok, %{state | port: port, tools: tools}}
            _ ->
              Port.close(port)
              {:error, :invalid_init_response}
          end
      after
        5000 ->
          Port.close(port)
          {:error, :init_timeout}
      end
    catch
      :error, reason ->
        {:error, {:port_open_failed, reason}}
    end
  end

  defp connect_http(state) do
    # Initialize HTTP client (using Finch or HTTPoison)
    base_url = state.config["url"] || "http://localhost:3000"
    
    # Send initialization request
    case send_http_request(base_url, build_init_message()) do
      {:ok, response} ->
        tools = extract_tools(response["result"])
        {:ok, %{state | http_client: base_url, tools: tools}}
      
      error ->
        error
    end
  end

  defp build_init_message do
    %{
      "jsonrpc" => "2.0",
      "id" => 0,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{
          "roots" => %{
            "listChanged" => true
          }
        },
        "clientInfo" => %{
          "name" => "vsm-phoenix",
          "version" => "1.0.0"
        }
      }
    }
  end

  defp build_tool_request(id, tool_name, params) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{
        "name" => tool_name,
        "arguments" => params
      }
    }
  end

  defp send_request(request, %{transport: :stdio, port: port}) do
    send_stdio_message(port, request)
  end

  defp send_request(request, %{transport: :http, http_client: base_url}) do
    case send_http_request(base_url, request) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp send_stdio_message(port, message) do
    json = Jason.encode!(message)
    data = "Content-Length: #{byte_size(json)}\r\n\r\n#{json}"
    Port.command(port, data)
    :ok
  catch
    :error, reason ->
      {:error, reason}
  end

  defp send_http_request(base_url, message) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(message)
    
    case :hackney.request(:post, base_url, headers, body, [recv_timeout: @http_timeout]) do
      {:ok, 200, _, ref} ->
        case :hackney.body(ref) do
          {:ok, response_body} ->
            Jason.decode(response_body)
          error ->
            error
        end
      
      error ->
        error
    end
  end

  defp parse_stdio_data(data) when is_binary(data) do
    # Handle MCP stdio protocol format
    case String.split(data, "\r\n\r\n", parts: 2) do
      [headers, body] ->
        # Extract content length and parse JSON body
        Jason.decode(body)
      
      _ ->
        # Try direct JSON parsing
        Jason.decode(data)
    end
  end

  defp handle_mcp_response(response, state) do
    case response do
      %{"method" => method, "params" => params} ->
        # Handle notifications
        handle_notification(method, params, state)
      
      %{"id" => id, "result" => result} ->
        # Handle response to our request
        handle_tool_response(id, {:ok, result}, state)
      
      %{"id" => id, "error" => error} ->
        # Handle error response
        Logger.error("MCP error for request #{id}: #{inspect(error)}")
        handle_tool_response(id, {:error, error}, state)
      
      _ ->
        {:noreply, state}
    end
  end

  defp handle_tool_response(request_id, response, state) do
    case Map.pop(state.pending_requests, request_id) do
      {{from, timer_ref}, new_pending} ->
        # Cancel the timeout timer
        Process.cancel_timer(timer_ref)
        
        # Reply to the caller
        GenServer.reply(from, response)
        
        {:noreply, %{state | pending_requests: new_pending}}
      
      {nil, _} ->
        # No pending request found (might have timed out)
        Logger.warning("Received response for unknown request #{request_id}")
        {:noreply, state}
    end
  end

  defp handle_notification("tools/list_changed", _params, state) do
    # Refresh tools list
    case fetch_tools(state) do
      {:ok, tools} ->
        {:noreply, %{state | tools: tools}}
      _ ->
        {:noreply, state}
    end
  end

  defp handle_notification(_method, _params, state) do
    {:noreply, state}
  end

  defp extract_tools(%{"capabilities" => %{"tools" => tools}}) when is_list(tools) do
    tools
  end

  defp extract_tools(_), do: []

  defp fetch_tools(%{transport: :stdio, port: port}) do
    request = %{
      "jsonrpc" => "2.0",
      "id" => :os.system_time(:millisecond),
      "method" => "tools/list",
      "params" => %{}
    }
    
    send_stdio_message(port, request)
    
    receive do
      {^port, {:data, data}} ->
        case parse_stdio_data(data) do
          {:ok, %{"result" => %{"tools" => tools}}} ->
            {:ok, tools}
          _ ->
            {:error, :invalid_response}
        end
    after
      5000 ->
        {:error, :timeout}
    end
  end

  defp fetch_tools(%{transport: :http, http_client: base_url}) do
    request = %{
      "jsonrpc" => "2.0",
      "id" => :os.system_time(:millisecond),
      "method" => "tools/list",
      "params" => %{}
    }
    
    case send_http_request(base_url, request) do
      {:ok, %{"result" => %{"tools" => tools}}} ->
        {:ok, tools}
      _ ->
        {:error, :fetch_failed}
    end
  end

  defp schedule_reconnect(state) do
    Process.send_after(self(), :reconnect, @reconnect_delay)
    {:noreply, state}
  end
end