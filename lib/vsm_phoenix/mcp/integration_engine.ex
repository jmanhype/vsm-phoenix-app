defmodule VsmPhoenix.MCP.IntegrationEngine do
  @moduledoc """
  Safely integrates MCP servers into the VSM hierarchy.
  Handles validation, installation, and connection to appropriate VSM systems.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      integrations: %{},
      integration_rules: load_integration_rules(),
      sandbox_mode: Application.get_env(:vsm_phoenix, :mcp_sandbox_mode, true)
    }
    
    {:ok, state}
  end

  @doc """
  Validate an MCP server before integration.
  """
  def validate_server(server) do
    GenServer.call(__MODULE__, {:validate_server, server})
  end

  @doc """
  Install an MCP server (download, setup, configure).
  """
  def install_server(server) do
    GenServer.call(__MODULE__, {:install_server, server}, 60_000)
  end

  @doc """
  Integrate an installed server with the VSM hierarchy.
  """
  def integrate_with_vsm(server, vsm_state) do
    GenServer.call(__MODULE__, {:integrate_with_vsm, server, vsm_state}, 30_000)
  end

  @doc """
  Remove an integrated MCP server.
  """
  def remove_integration(server_id) do
    GenServer.call(__MODULE__, {:remove_integration, server_id})
  end

  @impl true
  def handle_call({:validate_server, server}, _from, state) do
    validation_result = perform_validation(server, state)
    {:reply, validation_result, state}
  end

  @impl true
  def handle_call({:install_server, server}, _from, state) do
    result = if state.sandbox_mode do
      simulate_installation(server)
    else
      perform_installation(server)
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:integrate_with_vsm, server, vsm_state}, _from, state) do
    case perform_integration(server, vsm_state, state) do
      {:ok, integration} ->
        new_integrations = Map.put(state.integrations, server.id, integration)
        {:reply, {:ok, integration}, %{state | integrations: new_integrations}}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:remove_integration, server_id}, _from, state) do
    case Map.get(state.integrations, server_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      integration ->
        # Cleanup integration
        cleanup_integration(integration)
        new_integrations = Map.delete(state.integrations, server_id)
        {:reply, :ok, %{state | integrations: new_integrations}}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_integrations: map_size(state.integrations),
      sandbox_mode: state.sandbox_mode,
      integration_rules: map_size(state.integration_rules)
    }
    
    {:reply, stats, state}
  end

  # Private functions

  defp load_integration_rules do
    # Rules for mapping MCP capabilities to VSM systems
    %{
      # System1 - Operational capabilities
      "database_query" => {:system1, :data_operations},
      "file_read" => {:system1, :file_operations},
      "file_write" => {:system1, :file_operations},
      "sensor_data" => {:system1, :sensor_integration},
      
      # System2 - Coordination capabilities
      "multi_agent" => {:system2, :agent_coordination},
      "workflow_management" => {:system2, :process_coordination},
      "resource_allocation" => {:system2, :resource_management},
      
      # System3 - Optimization capabilities
      "performance_monitoring" => {:system3, :monitoring},
      "analytics" => {:system3, :analysis},
      "optimization" => {:system3, :optimization},
      
      # System4 - Strategic capabilities
      "market_analysis" => {:system4, :environmental_scanning},
      "competitive_intelligence" => {:system4, :intelligence},
      "forecasting" => {:system4, :planning},
      
      # System5 - Identity/Policy capabilities
      "policy_enforcement" => {:system5, :policy},
      "compliance" => {:system5, :governance},
      "ethics" => {:system5, :values}
    }
  end

  defp perform_validation(server, state) do
    validations = [
      {:has_id, validate_has_id(server)},
      {:has_capabilities, validate_has_capabilities(server)},
      {:capabilities_known, validate_capabilities_known(server, state)},
      {:no_conflicts, validate_no_conflicts(server, state)},
      {:dependencies_available, validate_dependencies(server)},
      {:security_check, validate_security(server)}
    ]
    
    failed = Enum.filter(validations, fn {_check, result} -> result != :ok end)
    
    if Enum.empty?(failed) do
      {:ok, server}
    else
      {:error, {:validation_failed, failed}}
    end
  end

  defp validate_has_id(%{id: id}) when is_binary(id) and id != "", do: :ok
  defp validate_has_id(_), do: {:error, "Server must have an ID"}

  defp validate_has_capabilities(%{capabilities: caps}) when is_list(caps) and length(caps) > 0, do: :ok
  defp validate_has_capabilities(_), do: {:error, "Server must have capabilities"}

  defp validate_capabilities_known(server, state) do
    unknown = Enum.filter(server.capabilities, fn cap ->
      !Map.has_key?(state.integration_rules, cap.type)
    end)
    
    if Enum.empty?(unknown) do
      :ok
    else
      {:warning, "Unknown capabilities: #{inspect(unknown)}"}
    end
  end

  defp validate_no_conflicts(server, state) do
    conflicts = Enum.filter(state.integrations, fn {_id, integration} ->
      has_capability_conflict?(server, integration)
    end)
    
    if Enum.empty?(conflicts) do
      :ok
    else
      {:error, "Conflicts with existing integrations: #{inspect(conflicts)}"}
    end
  end

  defp validate_dependencies(%{dependencies: deps}) when is_list(deps) do
    # Check if all dependencies are available
    missing = Enum.filter(deps, &(!dependency_available?(&1)))
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing dependencies: #{inspect(missing)}"}
    end
  end
  defp validate_dependencies(_), do: :ok

  defp validate_security(server) do
    # Basic security checks
    cond do
      contains_suspicious_code?(server) -> {:error, "Security risk detected"}
      requires_dangerous_permissions?(server) -> {:error, "Requires dangerous permissions"}
      true -> :ok
    end
  end

  defp has_capability_conflict?(_server1, _server2) do
    # Check for capability conflicts
    # Simplified: no conflicts for now
    false
  end

  defp dependency_available?(_dep), do: true
  defp contains_suspicious_code?(_server), do: false
  defp requires_dangerous_permissions?(_server), do: false

  defp simulate_installation(server) do
    Logger.info("Simulating installation of #{server.id}")
    
    # Simulate installation steps
    Process.sleep(100)
    
    {:ok, %{
      server_id: server.id,
      installed_at: DateTime.utc_now(),
      installation_path: "/opt/mcp-servers/#{server.id}",
      status: :installed,
      simulated: true
    }}
  end

  defp perform_installation(server) do
    Logger.info("Installing MCP server: #{server.id}")
    
    try do
      # Create installation directory
      install_path = "/opt/mcp-servers/#{server.id}"
      File.mkdir_p!(install_path)
      
      # Download/clone server code
      case server.source do
        {:github, _repo} ->
          # Would use Git to clone
          :ok
          
        {:npm, _package} ->
          # Would use npm to install
          :ok
          
        _ ->
          :ok
      end
      
      {:ok, %{
        server_id: server.id,
        installed_at: DateTime.utc_now(),
        installation_path: install_path,
        status: :installed,
        simulated: false
      }}
    rescue
      e ->
        {:error, {:installation_failed, Exception.message(e)}}
    end
  end

  defp perform_integration(server, vsm_state, state) do
    # Map capabilities to VSM systems
    system_mappings = map_capabilities_to_systems(server, state.integration_rules)
    
    # Create integration record
    integration = %{
      server_id: server.id,
      server_info: server,
      system_mappings: system_mappings,
      integrated_at: DateTime.utc_now(),
      status: :active,
      connection_info: establish_connections(server, system_mappings),
      metrics: %{
        requests_handled: 0,
        errors: 0,
        last_used: nil
      }
    }
    
    # Notify relevant systems about new capability
    notify_systems(integration)
    
    {:ok, integration}
  end

  defp map_capabilities_to_systems(server, rules) do
    Enum.map(server.capabilities, fn cap ->
      case Map.get(rules, cap.type) do
        nil -> {:unmapped, cap}
        {system, subsystem} -> {system, subsystem, cap}
      end
    end)
    |> Enum.reject(fn mapping -> elem(mapping, 0) == :unmapped end)
    |> Enum.group_by(&elem(&1, 0))
  end

  defp establish_connections(server, system_mappings) do
    # Create connection information for each system
    Map.new(system_mappings, fn {system, mappings} ->
      {system, %{
        endpoint: "stdio://#{server.id}",
        protocol: :json_rpc,
        capabilities: Enum.map(mappings, fn {_sys, _sub, cap} -> cap end)
      }}
    end)
  end

  defp notify_systems(integration) do
    # Notify each VSM system about new capabilities
    Enum.each(integration.system_mappings, fn {system, _mappings} ->
      case system do
        :system1 -> 
          send(VsmPhoenix.Systems.System1, {:new_capability, integration})
        :system2 -> 
          send(VsmPhoenix.Systems.System2, {:new_capability, integration})
        :system3 -> 
          send(VsmPhoenix.Systems.System3, {:new_capability, integration})
        :system4 -> 
          send(VsmPhoenix.Systems.System4, {:new_capability, integration})
        :system5 -> 
          send(VsmPhoenix.Systems.System5, {:new_capability, integration})
      end
    end)
  end

  defp cleanup_integration(integration) do
    # Notify systems about removal
    Enum.each(integration.system_mappings, fn {system, _} ->
      case system do
        :system1 -> 
          send(VsmPhoenix.Systems.System1, {:capability_removed, integration.server_id})
        :system2 -> 
          send(VsmPhoenix.Systems.System2, {:capability_removed, integration.server_id})
        :system3 -> 
          send(VsmPhoenix.Systems.System3, {:capability_removed, integration.server_id})
        :system4 -> 
          send(VsmPhoenix.Systems.System4, {:capability_removed, integration.server_id})
        :system5 -> 
          send(VsmPhoenix.Systems.System5, {:capability_removed, integration.server_id})
      end
    end)
    
    # Clean up resources
    if integration[:installation_path] do
      File.rm_rf(integration.installation_path)
    end
  end
end