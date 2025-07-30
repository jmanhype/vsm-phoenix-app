defmodule VsmPhoenix.MCP.DiscoveryEngine do
  @moduledoc """
  Discovery engine for finding and cataloging available MCP servers.
  Implements multiple discovery strategies to maximize variety acquisition.
  """

  require Logger
  alias VsmPhoenix.MCP.ServerCatalog

  @discovery_strategies [
    :magg_kits,          # MAGG kit discovery
    :npm_registry,       # NPM package search
    :github_search,      # GitHub repository discovery
    :local_filesystem,   # Local server discovery
    :network_discovery,  # Network-based discovery
    :registry_api       # Official MCP registry
  ]

  @doc """
  Run all discovery strategies to find available MCP servers
  """
  def discover_all(opts \\ []) do
    strategies = Keyword.get(opts, :strategies, @discovery_strategies)
    
    Logger.info("Starting MCP server discovery with strategies: #{inspect(strategies)}")
    
    results = 
      strategies
      |> Enum.map(&run_strategy/1)
      |> Enum.reduce(%{}, &merge_results/2)
    
    Logger.info("Discovery complete. Found #{map_size(results)} unique servers")
    results
  end

  @doc """
  Run a specific discovery strategy
  """
  def run_strategy(:magg_kits) do
    Logger.debug("Running MAGG kit discovery")
    
    case System.cmd("magg", ["kit", "list"], stderr_to_stdout: true) do
      {output, 0} ->
        servers = parse_magg_kits(output)
        Logger.info("Found #{length(servers)} servers from MAGG kits")
        Map.new(servers, fn server -> {server.id, server} end)
      
      {error, _} ->
        Logger.error("MAGG kit discovery failed: #{error}")
        %{}
    end
  end

  def run_strategy(:npm_registry) do
    Logger.debug("Running NPM registry discovery")
    
    search_terms = ["mcp server", "mcp-server", "model context protocol"]
    
    servers = 
      search_terms
      |> Enum.flat_map(&search_npm/1)
      |> Enum.uniq_by(& &1.id)
    
    Logger.info("Found #{length(servers)} servers from NPM")
    Map.new(servers, fn server -> {server.id, server} end)
  end

  def run_strategy(:github_search) do
    Logger.debug("Running GitHub discovery")
    
    repos = [
      "modelcontextprotocol/servers",
      "wong2/awesome-mcp-servers",
      "punkpeye/awesome-mcp-servers",
      "microsoft/mcp",
      "docker/mcp-servers"
    ]
    
    servers = 
      repos
      |> Enum.flat_map(&fetch_github_servers/1)
      |> Enum.uniq_by(& &1.id)
    
    Logger.info("Found #{length(servers)} servers from GitHub")
    Map.new(servers, fn server -> {server.id, server} end)
  end

  def run_strategy(:local_filesystem) do
    Logger.debug("Running local filesystem discovery")
    
    paths = [
      Path.join(System.user_home!(), ".mcp/servers"),
      "/usr/local/lib/mcp-servers",
      "./mcp-servers"
    ]
    
    servers = 
      paths
      |> Enum.filter(&File.exists?/1)
      |> Enum.flat_map(&scan_directory/1)
    
    Logger.info("Found #{length(servers)} local servers")
    Map.new(servers, fn server -> {server.id, server} end)
  end

  def run_strategy(:network_discovery) do
    Logger.debug("Running network discovery")
    # TODO: Implement mDNS/service discovery
    %{}
  end

  def run_strategy(:registry_api) do
    Logger.debug("Running registry API discovery")
    
    case fetch_from_registry() do
      {:ok, servers} ->
        Logger.info("Found #{length(servers)} servers from registry")
        Map.new(servers, fn server -> {server.id, server} end)
      
      {:error, reason} ->
        Logger.error("Registry discovery failed: #{reason}")
        %{}
    end
  end

  # Private functions

  defp merge_results(new_results, acc) do
    Map.merge(acc, new_results, fn _k, v1, v2 ->
      # Merge server info, preferring more complete data
      %{
        v1 | 
        capabilities: Enum.uniq(v1.capabilities ++ v2.capabilities),
        sources: Enum.uniq([v1.source | v2.sources] ++ [v2.source])
      }
    end)
  end

  defp parse_magg_kits(output) do
    # Parse MAGG kit output
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "•"))
    |> Enum.map(fn line ->
      case String.split(line, ":", parts: 2) do
        [name, description] ->
          %{
            id: String.trim(name) |> String.replace("•", "") |> String.trim(),
            name: String.trim(name) |> String.replace("•", "") |> String.trim(),
            description: String.trim(description),
            source: :magg,
            capabilities: [],
            install_command: "magg kit load #{String.trim(name)}",
            sources: [:magg]
          }
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp search_npm(query) do
    case System.cmd("npm", ["search", query, "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> Jason.decode()
        |> case do
          {:ok, packages} ->
            packages
            |> Enum.filter(&is_mcp_server?/1)
            |> Enum.map(&npm_to_server/1)
          _ -> []
        end
      _ -> []
    end
  rescue
    _ -> []
  end

  defp is_mcp_server?(package) do
    name = package["name"] || ""
    keywords = package["keywords"] || []
    description = package["description"] || ""
    
    String.contains?(name, "mcp") or
    Enum.any?(keywords, &String.contains?(&1, "mcp")) or
    String.contains?(description, "MCP") or
    String.contains?(description, "Model Context Protocol")
  end

  defp npm_to_server(package) do
    %{
      id: package["name"],
      name: package["name"],
      description: package["description"] || "",
      version: package["version"],
      source: :npm,
      capabilities: extract_capabilities(package),
      install_command: "npm install -g #{package["name"]}",
      sources: [:npm]
    }
  end

  defp extract_capabilities(package) do
    # Extract capabilities from keywords and description
    text = "#{package["description"]} #{Enum.join(package["keywords"] || [], " ")}"
    
    capabilities = []
    capabilities = if String.contains?(text, "file"), do: ["filesystem" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "git"), do: ["git" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "database"), do: ["database" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "api"), do: ["api" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "memory"), do: ["memory" | capabilities], else: capabilities
    
    Enum.uniq(capabilities)
  end

  defp fetch_github_servers(repo) do
    # TODO: Implement GitHub API calls to fetch server info
    # For now, return known servers from our research
    case repo do
      "modelcontextprotocol/servers" ->
        [
          %{
            id: "filesystem-mcp",
            name: "Filesystem MCP Server",
            description: "Secure file operations with configurable access controls",
            source: :github,
            capabilities: ["filesystem", "read", "write"],
            install_command: "npm install -g @modelcontextprotocol/server-filesystem",
            sources: [:github]
          },
          %{
            id: "git-mcp",
            name: "Git MCP Server",
            description: "Tools to read, search, and manipulate Git repositories",
            source: :github,
            capabilities: ["git", "version-control"],
            install_command: "npm install -g @modelcontextprotocol/server-git",
            sources: [:github]
          },
          %{
            id: "github-mcp",
            name: "GitHub MCP Server",
            description: "Repository management, file operations, and GitHub API integration",
            source: :github,
            capabilities: ["github", "api", "repository"],
            install_command: "npm install -g @modelcontextprotocol/server-github",
            sources: [:github]
          },
          %{
            id: "memory-mcp",
            name: "Memory MCP Server",
            description: "Knowledge graph-based persistent memory system",
            source: :github,
            capabilities: ["memory", "persistence", "knowledge-graph"],
            install_command: "npm install -g @modelcontextprotocol/server-memory",
            sources: [:github]
          }
        ]
      _ -> []
    end
  end

  defp scan_directory(path) do
    # TODO: Implement local directory scanning
    []
  end

  defp fetch_from_registry do
    # TODO: Implement official registry API calls
    {:error, "Registry API not yet implemented"}
  end
end