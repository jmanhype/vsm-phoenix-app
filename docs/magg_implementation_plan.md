# MAGG Implementation Plan for VSM Phoenix

## Executive Summary

This document outlines the complete implementation plan to replace VSM Phoenix's hardcoded MCP discovery with real discovery capabilities based on MAGG's approach. The implementation will enable VSM to dynamically discover and integrate external MCP servers, providing true variety acquisition through multiple discovery strategies.

## 1. Module Architecture

### 1.1 Current State Analysis

The current implementation has:
- **MCPRegistry**: Hardcoded mock servers, no real discovery
- **DiscoveryEngine**: Partially implemented strategies, mostly stubs
- **ExternalClient**: Functional stdio/HTTP transport layer
- **MaggWrapper**: Basic CLI integration, limited functionality

### 1.2 Target Architecture

```elixir
# New module hierarchy
VsmPhoenix.MCP
├── Discovery
│   ├── Engine         # Orchestrates all discovery strategies
│   ├── NPMStrategy    # Real NPM registry search
│   ├── GitHubStrategy # GitHub API integration
│   ├── MaggStrategy   # MAGG kit discovery
│   ├── LocalStrategy  # Filesystem scanning
│   └── Cache          # Discovery result caching
├── Registry
│   ├── ServerRegistry # Replaces MCPRegistry with real data
│   ├── ToolIndex      # Tool capability indexing
│   └── Persistence    # ETS/DETS for fast access
├── Integration
│   ├── MaggWrapper    # Enhanced MAGG CLI integration
│   ├── ExternalClient # Existing, minimal changes
│   └── Supervisor     # Dynamic client supervision
└── Coordination
    ├── LoadBalancer   # Distribute tool calls
    ├── HealthMonitor  # Server health tracking
    └── Failover       # Automatic failover logic
```

### 1.3 Supervision Tree Changes

```elixir
defmodule VsmPhoenix.MCP.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Core registries
      {VsmPhoenix.MCP.Registry.ServerRegistry, []},
      {VsmPhoenix.MCP.Registry.ToolIndex, []},
      
      # Discovery engine
      {VsmPhoenix.MCP.Discovery.Engine, []},
      {VsmPhoenix.MCP.Discovery.Cache, []},
      
      # Dynamic supervisor for external clients
      {DynamicSupervisor, name: VsmPhoenix.MCP.ExternalClientSupervisor, strategy: :one_for_one},
      
      # Coordination services
      {VsmPhoenix.MCP.Coordination.HealthMonitor, []},
      {VsmPhoenix.MCP.Coordination.LoadBalancer, []},
      
      # Registry for client processes
      {Registry, keys: :unique, name: VsmPhoenix.MCP.ExternalClientRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
```

## 2. Discovery Strategies Implementation

### 2.1 NPM Search Implementation

```elixir
defmodule VsmPhoenix.MCP.Discovery.NPMStrategy do
  @moduledoc """
  Discovers MCP servers from NPM registry using real API calls.
  """
  
  require Logger
  alias HTTPoison
  
  @npm_registry "https://registry.npmjs.org"
  @search_endpoint "/-/v1/search"
  @batch_size 250
  
  def discover(opts \\ []) do
    search_terms = opts[:search_terms] || default_search_terms()
    
    search_terms
    |> Task.async_stream(&search_npm/1, max_concurrency: 3, timeout: 30_000)
    |> Stream.map(&handle_search_result/1)
    |> Stream.concat()
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&enrich_package_info/1)
  end
  
  defp search_npm(query) do
    params = %{
      text: query,
      size: @batch_size,
      quality: 0.65,
      popularity: 0.98,
      maintenance: 0.5
    }
    
    url = "#{@npm_registry}#{@search_endpoint}?#{URI.encode_query(params)}"
    
    case HTTPoison.get(url, [{"Accept", "application/json"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode!(body)
        |> Map.get("objects", [])
        |> Enum.filter(&is_mcp_server?/1)
        |> Enum.map(&parse_npm_package/1)
      
      {:error, reason} ->
        Logger.error("NPM search failed: #{inspect(reason)}")
        []
    end
  end
  
  defp is_mcp_server?(package) do
    pkg = package["package"]
    name = pkg["name"] || ""
    keywords = pkg["keywords"] || []
    description = pkg["description"] || ""
    
    # Enhanced detection logic
    mcp_indicators = [
      String.contains?(name, "mcp"),
      String.contains?(name, "@modelcontextprotocol"),
      "mcp" in keywords,
      "model-context-protocol" in keywords,
      String.contains?(description, "MCP"),
      String.contains?(description, "Model Context Protocol")
    ]
    
    Enum.any?(mcp_indicators)
  end
  
  defp parse_npm_package(npm_data) do
    pkg = npm_data["package"]
    
    %{
      id: pkg["name"],
      name: pkg["name"],
      description: pkg["description"] || "",
      version: pkg["version"],
      source: :npm,
      npm_data: %{
        publisher: pkg["publisher"],
        maintainers: pkg["maintainers"],
        repository: get_in(pkg, ["links", "repository"]),
        homepage: get_in(pkg, ["links", "homepage"]),
        keywords: pkg["keywords"] || []
      },
      capabilities: extract_capabilities(pkg),
      install_command: "npm install -g #{pkg["name"]}",
      score: npm_data["score"]
    }
  end
  
  defp extract_capabilities(package) do
    # Intelligent capability extraction
    text = "#{package["description"]} #{Enum.join(package["keywords"] || [], " ")}"
    
    capability_map = %{
      "filesystem" => ["file", "fs", "directory", "folder"],
      "database" => ["db", "sql", "postgres", "mysql", "sqlite"],
      "api" => ["api", "rest", "graphql", "http"],
      "git" => ["git", "version", "repo"],
      "github" => ["github", "gh"],
      "memory" => ["memory", "cache", "store"],
      "search" => ["search", "find", "query"],
      "browser" => ["browser", "web", "puppeteer", "playwright"],
      "slack" => ["slack"],
      "docker" => ["docker", "container"],
      "kubernetes" => ["k8s", "kubernetes"],
      "aws" => ["aws", "s3", "lambda"],
      "azure" => ["azure"],
      "gcp" => ["google cloud", "gcp"]
    }
    
    Enum.reduce(capability_map, [], fn {capability, keywords}, acc ->
      if Enum.any?(keywords, &String.contains?(String.downcase(text), &1)) do
        [capability | acc]
      else
        acc
      end
    end)
  end
  
  defp enrich_package_info(package) do
    # Fetch additional info from NPM registry
    case fetch_package_details(package.id) do
      {:ok, details} ->
        Map.merge(package, %{
          readme: details["readme"],
          latest_version: get_in(details, ["dist-tags", "latest"]),
          repository_url: get_in(details, ["repository", "url"])
        })
      
      _ ->
        package
    end
  end
  
  defp fetch_package_details(package_name) do
    url = "#{@npm_registry}/#{URI.encode(package_name)}"
    
    case HTTPoison.get(url, [], recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      _ ->
        {:error, :fetch_failed}
    end
  end
  
  defp default_search_terms do
    [
      "mcp server",
      "mcp-server", 
      "@modelcontextprotocol",
      "model context protocol",
      "model-context-protocol server"
    ]
  end
  
  defp handle_search_result({:ok, results}), do: results
  defp handle_search_result(_), do: []
end
```

