defmodule VsmPhoenix.AMQP.CommandRouter do
  @moduledoc """
  Implements bidirectional AMQP communication with RPC pattern for VSM commands.
  
  ## Architecture:
  - Upward flow (S1→S5): Events use fan-out exchanges for broadcasting
  - Downward flow (S5→S1): Commands use RPC pattern for direct responses
  - Direct-reply-to pattern for efficient RPC without declaring response queues
  
  ## Command Flow:
  1. S5/S4/S3 issues command with correlation_id
  2. Command sent to specific system queue (e.g., vsm.system1.commands)
  3. Target system processes and replies to 'amq.rabbitmq.reply-to'
  4. CommandRPC.call/2 blocks until response received
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.ConnectionManager
  alias AMQP
  
  @command_exchange "vsm.commands"
  @event_exchanges %{
    algedonic: "vsm.algedonic",
    coordination: "vsm.coordination", 
    control: "vsm.control",
    intelligence: "vsm.intelligence",
    policy: "vsm.policy"
  }
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Routes an event upward through fan-out exchanges
  """
  def publish_event(event_type, payload) when is_atom(event_type) do
    GenServer.cast(__MODULE__, {:publish_event, event_type, payload})
  end
  
  @doc """
  Routes a command downward to a specific system
  """
  def send_command(target_system, command, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:send_command, target_system, command, timeout}, timeout + 1000)
  end
  
  @doc """
  Claude-style capability-based routing for PolyAgents
  Uses predicate dispatch to find optimal agent for task delegation
  """
  def delegate_to_capability(capability_predicate, task, options \\ []) do
    delegation_strategy = Keyword.get(options, :strategy, :stateless)
    timeout = Keyword.get(options, :timeout, 5000)
    
    GenServer.call(__MODULE__, {
      :delegate_to_capability, 
      capability_predicate, 
      task, 
      delegation_strategy,
      timeout
    }, timeout + 1000)
  end
  
  @doc """
  Enhanced routing with Claude-style tool selection patterns
  Finds agents based on capability matching with performance optimization
  """
  def route_with_capability_matching(requirements, context \\ %{}) do
    GenServer.call(__MODULE__, {:route_with_capability_matching, requirements, context})
  end
  
  @doc """
  Registers a command handler for a specific system
  """
  def register_handler(system, handler_fn) when is_function(handler_fn, 2) do
    GenServer.call(__MODULE__, {:register_handler, system, handler_fn})
  end
  
  # Server implementation
  
  def init(_opts) do
    Logger.info("🎯 Initializing Command Router with RPC support")
    
    # Get or create channel for routing
    case ConnectionManager.get_channel(:command_router) do
      {:ok, channel} ->
        setup_topology(channel)
        
        state = %{
          channel: channel,
          handlers: %{},
          pending_rpcs: %{},
          consumer_tags: %{}
        }
        
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to get channel: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  def handle_cast({:publish_event, event_type, payload}, state) do
    exchange = Map.get(@event_exchanges, event_type)
    
    if exchange do
      message = Jason.encode!(%{
        type: "event",
        event_type: event_type,
        payload: payload,
        timestamp: DateTime.utc_now(),
        source: node()
      })
      
      # Fan-out exchanges don't use routing keys
      AMQP.Basic.publish(state.channel, exchange, "", message)
      Logger.debug("📤 Published #{event_type} event to #{exchange}")
    else
      Logger.warning("Unknown event type: #{event_type}")
    end
    
    {:noreply, state}
  end
  
  def handle_call({:send_command, target_system, command, timeout}, from, state) do
    # Use separate channel for RPC to avoid conflicts
    case ConnectionManager.get_channel(:rpc) do
      {:ok, rpc_channel} ->
        correlation_id = generate_correlation_id()
        
        # Declare callback queue with Direct-reply-to
        # This is a special RabbitMQ feature for efficient RPC
        reply_queue = "amq.rabbitmq.reply-to"
        
        # Start consuming from reply queue if not already
        state = ensure_reply_consumer(state, rpc_channel, reply_queue)
        
        # Build command message
        message = Jason.encode!(%{
          type: "command",
          command: command,
          correlation_id: correlation_id,
          reply_to: reply_queue,
          timestamp: DateTime.utc_now(),
          source: node()
        })
        
        # Send command to target system's command queue
        target_queue = "vsm.#{target_system}.commands"
        
        # Store pending RPC info
        new_state = put_in(state.pending_rpcs[correlation_id], %{
          from: from,
          timeout_ref: Process.send_after(self(), {:rpc_timeout, correlation_id}, timeout)
        })
        
        # Publish command
        AMQP.Basic.publish(rpc_channel, "", target_queue, message,
          reply_to: reply_queue,
          correlation_id: correlation_id
        )
        
        Logger.debug("📮 Sent RPC command to #{target_queue} with correlation_id: #{correlation_id}")
        
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:register_handler, system, handler_fn}, _from, state) do
    # Set up command queue for this system
    queue_name = "vsm.#{system}.commands"
    
    case AMQP.Queue.declare(state.channel, queue_name, durable: true) do
      {:ok, _} ->
        # Start consuming from command queue
        {:ok, consumer_tag} = AMQP.Basic.consume(state.channel, queue_name)
        
        new_state = state
        |> put_in([:handlers, system], handler_fn)
        |> put_in([:consumer_tags, queue_name], consumer_tag)
        
        Logger.info("✅ Registered command handler for #{system}")
        
        {:reply, :ok, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  # Handle incoming commands (for systems that registered handlers)
  def handle_info({:basic_deliver, payload, meta}, state) when not is_map_key(meta, :correlation_id) or meta.correlation_id == nil do
    with {:ok, message} <- Jason.decode(payload),
         %{"type" => "command"} <- message do
      
      # Extract system from queue name
      system = extract_system_from_queue(meta.routing_key)
      
      case Map.get(state.handlers, system) do
        nil ->
          Logger.warning("No handler registered for system: #{system}")
          
        handler_fn ->
          # Execute handler and send response
          Task.start(fn ->
            try do
              result = handler_fn.(message["command"], message)
              send_command_response(state.channel, message, {:ok, result})
            rescue
              e ->
                send_command_response(state.channel, message, {:error, Exception.message(e)})
            end
          end)
      end
    end
    
    {:noreply, state}
  end
  
  # Handle RPC responses
  def handle_info({:basic_deliver, payload, %{correlation_id: correlation_id} = _meta}, state) do
    case Map.pop(state.pending_rpcs, correlation_id) do
      {nil, _} ->
        Logger.warning("Received response for unknown correlation_id: #{correlation_id}")
        {:noreply, state}
        
      {rpc_info, new_pending} ->
        # Cancel timeout
        Process.cancel_timer(rpc_info.timeout_ref)
        
        # Parse response
        response = case Jason.decode(payload) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:ok, %{"error" => error}} -> {:error, error}
          {:error, reason} -> {:error, {:decode_error, reason}}
        end
        
        # Reply to waiting caller
        GenServer.reply(rpc_info.from, response)
        
        {:noreply, %{state | pending_rpcs: new_pending}}
    end
  end
  
  # Handle RPC timeouts
  def handle_info({:rpc_timeout, correlation_id}, state) do
    case Map.pop(state.pending_rpcs, correlation_id) do
      {nil, _} ->
        {:noreply, state}
        
      {rpc_info, new_pending} ->
        GenServer.reply(rpc_info.from, {:error, :timeout})
        {:noreply, %{state | pending_rpcs: new_pending}}
    end
  end
  
  # Private functions
  
  defp setup_topology(channel) do
    # Declare command exchange (topic routing to match existing)
    AMQP.Exchange.declare(channel, @command_exchange, :topic, durable: true)
    
    # Event exchanges are already declared in ConnectionManager
    Logger.info("📋 Command routing topology ready")
  end
  
  defp ensure_reply_consumer(state, channel, reply_queue) do
    case Map.get(state.consumer_tags, reply_queue) do
      nil ->
        # Start consuming from reply queue
        {:ok, consumer_tag} = AMQP.Basic.consume(channel, reply_queue, no_ack: true)
        put_in(state.consumer_tags[reply_queue], consumer_tag)
        
      _ ->
        state
    end
  end
  
  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
  
  defp extract_system_from_queue(queue_name) do
    case String.split(queue_name, ".") do
      ["vsm", system, "commands"] -> String.to_atom(system)
      _ -> nil
    end
  end
  
  defp send_command_response(channel, command_message, response) do
    reply_to = command_message["reply_to"]
    correlation_id = command_message["correlation_id"]
    
    response_payload = case response do
      {:ok, result} ->
        %{status: "success", result: result, correlation_id: correlation_id}
        
      {:error, error} ->
        %{status: "error", error: error, correlation_id: correlation_id}
    end
    
    message = Jason.encode!(response_payload)
    
    AMQP.Basic.publish(channel, "", reply_to, message,
      correlation_id: correlation_id
    )
  end
  
  # Claude-style capability routing handlers
  def handle_call({:delegate_to_capability, capability_predicate, task, strategy, timeout}, from, state) do
    # Find agents matching capability using Discovery protocol
    matching_agents = VsmPhoenix.AMQP.Discovery.discover_agents_by_capability(capability_predicate)
    
    case select_optimal_agent_claude_style(matching_agents, task, strategy) do
      {:ok, selected_agent} ->
        # Use stateless delegation pattern from Claude Code
        delegation_result = delegate_task_stateless(selected_agent, task, timeout, state)
        {:reply, delegation_result, state}
        
      {:error, :no_agents} ->
        {:reply, {:error, :no_capable_agents}, state}
    end
  end
  
  def handle_call({:route_with_capability_matching, requirements, context}, _from, state) do
    # Enhanced routing with Claude-style tool selection
    capability_catalog = VsmPhoenix.AMQP.Discovery.define_capability_catalog()
    
    # Score capabilities against requirements using Claude's approach
    capability_scores = score_capabilities_against_requirements(capability_catalog, requirements)
    
    # Find agents with highest scoring capabilities
    optimal_routing = find_optimal_routing_claude_style(capability_scores, context)
    
    {:reply, {:ok, optimal_routing}, state}
  end
  
  # Claude-style agent selection with performance optimization
  defp select_optimal_agent_claude_style(agents, task, strategy) do
    case agents do
      [] -> 
        {:error, :no_agents}
        
      agents_list ->
        # Score agents based on Claude's approach: capability match + performance + availability
        scored_agents = Enum.map(agents_list, fn agent ->
          capability_score = calculate_capability_match_score(agent, task)
          performance_score = get_agent_performance_score(agent)
          availability_score = calculate_availability_score(agent)
          
          total_score = case strategy do
            :stateless ->
              # For stateless: prioritize capability match and availability
              capability_score * 0.6 + availability_score * 0.4
              
            :stateful ->  
              # For stateful: include performance history
              capability_score * 0.5 + performance_score * 0.3 + availability_score * 0.2
              
            :hybrid ->
              # Balanced scoring
              capability_score * 0.4 + performance_score * 0.3 + availability_score * 0.3
          end
          
          {agent, total_score}
        end)
        
        # Select highest scoring agent
        {best_agent, _score} = Enum.max_by(scored_agents, fn {_agent, score} -> score end)
        {:ok, best_agent}
    end
  end
  
  # Stateless delegation following Claude Code patterns
  defp delegate_task_stateless(agent, task, timeout, state) do
    # Create independent task context - no shared state
    delegation_context = %{
      agent_id: agent.id,
      task: task,
      delegation_timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id(),
      delegation_strategy: :stateless,
      timeout: timeout
    }
    
    # Send task via AMQP with direct reply pattern
    case send_delegation_command(agent, delegation_context, timeout, state) do
      {:ok, result} ->
        # Log delegation for analytics but don't maintain state
        Logger.info("Stateless delegation successful: #{agent.id} -> #{inspect(result)}")
        {:ok, %{
          agent: agent.id,
          result: result,
          delegation_type: :stateless,
          performance_metrics: extract_performance_metrics(result)
        }}
        
      {:error, reason} ->
        Logger.warning("Stateless delegation failed: #{agent.id} -> #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Capability scoring inspired by Claude's tool selection
  defp score_capabilities_against_requirements(capability_catalog, requirements) do
    Enum.map(capability_catalog, fn {capability_name, capability_def} ->
      # Score based on input/output type match
      input_match_score = calculate_input_type_match(capability_def, requirements)
      output_match_score = calculate_output_type_match(capability_def, requirements)
      
      # Score based on "when_to_use" patterns (like Claude's tool descriptions)
      usage_pattern_score = calculate_usage_pattern_match(capability_def, requirements)
      
      # Resource compatibility score
      resource_score = calculate_resource_compatibility(capability_def, requirements)
      
      total_score = input_match_score * 0.3 + output_match_score * 0.3 + 
                   usage_pattern_score * 0.3 + resource_score * 0.1
      
      {capability_name, total_score, capability_def}
    end)
    |> Enum.sort_by(fn {_name, score, _def} -> score end, :desc)
  end
  
  # Helper functions for Claude-style scoring
  defp calculate_capability_match_score(agent, task) do
    # Score based on how well agent capabilities match task requirements
    task_requirements = Map.get(task, :required_capabilities, [])
    agent_capabilities = Map.get(agent.metadata, :capabilities, [])
    
    if Enum.empty?(task_requirements) do
      0.5  # Default score if no specific requirements
    else
      matches = Enum.count(task_requirements, &(&1 in agent_capabilities))
      matches / length(task_requirements)
    end
  end
  
  defp get_agent_performance_score(agent) do
    # Get performance metrics from agent metadata
    performance_data = Map.get(agent.metadata, :performance_metrics, %{})
    
    # Score based on success rate, avg response time, etc.
    success_rate = Map.get(performance_data, :success_rate, 0.5)
    avg_response_time = Map.get(performance_data, :avg_response_time_ms, 1000)
    
    # Normalize scores (higher success rate = better, lower response time = better)
    time_score = max(0, 1 - (avg_response_time / 5000))  # 5sec max
    success_rate * 0.7 + time_score * 0.3
  end
  
  defp calculate_availability_score(agent) do
    # Score based on agent availability and load
    current_load = Map.get(agent.metadata, :current_load, 0.5)
    last_seen_diff = DateTime.diff(DateTime.utc_now(), agent.last_seen, :second)
    
    # Recent activity = higher availability
    recency_score = max(0, 1 - (last_seen_diff / 60))  # 60 sec max
    load_score = max(0, 1 - current_load)
    
    recency_score * 0.6 + load_score * 0.4
  end
  
  # Additional helper functions for comprehensive capability matching
  defp calculate_input_type_match(capability_def, requirements) do
    required_inputs = Map.get(requirements, :input_types, [])
    supported_inputs = Map.get(capability_def, :input_types, [])
    
    if Enum.empty?(required_inputs) do
      0.5
    else
      matches = Enum.count(required_inputs, &(&1 in supported_inputs))
      matches / length(required_inputs)
    end
  end
  
  defp calculate_output_type_match(capability_def, requirements) do
    required_outputs = Map.get(requirements, :output_types, [])
    supported_outputs = Map.get(capability_def, :output_types, [])
    
    if Enum.empty?(required_outputs) do
      0.5
    else
      matches = Enum.count(required_outputs, &(&1 in supported_outputs))
      matches / length(required_outputs)
    end
  end
  
  defp calculate_usage_pattern_match(capability_def, requirements) do
    # Match against Claude-style "when_to_use" patterns
    usage_patterns = Map.get(capability_def, :when_to_use, [])
    requirement_context = Map.get(requirements, :context, "")
    
    # Simple text matching for usage patterns
    pattern_matches = Enum.count(usage_patterns, fn pattern ->
      String.contains?(String.downcase(requirement_context), String.downcase(pattern))
    end)
    
    if Enum.empty?(usage_patterns) do
      0.5
    else
      min(1.0, pattern_matches / length(usage_patterns))
    end
  end
  
  defp calculate_resource_compatibility(capability_def, requirements) do
    # Check resource requirements compatibility
    required_resources = Map.get(requirements, :resource_constraints, %{})
    capability_resources = Map.get(capability_def, :resource_requirements, %{})
    
    # Simple compatibility check - capability should meet or exceed requirements
    memory_compat = check_memory_compatibility(required_resources, capability_resources)
    cpu_compat = check_cpu_compatibility(required_resources, capability_resources)
    
    (memory_compat + cpu_compat) / 2
  end
  
  defp check_memory_compatibility(required, available) do
    required_mem = Map.get(required, :memory_mb, 256)
    available_mem = Map.get(available, :recommended_memory_mb, 512)
    
    if available_mem >= required_mem, do: 1.0, else: available_mem / required_mem
  end
  
  defp check_cpu_compatibility(required, available) do
    required_cpu = Map.get(required, :cpu_intensive, false)
    available_cpu = Map.get(available, :cpu_intensive, false)
    
    cond do
      not required_cpu -> 1.0  # No CPU requirements
      required_cpu and available_cpu -> 1.0  # Both CPU intensive
      true -> 0.5  # CPU required but not available
    end
  end
  
  defp find_optimal_routing_claude_style(scored_capabilities, context) do
    # Return the top-scored capabilities with routing suggestions
    top_capabilities = Enum.take(scored_capabilities, 3)
    
    %{
      recommended_capabilities: top_capabilities,
      routing_strategy: determine_routing_strategy(context),
      fallback_options: Enum.drop(scored_capabilities, 3) |> Enum.take(2)
    }
  end
  
  defp determine_routing_strategy(context) do
    priority = Map.get(context, :priority, :medium)
    complexity = Map.get(context, :complexity, :medium)
    
    case {priority, complexity} do
      {:high, _} -> :direct_routing
      {_, :high} -> :distributed_routing
      _ -> :balanced_routing
    end
  end
  
  defp send_delegation_command(agent, delegation_context, timeout, state) do
    # Send delegation command using existing RPC infrastructure
    command = %{
      type: "delegation",
      task: delegation_context.task,
      strategy: :stateless,
      correlation_id: delegation_context.correlation_id
    }
    
    # Route to agent's system - assume agents are organized by system
    target_system = determine_agent_system(agent)
    send_command(target_system, command, timeout)
  end
  
  defp determine_agent_system(agent) do
    # Extract system from agent metadata or use default
    Map.get(agent.metadata, :system, :system1)
  end
  
  defp extract_performance_metrics(result) do
    # Extract performance data from delegation result
    %{
      response_time_ms: Map.get(result, :processing_time, 0),
      success: Map.get(result, :status) == "success",
      data_size: Map.get(result, :data_size, 0)
    }
  end
end