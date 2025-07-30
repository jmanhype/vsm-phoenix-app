defmodule VsmPhoenix.MCP.MaggIntegration do
  @moduledoc """
  High-level integration module for MAGG-based MCP server discovery and management.
  
  This module provides the main interface for VSM to discover and integrate
  external MCP servers for variety acquisition.
  """

  require Logger

  alias VsmPhoenix.MCP.{MaggWrapper, ExternalClient, ExternalClientSupervisor}

  @doc """
  Discover MCP servers based on a capability need.
  
  ## Examples
  
      iex> VsmPhoenix.MCP.MaggIntegration.discover_servers("weather API")
      {:ok, [
        %{
          "name" => "@modelcontextprotocol/server-weather",
          "description" => "Weather data via MCP",
          "tools" => ["get_weather", "get_forecast"]
        }
      ]}
  """
  def discover_servers(capability_need) do
    Logger.info("Discovering MCP servers for capability: #{capability_need}")
    
    with {:ok, servers} <- MaggWrapper.search_servers(query: capability_need, limit: 20) do
      # Enrich with tool information if possible
      enriched_servers = Enum.map(servers, fn server ->
        case get_server_tools(server["name"]) do
          {:ok, tools} ->
            Map.put(server, "tools", tools)
          _ ->
            server
        end
      end)
      
      {:ok, enriched_servers}
    end
  end

  @doc """
  Add and connect to an MCP server.
  
  ## Examples
  
      iex> VsmPhoenix.MCP.MaggIntegration.add_and_connect("@modelcontextprotocol/server-weather")
      {:ok, %{
        "server" => "@modelcontextprotocol/server-weather",
        "status" => "connected",
        "tools" => ["get_weather", "get_forecast"]
      }}
  """
  def add_and_connect(server_name) do
    Logger.info("Adding and connecting to MCP server: #{server_name}")
    
    with {:ok, _config} <- MaggWrapper.add_server(server_name),
         {:ok, _pid} <- ExternalClientSupervisor.start_client(server_name),
         :ok <- wait_for_connection(server_name),
         {:ok, tools} <- ExternalClient.list_tools(server_name) do
      
      {:ok, %{
        "server" => server_name,
        "status" => "connected",
        "tools" => Enum.map(tools, & &1["name"])
      }}
    else
      error ->
        Logger.error("Failed to add and connect to #{server_name}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Execute a tool on an external MCP server.
  
  ## Examples
  
      iex> VsmPhoenix.MCP.MaggIntegration.execute_external_tool(
      ...>   "@modelcontextprotocol/server-weather",
      ...>   "get_weather",
      ...>   %{"location" => "London"}
      ...> )
      {:ok, %{"temperature" => 15, "conditions" => "cloudy"}}
  """
  def execute_external_tool(server_name, tool_name, params \\ %{}) do
    Logger.info("Executing tool #{tool_name} on #{server_name}")
    
    case ExternalClient.execute_tool(server_name, tool_name, params) do
      {:ok, result} ->
        {:ok, result}
      
      {:error, :client_not_started} ->
        # Try to start the client and retry
        with {:ok, _} <- ExternalClientSupervisor.start_client(server_name),
             :ok <- wait_for_connection(server_name) do
          ExternalClient.execute_tool(server_name, tool_name, params)
        else
          _ -> {:error, :connection_failed}
        end
      
      error ->
        error
    end
  end

  @doc """
  List all connected external MCP servers and their tools.
  """
  def list_connected_servers do
    clients = ExternalClientSupervisor.list_clients()
    
    Enum.map(clients, fn {server_name, status} ->
      tools = case ExternalClient.list_tools(server_name) do
        {:ok, tools} -> Enum.map(tools, & &1["name"])
        _ -> []
      end
      
      %{
        "server" => server_name,
        "status" => status.status,
        "transport" => status.transport,
        "tools" => tools
      }
    end)
  end

  @doc """
  Search for servers that provide specific tools.
  
  ## Examples
  
      iex> VsmPhoenix.MCP.MaggIntegration.find_servers_with_tool("get_weather")
      {:ok, ["@modelcontextprotocol/server-weather"]}
  """
  def find_servers_with_tool(tool_name) do
    with {:ok, all_tools} <- MaggWrapper.get_tools() do
      servers = Enum.reduce(all_tools, [], fn {server, tools}, acc ->
        if Enum.any?(tools, fn tool -> tool["name"] == tool_name end) do
          [server | acc]
        else
          acc
        end
      end)
      
      {:ok, servers}
    end
  end

  @doc """
  Automatically discover and connect servers based on capability gaps.
  
  This is the main entry point for autonomous variety acquisition.
  """
  def acquire_variety_for_capability(capability_description) do
    Logger.info("Acquiring variety for capability: #{capability_description}")
    
    with {:ok, servers} <- discover_servers(capability_description),
         {:ok, selected_server} <- select_best_server(servers, capability_description),
         {:ok, connection_info} <- add_and_connect(selected_server["name"]) do
      
      Logger.info("Successfully acquired variety via #{selected_server["name"]}")
      
      {:ok, %{
        capability: capability_description,
        server: connection_info,
        tools: connection_info["tools"]
      }}
    end
  end

  @doc """
  Remove an external MCP server and disconnect the client.
  """
  def remove_server(server_name) do
    Logger.info("Removing MCP server: #{server_name}")
    
    # Stop the client first
    ExternalClientSupervisor.stop_client(server_name)
    
    # Remove from MAGG configuration
    MaggWrapper.remove_server(server_name)
  end

  @doc """
  Get detailed information about a connected server.
  """
  def get_server_info(server_name) do
    with {:ok, config} <- MaggWrapper.get_server_config(server_name),
         {:ok, status} <- ExternalClient.get_status(server_name),
         {:ok, tools} <- ExternalClient.list_tools(server_name) do
      
      {:ok, %{
        "config" => config,
        "status" => status,
        "tools" => tools
      }}
    end
  end

  # Private functions

  defp get_server_tools(server_name) do
    case MaggWrapper.get_tools(server: server_name) do
      {:ok, tools_map} ->
        tools = Map.get(tools_map, server_name, [])
        {:ok, Enum.map(tools, & &1["name"])}
      _ ->
        {:error, :tools_not_available}
    end
  end

  defp wait_for_connection(server_name, timeout \\ 10_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    
    wait_loop(server_name, deadline)
  end

  defp wait_loop(server_name, deadline) do
    case ExternalClient.get_status(server_name) do
      {:ok, %{status: :connected}} ->
        :ok
      
      _ ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(500)
          wait_loop(server_name, deadline)
        else
          {:error, :connection_timeout}
        end
    end
  end

  defp select_best_server(servers, capability_description) do
    # Simple selection strategy - can be enhanced with more sophisticated scoring
    scored_servers = Enum.map(servers, fn server ->
      score = calculate_server_score(server, capability_description)
      {score, server}
    end)
    
    case Enum.sort_by(scored_servers, &elem(&1, 0), :desc) do
      [{_score, best_server} | _] ->
        {:ok, best_server}
      
      [] ->
        {:error, :no_suitable_servers}
    end
  end

  defp calculate_server_score(server, capability_description) do
    # Score based on various factors
    base_score = 0
    
    # Check description relevance
    description_score = if String.contains?(
      String.downcase(server["description"] || ""), 
      String.downcase(capability_description)
    ), do: 50, else: 0
    
    # Check if server has tools
    tools_score = length(server["tools"] || []) * 10
    
    # Prefer official servers
    official_score = if String.starts_with?(server["name"], "@modelcontextprotocol/"), 
      do: 20, else: 0
    
    base_score + description_score + tools_score + official_score
  end
end