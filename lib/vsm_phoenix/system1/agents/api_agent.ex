defmodule VsmPhoenix.System1.Agents.ApiAgent do
  @moduledoc """
  S1 API Agent - Handles external requests and provides API interface.
  
  Exposes HTTP/WebSocket endpoints for external systems to interact
  with the S1 operational context.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  alias Phoenix.PubSub
  alias AMQP

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end

  def handle_request(agent_id, request) do
    GenServer.call({:global, agent_id}, {:handle_request, request}, 5_000)
  end

  def get_endpoints(agent_id) do
    GenServer.call({:global, agent_id}, :get_endpoints)
  end

  def update_endpoints(agent_id, endpoints) do
    GenServer.cast({:global, agent_id}, {:update_endpoints, endpoints})
  end

  def get_api_metrics(agent_id) do
    GenServer.call({:global, agent_id}, :get_api_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    config = Keyword.get(opts, :config, %{})
    registry = Keyword.get(opts, :registry, Registry)
    
    Logger.info("🌐 API Agent #{agent_id} initializing...")
    
    # Register with S1 Registry if not skipped
    unless registry == :skip_registration do
      :ok = registry.register(agent_id, self(), %{
        type: :api,
        config: config,
        endpoints: get_configured_endpoints(config),
        started_at: DateTime.utc_now()
      })
    end
    
    # Get AMQP channel for events
    {:ok, channel} = ConnectionManager.get_channel(:api_events)
    
    # Setup API events exchange
    events_exchange = "vsm.s1.#{agent_id}.api.events"
    :ok = AMQP.Exchange.declare(channel, events_exchange, :topic, durable: true)
    
    # Subscribe to WebSocket topics if configured
    if config[:enable_websocket] do
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:api:#{agent_id}")
    end
    
    # Setup request/response queues
    request_queue = "vsm.s1.#{agent_id}.api.requests"
    response_exchange = "vsm.s1.#{agent_id}.api.responses"
    
    {:ok, _queue} = AMQP.Queue.declare(channel, request_queue, durable: true)
    :ok = AMQP.Exchange.declare(channel, response_exchange, :topic, durable: true)
    
    # Start consuming API requests
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, request_queue)
    
    state = %{
      agent_id: agent_id,
      config: config,
      channel: channel,
      events_exchange: events_exchange,
      response_exchange: response_exchange,
      endpoints: get_configured_endpoints(config),
      active_requests: %{},
      metrics: %{
        requests_handled: 0,
        requests_failed: 0,
        response_times: [],
        endpoints_hit: %{},
        last_request_at: nil
      },
      rate_limiter: initialize_rate_limiter(config)
    }
    
    {:ok, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle API request from AMQP
    case Jason.decode(payload) do
      {:ok, request} ->
        Logger.info("API Agent #{state.agent_id} received request: #{request["method"]} #{request["path"]}")
        
        # Process request
        new_state = process_api_request(request, meta, state)
        
        # Acknowledge message
        AMQP.Basic.ack(state.channel, meta.delivery_tag)
        
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Failed to parse API request: #{inspect(reason)}")
        AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    Logger.info("API Agent #{state.agent_id} successfully subscribed to request queue")
    {:noreply, state}
  end

  @impl true
  def handle_info({:pubsub_message, message}, state) do
    # Handle WebSocket message
    Logger.debug("API Agent received WebSocket message: #{inspect(message)}")
    
    # Broadcast to API events
    publish_api_event("websocket", message, state)
    
    {:noreply, state}
  end

  @impl true
  def handle_call({:handle_request, request}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Check rate limit
    case check_rate_limit(request, state.rate_limiter) do
      {:ok, rate_limiter} ->
        # Process request
        {response, new_state} = execute_api_request(request, %{state | rate_limiter: rate_limiter})
        
        # Update metrics
        response_time = System.monotonic_time(:millisecond) - start_time
        final_state = update_api_metrics(new_state, request, response, response_time)
        
        {:reply, response, final_state}
        
      {:error, :rate_limited} ->
        {:reply, {:error, :rate_limited, "Too many requests"}, state}
    end
  end

  @impl true
  def handle_call(:get_endpoints, _from, state) do
    {:reply, {:ok, state.endpoints}, state}
  end

  @impl true
  def handle_call(:get_api_metrics, _from, state) do
    metrics = calculate_api_statistics(state.metrics)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_cast({:update_endpoints, endpoints}, state) do
    Logger.info("API Agent #{state.agent_id} updating endpoints")
    {:noreply, %{state | endpoints: endpoints}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("API Agent #{state.agent_id} terminating: #{inspect(reason)}")
    
    # Unregister from registry
    Registry.unregister(state.agent_id)
    
    # Unsubscribe from PubSub
    if state.config[:enable_websocket] do
      PubSub.unsubscribe(VsmPhoenix.PubSub, "vsm:api:#{state.agent_id}")
    end
    
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

  defp get_configured_endpoints(config) do
    Map.get(config, :endpoints, default_endpoints())
  end

  defp default_endpoints do
    [
      %{
        path: "/status",
        method: "GET",
        handler: :get_status,
        description: "Get agent status"
      },
      %{
        path: "/metrics",
        method: "GET", 
        handler: :get_metrics,
        description: "Get agent metrics"
      },
      %{
        path: "/execute",
        method: "POST",
        handler: :execute_command,
        description: "Execute a command"
      },
      %{
        path: "/query",
        method: "POST",
        handler: :query_data,
        description: "Query agent data"
      }
    ]
  end

  defp initialize_rate_limiter(config) do
    %{
      max_requests: Map.get(config, :rate_limit, 100),
      window: Map.get(config, :rate_window, 60_000), # 1 minute
      requests: %{}
    }
  end

  defp check_rate_limit(request, rate_limiter) do
    client_id = request["client_id"] || "anonymous"
    now = System.monotonic_time(:millisecond)
    window_start = now - rate_limiter.window
    
    # Clean old requests
    client_requests = Map.get(rate_limiter.requests, client_id, [])
    |> Enum.filter(fn timestamp -> timestamp > window_start end)
    
    if length(client_requests) < rate_limiter.max_requests do
      new_requests = Map.put(rate_limiter.requests, client_id, [now | client_requests])
      {:ok, %{rate_limiter | requests: new_requests}}
    else
      {:error, :rate_limited}
    end
  end

  defp process_api_request(request, _meta, state) do
    # Process AMQP API request
    {response, new_state} = execute_api_request(request, state)
    
    # Publish response
    publish_api_response(request, response, state)
    
    new_state
  end

  defp execute_api_request(request, state) do
    path = request["path"] || "/"
    method = String.upcase(request["method"] || "GET")
    
    # Find matching endpoint
    endpoint = Enum.find(state.endpoints, fn ep ->
      ep.path == path && ep.method == method
    end)
    
    if endpoint do
      # Execute endpoint handler
      response = execute_endpoint_handler(endpoint.handler, request, state)
      
      # Publish API event
      publish_api_event("request", %{
        endpoint: endpoint.path,
        method: method,
        status: elem(response, 0)
      }, state)
      
      {response, state}
    else
      {{:error, :not_found, "Endpoint not found"}, state}
    end
  end

  defp execute_endpoint_handler(handler, request, state) do
    try do
      case handler do
        :get_status ->
          {:ok, %{
            agent_id: state.agent_id,
            type: :api,
            endpoints: length(state.endpoints),
            active_requests: map_size(state.active_requests),
            uptime: DateTime.diff(DateTime.utc_now(), 
                     state.metrics.last_request_at || DateTime.utc_now(), :second)
          }}
          
        :get_metrics ->
          {:ok, calculate_api_statistics(state.metrics)}
          
        :execute_command ->
          command = request["body"] || %{}
          # Forward to worker agents
          {:ok, %{command_received: true, processing: true}}
          
        :query_data ->
          query = request["body"] || %{}
          # Execute query
          {:ok, %{query: query, results: []}}
          
        custom when is_function(custom) ->
          custom.(request, state)
          
        _ ->
          {:error, :handler_not_implemented}
      end
    rescue
      error ->
        {:error, :internal_error, Exception.format(:error, error)}
    end
  end

  defp publish_api_response(request, response, state) do
    response_message = %{
      request_id: request["id"] || generate_request_id(),
      status: elem(response, 0),
      data: case response do
        {:ok, data} -> data
        {:error, code, message} -> %{error: code, message: message}
        {:error, code} -> %{error: code}
      end,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    message = Jason.encode!(response_message)
    routing_key = "api.response.#{request["client_id"] || "anonymous"}"
    
    AMQP.Basic.publish(state.channel, state.response_exchange, routing_key, message,
      content_type: "application/json",
      persistent: true
    )
  end

  defp publish_api_event(event_type, event_data, state) do
    event = %{
      agent_id: state.agent_id,
      event_type: event_type,
      data: event_data,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    message = Jason.encode!(event)
    routing_key = "api.event.#{event_type}"
    
    AMQP.Basic.publish(state.channel, state.events_exchange, routing_key, message,
      content_type: "application/json"
    )
  end

  defp update_api_metrics(state, request, response, response_time) do
    endpoint = request["path"] || "unknown"
    status = elem(response, 0)
    
    endpoints_hit = Map.update(state.metrics.endpoints_hit, endpoint, 1, &(&1 + 1))
    
    new_metrics = %{state.metrics |
      requests_handled: state.metrics.requests_handled + (if status == :ok, do: 1, else: 0),
      requests_failed: state.metrics.requests_failed + (if status != :ok, do: 1, else: 0),
      response_times: [response_time | Enum.take(state.metrics.response_times, 999)],
      endpoints_hit: endpoints_hit,
      last_request_at: DateTime.utc_now()
    }
    
    %{state | metrics: new_metrics}
  end

  defp calculate_api_statistics(metrics) do
    response_times = metrics.response_times
    
    %{
      total_requests: metrics.requests_handled + metrics.requests_failed,
      success_rate: if metrics.requests_handled + metrics.requests_failed > 0 do
        metrics.requests_handled / (metrics.requests_handled + metrics.requests_failed)
      else
        1.0
      end,
      average_response_time: if length(response_times) > 0 do
        Enum.sum(response_times) / length(response_times)
      else
        0
      end,
      p95_response_time: calculate_percentile(response_times, 0.95),
      p99_response_time: calculate_percentile(response_times, 0.99),
      endpoints_hit: metrics.endpoints_hit,
      last_request_at: metrics.last_request_at
    }
  end

  defp calculate_percentile([], _), do: 0
  defp calculate_percentile(values, percentile) do
    sorted = Enum.sort(values)
    index = round(percentile * length(sorted)) - 1
    Enum.at(sorted, max(0, index), 0)
  end

  defp generate_request_id do
    "req-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(9999)}"
  end
end