### 2.2 GitHub API Integration

```elixir
defmodule VsmPhoenix.MCP.Discovery.GitHubStrategy do
  @moduledoc """
  Discovers MCP servers from GitHub repositories using the GitHub API.
  """
  
  require Logger
  alias HTTPoison
  
  @github_api "https://api.github.com"
  @known_repos [
    "modelcontextprotocol/servers",
    "wong2/awesome-mcp-servers",
    "punkpeye/awesome-mcp-servers",
    "microsoft/mcp",
    "docker/mcp-servers"
  ]
  
  def discover(opts \\ []) do
    token = opts[:github_token] || System.get_env("GITHUB_TOKEN")
    
    tasks = [
      Task.async(fn -> search_repositories(token) end),
      Task.async(fn -> scan_known_repos(token) end),
      Task.async(fn -> search_topics(token) end)
    ]
    
    tasks
    |> Task.await_many(30_000)
    |> List.flatten()
    |> Enum.uniq_by(& &1.id)
  end
  
  defp search_repositories(token) do
    query = "mcp server in:name,description,readme language:typescript language:javascript"
    
    case github_search("/search/repositories", query, token) do
      {:ok, results} ->
        results["items"]
        |> Enum.filter(&is_mcp_server_repo?/1)
        |> Enum.map(&parse_github_repo/1)
      
      _ ->
        []
    end
  end
  
  defp scan_known_repos(token) do
    @known_repos
    |> Task.async_stream(&scan_repo(&1, token), max_concurrency: 3)
    |> Enum.flat_map(fn
      {:ok, servers} -> servers
      _ -> []
    end)
  end
  
  defp scan_repo(repo_path, token) do
    case fetch_repo_contents(repo_path, token) do
      {:ok, contents} ->
        parse_repo_servers(repo_path, contents)
      _ ->
        []
    end
  end
  
  defp fetch_repo_contents(repo_path, token) do
    headers = build_headers(token)
    
    # First, try to get the repo structure
    case HTTPoison.get("#{@github_api}/repos/#{repo_path}/contents", headers) do
      {:ok, %{status_code: 200, body: body}} ->
        contents = Jason.decode!(body)
        
        # For "awesome" lists, fetch README
        if String.contains?(repo_path, "awesome") do
          fetch_readme(repo_path, token)
        else
          # For server repos, analyze directory structure
          {:ok, contents}
        end
      
      _ ->
        {:error, :fetch_failed}
    end
  end
  
  defp fetch_readme(repo_path, token) do
    headers = build_headers(token)
    
    case HTTPoison.get("#{@github_api}/repos/#{repo_path}/readme", headers) do
      {:ok, %{status_code: 200, body: body}} ->
        readme = Jason.decode!(body)
        content = Base.decode64!(readme["content"])
        {:ok, parse_awesome_list(content)}
      
      _ ->
        {:error, :readme_fetch_failed}
    end
  end
  
  defp parse_awesome_list(readme_content) do
    # Parse markdown to extract server listings
    readme_content
    |> String.split("\n")
    |> Enum.reduce({[], nil}, fn line, {servers, current_category} ->
      cond do
        # Category header
        String.match?(line, ~r/^##\s+[^#]/) ->
          category = String.replace(line, ~r/^##\s+/, "") |> String.trim()
          {servers, category}
        
        # Server entry
        String.match?(line, ~r/^\s*[-*]\s*\[/) ->
          case parse_server_line(line, current_category) do
            nil -> {servers, current_category}
            server -> {[server | servers], current_category}
          end
        
        true ->
          {servers, current_category}
      end
    end)
    |> elem(0)
  end
  
  defp parse_server_line(line, category) do
    # Parse markdown link format: - [Name](url) - Description
    case Regex.run(~r/\[([^\]]+)\]\(([^)]+)\)\s*[-–]\s*(.*)/, line) do
      [_, name, url, description] ->
        %{
          id: generate_id_from_url(url),
          name: String.trim(name),
          description: String.trim(description),
          source: :github,
          category: category,
          repository_url: url,
          capabilities: extract_capabilities_from_text(description),
          install_command: infer_install_command(url, name)
        }
      
      _ ->
        nil
    end
  end
  
  defp search_topics(token) do
    topics = ["mcp-server", "model-context-protocol", "mcp-tools"]
    
    topics
    |> Task.async_stream(&search_by_topic(&1, token))
    |> Enum.flat_map(fn
      {:ok, results} -> results
      _ -> []
    end)
  end
  
  defp search_by_topic(topic, token) do
    query = "topic:#{topic}"
    
    case github_search("/search/repositories", query, token) do
      {:ok, results} ->
        results["items"]
        |> Enum.map(&parse_github_repo/1)
      
      _ ->
        []
    end
  end
  
  defp github_search(endpoint, query, token) do
    headers = build_headers(token)
    params = %{q: query, per_page: 100, sort: "stars"}
    url = "#{@github_api}#{endpoint}?#{URI.encode_query(params)}"
    
    case HTTPoison.get(url, headers, recv_timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      
      {:ok, %{status_code: 403}} ->
        Logger.error("GitHub API rate limit exceeded")
        {:error, :rate_limited}
      
      error ->
        Logger.error("GitHub search failed: #{inspect(error)}")
        {:error, :search_failed}
    end
  end
  
  defp build_headers(nil), do: [{"Accept", "application/vnd.github.v3+json"}]
  defp build_headers(token) do
    [
      {"Accept", "application/vnd.github.v3+json"},
      {"Authorization", "token #{token}"}
    ]
  end
  
  defp is_mcp_server_repo?(repo) do
    name = repo["name"] || ""
    description = repo["description"] || ""
    topics = repo["topics"] || []
    
    String.contains?(name, "mcp") or
    String.contains?(description, "MCP") or
    String.contains?(description, "Model Context Protocol") or
    Enum.any?(topics, &String.contains?(&1, "mcp"))
  end
  
  defp parse_github_repo(repo) do
    %{
      id: "github_#{repo["owner"]["login"]}_#{repo["name"]}",
      name: repo["name"],
      description: repo["description"] || "",
      source: :github,
      github_data: %{
        owner: repo["owner"]["login"],
        stars: repo["stargazers_count"],
        language: repo["language"],
        topics: repo["topics"] || [],
        url: repo["html_url"],
        clone_url: repo["clone_url"]
      },
      capabilities: extract_capabilities_from_repo(repo),
      install_command: infer_install_command(repo["html_url"], repo["name"])
    }
  end
  
  defp extract_capabilities_from_repo(repo) do
    text = "#{repo["name"]} #{repo["description"]} #{Enum.join(repo["topics"] || [], " ")}"
    extract_capabilities_from_text(text)
  end
  
  defp extract_capabilities_from_text(text) do
    text = String.downcase(text)
    
    capabilities = []
    capabilities = if String.contains?(text, "file"), do: ["filesystem" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "git"), do: ["git" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "github"), do: ["github" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "database"), do: ["database" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "memory"), do: ["memory" | capabilities], else: capabilities
    capabilities = if String.contains?(text, "search"), do: ["search" | capabilities], else: capabilities
    
    Enum.uniq(capabilities)
  end
  
  defp infer_install_command(url, name) do
    cond do
      String.contains?(url, "modelcontextprotocol/servers") ->
        "npm install -g @modelcontextprotocol/server-#{name}"
      
      String.contains?(name, "mcp-server-") ->
        "npm install -g #{name}"
      
      true ->
        "git clone #{url} && cd #{name} && npm install"
    end
  end
  
  defp generate_id_from_url(url) do
    url
    |> String.replace(~r/https?:\/\/github\.com\//, "")
    |> String.replace("/", "_")
    |> String.downcase()
  end
  
  defp parse_repo_servers(repo_path, contents) when is_list(contents) do
    # For official server repos, each directory might be a server
    contents
    |> Enum.filter(& &1["type"] == "dir")
    |> Enum.map(fn dir ->
      %{
        id: "#{repo_path}_#{dir["name"]}",
        name: dir["name"],
        description: "MCP server from #{repo_path}",
        source: :github,
        repository_url: "https://github.com/#{repo_path}/tree/main/#{dir["name"]}",
        capabilities: infer_capabilities_from_name(dir["name"]),
        install_command: "npm install -g @modelcontextprotocol/server-#{dir["name"]}"
      }
    end)
  end
  
  defp parse_repo_servers(_, _), do: []
  
  defp infer_capabilities_from_name(name) do
    name = String.downcase(name)
    
    cond do
      String.contains?(name, "file") -> ["filesystem"]
      String.contains?(name, "git") -> ["git"]
      String.contains?(name, "db") or String.contains?(name, "sql") -> ["database"]
      String.contains?(name, "memory") -> ["memory"]
      true -> []
    end
  end
end
```

