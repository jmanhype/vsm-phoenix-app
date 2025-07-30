defmodule VsmPhoenix.MCP.ServerCatalog do
  @moduledoc """
  Catalog of known MCP servers with their capabilities and installation methods.
  This serves as a curated list of verified servers for variety acquisition.
  """

  @official_servers %{
    "filesystem" => %{
      id: "filesystem",
      name: "Filesystem MCP Server",
      package: "@modelcontextprotocol/server-filesystem",
      description: "Secure file operations with configurable access controls",
      capabilities: ["file_read", "file_write", "directory_ops", "access_control"],
      category: :core,
      install: %{
        npm: "@modelcontextprotocol/server-filesystem",
        command: "npx @modelcontextprotocol/server-filesystem"
      },
      config_example: %{
        "allowed_paths" => ["/tmp", "./data"],
        "read_only" => false
      }
    },
    "git" => %{
      id: "git",
      name: "Git MCP Server",
      package: "@modelcontextprotocol/server-git",
      description: "Tools to read, search, and manipulate Git repositories",
      capabilities: ["git_log", "git_diff", "git_search", "git_blame"],
      category: :development,
      install: %{
        npm: "@modelcontextprotocol/server-git",
        command: "npx @modelcontextprotocol/server-git"
      }
    },
    "github" => %{
      id: "github",
      name: "GitHub MCP Server",
      package: "@modelcontextprotocol/server-github",
      description: "Repository management, file operations, and GitHub API integration",
      capabilities: ["repo_management", "pr_operations", "issue_tracking", "actions"],
      category: :development,
      install: %{
        npm: "@modelcontextprotocol/server-github",
        command: "npx @modelcontextprotocol/server-github"
      },
      config_example: %{
        "token" => "GITHUB_TOKEN",
        "owner" => "username",
        "repo" => "repository"
      }
    },
    "memory" => %{
      id: "memory",
      name: "Memory MCP Server",
      package: "@modelcontextprotocol/server-memory",
      description: "Knowledge graph-based persistent memory system",
      capabilities: ["store", "retrieve", "graph_ops", "persistence"],
      category: :core,
      install: %{
        npm: "@modelcontextprotocol/server-memory",
        command: "npx @modelcontextprotocol/server-memory"
      }
    },
    "sqlite" => %{
      id: "sqlite",
      name: "SQLite MCP Server",
      package: "@modelcontextprotocol/server-sqlite",
      description: "Database queries, schema management, and data analysis",
      capabilities: ["sql_query", "schema_ops", "data_analysis"],
      category: :data,
      install: %{
        npm: "@modelcontextprotocol/server-sqlite",
        command: "npx @modelcontextprotocol/server-sqlite"
      },
      config_example: %{
        "database" => "./data.db",
        "read_only" => false
      }
    }
  }

  @community_servers %{
    "notion" => %{
      id: "notion",
      name: "Notion MCP Server",
      package: "@notionhq/notion-mcp-server",
      description: "Official MCP server for Notion API",
      capabilities: ["page_ops", "database_ops", "content_creation"],
      category: :productivity,
      install: %{
        npm: "@notionhq/notion-mcp-server",
        command: "npx @notionhq/notion-mcp-server"
      },
      config_example: %{
        "api_key" => "NOTION_API_KEY"
      }
    },
    "sentry" => %{
      id: "sentry",
      name: "Sentry MCP Server",
      package: "@sentry/mcp-server",
      description: "Error tracking and performance monitoring",
      capabilities: ["error_tracking", "performance", "issue_management"],
      category: :monitoring,
      install: %{
        npm: "@sentry/mcp-server",
        command: "npx @sentry/mcp-server"
      }
    },
    "heroku" => %{
      id: "heroku",
      name: "Heroku MCP Server",
      package: "@heroku/mcp-server",
      description: "Heroku platform operations",
      capabilities: ["app_management", "deployment", "config", "addons"],
      category: :deployment,
      install: %{
        npm: "@heroku/mcp-server",
        command: "npx @heroku/mcp-server"
      }
    },
    "code-runner" => %{
      id: "code-runner",
      name: "Code Runner MCP Server",
      package: "mcp-server-code-runner",
      description: "Multi-language code execution with sandboxing",
      capabilities: ["code_execution", "multi_language", "sandboxing"],
      category: :development,
      install: %{
        npm: "mcp-server-code-runner",
        command: "npx mcp-server-code-runner"
      }
    },
    "graphlit" => %{
      id: "graphlit",
      name: "Graphlit MCP Server",
      package: "graphlit-mcp-server",
      description: "Knowledge graphs, RAG, and document processing",
      capabilities: ["knowledge_graph", "rag", "parsing", "web_scraping"],
      category: :data,
      install: %{
        npm: "graphlit-mcp-server",
        command: "npx graphlit-mcp-server"
      }
    }
  }

  @doc """
  Get all available servers
  """
  def all_servers do
    Map.merge(@official_servers, @community_servers)
  end

  @doc """
  Get servers by category
  """
  def by_category(category) when is_atom(category) do
    all_servers()
    |> Enum.filter(fn {_id, server} -> server.category == category end)
    |> Map.new()
  end

  @doc """
  Get servers by capability
  """
  def by_capability(capability) when is_binary(capability) do
    all_servers()
    |> Enum.filter(fn {_id, server} -> 
      capability in server.capabilities 
    end)
    |> Map.new()
  end

  @doc """
  Get official servers only
  """
  def official_servers, do: @official_servers

  @doc """
  Get community servers only
  """
  def community_servers, do: @community_servers

  @doc """
  Get server installation command
  """
  def install_command(server_id) do
    case all_servers()[server_id] do
      nil -> {:error, :not_found}
      server -> {:ok, server.install}
    end
  end

  @doc """
  Get server by package name
  """
  def by_package(package_name) do
    all_servers()
    |> Enum.find(fn {_id, server} -> 
      server.package == package_name 
    end)
    |> case do
      nil -> nil
      {_id, server} -> server
    end
  end

  @doc """
  List all categories
  """
  def categories do
    all_servers()
    |> Enum.map(fn {_id, server} -> server.category end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  List all capabilities
  """
  def capabilities do
    all_servers()
    |> Enum.flat_map(fn {_id, server} -> server.capabilities end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Search servers by name or description
  """
  def search(query) when is_binary(query) do
    query_lower = String.downcase(query)
    
    all_servers()
    |> Enum.filter(fn {id, server} ->
      String.contains?(String.downcase(id), query_lower) or
      String.contains?(String.downcase(server.name), query_lower) or
      String.contains?(String.downcase(server.description), query_lower)
    end)
    |> Map.new()
  end

  @doc """
  Get recommended servers for a use case
  """
  def recommend_for_use_case(use_case) when is_atom(use_case) do
    case use_case do
      :basic_development ->
        ["filesystem", "git", "memory", "sqlite"]
        
      :web_development ->
        ["filesystem", "git", "github", "memory", "code-runner"]
        
      :data_analysis ->
        ["sqlite", "graphlit", "memory", "filesystem"]
        
      :productivity ->
        ["notion", "memory", "filesystem"]
        
      :monitoring ->
        ["sentry", "memory"]
        
      :deployment ->
        ["heroku", "github", "git"]
        
      _ ->
        ["filesystem", "memory"]
    end
    |> Enum.map(&{&1, all_servers()[&1]})
    |> Enum.reject(fn {_id, server} -> is_nil(server) end)
    |> Map.new()
  end
end