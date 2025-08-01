defmodule VsmPhoenix.System1.Agents.WorkerAgent do
  @moduledoc """
  S1 Worker Agent - Processes commands from vsm.s1.<id>.command queue.
  
  Consumes from: vsm.s1.<id>.command
  Publishes results to: vsm.s1.<id>.results
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  alias AMQP

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end

  def execute_command(agent_id, command) do
    GenServer.call({:global, agent_id}, {:execute_command, command}, 10_000)
  end

  def get_status(agent_id) do
    GenServer.call({:global, agent_id}, :get_status)
  end

  def get_work_metrics(agent_id) do
    GenServer.call({:global, agent_id}, :get_work_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    config = Keyword.get(opts, :config, %{})
    registry = Keyword.get(opts, :registry, Registry)
    
    Logger.info("⚙️ Worker Agent #{agent_id} initializing...")
    
    # Register with S1 Registry if not skipped
    unless registry == :skip_registration do
      :ok = registry.register(agent_id, self(), %{
        type: :worker,
        config: config,
        capabilities: get_capabilities(config),
        started_at: DateTime.utc_now()
      })
    end
    
    # Get AMQP channel
    {:ok, channel} = ConnectionManager.get_channel(:commands)
    
    # Setup command queue
    command_queue = "vsm.s1.#{agent_id}.command"
    command_exchange = "vsm.s1.commands"
    
    # Declare exchange and queue
    :ok = AMQP.Exchange.declare(channel, command_exchange, :topic, durable: true)
    {:ok, _queue} = AMQP.Queue.declare(channel, command_queue, durable: true)
    :ok = AMQP.Queue.bind(channel, command_queue, command_exchange, 
           routing_key: "worker.#{agent_id}.#")
    
    # Setup results exchange
    results_exchange = "vsm.s1.#{agent_id}.results"
    :ok = AMQP.Exchange.declare(channel, results_exchange, :topic, durable: true)
    
    # Start consuming commands
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, command_queue)
    
    state = %{
      agent_id: agent_id,
      config: config,
      channel: channel,
      command_queue: command_queue,
      results_exchange: results_exchange,
      status: :idle,
      current_work: nil,
      metrics: %{
        commands_processed: 0,
        commands_failed: 0,
        total_processing_time: 0,
        last_command_at: nil,
        work_queue_length: 0
      },
      capabilities: get_capabilities(config)
    }
    
    {:ok, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Parse command from AMQP message
    case Jason.decode(payload) do
      {:ok, command} ->
        Logger.info("Worker #{state.agent_id} received command: #{command["type"]}")
        
        # Process command
        new_state = process_command(command, meta, state)
        
        # Acknowledge message
        AMQP.Basic.ack(state.channel, meta.delivery_tag)
        
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Failed to parse command: #{inspect(reason)}")
        # Reject and don't requeue malformed messages
        AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    Logger.info("Worker #{state.agent_id} successfully subscribed to command queue")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_cancel, _}, state) do
    Logger.warn("Worker #{state.agent_id} consumer cancelled")
    {:stop, :consumer_cancelled, state}
  end

  @impl true
  def handle_info({:basic_cancel_ok, _}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:execute_command, command}, from, state) do
    # Direct command execution (not via AMQP)
    if state.status == :busy do
      {:reply, {:error, :worker_busy}, state}
    else
      # Execute in background and reply when done
      Task.start(fn ->
        result = execute_work(command, state)
        GenServer.reply(from, result)
      end)
      
      new_state = %{state | 
        status: :busy,
        current_work: command
      }
      
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      agent_id: state.agent_id,
      status: state.status,
      current_work: state.current_work,
      capabilities: state.capabilities,
      queue_size: state.metrics.work_queue_length || 0
    }
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:get_work_metrics, _from, state) do
    # Build clean metrics without any queue structures
    clean_metrics = %{
      commands_processed: state.metrics.commands_processed || 0,
      commands_failed: state.metrics.commands_failed || 0,
      total_processing_time: state.metrics.total_processing_time || 0,
      last_command_at: state.metrics.last_command_at,
      work_queue_length: state.metrics.work_queue_length || 0,
      average_processing_time: if (state.metrics.commands_processed || 0) > 0 do
        (state.metrics.total_processing_time || 0) / state.metrics.commands_processed
      else
        0
      end
    }
    
    {:reply, {:ok, clean_metrics}, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Worker Agent #{state.agent_id} terminating: #{inspect(reason)}")
    
    # Unregister from registry
    Registry.unregister(state.agent_id)
    
    # Close AMQP channel
    if state.channel && Process.alive?(state.channel.pid) do
      AMQP.Channel.close(state.channel)
    end
    
    :ok
  end

  # Private Functions

  defp via_tuple(agent_id) do
    {:via, Registry, {:s1_registry, agent_id}}
  end

  defp get_capabilities(config) do
    default_caps = [:process_data, :transform, :analyze]
    
    # Add LLM capabilities if enabled
    llm_caps = if config[:llm_enabled] do
      [:llm_reasoning, :mcp_tools, :recursive_spawning, :task_planning]
    else
      []
    end
    
    Map.get(config, :capabilities, default_caps) ++ llm_caps
  end

  defp process_command(command, _meta, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Update status
    state = %{state | status: :busy, current_work: command}
    
    # Execute work based on command type
    result = execute_work(command, state)
    
    # Calculate processing time
    processing_time = System.monotonic_time(:millisecond) - start_time
    
    # Publish result
    publish_result(command, result, processing_time, state)
    
    # Update metrics
    new_metrics = update_work_metrics(state.metrics, result, processing_time)
    
    %{state | 
      status: :idle,
      current_work: nil,
      metrics: new_metrics
    }
  end

  defp execute_work(command, state) do
    command_type = command["type"] || "unknown"
    
    # Check if worker has capability
    capability_strings = Enum.map(state.capabilities, &to_string/1)
    
    if command_type in capability_strings do
      try do
        case command_type do
          "process_data" ->
            process_data(command["data"], state.config)
            
          "transform" ->
            transform_data(command["data"], command["transformation"], state.config)
            
          "analyze" ->
            analyze_data(command["data"], command["analysis_type"], state.config)
            
          # NEW: LLM Capabilities
          "llm_reasoning" ->
            llm_reasoning(command["data"], state.config)
            
          "mcp_tools" ->
            execute_mcp_tools(command["data"], state.config)
            
          "recursive_spawning" ->
            recursive_spawning(command["data"], state.config)
            
          "task_planning" ->
            task_planning(command["data"], state.config)
            
          _ ->
            # Generic work simulation
            Process.sleep(100 + :rand.uniform(400))
            {:ok, %{processed: true, timestamp: DateTime.utc_now()}}
        end
      rescue
        error ->
          {:error, Exception.format(:error, error)}
      end
    else
      {:error, :capability_not_supported}
    end
  end

  defp process_data(data, _config) do
    # Simulate data processing
    Process.sleep(50 + :rand.uniform(150))
    
    processed = %{
      original_size: byte_size(Jason.encode!(data)),
      processed_at: DateTime.utc_now(),
      checksum: :crypto.hash(:sha256, Jason.encode!(data)) |> Base.encode16()
    }
    
    {:ok, processed}
  end

  defp transform_data(data, transformation, _config) do
    # Simulate data transformation
    Process.sleep(100 + :rand.uniform(200))
    
    transformed = case transformation do
      "uppercase" when is_binary(data) ->
        String.upcase(data)
        
      "aggregate" when is_list(data) ->
        Enum.reduce(data, %{}, fn item, acc ->
          Map.update(acc, item["type"] || "unknown", 1, &(&1 + 1))
        end)
        
      _ ->
        data
    end
    
    {:ok, %{transformed: transformed, transformation: transformation}}
  end

  defp analyze_data(data, analysis_type, _config) do
    # Simulate data analysis
    Process.sleep(200 + :rand.uniform(300))
    
    analysis = case analysis_type do
      "statistics" ->
        %{
          count: length(data),
          types: Enum.frequencies_by(data, & &1["type"]),
          timestamp: DateTime.utc_now()
        }
        
      "pattern" ->
        %{
          patterns_found: :rand.uniform(5),
          confidence: :rand.uniform(),
          timestamp: DateTime.utc_now()
        }
        
      _ ->
        %{analysis_type: analysis_type, completed: true}
    end
    
    {:ok, analysis}
  end

  defp publish_result(command, result, processing_time, state) do
    result_message = %{
      agent_id: state.agent_id,
      command_id: command["id"] || generate_command_id(),
      command_type: command["type"],
      status: elem(result, 0),
      result: elem(result, 1),
      processing_time_ms: processing_time,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    message = Jason.encode!(result_message)
    routing_key = "worker.#{state.agent_id}.result"
    
    case AMQP.Basic.publish(state.channel, state.results_exchange, routing_key, message,
           content_type: "application/json",
           persistent: true) do
      :ok ->
        Logger.debug("Worker #{state.agent_id} published result for command #{result_message.command_id}")
      error ->
        Logger.error("Failed to publish result: #{inspect(error)}")
    end
  end

  defp update_work_metrics(metrics, result, processing_time) do
    {success_count, fail_count} = case result do
      {:ok, _} -> {1, 0}
      {:error, _} -> {0, 1}
    end
    
    %{metrics |
      commands_processed: metrics.commands_processed + success_count,
      commands_failed: metrics.commands_failed + fail_count,
      total_processing_time: metrics.total_processing_time + processing_time,
      last_command_at: DateTime.utc_now()
    }
  end

  # LLM Capability Functions
  
  defp llm_reasoning(data, config) do
    # Fail fast - no simulations
    Logger.error("❌ Worker Agent LLM reasoning not implemented - use llm_worker type")
    {:error, :llm_not_available}
  end
  
  defp execute_mcp_tools(data, config) do
    # Fail fast - no simulations
    Logger.error("❌ Worker Agent MCP tools not implemented - use llm_worker type")
    {:error, :mcp_tools_not_available}
  end
  
  defp recursive_spawning(data, config) do
    # Fail fast - no simulations
    Logger.error("❌ Worker Agent recursive spawning not implemented - use llm_worker type")
    {:error, :recursive_spawning_not_available}
  end
  
  defp task_planning(data, config) do
    # Fail fast - no simulations
    Logger.error("❌ Worker Agent task planning not implemented - use llm_worker type")
    {:error, :task_planning_not_available}
  end
  
  defp generate_command_id do
    "cmd-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(9999)}"
  end
end