### 2.3 MAGG Kit Parsing

```elixir
defmodule VsmPhoenix.MCP.Discovery.MaggStrategy do
  @moduledoc """
  Discovers MCP servers through MAGG kit system.
  """
  
  require Logger
  alias VsmPhoenix.MCP.MaggWrapper
  
  def discover(_opts \\ []) do
    with {:ok, kits} <- discover_kits(),
         servers <- extract_servers_from_kits(kits) do
      servers
    else
      _ -> []
    end
  end
  
  defp discover_kits do
    case System.cmd("magg", ["kit", "list", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        parse_kit_output(output)
      
      {output, _} ->
        # Fallback to text parsing
        parse_kit_text_output(output)
    end
  end
  
  defp parse_kit_output(output) do
    case Jason.decode(output) do
      {:ok, data} when is_list(data) ->
        {:ok, Enum.map(data, &normalize_kit/1)}
      
      _ ->
        parse_kit_text_output(output)
    end
  end
  
  defp parse_kit_text_output(output) do
    kits = output
    |> String.split("\n")
    |> Enum.reduce({[], nil}, fn line, {kits, current_kit} ->
      cond do
        # Kit header: "example-kit: Example Kit"
        String.match?(line, ~r/^[a-z-]+:/) ->
          case String.split(line, ":", parts: 2) do
            [id, name] ->
              kit = %{
                id: String.trim(id),
                name: String.trim(name),
                servers: []
              }
              {[kit | kits], kit}
            _ ->
              {kits, current_kit}
          end
        
        # Server listing: "  - filesystem: File system operations"
        String.match?(line, ~r/^\s+-\s+/) && current_kit ->
          case Regex.run(~r/^\s+-\s+([^:]+):\s*(.*)/, line) do
            [_, server_id, description] ->
              server = %{
                id: String.trim(server_id),
                description: String.trim(description)
              }
              updated_kit = Map.update!(current_kit, :servers, &[server | &1])
              
              # Update the kit in the list
              kits = List.replace_at(kits, 0, updated_kit)
              {kits, updated_kit}
            
            _ ->
              {kits, current_kit}
          end
        
        true ->
          {kits, current_kit}
      end
    end)
    |> elem(0)
    |> Enum.map(fn kit ->
      Map.update!(kit, :servers, &Enum.reverse/1)
    end)
    
    {:ok, kits}
  end
  
  defp normalize_kit(kit) do
    %{
      id: kit["id"] || kit[:id],
      name: kit["name"] || kit[:name],
      description: kit["description"] || kit[:description] || "",
      servers: kit["servers"] || kit[:servers] || []
    }
  end
  
  defp extract_servers_from_kits(kits) do
    kits
    |> Enum.flat_map(fn kit ->
      kit.servers
      |> Enum.map(fn server ->
        %{
          id: "magg_kit_#{kit.id}_#{server.id}",
          name: server.id,
          description: server.description,
          source: :magg_kit,
          kit_id: kit.id,
          capabilities: infer_capabilities(server),
          install_command: "magg kit load #{kit.id}",
          config_command: "magg server enable #{server.id}"
        }
      end)
    end)
  end
  
  defp infer_capabilities(server) do
    text = "#{server.id} #{server.description}" |> String.downcase()
    
    capability_patterns = %{
      "filesystem" => ~r/file|fs|directory|folder/,
      "database" => ~r/db|sql|database|postgres|mysql|sqlite/,
      "memory" => ~r/memory|cache|store|persist/,
      "git" => ~r/git|version|repository/,
      "api" => ~r/api|rest|http|graphql/
    }
    
    Enum.reduce(capability_patterns, [], fn {capability, pattern}, acc ->
      if Regex.match?(pattern, text) do
        [capability | acc]
      else
        acc
      end
    end)
  end
end
```

