defmodule VsmPhoenix.MCP.BulletproofMaggIntegrationManager do
  @moduledoc """
  Bulletproof version of MAGG Integration Manager with graceful degradation.
  
  This module provides resilient integration with MAGG, handling:
  - Missing MAGG CLI gracefully
  - Network failures without crashing
  - External process timeouts
  - Automatic fallback to degraded mode
  
  Key improvements:
  - Never crashes the application
  - Provides clear status of MAGG availability
  - Continues operating in degraded mode when MAGG is unavailable
  - Periodic retry of MAGG availability
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{MaggWrapper, ExternalClient, ExternalClientSupervisor}
  
  defmodule State do
    @moduledoc false
    defstruct [
      :configured_servers,      # Map of server_name => config
      :active_clients,         # Map of server_name => pid
      :health_check_timer,
      :auto_connect,
      :magg_available,         # Boolean indicating MAGG availability
      :availability_check_timer, # Timer for periodic MAGG availability checks
      :degraded_mode,          # Boolean indicating degraded operation
      :last_error              # Last error encountered
    ]
  end
  
  # Configuration
  @health_check_interval 60_000
  @availability_check_interval 300_000  # Check MAGG availability every 5 minutes
  @init_timeout 5_000                  # Timeout for initial operations
  
  # Client API
  
  @doc """
  Start the bulletproof MAGG integration manager.
  
  ## Options
  - `:auto_connect` - Automatically connect to all configured servers (default: true)
  - `:health_check_interval` - Interval for health checks in ms (default: 60_000)
  - `:require_magg` - If true, will log errors when MAGG unavailable (default: false)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get the current status of the manager including MAGG availability.
  """
  def get_full_status do
    GenServer.call(__MODULE__, :get_full_status)
  end
  
  @doc """
  Check if MAGG is currently available.
  """
  def magg_available? do
    GenServer.call(__MODULE__, :magg_available?)
  end
  
  @doc """
  Discover and add a new MCP server (if MAGG is available).
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
    # Trap exits to handle graceful shutdown
    Process.flag(:trap_exit, true)
    
    auto_connect = Keyword.get(opts, :auto_connect, true)
    require_magg = Keyword.get(opts, :require_magg, false)
    
    state = %State{
      configured_servers: %{},
      active_clients: %{},
      auto_connect: auto_connect,
      magg_available: false,
      degraded_mode: true,
      last_error: nil
    }
    
    # Schedule initial setup with a short delay to ensure system is ready
    Process.send_after(self(), :initial_setup, 100)
    
    # Log startup
    if require_magg do
      Logger.warning("Starting MAGG Integration Manager - MAGG is required but may not be available")
    else
      Logger.info("Starting Bulletproof MAGG Integration Manager - will operate in degraded mode if MAGG unavailable")
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:initial_setup, state) do
    Logger.info("Performing initial MAGG availability check...")
    
    # Check MAGG availability with timeout protection
    new_state = safely_check_magg_availability(state)
    
    # Schedule periodic health checks
    health_timer = Process.send_after(self(), :health_check, @health_check_interval)
    new_state = %{new_state | health_check_timer: health_timer}
    
    # Schedule periodic MAGG availability checks
    availability_timer = Process.send_after(self(), :check_magg_availability, @availability_check_interval)
    new_state = %{new_state | availability_check_timer: availability_timer}
    
    # If MAGG is available and auto-connect is enabled, try to connect
    new_state = if new_state.magg_available and state.auto_connect do
      Logger.info("MAGG available, attempting auto-connect to configured servers...")
      safely_auto_connect_servers(new_state)
    else
      if not new_state.magg_available do
        Logger.warning("MAGG not available - operating in degraded mode. MCP server discovery disabled.")
      end
      new_state
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:check_magg_availability, state) do
    # Periodic check for MAGG availability
    was_available = state.magg_available
    new_state = safely_check_magg_availability(state)
    
    # Log status change
    cond do
      not was_available and new_state.magg_available ->
        Logger.info("MAGG is now available! Exiting degraded mode.")
        new_state = %{new_state | degraded_mode: false}
        # Try to refresh servers and auto-connect
        if state.auto_connect do
          safely_auto_connect_servers(new_state)
        else
          new_state
        end
        
      was_available and not new_state.magg_available ->
        Logger.warning("MAGG is no longer available! Entering degraded mode.")
        %{new_state | degraded_mode: true}
        
      true ->
        new_state
    end
    
    # Schedule next check
    timer = Process.send_after(self(), :check_magg_availability, @availability_check_interval)
    
    {:noreply, %{new_state | availability_check_timer: timer}}
  end
  
  @impl true
  def handle_info(:health_check, state) do
    # Check health of all active clients
    new_state = if map_size(state.active_clients) > 0 do
      Logger.debug("Performing health check on #{map_size(state.active_clients)} active clients...")
      
      Enum.reduce(state.active_clients, state, fn {server_name, _pid}, acc ->
        try do
          case ExternalClient.get_status(server_name) do
            {:ok, %{status: :connected}} ->
              acc
            
            _ ->
              Logger.warning("Server #{server_name} is not healthy, attempting reconnect...")
              ExternalClient.reconnect(server_name)
              acc
          end
        rescue
          e ->
            Logger.error("Health check failed for #{server_name}: #{inspect(e)}")
            acc
        end
      end)
    else
      state
    end
    
    # Schedule next health check
    timer = Process.send_after(self(), :health_check, @health_check_interval)
    
    {:noreply, %{new_state | health_check_timer: timer}}
  end
  
  @impl true
  def handle_call(:get_full_status, _from, state) do
    status = %{
      magg_available: state.magg_available,
      degraded_mode: state.degraded_mode,
      configured_servers: Map.keys(state.configured_servers),
      active_connections: Map.keys(state.active_clients),
      auto_connect: state.auto_connect,
      last_error: state.last_error,
      server_details: safely_get_server_details(state)
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_call(:magg_available?, _from, state) do
    {:reply, state.magg_available, state}
  end
  
  @impl true
  def handle_call({:discover_and_add, query}, _from, state) do
    if state.magg_available do
      result = safely_discover_and_add(query, state)
      case result do
        {:ok, server_name, new_state} ->
          {:reply, {:ok, server_name}, new_state}
        {:error, reason, new_state} ->
          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, :magg_not_available}, state}
    end
  end
  
  @impl true
  def handle_call({:connect_server, server_name}, _from, state) do
    case safely_start_client(server_name, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:disconnect_server, server_name}, _from, state) do
    case Map.get(state.active_clients, server_name) do
      nil ->
        {:reply, {:error, :not_connected}, state}
      
      _pid ->
        try do
          ExternalClient.stop(server_name)
          new_clients = Map.delete(state.active_clients, server_name)
          {:reply, :ok, %{state | active_clients: new_clients}}
        rescue
          e ->
            Logger.error("Failed to disconnect server #{server_name}: #{inspect(e)}")
            {:reply, {:error, :disconnect_failed}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:execute_tool, tool_name, params}, _from, state) do
    # Find a server that has this tool
    result = safely_find_and_execute_tool(tool_name, params, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:execute_tool_on_server, server_name, tool_name, params}, _from, state) do
    case Map.get(state.active_clients, server_name) do
      nil ->
        {:reply, {:error, :server_not_connected}, state}
      
      _pid ->
        result = safely_execute_tool(server_name, tool_name, params)
        {:reply, result, state}
    end
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      configured_servers: Map.keys(state.configured_servers),
      active_connections: Map.keys(state.active_clients),
      auto_connect: state.auto_connect,
      server_details: safely_get_server_details(state)
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_cast(:refresh_servers, state) do
    new_state = if state.magg_available do
      safely_refresh_server_list(state)
    else
      Logger.debug("Cannot refresh servers - MAGG not available")
      state
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def terminate(reason, state) do
    Logger.info("Bulletproof MAGG Integration Manager shutting down: #{inspect(reason)}")
    
    # Cancel timers
    if state.health_check_timer, do: Process.cancel_timer(state.health_check_timer)
    if state.availability_check_timer, do: Process.cancel_timer(state.availability_check_timer)
    
    # Disconnect all clients gracefully
    Enum.each(state.active_clients, fn {server_name, _} ->
      try do
        ExternalClient.stop(server_name)
      rescue
        _ -> :ok
      end
    end)
    
    :ok
  end
  
  # Private helper functions with error handling
  
  defp safely_check_magg_availability(state) do
    try do
      case MaggWrapper.check_availability() do
        {:ok, info} ->
          Logger.info("MAGG CLI available: #{inspect(info)}")
          %{state | magg_available: true, degraded_mode: false, last_error: nil}
        
        {:error, reason} ->
          Logger.debug("MAGG CLI not available: #{reason}")
          %{state | magg_available: false, degraded_mode: true, last_error: reason}
      end
    rescue
      e ->
        Logger.error("Error checking MAGG availability: #{inspect(e)}")
        %{state | magg_available: false, degraded_mode: true, last_error: inspect(e)}
    end
  end
  
  defp safely_refresh_server_list(state) do
    try do
      case MaggWrapper.list_servers() do
        {:ok, servers} ->
          configured = Enum.reduce(servers, %{}, fn server, acc ->
            Map.put(acc, server["name"], server)
          end)
          
          %{state | configured_servers: configured}
        
        {:error, reason} ->
          Logger.error("Failed to refresh server list: #{inspect(reason)}")
          %{state | last_error: reason}
      end
    rescue
      e ->
        Logger.error("Exception refreshing server list: #{inspect(e)}")
        %{state | last_error: inspect(e)}
    end
  end
  
  defp safely_auto_connect_servers(state) do
    state = safely_refresh_server_list(state)
    
    Enum.reduce(state.configured_servers, state, fn {server_name, _config}, acc ->
      if Map.has_key?(acc.active_clients, server_name) do
        acc
      else
        case safely_start_client(server_name, acc) do
          {:ok, new_state} -> new_state
          {:error, _reason, new_state} -> new_state
        end
      end
    end)
  end
  
  defp safely_start_client(server_name, state) do
    try do
      case Map.get(state.configured_servers, server_name) do
        nil ->
          {:error, :server_not_configured, state}
        
        _config ->
          case ExternalClientSupervisor.start_client(server_name) do
            {:ok, pid} ->
              new_clients = Map.put(state.active_clients, server_name, pid)
              {:ok, %{state | active_clients: new_clients}}
            
            {:error, {:already_started, pid}} ->
              new_clients = Map.put(state.active_clients, server_name, pid)
              {:ok, %{state | active_clients: new_clients}}
            
            {:error, reason} ->
              Logger.error("Failed to start client for #{server_name}: #{inspect(reason)}")
              {:error, reason, state}
          end
      end
    rescue
      e ->
        Logger.error("Exception starting client for #{server_name}: #{inspect(e)}")
        {:error, inspect(e), state}
    end
  end
  
  defp safely_find_and_execute_tool(tool_name, params, state) do
    try do
      # Get tools from all active clients
      active_servers = Map.keys(state.active_clients)
      
      # Find first server with the tool
      Enum.find_value(active_servers, {:error, :tool_not_found}, fn server_name ->
        case ExternalClient.list_tools(server_name) do
          {:ok, tools} ->
            if Enum.any?(tools, &(&1["name"] == tool_name)) do
              safely_execute_tool(server_name, tool_name, params)
            else
              nil
            end
          
          _ ->
            nil
        end
      end)
    rescue
      e ->
        Logger.error("Error finding and executing tool #{tool_name}: #{inspect(e)}")
        {:error, :execution_failed}
    end
  end
  
  defp safely_execute_tool(server_name, tool_name, params) do
    try do
      ExternalClient.execute_tool(server_name, tool_name, params)
    rescue
      e ->
        Logger.error("Error executing tool #{tool_name} on #{server_name}: #{inspect(e)}")
        {:error, :execution_failed}
    end
  end
  
  defp safely_get_server_details(state) do
    try do
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
    rescue
      _ ->
        []
    end
  end
  
  defp safely_discover_and_add(query, state) do
    try do
      case MaggWrapper.search_servers(query: query, limit: 10) do
        {:ok, servers} when servers != [] ->
          # Let user choose or auto-select first
          server = hd(servers)
          server_name = server["name"]
          
          case MaggWrapper.add_server(server_name) do
            {:ok, _} ->
              # Refresh our server list
              new_state = safely_refresh_server_list(state)
              
              # Auto-connect if enabled
              if state.auto_connect do
                case safely_start_client(server_name, new_state) do
                  {:ok, updated_state} ->
                    {:ok, server_name, updated_state}
                  {:error, reason, updated_state} ->
                    {:error, reason, updated_state}
                end
              else
                {:ok, server_name, new_state}
              end
            
            {:error, reason} ->
              {:error, reason, state}
          end
        
        {:ok, []} ->
          {:error, :no_servers_found, state}
        
        {:error, reason} ->
          {:error, reason, state}
      end
    rescue
      e ->
        Logger.error("Error discovering and adding server: #{inspect(e)}")
        {:error, :discovery_failed, state}
    end
  end
  
  # Registry helpers
  defp via_tuple(server_name) do
    {:via, Registry, {VsmPhoenix.MCP.ExternalClientRegistry, server_name}}
  end
end