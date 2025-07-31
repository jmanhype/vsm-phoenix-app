defmodule VsmPhoenix.MCP.VsmTools do
  @moduledoc """
  VSM-specific MCP Tools exposed via Hermes MCP
  
  These tools allow external systems to interact with the VSM hierarchy,
  enabling recursive VSM-to-VSM communication and meta-system spawning.
  """
  
  require Logger
  
  alias VsmPhoenix.System1.Operations
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.MCP.VsmTools.HiveCoordination
  
  @behaviour HermesMCP.Tool
  
  @doc """
  List all available VSM tools
  """
  def list_tools do
    # Tools from registered Hermes components
    hermes_tools = [
      %{
        name: "analyze_variety",
        description: "Analyze variety data and return patterns and recommendations",
        inputSchema: %{
          type: "object",
          properties: %{
            variety_data: %{type: "object"},
            context: %{type: "object"}
          },
          required: ["variety_data"]
        }
      },
      %{
        name: "synthesize_policy",
        description: "Synthesize policy from anomaly data",
        inputSchema: %{
          type: "object",
          properties: %{
            anomaly_type: %{type: "string"},
            severity: %{type: "number", minimum: 0, maximum: 1},
            context: %{type: "object"}
          },
          required: ["anomaly_type", "severity"]
        }
      },
      %{
        name: "check_meta_system_need",
        description: "Check if a meta-system needs to be spawned",
        inputSchema: %{
          type: "object",
          properties: %{
            complexity_level: %{type: "string"},
            resource_strain: %{type: "number"},
            anomaly_count: %{type: "integer"}
          },
          required: ["complexity_level"]
        }
      }
    ]
    
    # Additional VSM tools
    base_tools = [
      %{
        name: "vsm_scan_environment",
        description: "Scan environment for variety and anomalies via System 4",
        inputSchema: %{
          type: "object",
          properties: %{
            scope: %{type: "string", enum: ["full", "scheduled", "targeted"]},
            include_llm: %{type: "boolean", default: true}
          }
        }
      },
      %{
        name: "vsm_synthesize_policy", 
        description: "Generate policy from anomaly via System 5",
        inputSchema: %{
          type: "object",
          properties: %{
            anomaly_type: %{type: "string"},
            severity: %{type: "number", minimum: 0, maximum: 1},
            context: %{type: "object"}
          },
          required: ["anomaly_type", "severity"]
        }
      },
      %{
        name: "vsm_spawn_meta_system",
        description: "Spawn a recursive meta-VSM with S3-4-5 subsystems",
        inputSchema: %{
          type: "object", 
          properties: %{
            identity: %{type: "string"},
            purpose: %{type: "string"},
            recursive_depth: %{type: "integer", minimum: 1},
            parent_context: %{type: "string"}
          },
          required: ["identity", "purpose"]
        }
      },
      %{
        name: "vsm_allocate_resources",
        description: "Request resource allocation via System 3",
        inputSchema: %{
          type: "object",
          properties: %{
            resources: %{type: "object"},
            priority: %{type: "string", enum: ["low", "normal", "high", "critical"]},
            context: %{type: "string"}
          },
          required: ["resources"]
        }
      },
      %{
        name: "vsm_check_viability",
        description: "Check overall VSM viability via System 5",
        inputSchema: %{
          type: "object",
          properties: %{
            include_subsystems: %{type: "boolean", default: true}
          }
        }
      },
      %{
        name: "vsm_trigger_adaptation",
        description: "Trigger adaptation proposal via System 4",
        inputSchema: %{
          type: "object",
          properties: %{
            challenge: %{type: "object"},
            urgency: %{type: "string", enum: ["low", "medium", "high"]}
          },
          required: ["challenge"]
        }
      },
      %{
        name: "vsm_coordinate_message",
        description: "Send coordinated message between System 1 contexts",
        inputSchema: %{
          type: "object",
          properties: %{
            from_context: %{type: "string"},
            to_context: %{type: "string"},
            message: %{type: "object"}
          },
          required: ["from_context", "to_context", "message"]
        }
      },
      %{
        name: "vsm_query_meta_systems",
        description: "Query active meta-VSMs and their status",
        inputSchema: %{
          type: "object",
          properties: %{
            filter: %{type: "string", enum: ["all", "active", "policy_domain"]}
          }
        }
      }
    ]
    
    # Combine all tools: Hermes components + VSM tools + hive coordination tools
    hive_tools = HiveCoordination.list_hive_tools()
    hermes_tools ++ base_tools ++ hive_tools
  end
  
  @doc """
  Execute a VSM tool
  """
  def execute(tool_name, params) do
    Logger.info("🔧 Executing VSM MCP tool: #{tool_name}")
    
    case tool_name do
      # Hermes component tools (these are handled by Hermes itself)
      "analyze_variety" ->
        # This is handled by the AnalyzeVariety component through Hermes
        {:ok, %{status: "delegated_to_hermes", tool: tool_name}}
        
      "synthesize_policy" ->
        # Delegate to our synthesize_policy implementation
        synthesize_policy(params)
        
      "check_meta_system_need" ->
        # This is handled by the CheckMetaSystemNeed component through Hermes
        {:ok, %{status: "delegated_to_hermes", tool: tool_name}}
        
      # VSM tools
      "vsm_scan_environment" ->
        scan_environment(params)
        
      "vsm_synthesize_policy" ->
        synthesize_policy(params)
        
      "vsm_spawn_meta_system" ->
        spawn_meta_system(params)
        
      "vsm_allocate_resources" ->
        allocate_resources(params)
        
      "vsm_check_viability" ->
        check_viability(params)
        
      "vsm_trigger_adaptation" ->
        trigger_adaptation(params)
        
      "vsm_coordinate_message" ->
        coordinate_message(params)
        
      "vsm_query_meta_systems" ->
        query_meta_systems(params)
        
      # Hive coordination tools
      "hive_" <> _ ->
        HiveCoordination.execute_hive_tool(tool_name, params)
        
      _ ->
        {:error, "Unknown tool: #{tool_name}"}
    end
  end
  
  # Tool implementations
  
  defp scan_environment(params) do
    scope = String.to_atom(params["scope"] || "full")
    
    case Intelligence.scan_environment(scope) do
      insights when is_map(insights) ->
        {:ok, %{
          insights: insights,
          timestamp: DateTime.utc_now(),
          llm_enabled: params["include_llm"] || true
        }}
      error ->
        error
    end
  end
  
  defp synthesize_policy(params) do
    anomaly_data = %{
      type: String.to_atom(params["anomaly_type"]),
      severity: params["severity"],
      context: params["context"] || %{},
      timestamp: DateTime.utc_now()
    }
    
    # Direct call to Queen for policy synthesis
    GenServer.cast(VsmPhoenix.System5.Queen, {:anomaly_detected, anomaly_data})
    
    {:ok, %{
      status: "policy_synthesis_initiated",
      anomaly: anomaly_data
    }}
  end
  
  defp spawn_meta_system(params) do
    meta_config = %{
      identity: params["identity"],
      purpose: params["purpose"],
      recursive_depth: params["recursive_depth"] || 1,
      parent_context: params["parent_context"] || "operations_context"
    }
    
    case Operations.spawn_meta_system(meta_config) do
      {:ok, result} ->
        {:ok, %{
          meta_vsm_id: result.identity,
          supervisor_pid: inspect(result.supervisor),
          status: "spawned",
          config: meta_config
        }}
      error ->
        error
    end
  end
  
  defp allocate_resources(params) do
    request = %{
      resources: params["resources"],
      priority: String.to_atom(params["priority"] || "normal"),
      context: params["context"] || "mcp_request"
    }
    
    case Control.allocate_resources(request) do
      {:ok, allocation_id} ->
        {:ok, %{
          allocation_id: allocation_id,
          status: "allocated",
          request: request
        }}
      error ->
        error
    end
  end
  
  defp check_viability(_params) do
    case Queen.evaluate_viability() do
      viability when is_map(viability) ->
        {:ok, %{
          viability_metrics: viability,
          timestamp: DateTime.utc_now(),
          recommendation: analyze_viability(viability)
        }}
      error ->
        error
    end
  end
  
  defp trigger_adaptation(params) do
    challenge = params["challenge"]
    
    case Intelligence.generate_adaptation_proposal(challenge) do
      proposal when is_map(proposal) ->
        {:ok, %{
          proposal_id: proposal.id,
          actions: proposal.actions,
          timeline: proposal.timeline,
          status: "generated"
        }}
      error ->
        error
    end
  end
  
  defp coordinate_message(params) do
    # This would use System 2 coordinator
    {:ok, %{
      status: "message_coordinated",
      from: params["from_context"],
      to: params["to_context"],
      coordination_id: "COORD-#{:erlang.unique_integer([:positive])}"
    }}
  end
  
  defp query_meta_systems(params) do
    # Query active meta-VSMs
    # In production, this would query actual meta-VSM registry
    {:ok, %{
      meta_systems: [
        %{
          id: "policy_vsm_POL-123",
          type: "policy_domain",
          status: "active",
          spawned_at: DateTime.utc_now()
        }
      ],
      filter: params["filter"] || "all",
      count: 1
    }}
  end
  
  defp analyze_viability(metrics) do
    cond do
      metrics.overall_viability > 0.8 -> "System healthy and viable"
      metrics.overall_viability > 0.6 -> "System functional but requires optimization"
      metrics.overall_viability > 0.4 -> "System stressed, intervention recommended"
      true -> "Critical: Immediate intervention required"
    end
  end
end