### 2.4 Local Filesystem Scanning

```elixir
defmodule VsmPhoenix.MCP.Discovery.LocalStrategy do
  @moduledoc """
  Discovers locally installed MCP servers.
  """
  
  require Logger
  
  @search_paths [
    "~/.mcp/servers",
    "~/.config/mcp/servers",
    "/usr/local/lib/mcp-servers",
    "/opt/mcp-servers",
    "./mcp-servers"
  ]
  
  def discover(_opts \\ []) do
    @search_paths
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.exists?/1)
    |> Enum.flat_map(&scan_directory/1)
    |> Enum.uniq_by(& &1.id)
  end
  
  defp scan_directory(path) do
    Logger.debug("Scanning directory for MCP servers: #{path}")
    
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(path, &1))
        |> Enum.filter(&is_mcp_server?/1)
        |> Enum.map(&parse_local_server/1)
        |> Enum.reject(&is_nil/1)
      
      _ ->
        []
    end
  end
  
  defp is_mcp_server?(path) do
    # Check if directory contains MCP server indicators
    cond do
      File.exists?(Path.join(path, "mcp.json")) -> true
      File.exists?(Path.join(path, "package.json")) -> has_mcp_package?(path)
      File.exists?(Path.join(path, ".mcp")) -> true
      true -> false
    end
  end
  
  defp has_mcp_package?(path) do
    package_path = Path.join(path, "package.json")
    
    with {:ok, content} <- File.read(package_path),
         {:ok, package} <- Jason.decode(content) do
      
      name = package["name"] || ""
      keywords = package["keywords"] || []
      
      String.contains?(name, "mcp") or
      "mcp" in keywords or
      "model-context-protocol" in keywords
    else
      _ -> false
    end
  end
  
  defp parse_local_server(path) do
    server_name = Path.basename(path)
    
    config = 
      cond do
        File.exists?(Path.join(path, "mcp.json")) ->
          parse_mcp_json(path)
        
        File.exists?(Path.join(path, "package.json")) ->
          parse_package_json(path)
        
        true ->
          %{}
      end
    
    %{
      id: "local_#{server_name}",
      name: config["name"] || server_name,
      description: config["description"] || "Local MCP server",
      version: config["version"] || "unknown",
      source: :local,
      path: path,
      transport: config["transport"] || determine_transport(path),
      command: config["command"] || determine_command(path),
      capabilities: config["capabilities"] || infer_capabilities_from_path(path),
      install_command: "# Already installed at #{path}"
    }
  end
  
  defp parse_mcp_json(path) do
    mcp_path = Path.join(path, "mcp.json")
    
    with {:ok, content} <- File.read(mcp_path),
         {:ok, config} <- Jason.decode(content) do
      config
    else
      _ -> %{}
    end
  end
  
  defp parse_package_json(path) do
    package_path = Path.join(path, "package.json")
    
    with {:ok, content} <- File.read(package_path),
         {:ok, package} <- Jason.decode(content) do
      
      %{
        "name" => package["name"],
        "description" => package["description"],
        "version" => package["version"],
        "capabilities" => extract_capabilities_from_keywords(package["keywords"] || [])
      }
    else
      _ -> %{}
    end
  end
  
  defp determine_transport(path) do
    cond do
      File.exists?(Path.join(path, "http-server.js")) -> "http"
      File.exists?(Path.join(path, "server.js")) -> "stdio"
      File.exists?(Path.join(path, "index.js")) -> "stdio"
      true -> "stdio"
    end
  end
  
  defp determine_command(path) do
    cond do
      File.exists?(Path.join(path, "bin/server")) ->
        Path.join(path, "bin/server")
      
      File.exists?(Path.join(path, "server.js")) ->
        "node #{Path.join(path, "server.js")}"
      
      File.exists?(Path.join(path, "index.js")) ->
        "node #{Path.join(path, "index.js")}"
      
      true ->
        "node #{path}"
    end
  end
  
  defp infer_capabilities_from_path(path) do
    name = Path.basename(path) |> String.downcase()
    
    capabilities = []
    capabilities = if String.contains?(name, "file"), do: ["filesystem" | capabilities], else: capabilities
    capabilities = if String.contains?(name, "git"), do: ["git" | capabilities], else: capabilities
    capabilities = if String.contains?(name, "db"), do: ["database" | capabilities], else: capabilities
    capabilities = if String.contains?(name, "memory"), do: ["memory" | capabilities], else: capabilities
    
    capabilities
  end
  
  defp extract_capabilities_from_keywords(keywords) do
    keyword_map = %{
      "filesystem" => ["file", "fs", "filesystem"],
      "database" => ["database", "db", "sql"],
      "git" => ["git", "vcs", "version-control"],
      "api" => ["api", "rest", "http"],
      "memory" => ["memory", "cache", "storage"]
    }
    
    Enum.reduce(keywords, [], fn keyword, acc ->
      capability = Enum.find_value(keyword_map, fn {cap, patterns} ->
        if keyword in patterns, do: cap
      end)
      
      if capability, do: [capability | acc], else: acc
    end)
    |> Enum.uniq()
  end
end
```

