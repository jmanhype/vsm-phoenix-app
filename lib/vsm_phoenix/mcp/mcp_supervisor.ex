defmodule VsmPhoenix.MCP.MCPSupervisor do
  @moduledoc """
  Isolated supervisor for all MCP-related components.
  
  This supervisor isolates MCP components from the main application,
  preventing cascading failures when external dependencies are unavailable.
  
  Features:
  - Isolated supervision tree for MCP components
  - Graceful degradation when MAGG is unavailable
  - Circuit breaker pattern for external dependencies
  - Optional startup based on configuration
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(init_arg) do
    # Check if MCP should be disabled entirely
    disable_mcp = Application.get_env(:vsm_phoenix, :disable_mcp_servers, false)
    
    if disable_mcp do
      Logger.info("MCP Supervisor: MCP servers disabled by configuration")
      :ignore
    else
      # Check for bulletproof mode
      use_bulletproof = Application.get_env(:vsm_phoenix, :bulletproof_mcp, true)
      
      children = [
        # Registry for External MCP Clients
        {Registry, keys: :unique, name: VsmPhoenix.MCP.ExternalClientRegistry},
        
        # MCP Server Registry
        {VsmPhoenix.MCP.MCPRegistry, []},
        
        # Supervisor for External MCP Clients
        VsmPhoenix.MCP.ExternalClientSupervisor,
        
        # MAGG Integration Manager - use bulletproof version if enabled
        if use_bulletproof do
          {VsmPhoenix.MCP.BulletproofMaggIntegrationManager, [auto_connect: true]}
        else
          {VsmPhoenix.MCP.MaggIntegrationManager, [auto_connect: true]}
        end,
        
        # Start REAL Hermes STDIO Client that actually works
        {VsmPhoenix.MCP.HermesStdioClient, []},
        
        # Keep the old client for backward compatibility
        {VsmPhoenix.MCP.HermesClient, []},
        
        # CYBERNETIC HIVE MIND COMPONENTS
        # HiveMindServer is the primary MCP implementation
        # It provides VSM-to-VSM communication via stdio transport
        {VsmPhoenix.MCP.HiveMindServer, [discovery: true]},
        
        # Start VSM Spawner for recursive VSM creation
        {VsmPhoenix.Hive.Spawner, []},
        
        # Autonomous MCP Acquisition System
        VsmPhoenix.MCP.AcquisitionSupervisor
      ]
      
      # Filter out nil children
      children = Enum.filter(children, & &1)
      
      # Use rest_for_one strategy: if MAGG fails, restart everything after it
      # but don't affect components before it
      opts = [
        strategy: :rest_for_one,
        max_restarts: 10,
        max_seconds: 60,
        name: __MODULE__
      ]
      
      Logger.info("Starting MCP Supervisor with #{length(children)} children (bulletproof: #{use_bulletproof})")
      
      Supervisor.init(children, opts)
    end
  end
  
  @doc """
  Check if MCP supervisor is running and healthy.
  """
  def healthy? do
    case Process.whereis(__MODULE__) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
  
  @doc """
  Get status of all MCP components.
  """
  def status do
    if healthy?() do
      children = Supervisor.which_children(__MODULE__)
      
      Enum.map(children, fn {id, child, type, modules} ->
        status = case child do
          :undefined -> :not_started
          pid when is_pid(pid) -> 
            if Process.alive?(pid), do: :running, else: :dead
          :restarting -> :restarting
        end
        
        %{
          id: id,
          type: type,
          status: status,
          modules: modules
        }
      end)
    else
      :not_running
    end
  end
  
  @doc """
  Restart all MCP components.
  """
  def restart_all do
    if healthy?() do
      Logger.info("Restarting all MCP components...")
      
      # Get all children
      children = Supervisor.which_children(__MODULE__)
      
      # Terminate each child
      Enum.each(children, fn {id, _child, _type, _modules} ->
        Supervisor.terminate_child(__MODULE__, id)
      end)
      
      # Restart each child
      Enum.each(children, fn {id, _child, _type, _modules} ->
        Supervisor.restart_child(__MODULE__, id)
      end)
      
      :ok
    else
      {:error, :not_running}
    end
  end
  
  @doc """
  Stop a specific MCP component.
  """
  def stop_component(component_id) do
    if healthy?() do
      case Supervisor.terminate_child(__MODULE__, component_id) do
        :ok -> :ok
        {:error, :not_found} -> {:error, :component_not_found}
        error -> error
      end
    else
      {:error, :supervisor_not_running}
    end
  end
  
  @doc """
  Start a specific MCP component.
  """
  def start_component(component_id) do
    if healthy?() do
      case Supervisor.restart_child(__MODULE__, component_id) do
        {:ok, _child} -> :ok
        {:ok, _child, _info} -> :ok
        {:error, :not_found} -> {:error, :component_not_found}
        error -> error
      end
    else
      {:error, :supervisor_not_running}
    end
  end
end