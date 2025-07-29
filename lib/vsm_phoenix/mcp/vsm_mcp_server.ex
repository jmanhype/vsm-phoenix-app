defmodule VsmPhoenix.MCP.VsmMcpServer do
  @moduledoc """
  VSM MCP Server - Exposes VSM capabilities as MCP tools
  
  This server allows other systems (including other VSMs!) to interact
  with this VSM via the Model Context Protocol, enabling:
  
  - Recursive VSM-to-VSM communication
  - External variety sources connecting to S4
  - Policy synthesis requests to S5
  - Meta-system spawning triggers
  - Resource allocation negotiations
  
  THIS IS THE VSMCP PROTOCOL IN ACTION!
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.VsmTools
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Register this VSM as an MCP server
  """
  def register_as_mcp_server do
    GenServer.call(@name, :register_server)
  end
  
  @doc """
  Handle incoming MCP requests
  """
  def handle_mcp_request(request) do
    GenServer.call(@name, {:handle_request, request})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("🚀 VSM MCP Server initializing...")
    
    state = %{
      server_id: "vsm_#{node()}_#{:erlang.unique_integer([:positive])}",
      capabilities: VsmTools.list_tools(),
      active_connections: %{},
      config: opts
    }
    
    # Register with Hermes MCP if available
    if opts[:auto_register] do
      register_with_hermes(state)
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:register_server, _from, state) do
    Logger.info("📡 Registering VSM as MCP server")
    
    registration = %{
      name: "VSM Phoenix MCP Server",
      version: "1.0.0",
      protocol_version: "1.0",
      capabilities: %{
        tools: state.capabilities,
        resources: list_vsm_resources(),
        prompts: list_vsm_prompts()
      }
    }
    
    {:reply, {:ok, registration}, state}
  end
  
  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    Logger.info("🔧 Processing MCP request: #{request.method}")
    
    response = case request.method do
      "initialize" ->
        handle_initialize(request, state)
        
      "tools/list" ->
        {:ok, %{tools: state.capabilities}}
        
      "tools/call" ->
        handle_tool_call(request.params, state)
        
      "resources/list" ->
        {:ok, %{resources: list_vsm_resources()}}
        
      "resources/read" ->
        handle_resource_read(request.params)
        
      "prompts/list" ->
        {:ok, %{prompts: list_vsm_prompts()}}
        
      "prompts/get" ->
        handle_prompt_get(request.params)
        
      _ ->
        {:error, "Unknown method: #{request.method}"}
    end
    
    {:reply, response, state}
  end
  
  # Private Functions
  
  defp register_with_hermes(state) do
    # Register this VSM as an MCP server with Hermes
    Logger.info("🔌 Registering with Hermes MCP...")
    
    # This would connect to Hermes MCP registry
    # For now, we'll just log it
    :ok
  end
  
  defp handle_initialize(_request, state) do
    {:ok, %{
      protocolVersion: "1.0",
      serverInfo: %{
        name: "VSM Phoenix",
        version: "1.0.0",
        vsm_hierarchy: %{
          s5: "Policy Governance",
          s4: "Intelligence & Adaptation",
          s3: "Resource Control",
          s2: "Coordination",
          s1: "Operations"
        }
      },
      capabilities: %{
        tools: state.capabilities,
        resources: %{
          list: true,
          read: true
        },
        prompts: %{
          list: true,
          get: true
        }
      }
    }}
  end
  
  defp handle_tool_call(params, _state) do
    tool_name = params["name"]
    tool_args = params["arguments"] || %{}
    
    case VsmTools.execute(tool_name, tool_args) do
      {:ok, result} ->
        {:ok, %{
          content: [
            %{
              type: "text",
              text: Jason.encode!(result)
            }
          ]
        }}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp list_vsm_resources do
    [
      %{
        uri: "vsm://system5/policies",
        name: "System 5 Policies",
        description: "Active governance policies",
        mimeType: "application/json"
      },
      %{
        uri: "vsm://system4/environmental-scan",
        name: "Environmental Scan Data",
        description: "Latest S4 intelligence scan",
        mimeType: "application/json"
      },
      %{
        uri: "vsm://system3/resources",
        name: "Resource Allocation",
        description: "Current resource allocation state",
        mimeType: "application/json"
      },
      %{
        uri: "vsm://system1/contexts",
        name: "Operational Contexts",
        description: "Active S1 operational units",
        mimeType: "application/json"
      },
      %{
        uri: "vsm://meta/systems",
        name: "Meta-VSM Registry",
        description: "Spawned recursive VSMs",
        mimeType: "application/json"
      }
    ]
  end
  
  defp handle_resource_read(params) do
    uri = params["uri"]
    
    # Parse VSM URI and fetch data
    case parse_vsm_uri(uri) do
      {:ok, {system, resource}} ->
        data = fetch_vsm_resource(system, resource)
        {:ok, %{
          contents: [
            %{
              uri: uri,
              mimeType: "application/json",
              text: Jason.encode!(data)
            }
          ]
        }}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp list_vsm_prompts do
    [
      %{
        id: "vsm_analyze_variety",
        name: "Analyze Variety Explosion",
        description: "Analyze if current variety exceeds VSM capacity"
      },
      %{
        id: "vsm_policy_synthesis",
        name: "Synthesize Adaptive Policy",
        description: "Generate policy from anomaly pattern"
      },
      %{
        id: "vsm_meta_spawn",
        name: "Design Meta-VSM",
        description: "Design recursive VSM for specialized domain"
      }
    ]
  end
  
  defp handle_prompt_get(params) do
    prompt_id = params["id"]
    
    prompt = case prompt_id do
      "vsm_analyze_variety" ->
        """
        Analyze the following data for variety patterns that might exceed current VSM capacity:
        
        {{SCAN_DATA}}
        
        Consider:
        1. Novel patterns not currently handled
        2. Emergent behaviors requiring new capabilities
        3. Recursive opportunities for meta-system spawning
        4. External connections that could amplify variety
        
        Recommend if meta-VSM spawning is needed.
        """
        
      "vsm_policy_synthesis" ->
        """
        Generate an adaptive policy for the following anomaly:
        
        {{ANOMALY_DATA}}
        
        Include:
        1. Standard Operating Procedure (SOP)
        2. Mitigation steps with priorities
        3. Success criteria and KPIs
        4. Recursive triggers for meta-VSM spawning
        5. Auto-execution safety boundaries
        """
        
      "vsm_meta_spawn" ->
        """
        Design a recursive meta-VSM for the following specialized domain:
        
        {{DOMAIN_DESCRIPTION}}
        
        Specify:
        1. Identity and purpose
        2. S3-4-5 subsystem configurations
        3. Autonomy level and constraints
        4. Parent VSM integration points
        5. Recursive spawning conditions
        """
        
      _ ->
        nil
    end
    
    if prompt do
      {:ok, %{
        prompt: prompt,
        arguments: extract_prompt_arguments(prompt)
      }}
    else
      {:error, "Unknown prompt: #{prompt_id}"}
    end
  end
  
  defp parse_vsm_uri(uri) do
    case String.split(uri, "://") do
      ["vsm", path] ->
        [system | resource_parts] = String.split(path, "/")
        {:ok, {system, Enum.join(resource_parts, "/")}}
        
      _ ->
        {:error, "Invalid VSM URI format"}
    end
  end
  
  defp fetch_vsm_resource("system5", "policies") do
    # Fetch active policies from S5
    %{policies: ["POL-123", "POL-456"], count: 2}
  end
  
  defp fetch_vsm_resource("system4", "environmental-scan") do
    # Fetch latest scan from S4
    %{timestamp: DateTime.utc_now(), patterns: %{}, anomalies: []}
  end
  
  defp fetch_vsm_resource("system3", "resources") do
    # Fetch resource state from S3
    %{compute: 0.7, memory: 0.8, network: 0.5}
  end
  
  defp fetch_vsm_resource("system1", "contexts") do
    # List active S1 contexts
    %{contexts: [:operations_context], count: 1}
  end
  
  defp fetch_vsm_resource("meta", "systems") do
    # List spawned meta-VSMs
    %{meta_vsms: [], count: 0}
  end
  
  defp fetch_vsm_resource(_, _), do: %{error: "Unknown resource"}
  
  defp extract_prompt_arguments(prompt) do
    prompt
    |> String.split("{{")
    |> Enum.drop(1)
    |> Enum.map(fn part ->
      [arg | _] = String.split(part, "}}")
      %{
        name: String.downcase(arg),
        description: "Input for #{arg}",
        required: true
      }
    end)
  end
end