## 3. Code Templates

### 3.1 Enhanced Discovery Engine

```elixir
defmodule VsmPhoenix.MCP.Discovery.Engine do
  @moduledoc """
  Orchestrates all discovery strategies and manages caching.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.Discovery.{
    NPMStrategy,
    GitHubStrategy,
    MaggStrategy,
    LocalStrategy,
    Cache
  }
  
  @discovery_interval :timer.minutes(30)
  @cache_ttl :timer.hours(1)
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def discover_all(opts \\ []) do
    GenServer.call(__MODULE__, {:discover_all, opts}, :infinity)
  end
  
  def discover_by_capability(capability) do
    GenServer.call(__MODULE__, {:discover_by_capability, capability})
  end
  
  def search(query) do
    GenServer.call(__MODULE__, {:search, query})
  end
  
  @impl true
  def init(_opts) do
    # Schedule periodic discovery
    schedule_discovery()
    
    state = %{
      last_discovery: nil,
      discovery_running: false,
      strategies: %{
        npm: NPMStrategy,
        github: GitHubStrategy,
        magg: MaggStrategy,
        local: LocalStrategy
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:discover_all, opts}, from, state) do
    if state.discovery_running do
      {:reply, {:error, :discovery_in_progress}, state}
    else
      # Check cache first
      case Cache.get(:all_servers) do
        {:ok, servers} when is_map(servers) ->
          {:reply, {:ok, servers}, state}
        
        _ ->
          # Start async discovery
          task = Task.async(fn ->
            run_discovery(state.strategies, opts)
          end)
          
          state = %{state | discovery_running: true}
          
          # Store the task and reply later
          GenServer.reply(from, {:ok, :discovery_started})
          
          {:noreply, Map.put(state, :discovery_task, {task, from})}
      end
    end
  end
  
  @impl true
  def handle_call({:discover_by_capability, capability}, _from, state) do
    servers = 
      case Cache.get({:capability, capability}) do
        {:ok, cached} ->
          cached
        
        _ ->
          # Quick search in last discovery results
          case Cache.get(:all_servers) do
            {:ok, all_servers} ->
              filtered = filter_by_capability(all_servers, capability)
              Cache.put({:capability, capability}, filtered, @cache_ttl)
              filtered
            
            _ ->
              []
          end
      end
    
    {:reply, {:ok, servers}, state}
  end
  
  @impl true
  def handle_call({:search, query}, _from, state) do
    # Implement fuzzy search across all discovered servers
    results = 
      case Cache.get(:all_servers) do
        {:ok, servers} ->
          search_servers(servers, query)
        _ ->
          []
      end
    
    {:reply, {:ok, results}, state}
  end
  
  @impl true
  def handle_info(:run_discovery, state) do
    if not state.discovery_running do
      task = Task.async(fn ->
        run_discovery(state.strategies, [])
      end)
      
      schedule_discovery()
      
      {:noreply, %{state | discovery_running: true, discovery_task: {task, nil}}}
    else
      # Skip if discovery is already running
      schedule_discovery()
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({task_ref, result}, state) when is_reference(task_ref) do
    # Handle task completion
    case Map.get(state, :discovery_task) do
      {%Task{ref: ^task_ref}, from} ->
        # Process discovery results
        handle_discovery_complete(result, from, state)
      
      _ ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Task process died
    {:noreply, %{state | discovery_running: false}}
  end
  
  defp run_discovery(strategies, opts) do
    Logger.info("Starting MCP server discovery across all strategies")
    
    # Run strategies in parallel
    results = 
      strategies
      |> Enum.map(fn {name, module} ->
        Task.async(fn ->
          Logger.debug("Running discovery strategy: #{name}")
          start_time = System.monotonic_time(:millisecond)
          
          result = 
            try do
              servers = module.discover(opts)
              duration = System.monotonic_time(:millisecond) - start_time
              Logger.info("Strategy #{name} found #{length(servers)} servers in #{duration}ms")
              {name, servers}
            rescue
              e ->
                Logger.error("Strategy #{name} failed: #{inspect(e)}")
                {name, []}
            end
          
          result
        end)
      end)
      |> Task.await_many(60_000)
    
    # Merge results
    merged_servers = 
      results
      |> Enum.reduce(%{}, fn {_strategy, servers}, acc ->
        Enum.reduce(servers, acc, fn server, acc2 ->
          Map.update(acc2, server.id, server, fn existing ->
            merge_server_info(existing, server)
          end)
        end)
      end)
    
    # Update cache
    Cache.put(:all_servers, merged_servers, @cache_ttl)
    
    # Update registry
    update_registry(merged_servers)
    
    Logger.info("Discovery complete. Found #{map_size(merged_servers)} unique servers")
    
    merged_servers
  end
  
  defp merge_server_info(server1, server2) do
    # Merge server information, preferring more complete data
    %{
      server1 |
      description: choose_better(server1.description, server2.description),
      capabilities: Enum.uniq(server1.capabilities ++ server2.capabilities),
      sources: Enum.uniq([server1.source | Map.get(server1, :sources, [])] ++ [server2.source])
    }
  end
  
  defp choose_better("", value), do: value
  defp choose_better(value, ""), do: value
  defp choose_better(value1, value2) when byte_size(value1) > byte_size(value2), do: value1
  defp choose_better(_, value2), do: value2
  
  defp filter_by_capability(servers, capability) do
    servers
    |> Map.values()
    |> Enum.filter(fn server ->
      capability in server.capabilities
    end)
  end
  
  defp search_servers(servers, query) do
    query_lower = String.downcase(query)
    
    servers
    |> Map.values()
    |> Enum.map(fn server ->
      score = calculate_search_score(server, query_lower)
      {server, score}
    end)
    |> Enum.filter(fn {_, score} -> score > 0 end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.map(fn {server, _} -> server end)
    |> Enum.take(20)
  end
  
  defp calculate_search_score(server, query) do
    name_score = if String.contains?(String.downcase(server.name), query), do: 10, else: 0
    desc_score = if String.contains?(String.downcase(server.description), query), do: 5, else: 0
    cap_score = if Enum.any?(server.capabilities, &String.contains?(&1, query)), do: 3, else: 0
    
    name_score + desc_score + cap_score
  end
  
  defp update_registry(servers) do
    # Update the main registry with discovered servers
    VsmPhoenix.MCP.Registry.ServerRegistry.bulk_update(servers)
  end
  
  defp handle_discovery_complete(result, from, state) do
    # Clear the discovery task
    state = Map.delete(state, :discovery_task)
    
    # Reply to waiting caller if any
    if from do
      GenServer.reply(from, {:ok, result})
    end
    
    {:noreply, %{state | 
      discovery_running: false,
      last_discovery: DateTime.utc_now()
    }}
  end
  
  defp schedule_discovery do
    Process.send_after(self(), :run_discovery, @discovery_interval)
  end
end
```

