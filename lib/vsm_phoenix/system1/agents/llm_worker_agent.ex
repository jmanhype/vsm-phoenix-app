defmodule VsmPhoenix.System1.Agents.LLMWorkerAgent do
  @moduledoc """
  S1 Worker Agent that IS an MCP client.
  Connects to MCP servers to acquire capabilities dynamically.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{Client, LLMBridge}
  alias VsmPhoenix.System1.Agents.WorkerAgent
  
  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end
  
  defdelegate get_status(agent_id), to: WorkerAgent
  
  def execute_command(agent_id, command) do
    GenServer.call({:global, agent_id}, {:execute_command, command}, 30_000)
  end
  
  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    config = Keyword.get(opts, :config, %{})
    
    Logger.info("🤖 LLM Worker Agent #{agent_id} initializing as MCP client...")
    
    # Start MCP client for this agent
    {:ok, mcp_client} = Client.start_link(agent_id: agent_id)
    
    # Connect to MCP servers if specified (handle both atom and string keys)
    mcp_servers = config[:mcp_servers] || config["mcp_servers"] || []
    Logger.info("📋 Full config received: #{inspect(config)}")
    Logger.info("🔌 MCP servers to connect: #{inspect(mcp_servers)}")
    
    # If we have servers to connect to, do it!
    connected_servers = if length(mcp_servers) > 0 do
      Logger.info("🚀 Auto-connecting to #{length(mcp_servers)} MCP servers on init...")
      connect_to_servers(mcp_client, mcp_servers)
    else
      Logger.info("⚠️  No MCP servers specified in config")
      %{}
    end
    
    state = %{
      agent_id: agent_id,
      mcp_client: mcp_client,
      connected_servers: connected_servers,
      config: config
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute_command, command}, _from, state) do
    result = case command["type"] do
      "connect_mcp" ->
        # The server command comes directly in the command params
        server_cmd = command["server"] || command["data"]["server"]
        connect_to_mcp_server(server_cmd, state)
        
      "list_tools" ->
        list_available_tools(state)
        
      "direct_tool" ->
        # Direct tool execution without LLM
        tool_name = command["tool"]
        arguments = command["arguments"] || %{}
        execute_direct_tool(tool_name, arguments, state)
        
      "spawn_specialists" ->
        # Spawn specialist agents with MCP servers
        spawn_specialist_agents(command["data"], state)
        
      "create_deep_hierarchy" ->
        # Create deep agent hierarchy
        create_deep_hierarchy(command["data"], state)
        
      "swarm_task" ->
        # Execute coordinated swarm task
        execute_swarm_task(command["data"], state)
        
      _ ->
        execute_with_llm(command, state)
    end
    
    {:reply, result, state}
  end
  
  defp execute_direct_tool(tool_name, arguments, state) do
    Logger.info("🔧 Direct tool execution: #{tool_name} with args: #{inspect(arguments)}")
    
    case Client.execute_tool(state.mcp_client, tool_name, arguments) do
      {:ok, %{"result" => %{"content" => [%{"type" => "text", "text" => text}]}}} ->
        # Handle MCP text content response format
        Logger.info("📦 Tool result with text content: #{inspect(text)}")
        {:ok, text}
        
      {:ok, %{"result" => %{"content" => content}}} when is_list(content) ->
        # Handle MCP content array format
        Logger.info("📦 Tool result with content array: #{inspect(content)}")
        {:ok, content}
        
      {:ok, %{"result" => %{"content" => content}}} ->
        # Handle MCP tool response with content field
        Logger.info("📦 Tool result with content: #{inspect(content)}")
        {:ok, content}
        
      {:ok, %{"result" => result}} when is_list(result) ->
        # Handle array results (like from filesystem operations)
        Logger.info("📦 Tool result (array): #{inspect(result)}")
        {:ok, result}
        
      {:ok, %{"result" => result}} ->
        Logger.info("📦 Tool result (unwrapped): #{inspect(result)}")
        {:ok, result}
        
      {:ok, %{"error" => error}} ->
        Logger.error("❌ MCP error response: #{inspect(error)}")
        {:error, error}
        
      {:ok, result} ->
        Logger.info("📦 Tool result (direct): #{inspect(result)}")
        {:ok, result}
        
      error ->
        Logger.error("❌ Tool execution error: #{inspect(error)}")
        error
    end
  end
  
  defp connect_to_servers(mcp_client, servers) do
    Logger.info("🔄 Attempting to connect to #{length(servers)} MCP servers...")
    
    Enum.map(servers, fn server ->
      Logger.info("🔌 Connecting to: #{server}")
      case Client.connect(mcp_client, server) do
        {:ok, info} ->
          Logger.info("✅ Connected to MCP server: #{server}")
          {server, info}
        error ->
          Logger.error("❌ Failed to connect to #{server}: #{inspect(error)}")
          nil
      end
    end)
    |> Enum.filter(& &1)
    |> Map.new()
  end
  
  defp connect_to_mcp_server(server_command, state) do
    # Extract server command from the command data
    actual_command = server_command || ""
    
    Logger.info("🔌 Agent #{state.agent_id} connecting to: #{actual_command}")
    
    case Client.connect(state.mcp_client, actual_command) do
      {:ok, info} ->
        {:ok, %{
          connected: true,
          server_info: info,
          message: "Connected to MCP server: #{actual_command}"
        }}
      error ->
        error
    end
  end
  
  defp list_available_tools(state) do
    case Client.list_tools(state.mcp_client) do
      {:ok, tools} ->
        {:ok, %{
          tools: tools,
          count: length(tools)
        }}
      error ->
        error
    end
  end
  
  defp execute_with_llm(command, state) do
    prompt = command["prompt"] || command["data"]["prompt"] || "Execute task"
    context = command["context"] || command["data"] || %{}
    
    Logger.info("🤖 LLM analyzing prompt: #{prompt}")
    Logger.info("📊 Context: #{inspect(context)}")
    
    # Use LLM to analyze and execute
    case LLMBridge.analyze_task(prompt, context, state.mcp_client) do
      {:ok, %{action: :execute_tool, tool_calls: tool_calls}} ->
        execute_tools(tool_calls, state)
        
      {:ok, %{action: :spawn_agents, spawn_config: config}} ->
        spawn_agents(config, state)
        
      {:ok, %{action: :both, tool_calls: tool_calls, spawn_config: spawn_config}} ->
        tool_results = execute_tools(tool_calls, state)
        spawn_results = spawn_agents(spawn_config, state)
        {:ok, %{tools: tool_results, agents: spawn_results}}
        
      error ->
        error
    end
  end
  
  defp execute_tools(tool_calls, state) do
    Logger.info("🔧 Executing #{length(tool_calls)} tool calls")
    
    results = Enum.map(tool_calls, fn %{"name" => name, "arguments" => args} ->
      Logger.info("📞 Calling tool: #{name} with args: #{inspect(args)}")
      
      case Client.execute_tool(state.mcp_client, name, args) do
        {:ok, result} -> 
          Logger.info("✅ Tool #{name} returned: #{inspect(result)}")
          %{tool: name, result: result}
        error -> 
          Logger.error("❌ Tool #{name} failed: #{inspect(error)}")
          %{tool: name, error: error}
      end
    end)
    
    {:ok, results}
  end
  
  defp spawn_specialist_agents(data, state) do
    specialists = data["specialists"] || []
    
    Logger.info("🚀 Spawning #{length(specialists)} specialist agents...")
    
    results = Enum.map(specialists, fn spec ->
      config = %{
        name: spec["name"],
        role: "specialist",
        level: 1,
        parent: state.agent_id,
        mcp_servers: [spec["mcp_server"]],
        amqp_routing_key: spec["routing_key"]
      }
      
      case VsmPhoenix.System1.Supervisor.spawn_agent(:llm_worker, config: config) do
        {:ok, agent_info} ->
          # Connect to MCP server immediately
          Task.start(fn ->
            Process.sleep(1000)  # Let agent initialize
            result = GenServer.call(
              {:global, agent_info.id},
              {:execute_command, %{"type" => "connect_mcp", "server" => spec["mcp_server"]}},
              30_000
            )
            Logger.info("🔌 #{spec["name"]} connected to MCP: #{inspect(result)}")
          end)
          
          Map.merge(agent_info, %{
            mcp_server: spec["mcp_server"],
            name: spec["name"],
            connected: true
          })
          
        error ->
          %{error: error}
      end
    end)
    
    {:ok, results}
  end
  
  defp create_deep_hierarchy(data, state) do
    max_depth = data["recursion_depth"] || 3
    hierarchy = data["hierarchy"] || %{}
    
    Logger.info("🌳 Creating deep hierarchy with max depth: #{max_depth}")
    
    # Recursive function to create hierarchy
    create_level = fn create_level, parent_id, level, branch ->
      if level >= max_depth do
        []
      else
        Enum.flat_map(branch, fn
          %{} = node_map ->
            # Handle map nodes
            Enum.flat_map(node_map, fn {agent_name, children} when is_list(children) ->
              # Create this agent
              config = %{
                name: agent_name,
                role: "sub-specialist",
                level: level,
                parent: parent_id,
                mcp_servers: []  # Sub-specialists may not need MCP
              }
              
              case VsmPhoenix.System1.Supervisor.spawn_agent(:llm_worker, config: config) do
                {:ok, agent_info} ->
                  # Recursively create children
                  child_results = create_level.(create_level, agent_info.id, level + 1, children)
                  [agent_info | child_results]
                  
                _ ->
                  []
              end
            end)
            
          agent_name when is_binary(agent_name) ->
            # Leaf node
            config = %{
              name: agent_name,
              role: "worker",
              level: level,
              parent: parent_id
            }
            
            case VsmPhoenix.System1.Supervisor.spawn_agent(:llm_worker, config: config) do
              {:ok, agent_info} -> [agent_info]
              _ -> []
            end
        end)
      end
    end
    
    # Start creating from level 1
    all_agents = create_level.(create_level, state.agent_id, 1, [hierarchy])
    
    {:ok, %{
      total_agents: length(all_agents),
      max_depth_achieved: max_depth,
      hierarchy_created: true
    }}
  end
  
  defp execute_swarm_task(data, state) do
    steps = data["steps"] || []
    
    Logger.info("🎪 Executing swarm task with #{length(steps)} steps")
    
    # Execute steps sequentially, passing context
    {results, _context} = Enum.reduce(steps, {[], %{}}, fn step, {acc_results, context} ->
      agent_name = step["agent"]
      action = step["action"]
      args = step["arguments"] || step["args"] || %{}
      output_key = step["output_key"]
      
      # Interpolate arguments with context values
      interpolated_args = interpolate_args(args, context)
      
      # Find the agent by name and execute the actual action
      result = case find_agent_by_name(agent_name) do
        {:ok, agent_id} ->
          # Execute the actual tool on the target agent
          tool_command = %{
            "type" => "direct_tool",
            "tool" => action,
            "arguments" => interpolated_args
          }
          
          case GenServer.call({:global, agent_id}, {:execute_command, tool_command}, 30_000) do
            {:ok, tool_result} ->
              %{
                agent: agent_name,
                action: action,
                status: "completed",
                output: tool_result
              }
            error ->
              %{
                agent: agent_name,
                action: action,
                status: "failed",
                error: error
              }
          end
          
        {:error, :not_found} ->
          %{
            agent: agent_name,
            action: action,
            status: "failed",
            error: "Agent not found"
          }
      end
      
      # Update context if output_key provided
      new_context = if output_key do
        Map.put(context, output_key, result.output)
      else
        context
      end
      
      {[result | acc_results], new_context}
    end)
    
    {:ok, %{
      task: "swarm_task",
      steps_completed: length(results),
      results: Enum.reverse(results)
    }}
  end
  
  defp interpolate_args(args, context) when is_map(args) do
    args
    |> Enum.map(fn {key, value} ->
      {key, interpolate_value(value, context)}
    end)
    |> Map.new()
  end
  
  defp interpolate_args(args, _context), do: args
  
  defp interpolate_value(value, context) when is_binary(value) do
    # Replace {{key}} with context values
    Regex.replace(~r/\{\{(\w+)\}\}/, value, fn _, key ->
      case Map.get(context, key) do
        nil -> "{{#{key}}}"  # Keep original if not found
        val -> to_string(val)
      end
    end)
  end
  
  defp interpolate_value(value, context) when is_map(value) do
    interpolate_args(value, context)
  end
  
  defp interpolate_value(value, _context), do: value
  
  defp find_agent_by_name(name) do
    # Search through all agents to find one with matching name
    agents = VsmPhoenix.System1.Registry.list_agents()
    
    case Enum.find(agents, fn agent ->
      agent.metadata[:config][:name] == name
    end) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent.agent_id}
    end
  end
  
  defp spawn_agents(nil, _state), do: {:ok, []}
  defp spawn_agents(config, state) do
    count = config["agent_count"] || 1
    types = config["agent_types"] || ["worker"]
    
    agents = Enum.map(1..count, fn i ->
      agent_type = Enum.at(types, rem(i-1, length(types)))
      
      spawn_config = %{
        parent: state.agent_id,
        mcp_servers: Map.keys(state.connected_servers)
      }
      
      case VsmPhoenix.System1.Supervisor.spawn_agent(:llm_worker, config: spawn_config) do
        {:ok, agent_info} -> agent_info
        error -> %{error: error}
      end
    end)
    
    {:ok, agents}
  end
end