defmodule VsmPhoenix.MCP.MCPRegistry do
  @moduledoc """
  Registry of available MCP servers and their capabilities.
  Discovers, catalogs, and tracks MCP servers that can be integrated.
  """

  use GenServer
  require Logger

  @discovery_interval 60_000  # Discover new servers every minute

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      servers: %{},
      capabilities_index: %{},
      discovery_sources: [
        # Known MCP server sources
        {:github, "modelcontextprotocol/servers"},
        {:npm, "@modelcontextprotocol"},
        {:local, "./mcp-servers"},
        {:community, "https://mcp-registry.anthropic.com"}
      ]
    }
    
    # Schedule first discovery
    Process.send_after(self(), :discover_servers, 1000)
    
    {:ok, state}
  end

  @doc """
  Search for MCP servers that provide a specific capability.
  """
  def search_by_capability(capability) do
    GenServer.call(__MODULE__, {:search_by_capability, capability})
  end

  @doc """
  Get information about a specific MCP server.
  """
  def get_server(server_id) do
    GenServer.call(__MODULE__, {:get_server, server_id})
  end

  @doc """
  List all discovered MCP servers.
  """
  def list_servers do
    GenServer.call(__MODULE__, :list_servers)
  end

  @doc """
  List currently active/integrated servers.
  """
  def list_active_servers do
    GenServer.call(__MODULE__, :list_active_servers)
  end

  @doc """
  Register a new MCP server discovery.
  """
  def register_server(server_info) do
    GenServer.cast(__MODULE__, {:register_server, server_info})
  end

  @impl true
  def handle_call({:search_by_capability, capability}, _from, state) do
    matching_servers = case Map.get(state.capabilities_index, capability) do
      nil -> []
      server_ids ->
        Enum.map(server_ids, fn id -> Map.get(state.servers, id) end)
        |> Enum.filter(& &1)
    end
    
    {:reply, matching_servers, state}
  end

  @impl true
  def handle_call({:get_server, server_id}, _from, state) do
    {:reply, Map.get(state.servers, server_id), state}
  end

  @impl true
  def handle_call(:list_servers, _from, state) do
    servers = Map.values(state.servers)
    {:reply, servers, state}
  end

  @impl true
  def handle_call(:list_active_servers, _from, state) do
    active_servers = state.servers
    |> Map.values()
    |> Enum.filter(& &1.status == :active)
    
    {:reply, active_servers, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_servers: map_size(state.servers),
      active_servers: Enum.count(state.servers, fn {_id, s} -> s.status == :active end),
      total_capabilities: map_size(state.capabilities_index),
      discovery_sources: length(state.discovery_sources)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:register_server, server_info}, state) do
    # Validate and normalize server info
    server = normalize_server_info(server_info)
    
    # Update servers map
    new_servers = Map.put(state.servers, server.id, server)
    
    # Update capabilities index
    new_index = update_capabilities_index(state.capabilities_index, server)
    
    new_state = %{state | servers: new_servers, capabilities_index: new_index}
    
    Logger.info("Registered MCP server: #{server.id} with #{length(server.capabilities)} capabilities")
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:discover_servers, state) do
    # Discover servers from various sources
    Task.async_stream(state.discovery_sources, &discover_from_source/1,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.each(fn
      {:ok, servers} when is_list(servers) ->
        Enum.each(servers, &register_server/1)
      _ -> :ok
    end)
    
    # Schedule next discovery
    Process.send_after(self(), :discover_servers, @discovery_interval)
    
    {:noreply, state}
  end

  # Private functions

  defp normalize_server_info(info) do
    %{
      id: info[:id] || generate_server_id(info),
      name: info[:name] || "Unknown MCP Server",
      description: info[:description] || "",
      version: info[:version] || "0.0.0",
      capabilities: normalize_capabilities(info[:capabilities] || []),
      source: info[:source] || :unknown,
      repository: info[:repository],
      dependencies: info[:dependencies] || [],
      status: :discovered,
      discovered_at: DateTime.utc_now(),
      metadata: info[:metadata] || %{}
    }
  end

  defp generate_server_id(info) do
    base = info[:name] || "mcp_server"
    "#{base}_#{:erlang.phash2(info)}"
  end

  defp normalize_capabilities(capabilities) when is_list(capabilities) do
    Enum.map(capabilities, fn cap ->
      case cap do
        %{type: type} = capability -> capability
        type when is_binary(type) -> %{type: type, description: ""}
        type when is_atom(type) -> %{type: to_string(type), description: ""}
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end
  defp normalize_capabilities(_), do: []

  defp update_capabilities_index(index, server) do
    Enum.reduce(server.capabilities, index, fn cap, acc ->
      Map.update(acc, cap.type, [server.id], fn existing ->
        if server.id in existing do
          existing
        else
          [server.id | existing]
        end
      end)
    end)
  end

  defp discover_from_source({:github, repo}) do
    # Discover from GitHub repository
    Logger.info("Discovering MCP servers from GitHub: #{repo}")
    
    # Simulated discovery - in real implementation, would use GitHub API
    [
      %{
        id: "github_sqlite",
        name: "SQLite MCP Server",
        description: "MCP server for SQLite database operations",
        source: {:github, repo},
        repository: "https://github.com/#{repo}/sqlite",
        capabilities: [
          %{type: "database_query", description: "Execute SQL queries"},
          %{type: "database_schema", description: "Manage database schema"}
        ]
      },
      %{
        id: "github_filesystem",
        name: "Filesystem MCP Server",
        description: "MCP server for file system operations",
        source: {:github, repo},
        repository: "https://github.com/#{repo}/filesystem",
        capabilities: [
          %{type: "file_read", description: "Read files"},
          %{type: "file_write", description: "Write files"},
          %{type: "directory_list", description: "List directory contents"}
        ]
      }
    ]
  end

  defp discover_from_source({:npm, scope}) do
    # Discover from NPM registry
    Logger.info("Discovering MCP servers from NPM: #{scope}")
    
    # Simulated discovery
    [
      %{
        id: "npm_web_search",
        name: "Web Search MCP",
        description: "MCP server for web search capabilities",
        source: {:npm, scope},
        capabilities: [
          %{type: "web_search", description: "Search the web"},
          %{type: "web_scrape", description: "Scrape web pages"}
        ]
      }
    ]
  end

  defp discover_from_source({:local, path}) do
    # Discover from local directory
    Logger.info("Discovering MCP servers from local: #{path}")
    []  # Would scan local directory in real implementation
  end

  defp discover_from_source({:community, url}) do
    # Discover from community registry
    Logger.info("Discovering MCP servers from community: #{url}")
    
    # Simulated discovery
    [
      %{
        id: "community_github_api",
        name: "GitHub API MCP",
        description: "MCP server for GitHub API operations",
        source: {:community, url},
        capabilities: [
          %{type: "github_repos", description: "Manage GitHub repositories"},
          %{type: "github_issues", description: "Manage GitHub issues"},
          %{type: "github_prs", description: "Manage pull requests"}
        ]
      },
      %{
        id: "community_slack",
        name: "Slack MCP",
        description: "MCP server for Slack integration",
        source: {:community, url},
        capabilities: [
          %{type: "slack_messages", description: "Send and receive Slack messages"},
          %{type: "slack_channels", description: "Manage Slack channels"}
        ]
      }
    ]
  end
end