### 3.2 Discovery Cache Implementation

```elixir
defmodule VsmPhoenix.MCP.Discovery.Cache do
  @moduledoc """
  ETS-based cache for discovery results with TTL support.
  """
  
  use GenServer
  require Logger
  
  @table_name :mcp_discovery_cache
  @cleanup_interval :timer.minutes(5)
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(DateTime.utc_now(), expiry) == :lt do
          {:ok, value}
        else
          :ets.delete(@table_name, key)
          {:error, :expired}
        end
      
      [] ->
        {:error, :not_found}
    end
  end
  
  def put(key, value, ttl_ms) do
    expiry = DateTime.add(DateTime.utc_now(), ttl_ms, :millisecond)
    :ets.insert(@table_name, {key, value, expiry})
    :ok
  end
  
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end
  
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end
  
  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end
  
  defp cleanup_expired do
    now = DateTime.utc_now()
    
    :ets.foldl(fn {key, _value, expiry}, count ->
      if DateTime.compare(now, expiry) == :gt do
        :ets.delete(@table_name, key)
        count + 1
      else
        count
      end
    end, 0, @table_name)
    |> case do
      0 -> :ok
      count -> Logger.debug("Cleaned up #{count} expired cache entries")
    end
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
```

### 3.3 Enhanced Server Registry

