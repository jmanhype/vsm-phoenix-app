defmodule VsmPhoenix.Application do
  @moduledoc """
  VSM Phoenix Application
  
  Bootstraps the complete Viable Systems Model hierarchy:
  - System 5: Queen (Policy and Identity)
  - System 4: Intelligence (Environment and Adaptation)
  - System 3: Control (Resource Management)
  - System 2: Coordinator (Anti-oscillation)
  - System 1: Operations (Operational Contexts)
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Check if MCP servers should be disabled
    disable_mcp = Application.get_env(:vsm_phoenix, :disable_mcp_servers, false)
    
    base_children = [
      # Start the Telemetry supervisor
      VsmPhoenixWeb.Telemetry,
      
      # Start the Ecto repository
      # VsmPhoenix.Repo, # Temporarily disabled due to Postgrex issues
      
      # Start the PubSub system
      {Phoenix.PubSub, name: VsmPhoenix.PubSub},
      
      # Start the Endpoint (http/https)
      VsmPhoenixWeb.Endpoint,
      
      # Start Goldrush Telemetry for real event processing
      VsmPhoenix.Goldrush.Telemetry,
      
      # Start Goldrush Manager with plugins
      VsmPhoenix.Goldrush.Manager,
      
      # Start Hermes Server Registry first
      Hermes.Server.Registry,
      
      # Conditionally start MCP servers
    ] ++ if disable_mcp do
      []
    else
      [
        # Registry for External MCP Clients
        {Registry, keys: :unique, name: VsmPhoenix.MCP.ExternalClientRegistry},
        
        # MCP Server Registry
        {VsmPhoenix.MCP.MCPRegistry, []},
        
        # Supervisor for External MCP Clients
        VsmPhoenix.MCP.ExternalClientSupervisor,
        
        # MAGG Integration Manager for discovering and managing external MCP servers
        # Only start if MAGG is enabled and available
      ] ++ if Application.get_env(:vsm_phoenix, :disable_magg, false) do
        []
      else
        [{VsmPhoenix.MCP.MaggIntegrationManager, [auto_connect: false]}]
      end ++ [
        
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
    end ++ [
      
      # VSM System Hierarchy (start from top down for proper dependencies)
      
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
    
    # Add Service Bus connector if configured
    children = if System.get_env("AZURE_SERVICE_BUS_NAMESPACE") do
      base_children ++ [VsmPhoenix.ServiceBus.Connector]
    else
      base_children
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: VsmPhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VsmPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end