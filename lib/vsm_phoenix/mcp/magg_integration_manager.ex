defmodule VsmPhoenix.MCP.MaggIntegrationManager do
  @moduledoc """
  High-level manager for MAGG integration with VSM Phoenix.
  
  This module orchestrates:
  - Server discovery and installation
  - External client lifecycle management
  - Tool execution proxying
  - Connection health monitoring
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{MaggWrapper, ExternalClient, ExternalClientSupervisor}
  
  defmodule State do
    @moduledoc false
    defstruct [
      :configured_servers,  # Map of server_name => config
      :active_clients,      # Map of server_name => pid
      :health_check_timer,
      :auto_connect
    ]
  end
  
  # Client API
  
  @doc """
  Start the MAGG integration manager.
  
  ## Options
  - `:auto_connect` - Automatically connect to all configured servers (default: true)
  - `:health_check_interval` - Interval for health checks in ms (default: 60_000)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Discover and add a new MCP server.
  """
  def discover_and_add_server(query) do
    GenServer.call(__MODULE__, {:discover_and_add, query})
  end
  
  @doc """
  Connect to a configured server.
  """
  def connect_server(server_name) do
    GenServer.call(__MODULE__, {:connect_server, server_name})
  end
  
  @doc """
  Disconnect from a server.
  """
  def disconnect_server(server_name) do
    GenServer.call(__MODULE__, {:disconnect_server, server_name})
  end
  
  @doc """
  Execute a tool on any available server that has it.
  """
  def execute_tool(tool_name, params \\ %{}) do
    GenServer.call(__MODULE__, {:execute_tool, tool_name, params})
  end
  
  @doc """
  Execute a tool on a specific server.
  """
  def execute_tool_on_server(server_name, tool_name, params \\ %{}) do
    GenServer.call(__MODULE__, {:execute_tool_on_server, server_name, tool_name, params})
  end
  
  @doc """
  Get the status of all managed servers.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  @doc """
  Refresh the list of configured servers from MAGG.
  """
  def refresh_servers do
    GenServer.cast(__MODULE__, :refresh_servers)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    auto_connect = Keyword.get(opts, :auto_connect, true)
    health_check_interval = Keyword.get(opts, :health_check_interval, 60_000)
    
    state = %State{
      configured_servers: %{},
      active_clients: %{},
      auto_connect: auto_connect
    }
    
    # Start health check timer
    timer = Process.send_after(self(), :health_check, health_check_interval)
    state = %{state | health_check_timer: timer}
    
    # Initial server refresh
    send(self(), :initial_setup)
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:initial_setup, state) do
    Logger.info("Starting MAGG integration manager...")
    
    # Check MAGG availability
    case MaggWrapper.check_availability() do
      {:ok, info} ->
        Logger.info("MAGG CLI available: #{inspect(info)}")
        
        # Refresh servers
        new_state = refresh_server_list(state)
        
        # Auto-connect if enabled
        if state.auto_connect do
          new_state = auto_connect_servers(new_state)
        end
        
        {:noreply, new_state}
      
      {:error, reason} ->
        Logger.error("MAGG CLI not available: #{reason}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:health_check, state) do
    # Check health of all active clients
    new_state = Enum.reduce(state.active_clients, state, fn {server_name, _pid}, acc ->
      case ExternalClient.get_status(server_name) do
        {:ok, %{status: :connected}} ->
          acc
        
        _ ->
          Logger.warning("Server #{server_name} is not healthy, attempting reconnect...")
          ExternalClient.reconnect(server_name)
          acc
      end
    end)
    
    # Schedule next health check
    timer = Process.send_after(self(), :health_check, 60_000)
    
    {:noreply, %{new_state | health_check_timer: timer}}
  end
  
  @impl true
  def handle_call({:discover_and_add, query}, _from, state) do
    case MaggWrapper.search_servers(query: query, limit: 10) do
      {:ok, servers} when servers != [] ->
        # Let user choose or auto-select first
        server = hd(servers)
        server_name = server["name"]
        
        case MaggWrapper.add_server(server_name) do
          {:ok, _} ->
            # Refresh our server list
            new_state = refresh_server_list(state)
            
            # Auto-connect if enabled
            if state.auto_connect do
              case start_client(server_name, new_state) do
                {:ok, updated_state} ->
                  {:reply, {:ok, server_name}, updated_state}
                error ->
                  {:reply, error, new_state}
              end
            else
              {:reply, {:ok, server_name}, new_state}
            end
          
          error ->
            {:reply, error, state}
        end
      
      {:ok, []} ->
        {:reply, {:error, :no_servers_found}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:connect_server, server_name}, _from, state) do
    case start_client(server_name, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:disconnect_server, server_name}, _from, state) do
    case Map.get(state.active_clients, server_name) do
      nil ->
        {:reply, {:error, :not_connected}, state}
      
      _pid ->
        ExternalClient.stop(server_name)
        new_clients = Map.delete(state.active_clients, server_name)
        {:reply, :ok, %{state | active_clients: new_clients}}
    end
  end
  
  @impl true
  def handle_call({:execute_tool, tool_name, params}, _from, state) do
    # Find a server that has this tool
    result = find_and_execute_tool(tool_name, params, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:execute_tool_on_server, server_name, tool_name, params}, _from, state) do
    case Map.get(state.active_clients, server_name) do
      nil ->
        {:reply, {:error, :server_not_connected}, state}
      
      _pid ->
        result = ExternalClient.execute_tool(server_name, tool_name, params)
        {:reply, result, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      configured_servers: Map.keys(state.configured_servers),
      active_connections: Map.keys(state.active_clients),
      auto_connect: state.auto_connect,
      server_details: get_server_details(state)
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_cast(:refresh_servers, state) do
    new_state = refresh_server_list(state)
    {:noreply, new_state}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Cancel health check timer
    if state.health_check_timer do
      Process.cancel_timer(state.health_check_timer)
    end
    
    # Disconnect all clients gracefully
    Enum.each(state.active_clients, fn {server_name, _} ->
      ExternalClient.stop(server_name)
    end)
    
    :ok
  end
  
  # Private functions
  
  defp refresh_server_list(state) do
    case MaggWrapper.list_servers() do
      {:ok, servers} ->
        configured = Enum.reduce(servers, %{}, fn server, acc ->
          Map.put(acc, server["name"], server)
        end)
        
        %{state | configured_servers: configured}
      
      {:error, reason} ->
        Logger.error("Failed to refresh server list: #{inspect(reason)}")
        state
    end
  end
  
  defp auto_connect_servers(state) do
    Enum.reduce(state.configured_servers, state, fn {server_name, _config}, acc ->
      if Map.has_key?(acc.active_clients, server_name) do
        acc
      else
        case start_client(server_name, acc) do
          {:ok, new_state} -> new_state
          _ -> acc
        end
      end
    end)
  end
  
  defp start_client(server_name, state) do
    case Map.get(state.configured_servers, server_name) do
      nil ->
        {:error, :server_not_configured}
      
      _config ->
        case ExternalClientSupervisor.start_client(server_name) do
          {:ok, pid} ->
            new_clients = Map.put(state.active_clients, server_name, pid)
            {:ok, %{state | active_clients: new_clients}}
          
          {:error, {:already_started, pid}} ->
            new_clients = Map.put(state.active_clients, server_name, pid)
            {:ok, %{state | active_clients: new_clients}}
          
          error ->
            error
        end
    end
  end
  
  defp find_and_execute_tool(tool_name, params, state) do
    # Get tools from all active clients
    active_servers = Map.keys(state.active_clients)
    
    # Find first server with the tool
    Enum.find_value(active_servers, {:error, :tool_not_found}, fn server_name ->
      case ExternalClient.list_tools(server_name) do
        {:ok, tools} ->
          if Enum.any?(tools, &(&1["name"] == tool_name)) do
            ExternalClient.execute_tool(server_name, tool_name, params)
          else
            nil
          end
        
        _ ->
          nil
      end
    end)
  end
  
  defp get_server_details(state) do
    Enum.map(state.configured_servers, fn {server_name, config} ->
      status = if Map.has_key?(state.active_clients, server_name) do
        case ExternalClient.get_status(server_name) do
          {:ok, status_info} -> status_info
          _ -> %{status: :error}
        end
      else
        %{status: :disconnected}
      end
      
      Map.merge(config, status)
    end)
  end
end