```elixir
defmodule VsmPhoenix.MCP.Registry.ServerRegistry do
  @moduledoc """
  Real server registry replacing the mock MCPRegistry.
  """
  
  use GenServer
  require Logger
  
  @registry_table :mcp_server_registry
  @index_table :mcp_capability_index
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def register_server(server_info) do
    GenServer.call(__MODULE__, {:register_server, server_info})
  end
  
  def bulk_update(servers) when is_map(servers) do
    GenServer.call(__MODULE__, {:bulk_update, servers})
  end
  
  def get_server(server_id) do
    case :ets.lookup(@registry_table, server_id) do
      [{^server_id, server}] -> {:ok, server}
      [] -> {:error, :not_found}
    end
  end
  
  def list_servers do
    :ets.tab2list(@registry_table)
    |> Enum.map(fn {_id, server} -> server end)
  end
  
  def search_by_capability(capability) do
    case :ets.lookup(@index_table, capability) do
      [{^capability, server_ids}] ->
        servers = 
          Enum.map(server_ids, fn id ->
            case :ets.lookup(@registry_table, id) do
              [{^id, server}] -> server
              [] -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
        
        {:ok, servers}
      
      [] ->
        {:ok, []}
    end
  end
  
  def get_stats do
    %{
      total_servers: :ets.info(@registry_table, :size),
      total_capabilities: :ets.info(@index_table, :size),
      active_servers: count_active_servers()
    }
  end
  
  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@registry_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@index_table, [:set, :public, :named_table, read_concurrency: true])
    
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:register_server, server_info}, _from, state) do
    server = normalize_server(server_info)
    
    # Update registry
    :ets.insert(@registry_table, {server.id, server})
    
    # Update capability index
    update_capability_index(server)
    
    Logger.info("Registered server: #{server.id} with capabilities: #{inspect(server.capabilities)}")
    
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_call({:bulk_update, servers}, _from, state) do
    # Clear and rebuild
    :ets.delete_all_objects(@registry_table)
    :ets.delete_all_objects(@index_table)
    
    # Insert all servers
    Enum.each(servers, fn {_id, server_info} ->
      server = normalize_server(server_info)
      :ets.insert(@registry_table, {server.id, server})
      update_capability_index(server)
    end)
    
    Logger.info("Bulk updated #{map_size(servers)} servers")
    
    {:reply, :ok, state}
  end
  
  defp normalize_server(server) do
    Map.merge(%{
      status: :discovered,
      discovered_at: DateTime.utc_now(),
      capabilities: [],
      sources: []
    }, server)
  end
  
  defp update_capability_index(server) do
    Enum.each(server.capabilities, fn capability ->
      server_ids = 
        case :ets.lookup(@index_table, capability) do
          [{^capability, ids}] -> ids
          [] -> []
        end
      
      if server.id not in server_ids do
        :ets.insert(@index_table, {capability, [server.id | server_ids]})
      end
    end)
  end
  
  defp count_active_servers do
    :ets.foldl(fn {_id, server}, count ->
      if server.status == :active do
        count + 1
      else
        count
      end
    end, 0, @registry_table)
  end
end
```

## 4. Migration Path

### 4.1 Phase 1: Parallel Implementation (Week 1)

1. Implement all discovery strategies in parallel with existing mock
2. Create new Registry modules without removing old MCPRegistry
3. Add feature flag to switch between mock and real discovery

```elixir
defmodule VsmPhoenix.MCP.FeatureFlags do
  def use_real_discovery? do
    Application.get_env(:vsm_phoenix, :use_real_mcp_discovery, false)
  end
end
```

### 4.2 Phase 2: Integration Testing (Week 2)

1. Test each discovery strategy individually
2. Verify tool aggregation works with real servers
3. Ensure backward compatibility with existing S1 agents

### 4.3 Phase 3: Gradual Rollout (Week 3)

1. Enable real discovery for development environment
2. Monitor performance and error rates
3. Implement fallback mechanisms

```elixir
defmodule VsmPhoenix.MCP.Discovery.Fallback do
  @moduledoc """
  Provides fallback to mock data if real discovery fails.
  """
  
  def with_fallback(discovery_fn, fallback_fn) do
    case discovery_fn.() do
      {:ok, results} when results != [] ->
        {:ok, results}
      
      _ ->
        Logger.warning("Real discovery failed, using fallback")
        fallback_fn.()
    end
  end
end
```

### 4.4 Phase 4: Production Deployment (Week 4)

1. Remove feature flags
2. Deprecate old MCPRegistry
3. Full production deployment

## 5. Integration Examples

### 5.1 S1 Agent Discovery Usage

```elixir
defmodule VsmPhoenix.System1.Agents.DiscoveryAgent do
  @moduledoc """
  S1 agent that uses discovery to find tools.
  """
  
  alias VsmPhoenix.MCP.Discovery.Engine
  alias VsmPhoenix.MCP.Integration.MaggIntegration
  
  def find_capability(capability_request) do
    # Search for servers with capability
    case Engine.discover_by_capability(capability_request) do
      {:ok, servers} when servers != [] ->
        # Select best server
        server = select_best_server(servers, capability_request)
        
        # Auto-connect if not connected
        ensure_connected(server)
        
      _ ->
        {:error, :no_servers_found}
    end
  end
  
  defp select_best_server(servers, capability) do
    servers
    |> Enum.sort_by(fn server ->
      score = 0
      score = if server.source == :npm, do: score + 10, else: score
      score = if "official" in server.capabilities, do: score + 5, else: score
      score = if server.score, do: score + server.score.overall * 100, else: score
      score
    end, :desc)
    |> List.first()
  end
  
  defp ensure_connected(server) do
    case MaggIntegration.get_client_status(server.id) do
      {:ok, %{status: :connected}} ->
        {:ok, :already_connected}
      
      _ ->
        MaggIntegration.connect_server(server)
    end
  end
end
```

### 5.2 Auto-Connection Flow

```elixir
defmodule VsmPhoenix.MCP.Integration.AutoConnect do
  @moduledoc """
  Automatic connection management for discovered servers.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{MaggWrapper, ExternalClientSupervisor}
  
  def auto_connect(server) do
    GenServer.call(__MODULE__, {:auto_connect, server})
  end
  
  @impl true
  def handle_call({:auto_connect, server}, _from, state) do
    result = 
      with {:ok, _} <- ensure_installed(server),
           {:ok, _} <- ensure_configured(server),
           {:ok, client_pid} <- start_client(server) do
        {:ok, %{server_id: server.id, client_pid: client_pid}}
      end
    
    {:reply, result, state}
  end
  
  defp ensure_installed(server) do
    case server.source do
      :npm ->
        # Check if installed, install if not
        if npm_package_installed?(server.id) do
          {:ok, :already_installed}
        else
          Logger.info("Installing MCP server: #{server.id}")
          System.cmd("npm", ["install", "-g", server.id])
          {:ok, :installed}
        end
      
      :magg_kit ->
        # Use MAGG to install
        MaggWrapper.add_server(server.id)
      
      :local ->
        # Already installed
        {:ok, :local}
      
      _ ->
        {:error, :unsupported_source}
    end
  end
  
  defp ensure_configured(server) do
    case MaggWrapper.get_server_config(server.id) do
      {:ok, _config} ->
        {:ok, :configured}
      
      _ ->
        # Add to MAGG configuration
        MaggWrapper.add_server(server.id)
    end
  end
  
  defp start_client(server) do
    ExternalClientSupervisor.start_client(server.id)
  end
  
  defp npm_package_installed?(package_name) do
    case System.cmd("npm", ["list", "-g", package_name, "--depth=0"], stderr_to_stdout: true) do
      {output, 0} ->
        String.contains?(output, package_name)
      _ ->
        false
    end
  end
end
```

