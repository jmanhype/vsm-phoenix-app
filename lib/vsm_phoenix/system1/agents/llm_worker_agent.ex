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
    
    # Set up AMQP for conversation requests
    # Use agent_id as channel purpose to ensure uniqueness
    channel = case VsmPhoenix.AMQP.ConnectionManager.get_channel(String.to_atom(agent_id)) do
      {:ok, ch} -> 
        Logger.info("✅ Got AMQP channel for #{agent_id}")
        ch
      {:error, reason} ->
        Logger.error("Failed to get AMQP channel: #{inspect(reason)}")
        # Create a fallback connection
        case establish_fallback_channel() do
          {:ok, ch} -> ch
          _ -> raise "Cannot establish AMQP connection"
        end
    end
    
    # Declare exchanges
    :ok = AMQP.Exchange.declare(channel, "vsm.llm.requests", :topic, durable: true)
    :ok = AMQP.Exchange.declare(channel, "vsm.llm.responses", :topic, durable: true)
    
    # Create queue for this worker
    queue_name = "vsm.llm.worker.#{agent_id}"
    {:ok, _queue} = AMQP.Queue.declare(channel, queue_name, durable: true)
    
    # Bind to conversation requests
    :ok = AMQP.Queue.bind(channel, queue_name, "vsm.llm.requests", routing_key: "llm.request.conversation")
    
    # Start consuming
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue_name)
    
    state = %{
      agent_id: agent_id,
      mcp_client: mcp_client,
      connected_servers: connected_servers,
      config: config,
      channel: channel
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
        
      "conversation" ->
        # Handle conversational request
        process_conversation(command["data"], state)
        
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
      Logger.info("🔌 Connecting to: #{inspect(server)}")
      
      # Convert server map to command string
      command = case server do
        %{"command" => cmd, "args" => args} when is_list(args) ->
          Enum.join([cmd | args], " ")
        %{"command" => cmd} ->
          cmd
        cmd when is_binary(cmd) ->
          cmd
        _ ->
          Logger.error("❌ Invalid server format: #{inspect(server)}")
          nil
      end
      
      if command do
        case Client.connect(mcp_client, command) do
          {:ok, info} ->
            server_name = Map.get(server, "name", command)
            Logger.info("✅ Connected to MCP server: #{server_name}")
            {server_name, info}
          error ->
            Logger.error("❌ Failed to connect to #{inspect(server)}: #{inspect(error)}")
            nil
        end
      else
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
  
  defp process_conversation(data, state) do
    Logger.info("💬 Processing conversation request")
    
    # Extract conversation data
    chat_id = data["chat_id"]
    user_text = data["text"]
    context = data["context"] || %{}
    request_id = data["request_id"]
    
    # Build system prompt with VSM context
    system_prompt = build_vsm_system_prompt(context)
    
    # Build conversation messages from history
    messages = build_conversation_messages(context["history"] || [], user_text)
    
    # Use LLM to generate response
    case LLMBridge.generate_conversation_response(messages, system_prompt, state.mcp_client) do
      {:ok, response} ->
        Logger.info("✅ Generated conversation response for chat #{chat_id}")
        
        # Extract any conversation state updates
        conversation_state = extract_conversation_state(response, context["conversation_state"])
        
        {:ok, %{
          response: response.content,
          chat_id: chat_id,
          request_id: request_id,
          conversation_state: conversation_state
        }}
        
      error ->
        Logger.error("❌ Failed to generate conversation response: #{inspect(error)}")
        {:error, %{
          chat_id: chat_id,
          request_id: request_id,
          error: "Failed to generate response"
        }}
    end
  end
  
  defp build_vsm_system_prompt(context) do
    vsm_context = context["vsm_context"] || %{}
    capabilities = vsm_context["capabilities"] || []
    
    """
    You are a helpful AI assistant integrated with a Viable System Model (VSM) management platform. 
    You can help users understand and interact with their VSM systems.
    
    Current system status: #{vsm_context["system_status"] || "unknown"}
    
    Available capabilities:
    #{Enum.map_join(capabilities, "\n", fn cap -> "- #{cap}" end)}
    
    When users ask about the system, provide helpful, accurate information. If they request actions,
    suggest appropriate commands or explain how to perform them. Be conversational but informative.
    """
  end
  
  defp build_conversation_messages(history, current_text) do
    # Convert history to LLM message format
    historical_messages = history
    |> Enum.reverse()  # History is stored newest first
    |> Enum.take(10)   # Limit context to last 10 messages
    |> Enum.map(fn msg ->
      %{
        role: to_string(msg["role"] || msg[:role]),
        content: msg["text"] || msg[:text]
      }
    end)
    
    # Add current user message
    historical_messages ++ [%{role: "user", content: current_text}]
  end
  
  defp extract_conversation_state(response, current_state) do
    # Would extract any state updates from the response
    # For now, just maintain current state
    current_state || %{
      topic: nil,
      context_summary: nil,
      last_activity: DateTime.utc_now()
    }
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle AMQP message for conversation request
    case Jason.decode(payload) do
      {:ok, request} ->
        Logger.info("📨 LLM Worker received conversation request: #{request["request_id"]}")
        
        # Process the conversation request
        result = process_conversation(request, state)
        
        # Send response back via AMQP
        send_conversation_response(result, meta, state)
        
        # Acknowledge the message
        AMQP.Basic.ack(state.channel, meta.delivery_tag)
        
      {:error, reason} ->
        Logger.error("Failed to decode conversation request: #{inspect(reason)}")
        AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    Logger.info("LLM Worker #{state.agent_id} subscribed to conversation queue")
    {:noreply, state}
  end
  
  defp send_conversation_response({:ok, response}, meta, state) do
    # Send successful response
    reply_to = meta[:reply_to] || "vsm.telegram.commands"
    correlation_id = meta[:correlation_id] || response.request_id
    
    AMQP.Basic.publish(
      state.channel,
      reply_to,  # Send to reply exchange
      "",  # Default routing key
      Jason.encode!(response),
      content_type: "application/json",
      correlation_id: correlation_id
    )
    
    Logger.info("✅ Sent conversation response for request #{correlation_id}")
  end
  
  defp send_conversation_response({:error, error_data}, meta, state) do
    # Send error response
    reply_to = meta[:reply_to] || "vsm.telegram.commands"
    correlation_id = meta[:correlation_id] || error_data.request_id
    
    AMQP.Basic.publish(
      state.channel,
      reply_to,
      "",
      Jason.encode!(error_data),
      content_type: "application/json",
      correlation_id: correlation_id
    )
    
    Logger.error("❌ Sent error response for request #{correlation_id}")
  end
  
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
  
  defp establish_fallback_channel do
    try do
      {:ok, conn} = AMQP.Connection.open()
      {:ok, channel} = AMQP.Channel.open(conn)
      {:ok, channel}
    rescue
      e -> 
        Logger.error("Failed to create fallback channel: #{inspect(e)}")
        {:error, e}
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