defmodule VsmPhoenix.BulletproofApplication do
  @moduledoc """
  Bulletproof VSM Phoenix Application with isolated MCP supervision.
  
  This version isolates MCP components in their own supervisor to prevent
  cascading failures when external dependencies like MAGG are unavailable.
  
  Key improvements:
  - MCP components in isolated supervisor
  - Core VSM systems protected from MCP failures
  - Graceful degradation when external tools unavailable
  - Clear separation of concerns
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Core children that must always run
    core_children = [
      # Start the Telemetry supervisor
      VsmPhoenixWeb.Telemetry,
      
      # Start the Ecto repository
      VsmPhoenix.Repo,
      
      # Start the PubSub system
      {Phoenix.PubSub, name: VsmPhoenix.PubSub},
      
      # Start the Endpoint (http/https)
      VsmPhoenixWeb.Endpoint,
      
      # Start Goldrush Telemetry for real event processing
      VsmPhoenix.Goldrush.Telemetry,
      
      # Start Goldrush Manager with plugins
      VsmPhoenix.Goldrush.Manager,
      
      # Start Hermes Server Registry first
      Hermes.Server.Registry
    ]
    
    # MCP components in isolated supervisor (optional)
    mcp_children = unless Application.get_env(:vsm_phoenix, :disable_mcp_servers, false) do
      [
        # All MCP components isolated in their own supervisor
        {VsmPhoenix.MCP.MCPSupervisor, []}
      ]
    else
      []
    end
    
    # VSM System Hierarchy (core business logic)
    vsm_children = [
      # System 5 - Queen Policy Governance (highest authority, starts first)
      VsmPhoenix.System5.Queen,
      
      # System 4 - Intelligence and Adaptation
      VsmPhoenix.System4.Intelligence,
      
      # System 3 - Control and Resource Management
      VsmPhoenix.System3.Control,
      
      # System 2 - Coordination (must start before System 1)
      VsmPhoenix.System2.Coordinator,
      
      # System 1 - Operational Contexts (depends on System 2)
      VsmPhoenix.System1.Operations,
      
      # Additional VSM components
      {VsmPhoenix.VsmSupervisor, []}
    ]
    
    # Optional Service Bus connector
    service_bus_children = if System.get_env("AZURE_SERVICE_BUS_NAMESPACE") do
      [VsmPhoenix.ServiceBus.Connector]
    else
      []
    end
    
    # Combine all children in order
    children = core_children ++ mcp_children ++ vsm_children ++ service_bus_children
    
    # Log startup configuration
    Logger.info("""
    Starting Bulletproof VSM Phoenix Application
    - Core services: #{length(core_children)}
    - MCP services: #{length(mcp_children)} #{if mcp_children == [], do: "(disabled)", else: "(isolated)"}
    - VSM systems: #{length(vsm_children)}
    - Service Bus: #{if service_bus_children == [], do: "disabled", else: "enabled"}
    - Bulletproof MCP: #{Application.get_env(:vsm_phoenix, :bulletproof_mcp, true)}
    """)

    # Use one_for_one strategy - each child failure is isolated
    opts = [strategy: :one_for_one, name: VsmPhoenix.Supervisor]
    
    result = Supervisor.start_link(children, opts)
    
    # Log successful startup
    case result do
      {:ok, _pid} ->
        Logger.info("VSM Phoenix Application started successfully")
        
        # Check MCP health after startup
        if length(mcp_children) > 0 do
          Process.send_after(self(), :check_mcp_health, 5_000)
        end
        
      error ->
        Logger.error("Failed to start VSM Phoenix Application: #{inspect(error)}")
    end
    
    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VsmPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
  
  @doc """
  Check if MCP components are healthy and log status.
  """
  def check_mcp_health do
    Task.start(fn ->
      Process.sleep(5_000)
      
      if VsmPhoenix.MCP.MCPSupervisor.healthy?() do
        status = VsmPhoenix.MCP.MCPSupervisor.status()
        Logger.info("MCP Supervisor health check: #{inspect(status)}")
        
        # Check MAGG availability specifically
        if function_exported?(VsmPhoenix.MCP.BulletproofMaggIntegrationManager, :magg_available?, 0) do
          magg_available = VsmPhoenix.MCP.BulletproofMaggIntegrationManager.magg_available?()
          Logger.info("MAGG availability: #{magg_available}")
        end
      else
        Logger.warning("MCP Supervisor is not running - MCP features unavailable")
      end
    end)
  end
end