### 5.3 Tool Aggregation Pattern

```elixir
defmodule VsmPhoenix.MCP.ToolAggregator do
  @moduledoc """
  Aggregates tools from all connected MCP servers.
  """
  
  alias VsmPhoenix.MCP.ExternalClientSupervisor
  
  def aggregate_tools do
    ExternalClientSupervisor.list_clients()
    |> Task.async_stream(&get_client_tools/1, max_concurrency: 10)
    |> Enum.reduce(%{}, fn
      {:ok, {server_id, tools}}, acc ->
        Map.put(acc, server_id, tools)
      
      _, acc ->
        acc
    end)
  end
  
  def find_tool(tool_name) do
    aggregate_tools()
    |> Enum.find_value(fn {server_id, tools} ->
      if tool = Enum.find(tools, & &1["name"] == tool_name) do
        {server_id, tool}
      end
    end)
  end
  
  def execute_tool(tool_name, params) do
    case find_tool(tool_name) do
      {server_id, _tool} ->
        VsmPhoenix.MCP.ExternalClient.execute_tool(server_id, tool_name, params)
      
      nil ->
        {:error, :tool_not_found}
    end
  end
  
  defp get_client_tools(client_info) do
    case VsmPhoenix.MCP.ExternalClient.list_tools(client_info.server_id) do
      {:ok, tools} -> {client_info.server_id, tools}
      _ -> {client_info.server_id, []}
    end
  end
end
```

## 6. Performance Optimizations

### 6.1 Concurrent Discovery

- All strategies run in parallel with configurable timeouts
- Results are merged intelligently to avoid duplicates
- Failed strategies don't block others

### 6.2 Caching Strategy

- Discovery results cached for 1 hour
- Capability searches cached separately
- Background refresh before cache expiry

### 6.3 Connection Pooling

- Reuse ExternalClient processes
- Lazy connection establishment
- Automatic reconnection with backoff

### 6.4 Tool Call Optimization

- Tool lookups use ETS for O(1) access
- Load balancing across multiple servers with same tool
- Result caching for idempotent operations

## 7. Error Handling

### 7.1 Discovery Failures

```elixir
defmodule VsmPhoenix.MCP.Discovery.ErrorHandler do
  def handle_discovery_error(strategy, error) do
    Logger.error("Discovery failed for #{strategy}: #{inspect(error)}")
    
    # Report to telemetry
    :telemetry.execute(
      [:vsm_phoenix, :mcp, :discovery, :error],
      %{count: 1},
      %{strategy: strategy, error: error}
    )
    
    # Return empty result to allow other strategies to continue
    []
  end
end
```

### 7.2 Connection Failures

- Automatic retry with exponential backoff
- Circuit breaker pattern for consistently failing servers
- Graceful degradation to alternative servers

## 8. Testing Strategy

### 8.1 Unit Tests

```elixir
defmodule VsmPhoenix.MCP.Discovery.NPMStrategyTest do
  use ExUnit.Case
  import Mox
  
  setup :verify_on_exit!
  
  test "discovers MCP servers from NPM" do
    # Mock HTTP responses
    expect(HTTPoisonMock, :get, fn url, _headers ->
      assert String.contains?(url, "registry.npmjs.org")
      {:ok, %{status_code: 200, body: npm_response_fixture()}}
    end)
    
    servers = NPMStrategy.discover()
    
    assert length(servers) > 0
    assert Enum.all?(servers, & &1.source == :npm)
  end
end
```

### 8.2 Integration Tests

- Test against real NPM registry with known packages
- Verify GitHub API integration with test repository
- Test MAGG CLI integration in isolated environment

### 8.3 End-to-End Tests

- Full discovery → connection → tool execution flow
- Multi-server coordination tests
- Failure recovery scenarios

## 9. Monitoring and Metrics

### 9.1 Telemetry Events

```elixir
:telemetry.execute(
  [:vsm_phoenix, :mcp, :discovery, :complete],
  %{
    duration: duration_ms,
    server_count: map_size(servers),
    strategy_results: strategy_counts
  },
  %{source: :scheduled}
)
```

### 9.2 Health Checks

- Regular discovery health verification
- Server connection status monitoring
- Tool execution success rates

## 10. Security Considerations

### 10.1 Package Verification

- Verify NPM package signatures when possible
- Check GitHub repository stars/activity
- Validate server certificates for HTTPS

### 10.2 Sandboxing

- Run external servers in restricted environments
- Limit file system access based on capabilities
- Monitor resource usage

### 10.3 Input Validation

- Sanitize all discovery inputs
- Validate tool parameters before execution
- Rate limit discovery operations

## Conclusion

This implementation plan provides a complete path from VSM's current mock discovery to a real, production-ready discovery system. The phased approach ensures backward compatibility while gradually introducing new capabilities. The architecture is designed for extensibility, allowing new discovery strategies to be added easily as the MCP ecosystem evolves.

Key benefits:
- True variety acquisition through dynamic discovery
- Automatic tool aggregation from multiple sources
- Robust error handling and recovery
- Performance optimized for production use
- Security-first design

The implementation follows Elixir best practices and integrates seamlessly with VSM's existing architecture, particularly the System 1 agents that will benefit most from expanded variety.