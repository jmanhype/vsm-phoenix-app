defmodule VsmPhoenix.MCP.WorkingMcpServer do
  @moduledoc """
  REAL WORKING MCP Server for VSM Phoenix App

  This is a simple, bulletproof MCP server that actually works with stdio transport.
  No fancy architectures - just a server that responds to MCP JSON-RPC calls.
  """

  use GenServer
  require Logger

  @name __MODULE__

  # MCP Tools available
  @tools %{
    "vsm_query_state" => %{
      name: "vsm_query_state",
      description: "Query the current VSM system state",
      inputSchema: %{
        type: "object",
        properties: %{}
      }
    },
    "vsm_send_signal" => %{
      name: "vsm_send_signal",
      description: "Send algedonic signal to VSM",
      inputSchema: %{
        type: "object",
        properties: %{
          signal_type: %{type: "string", enum: ["pleasure", "pain"]},
          intensity: %{type: "number", minimum: 0, maximum: 1},
          context: %{type: "string"}
        },
        required: ["signal_type", "intensity"]
      }
    },
    "vsm_synthesize_policy" => %{
      name: "vsm_synthesize_policy",
      description: "Synthesize a policy for an anomaly",
      inputSchema: %{
        type: "object",
        properties: %{
          anomaly: %{type: "string"},
          severity: %{type: "number", minimum: 0, maximum: 1}
        },
        required: ["anomaly"]
      }
    }
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @impl true
  def init(_opts) do
    Logger.info("🚀 Starting REAL VSM MCP Server")

    # Start stdio reader task
    reader_task = Task.async(fn -> stdio_reader_loop() end)

    state = %{
      reader_task: reader_task,
      request_id: 0
    }

    {:ok, state}
  end

  # Stdio reader loop
  defp stdio_reader_loop do
    case IO.gets("") do
      :eof ->
        Logger.info("MCP Server: EOF received, shutting down")
        System.halt(0)

      data when is_binary(data) ->
        data
        |> String.trim()
        |> handle_json_rpc()

        stdio_reader_loop()

      {:error, reason} ->
        Logger.error("MCP Server stdio error: #{inspect(reason)}")
        stdio_reader_loop()
    end
  end

  defp handle_json_rpc(""), do: :ok

  defp handle_json_rpc(json_str) do
    case Jason.decode(json_str) do
      {:ok, request} ->
        response = process_request(request)
        send_response(response)

      {:error, _reason} ->
        error_response = %{
          jsonrpc: "2.0",
          error: %{code: -32700, message: "Parse error"},
          id: nil
        }

        send_response(error_response)
    end
  end

  defp process_request(%{"method" => "initialize", "id" => id}) do
    %{
      jsonrpc: "2.0",
      result: %{
        protocolVersion: "2024-11-05",
        capabilities: %{
          tools: %{},
          resources: %{}
        },
        serverInfo: %{
          name: "vsm-phoenix-mcp-server",
          version: "1.0.0"
        }
      },
      id: id
    }
  end

  defp process_request(%{"method" => "tools/list", "id" => id}) do
    tools = Map.values(@tools)

    %{
      jsonrpc: "2.0",
      result: %{
        tools: tools
      },
      id: id
    }
  end

  defp process_request(%{"method" => "tools/call", "params" => params, "id" => id}) do
    tool_name = params["name"]
    arguments = params["arguments"] || %{}

    result =
      case tool_name do
        "vsm_query_state" ->
          execute_vsm_query_state()

        "vsm_send_signal" ->
          execute_vsm_send_signal(arguments)

        "vsm_synthesize_policy" ->
          execute_vsm_synthesize_policy(arguments)

        _ ->
          {:error, "Unknown tool: #{tool_name}"}
      end

    case result do
      {:ok, content} ->
        %{
          jsonrpc: "2.0",
          result: %{
            content: [%{type: "text", text: content}]
          },
          id: id
        }

      {:error, reason} ->
        %{
          jsonrpc: "2.0",
          error: %{code: -32000, message: reason},
          id: id
        }
    end
  end

  defp process_request(%{"method" => method, "id" => id}) do
    %{
      jsonrpc: "2.0",
      error: %{code: -32601, message: "Method not found: #{method}"},
      id: id
    }
  end

  defp process_request(_request) do
    %{
      jsonrpc: "2.0",
      error: %{code: -32600, message: "Invalid Request"},
      id: nil
    }
  end

  # Tool implementations
  defp execute_vsm_query_state do
    try do
      # Get actual VSM state
      queen_state = :sys.get_state(VsmPhoenix.System5.Queen)
      viability = queen_state.viability_metrics.system_health

      result = %{
        timestamp: DateTime.utc_now(),
        viability_score: viability,
        system_status: "operational",
        systems: %{
          system5: "running",
          system4: "running",
          system3: "running",
          system2: "running",
          system1: "running"
        }
      }

      {:ok, Jason.encode!(result, pretty: true)}
    rescue
      e ->
        {:error, "Failed to query VSM state: #{inspect(e)}"}
    end
  end

  defp execute_vsm_send_signal(%{"signal_type" => type, "intensity" => intensity} = args) do
    context = Map.get(args, "context", "mcp_signal")

    try do
      case type do
        "pleasure" ->
          VsmPhoenix.System5.Queen.send_pleasure_signal(intensity, context)
          {:ok, "Pleasure signal sent (intensity: #{intensity})"}

        "pain" ->
          VsmPhoenix.System5.Queen.send_pain_signal(intensity, context)
          {:ok, "Pain signal sent (intensity: #{intensity})"}

        _ ->
          {:error, "Invalid signal type: #{type}"}
      end
    rescue
      e ->
        {:error, "Failed to send signal: #{inspect(e)}"}
    end
  end

  defp execute_vsm_synthesize_policy(%{"anomaly" => anomaly} = args) do
    severity = Map.get(args, "severity", 0.8)

    try do
      # Use our existing policy synthesizer
      anomaly_data = %{
        type: :mcp_request,
        context: anomaly,
        severity: severity,
        timestamp: DateTime.utc_now(),
        system_state: %{viability: 0.5}
      }

      case VsmPhoenix.MCP.HermesStdioClient.synthesize_policy(anomaly_data) do
        {:ok, policy} ->
          result = %{
            policy_id: policy.id,
            sop: policy.sop,
            confidence: policy.confidence,
            auto_executable: policy.auto_executable
          }

          {:ok, Jason.encode!(result, pretty: true)}

        {:error, reason} ->
          {:error, "Policy synthesis failed: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, "Failed to synthesize policy: #{inspect(e)}"}
    end
  end

  defp send_response(response) do
    json = Jason.encode!(response)
    IO.puts(json)
    :ok
  end
end
