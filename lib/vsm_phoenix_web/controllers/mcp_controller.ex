defmodule VsmPhoenixWeb.MCPController do
  @moduledoc """
  MCP (Model Context Protocol) Controller for handling JSON-RPC requests.
  
  This controller implements the MCP transport layer for Phoenix,
  forwarding requests to appropriate handlers and managing CORS headers
  for MCP compatibility.
  """
  
  use VsmPhoenixWeb, :controller
  require Logger
  
  @content_type "application/json"
  @cors_headers [
    {"access-control-allow-origin", "*"},
    {"access-control-allow-methods", "GET, POST, OPTIONS"},
    {"access-control-allow-headers", "content-type, authorization"},
    {"access-control-max-age", "86400"}
  ]
  
  # JSON-RPC 2.0 error codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603
  
  @doc """
  Handles preflight CORS requests
  """
  def options(conn, _params) do
    conn
    |> put_cors_headers()
    |> send_resp(204, "")
  end
  
  @doc """
  Main entry point for MCP JSON-RPC requests.
  
  Forwards requests to Hermes.Server.Transport.StreamableHTTP.Plug
  or handles them directly if Hermes is not available.
  """
  def handle(conn, params) do
    Logger.debug("MCP Controller params: #{inspect(params)}")
    
    # If params already contains the JSON-RPC request, use it directly
    if Map.has_key?(params, "jsonrpc") do
      json_rpc = %{
        id: params["id"],
        method: params["method"],
        params: params["params"] || %{}
      }
      
      case process_request(json_rpc) do
        {:ok, response} ->
          conn
          |> put_cors_headers()
          |> put_resp_content_type(@content_type)
          |> send_resp(200, encode_response(response))
          
        {:error, {reason, id}} ->
          Logger.error("MCP request error: #{inspect(reason)}")
          send_json_rpc_error(conn, id, @internal_error, "Internal error")
      end
    else
      # Fall back to reading the body
      with {:ok, body, conn} <- read_request_body(conn),
           {:ok, json_rpc} <- decode_json_rpc(body),
           {:ok, response} <- process_request(json_rpc) do
        
        conn
        |> put_cors_headers()
        |> put_resp_content_type(@content_type)
        |> send_resp(200, encode_response(response))
      else
      {:error, :parse_error} ->
        send_json_rpc_error(conn, nil, @parse_error, "Parse error")
        
      {:error, :invalid_request} ->
        send_json_rpc_error(conn, nil, @invalid_request, "Invalid request")
        
      {:error, {:method_not_found, id}} ->
        send_json_rpc_error(conn, id, @method_not_found, "Method not found")
        
      {:error, {:invalid_params, id}} ->
        send_json_rpc_error(conn, id, @invalid_params, "Invalid params")
        
      {:error, {reason, id}} ->
        Logger.error("MCP request error: #{inspect(reason)}")
        send_json_rpc_error(conn, id, @internal_error, "Internal error")
      end
    end
  end
  
  @doc """
  Health check endpoint for MCP service
  """
  def health(conn, _params) do
    status = %{
      status: "healthy",
      protocol: "mcp/1.0",
      transport: "http",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      capabilities: %{
        json_rpc: "2.0",
        streaming: check_streaming_support(),
        methods: get_supported_methods()
      }
    }
    
    conn
    |> put_cors_headers()
    |> json(status)
  end
  
  # Private functions
  
  defp read_request_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} -> 
        Logger.debug("MCP Request body: #{inspect(body)}")
        {:ok, body, conn}
      {:more, _partial, _conn} -> {:error, :body_too_large}
      {:error, _reason} -> {:error, :read_error}
    end
  end
  
  defp decode_json_rpc(body) do
    case Jason.decode(body) do
      {:ok, %{"jsonrpc" => "2.0", "method" => method, "id" => id} = request} ->
        {:ok, %{
          id: id,
          method: method,
          params: Map.get(request, "params", %{})
        }}
        
      {:ok, _} ->
        {:error, :invalid_request}
        
      {:error, _} ->
        {:error, :parse_error}
    end
  end
  
  defp process_request(%{id: id, method: method, params: params}) do
    # Handle directly - Hermes forwarding needs different implementation
    handle_mcp_request(id, method, params)
  end
  
  defp forward_to_hermes(id, method, params) do
    try do
      # Attempt to forward the request to Hermes
      case Hermes.Server.Transport.StreamableHTTP.Plug.process_json_rpc(id, method, params) do
        {:ok, result} -> {:ok, build_success_response(id, result)}
        {:error, reason} -> {:error, {reason, id}}
      end
    rescue
      error ->
        Logger.error("Hermes forwarding error: #{inspect(error)}")
        handle_mcp_request(id, method, params)
    end
  end
  
  defp handle_mcp_request(id, method, params) do
    # Direct MCP method handling
    # Strip "mcp/" prefix if present
    normalized_method = case method do
      "mcp/" <> rest -> rest
      other -> other
    end
    
    case normalized_method do
      "initialize" ->
        handle_initialize(id, params)
        
      "ping" ->
        {:ok, build_success_response(id, %{pong: true, timestamp: DateTime.utc_now()})}
        
      "list_tools" ->
        handle_list_tools(id, params)
        
      "call_tool" ->
        handle_call_tool(id, params)
        
      "list_resources" ->
        handle_list_resources(id, params)
        
      "read_resource" ->
        handle_read_resource(id, params)
        
      _ ->
        {:error, {:method_not_found, id}}
    end
  end
  
  defp handle_initialize(id, params) do
    response = %{
      protocolVersion: "1.0",
      capabilities: %{
        tools: %{
          enabled: true
        },
        resources: %{
          enabled: true,
          subscribe: false
        },
        prompts: %{
          enabled: false
        },
        logging: %{
          enabled: true
        }
      },
      serverInfo: %{
        name: "vsm-phoenix-mcp",
        version: "1.0.0"
      }
    }
    
    {:ok, build_success_response(id, response)}
  end
  
  defp handle_list_tools(id, _params) do
    tools = [
      %{
        name: "vsm_status",
        description: "Get VSM system status",
        inputSchema: %{
          type: "object",
          properties: %{
            system_level: %{
              type: "integer",
              description: "VSM system level (1-5)",
              minimum: 1,
              maximum: 5
            }
          }
        }
      },
      %{
        name: "queen_decision",
        description: "Request a policy decision from System 5 (Queen)",
        inputSchema: %{
          type: "object",
          properties: %{
            decision_type: %{type: "string"},
            context: %{type: "object"}
          },
          required: ["decision_type"]
        }
      },
      %{
        name: "algedonic_signal",
        description: "Send pleasure/pain signal through VSM",
        inputSchema: %{
          type: "object",
          properties: %{
            signal: %{type: "string", enum: ["pleasure", "pain"]},
            intensity: %{type: "number", minimum: 0, maximum: 1},
            context: %{type: "string"}
          },
          required: ["signal"]
        }
      }
    ]
    
    {:ok, build_success_response(id, %{tools: tools})}
  end
  
  defp handle_call_tool(id, %{"name" => tool_name, "arguments" => args}) do
    result = case tool_name do
      "vsm_status" ->
        call_vsm_status(args)
        
      "queen_decision" ->
        call_queen_decision(args)
        
      "algedonic_signal" ->
        call_algedonic_signal(args)
        
      _ ->
        {:error, "Unknown tool: #{tool_name}"}
    end
    
    case result do
      {:ok, content} ->
        {:ok, build_success_response(id, %{content: [%{type: "text", text: Jason.encode!(content)}]})}
        
      {:error, reason} ->
        {:error, {reason, id}}
    end
  end
  
  defp handle_list_resources(id, _params) do
    resources = [
      %{
        uri: "vsm://systems/overview",
        name: "VSM Systems Overview",
        description: "Overview of all VSM systems",
        mimeType: "application/json"
      },
      %{
        uri: "vsm://config/current",
        name: "Current VSM Configuration",
        description: "Current configuration of the VSM",
        mimeType: "application/json"
      }
    ]
    
    {:ok, build_success_response(id, %{resources: resources})}
  end
  
  defp handle_read_resource(id, %{"uri" => uri}) do
    content = case uri do
      "vsm://systems/overview" ->
        get_vsm_overview()
        
      "vsm://config/current" ->
        get_vsm_config()
        
      _ ->
        nil
    end
    
    if content do
      {:ok, build_success_response(id, %{
        contents: [%{
          uri: uri,
          mimeType: "application/json",
          text: Jason.encode!(content)
        }]
      })}
    else
      {:error, {"Resource not found: #{uri}", id}}
    end
  end
  
  # VSM integration helpers
  
  defp call_vsm_status(%{"system_level" => level}) do
    # Get system module based on level
    system_module = case to_string(level) do
      "5" -> VsmPhoenix.System5.Queen
      "4" -> VsmPhoenix.System4.Intelligence
      "3" -> VsmPhoenix.System3.Control
      "2" -> VsmPhoenix.System2.Coordinator
      "1" -> :operations_context
      _ -> nil
    end
    
    if system_module do
      status = get_detailed_system_status(system_module)
      {:ok, status}
    else
      {:error, "Invalid system level"}
    end
  end
  
  defp get_detailed_system_status(module_or_name) do
    try do
      process_name = case module_or_name do
        :operations_context -> :operations_context
        module -> module
      end
      
      case GenServer.whereis(process_name) do
        nil ->
          %{
            status: "not_running",
            pid: nil,
            details: %{error: "System not started"}
          }

        pid ->
          # Basic status information
          basic_status = %{
            status: "running",
            pid: inspect(pid),
            uptime: get_process_info(pid, :message_queue_len),
            memory: get_process_info(pid, :memory)
          }

          # Add system-specific details
          details = case module_or_name do
            VsmPhoenix.System5.Queen ->
              %{
                type: "Policy & Governance",
                description: "System 5 - Ultimate authority and policy decisions",
                capabilities: ["policy_governance", "strategic_planning", "system_balance"]
              }

            VsmPhoenix.System4.Intelligence ->
              %{
                type: "Intelligence & Future Planning",
                description: "System 4 - Environmental scanning and adaptation",
                capabilities: ["environmental_scanning", "future_planning", "tidewave_integration"]
              }

            VsmPhoenix.System3.Control ->
              %{
                type: "Control & Optimization",
                description: "System 3 - Resource allocation and optimization",
                capabilities: ["resource_control", "performance_optimization", "audit_management"]
              }

            VsmPhoenix.System2.Coordinator ->
              %{
                type: "Coordination & Anti-oscillation",
                description: "System 2 - Information flow coordination",
                capabilities: ["message_coordination", "anti_oscillation", "information_routing"]
              }

            :operations_context ->
              %{
                type: "Operations & Delivery",
                description: "System 1 - Primary operational activities",
                capabilities: ["order_processing", "customer_service", "inventory_management"]
              }
          end

          Map.put(basic_status, :details, details)
      end
    rescue
      error ->
        %{
          status: "error",
          pid: nil,
          details: %{error: inspect(error)}
        }
    end
  end
  
  defp get_process_info(pid, key) do
    case Process.info(pid, key) do
      {^key, value} -> value
      nil -> "unavailable"
    end
  end
  
  defp call_queen_decision(args) do
    alias VsmPhoenix.System5.Queen
    
    case Queen.make_policy_decision(args) do
      {:ok, decision} -> {:ok, %{decision: decision, timestamp: DateTime.utc_now()}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp call_algedonic_signal(%{"signal" => signal} = args) do
    alias VsmPhoenix.System5.Queen
    
    intensity = Map.get(args, "intensity", 0.5)
    context = Map.get(args, "context", "MCP request")
    
    case signal do
      "pleasure" ->
        :ok = Queen.send_pleasure_signal(intensity, context)
        {:ok, %{status: "pleasure_signal_sent", intensity: intensity}}
        
      "pain" ->
        :ok = Queen.send_pain_signal(intensity, context)
        {:ok, %{status: "pain_signal_sent", intensity: intensity}}
        
      _ ->
        {:error, "Invalid signal type"}
    end
  end
  
  defp get_vsm_overview do
    %{
      system5: %{
        name: "Policy and Governance",
        description: "Ultimate authority, policy decisions, and system balance"
      },
      system4: %{
        name: "Intelligence and Future Planning",
        description: "Environmental scanning and adaptation"
      },
      system3: %{
        name: "Control and Optimization",
        description: "Resource allocation and performance optimization"
      },
      system2: %{
        name: "Coordination",
        description: "Information flow coordination and anti-oscillation"
      },
      system1: %{
        name: "Operations",
        description: "Primary operational activities and delivery"
      }
    }
  end
  
  defp get_vsm_config do
    %{
      version: "1.0.0",
      environment: Application.get_env(:vsm_phoenix, :environment, :dev),
      features: %{
        algedonic_signals: true,
        tidewave_integration: true,
        neural_processing: false
      },
      timestamp: DateTime.utc_now()
    }
  end
  
  # Response helpers
  
  defp build_success_response(id, result) do
    %{
      jsonrpc: "2.0",
      id: id,
      result: result
    }
  end
  
  defp send_json_rpc_error(conn, id, code, message) do
    response = %{
      jsonrpc: "2.0",
      id: id,
      error: %{
        code: code,
        message: message
      }
    }
    
    conn
    |> put_cors_headers()
    |> put_resp_content_type(@content_type)
    |> send_resp(200, Jason.encode!(response))
  end
  
  defp encode_response(response) do
    Jason.encode!(response)
  end
  
  defp put_cors_headers(conn) do
    Enum.reduce(@cors_headers, conn, fn {key, value}, acc ->
      put_resp_header(acc, key, value)
    end)
  end
  
  defp check_streaming_support do
    Code.ensure_loaded?(Hermes.Server.Transport.StreamableHTTP.Plug)
  end
  
  defp get_supported_methods do
    base_methods = ["initialize", "ping", "list_tools", "call_tool", "list_resources", "read_resource"]
    
    if check_streaming_support() do
      base_methods ++ ["stream_resource", "subscribe"]
    else
      base_methods
    end
  end
end