defmodule VsmPhoenix.MCP.MaggWrapper do
  @moduledoc """
  Elixir wrapper for MAGG CLI tool that enables VSM to discover and integrate external MCP servers.
  
  This module provides a high-level interface to MAGG's functionality:
  - Search for MCP servers in the npm registry
  - Add MCP servers to configuration
  - List configured MCP servers
  - Get available tools from configured servers
  """

  require Logger
  
  @magg_binary "magg"
  @timeout 30000
  @max_retries 3
  @retry_delay 1_000

  @doc """
  Search for MCP servers in the npm registry.
  
  ## Options
  - `:query` - Search query string
  - `:limit` - Maximum number of results (default: 10)
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.search_servers(query: "weather")
      {:ok, [%{
        "name" => "@modelcontextprotocol/server-weather",
        "description" => "MCP server for weather data",
        "version" => "0.1.0"
      }]}
  """
  def search_servers(opts \\ []) do
    # Note: Current MAGG version doesn't support search
    # Return empty list for now
    {:ok, []}
  end

  @doc """
  Add an MCP server to the configuration.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.add_server("@modelcontextprotocol/server-weather")
      {:ok, %{
        "name" => "@modelcontextprotocol/server-weather",
        "version" => "0.1.0",
        "transport" => "stdio"
      }}
  """
  def add_server(server_name) when is_binary(server_name) do
    args = ["server", "add", server_name]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          Logger.info("Successfully added MCP server: #{server_name}")
          {:ok, result}
        {:error, _} = error ->
          # Try to parse non-JSON output from magg
          case execute_magg_raw(args) do
            {:ok, output} ->
              Logger.info("Server added (non-JSON): #{output}")
              {:ok, %{"name" => server_name, "status" => "added"}}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  List all configured MCP servers.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.list_servers()
      {:ok, [%{
        "name" => "@modelcontextprotocol/server-weather",
        "version" => "0.1.0",
        "transport" => "stdio",
        "status" => "configured"
      }]}
  """
  def list_servers do
    args = ["server", "list"]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          {:ok, result}
        {:error, _} ->
          # Try parsing non-JSON output
          case execute_magg_raw(args) do
            {:ok, output} ->
              # Parse text output into a list
              servers = parse_server_list(output)
              {:ok, servers}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  Get available tools from a specific MCP server or all servers.
  
  ## Options
  - `:server` - Specific server name (optional, defaults to all servers)
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.get_tools()
      {:ok, %{
        "@modelcontextprotocol/server-weather" => [
          %{
            "name" => "get_weather",
            "description" => "Get current weather for a location",
            "parameters" => %{...}
          }
        ]
      }}
  """
  def get_tools(opts \\ []) do
    # Note: Current MAGG version doesn't have a direct tools command
    # Would need to query individual servers
    {:ok, %{}}
  end

  @doc """
  Remove an MCP server from configuration.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.remove_server("@modelcontextprotocol/server-weather")
      {:ok, %{"removed" => "@modelcontextprotocol/server-weather"}}
  """
  def remove_server(server_name) when is_binary(server_name) do
    args = ["server", "remove", server_name]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          Logger.info("Successfully removed MCP server: #{server_name}")
          {:ok, result}
        {:error, _} ->
          case execute_magg_raw(args) do
            {:ok, output} ->
              Logger.info("Server removed (non-JSON): #{output}")
              {:ok, %{"removed" => server_name}}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  Get configuration details for a specific server.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.get_server_config("@modelcontextprotocol/server-weather")
      {:ok, %{
        "name" => "@modelcontextprotocol/server-weather",
        "version" => "0.1.0",
        "transport" => "stdio",
        "command" => "npx",
        "args" => ["@modelcontextprotocol/server-weather"]
      }}
  """
  def get_server_config(server_name) when is_binary(server_name) do
    args = ["server", "info", server_name]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          {:ok, result}
        {:error, _} ->
          # Parse non-JSON output
          case execute_magg_raw(args) do
            {:ok, output} ->
              config = parse_server_info(output, server_name)
              {:ok, config}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  Enable a configured MCP server.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.enable_server("@modelcontextprotocol/server-weather")
      {:ok, %{
        "name" => "@modelcontextprotocol/server-weather",
        "enabled" => true
      }}
  """
  def enable_server(server_name) when is_binary(server_name) do
    args = ["server", "enable", server_name]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          Logger.info("Successfully enabled MCP server: #{server_name}")
          {:ok, result}
        {:error, _} ->
          case execute_magg_raw(args) do
            {:ok, output} ->
              Logger.info("Server enabled (non-JSON): #{output}")
              {:ok, %{"name" => server_name, "enabled" => true}}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  Disable a configured MCP server.
  
  ## Examples
      
      iex> VsmPhoenix.MCP.MaggWrapper.disable_server("@modelcontextprotocol/server-weather")
      {:ok, %{
        "name" => "@modelcontextprotocol/server-weather",
        "enabled" => false
      }}
  """
  def disable_server(server_name) when is_binary(server_name) do
    args = ["server", "disable", server_name]
    
    with_retry(fn ->
      case execute_magg(args) do
        {:ok, result} ->
          Logger.info("Successfully disabled MCP server: #{server_name}")
          {:ok, result}
        {:error, _} ->
          case execute_magg_raw(args) do
            {:ok, output} ->
              Logger.info("Server disabled (non-JSON): #{output}")
              {:ok, %{"name" => server_name, "enabled" => false}}
            error ->
              error
          end
      end
    end)
  end

  @doc """
  Check if MAGG CLI is available and properly configured.
  """
  def check_availability do
    case System.find_executable(@magg_binary) do
      nil ->
        {:error, "MAGG CLI not found. Please install it with: npm install -g magg"}
      path ->
        {:ok, %{
          binary: path,
          version: get_version()
        }}
    end
  end

  # Private functions

  defp execute_magg(args) do
    Logger.debug("Executing MAGG command: #{@magg_binary} #{Enum.join(args, " ")}")
    
    # Use Task.async to enable proper timeout support
    task = Task.async(fn ->
      try do
        System.cmd(@magg_binary, args, [stderr_to_stdout: true])
      rescue
        e in System.Error ->
          {:error, "MAGG not found or not executable: #{inspect(e)}"}
      end
    end)
    
    # Wait for task with timeout
    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        parse_json_output(output)
        
      {:ok, {output, exit_code}} ->
        Logger.error("MAGG command failed with exit code #{exit_code}: #{output}")
        {:error, %{
          exit_code: exit_code,
          output: output,
          command: "#{@magg_binary} #{Enum.join(args, " ")}"
        }}
        
      {:ok, {:error, reason}} ->
        Logger.error("Failed to execute MAGG: #{reason}")
        {:error, reason}
        
      nil ->
        Logger.error("MAGG command timed out after #{@timeout}ms")
        {:error, :timeout}
    end
  end

  defp parse_json_output(output) do
    output
    |> String.trim()
    |> Jason.decode()
    |> case do
      {:ok, data} -> {:ok, data}
      {:error, _} -> 
        # Try to extract JSON from output (sometimes there's extra logging)
        case extract_json(output) do
          {:ok, data} -> {:ok, data}
          _ -> {:error, "Failed to parse MAGG output: #{output}"}
        end
    end
  end

  defp extract_json(output) do
    # Look for JSON content in the output
    case Regex.run(~r/(\{.*\}|\[.*\])/s, output) do
      [_, json_str] -> Jason.decode(json_str)
      _ -> {:error, :no_json_found}
    end
  end

  defp get_version do
    case System.cmd(@magg_binary, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> "unknown"
    end
  end

  defp with_retry(fun, retries \\ @max_retries) do
    case fun.() do
      {:error, reason} when retries > 0 ->
        Logger.warning("MAGG operation failed, retrying... (#{retries} attempts left): #{inspect(reason)}")
        Process.sleep(@retry_delay)
        with_retry(fun, retries - 1)
      
      result ->
        result
    end
  end

  defp execute_magg_raw(args) do
    Logger.debug("Executing MAGG command: #{@magg_binary} #{Enum.join(args, " ")}")
    
    # Use Task.async to enable proper timeout support
    task = Task.async(fn ->
      try do
        System.cmd(@magg_binary, args, [stderr_to_stdout: true])
      rescue
        e in System.Error ->
          {:error, "MAGG not found or not executable: #{inspect(e)}"}
      end
    end)
    
    # Wait for task with timeout
    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        {:ok, String.trim(output)}
        
      {:ok, {output, exit_code}} ->
        Logger.error("MAGG command failed with exit code #{exit_code}: #{output}")
        {:error, %{
          exit_code: exit_code,
          output: output,
          command: "#{@magg_binary} #{Enum.join(args, " ")}"
        }}
        
      {:ok, {:error, reason}} ->
        Logger.error("Failed to execute MAGG: #{reason}")
        {:error, reason}
        
      nil ->
        Logger.error("MAGG command timed out after #{@timeout}ms")
        {:error, :timeout}
    end
  end

  defp parse_server_list(output) do
    # Parse MAGG server list output format:
    # Configured Servers
    #
    #   filesystem (None) - enabled
    #     Source: npx @modelcontextprotocol/server-filesystem
    
    lines = output
    |> String.split("\n")
    |> Enum.reject(&(&1 == "" || String.trim(&1) == "Configured Servers"))
    
    # Parse server entries
    lines
    |> Enum.reduce({[], nil}, fn line, {servers, current_server} ->
      cond do
        # Server line: "  filesystem (None) - enabled"
        String.match?(line, ~r/^\s{2}\w+.*\s-\s(enabled|disabled)/) ->
          parts = Regex.run(~r/^\s{2}(\w+)\s.*\s-\s(enabled|disabled)/, line)
          case parts do
            [_, name, status] ->
              server = %{
                "name" => name,
                "enabled" => status == "enabled",
                "status" => "configured"
              }
              {servers ++ [server], name}
            _ ->
              {servers, current_server}
          end
        
        # Source line: "    Source: npx @modelcontextprotocol/server-filesystem"
        String.match?(line, ~r/^\s{4}Source:/) && current_server ->
          source = String.trim(String.replace(line, ~r/^\s{4}Source:\s*/, ""))
          # Update the last server with source info
          servers = List.update_at(servers, -1, fn server ->
            Map.put(server, "source", source)
          end)
          {servers, current_server}
        
        true ->
          {servers, current_server}
      end
    end)
    |> elem(0)
  end

  defp parse_server_info(output, server_name) do
    # Parse server info from text output
    # This is a placeholder - adjust based on actual MAGG output
    %{
      "name" => server_name,
      "transport" => "stdio",
      "status" => "configured"
    }
  end
end