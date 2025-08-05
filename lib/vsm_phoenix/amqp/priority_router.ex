defmodule VsmPhoenix.AMQP.PriorityRouter do
  @moduledoc """
  Priority-based routing for VSM messages with dynamic rules and load balancing.
  
  Features:
  - Priority queue implementation with 10 levels (0-9)
  - Dynamic routing rules based on message content and context
  - Load balancing across multiple consumers
  - Circuit breaker pattern for fault tolerance
  - Routing metrics and analytics
  """
  
  use GenServer
  require Logger
  
  @max_priority 10
  @default_priority 5
  @circuit_breaker_threshold 5
  @circuit_breaker_timeout 30_000  # 30 seconds
  
  defmodule RoutingRule do
    @moduledoc "Dynamic routing rule structure"
    defstruct [
      :id,
      :name,
      :condition,
      :target_exchange,
      :routing_key_pattern,
      :priority_modifier,
      :load_balance_strategy,
      :enabled,
      :metadata
    ]
  end
  
  defmodule QueueStats do
    @moduledoc "Queue statistics for load balancing"
    defstruct [
      :queue_name,
      :message_count,
      :consumer_count,
      :average_processing_time,
      :last_routed,
      :circuit_breaker_state,
      :failures
    ]
  end
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    Logger.info("🚦 Priority Router: Initializing with intelligent routing")
    
    channel = Keyword.fetch!(opts, :channel)
    
    state = %{
      channel: channel,
      
      # Priority queues (0-9, where 9 is highest)
      priority_queues: initialize_priority_queues(),
      
      # Dynamic routing rules
      routing_rules: %{},
      
      # Load balancing state
      queue_stats: %{},
      consumer_registry: %{},
      
      # Circuit breakers
      circuit_breakers: %{},
      
      # Metrics
      metrics: %{
        total_routed: 0,
        by_priority: %{},
        by_rule: %{},
        failures: 0
      },
      
      # Configuration
      config: %{
        default_exchange: Keyword.get(opts, :default_exchange, "vsm.priority"),
        load_balance_algorithm: Keyword.get(opts, :load_balance_algorithm, :round_robin),
        enable_circuit_breaker: Keyword.get(opts, :enable_circuit_breaker, true)
      }
    }
    
    # Load default routing rules
    state = load_default_rules(state)
    
    # Start metrics collection
    schedule_metrics_collection()
    
    {:ok, state}
  end
  
  # Public API
  
  def route(pid \\ __MODULE__, payload, routing_key, headers, priority) do
    GenServer.call(pid, {:route, payload, routing_key, headers, priority})
  end
  
  def add_rule(pid \\ __MODULE__, rule) do
    GenServer.call(pid, {:add_rule, rule})
  end
  
  def remove_rule(pid \\ __MODULE__, rule_id) do
    GenServer.call(pid, {:remove_rule, rule_id})
  end
  
  def update_rule(pid \\ __MODULE__, rule_id, updates) do
    GenServer.call(pid, {:update_rule, rule_id, updates})
  end
  
  def get_metrics(pid \\ __MODULE__) do
    GenServer.call(pid, :get_metrics)
  end
  
  def register_consumer(pid \\ __MODULE__, queue_name, consumer_info) do
    GenServer.cast(pid, {:register_consumer, queue_name, consumer_info})
  end
  
  def get_queue_stats(pid \\ __MODULE__) do
    GenServer.call(pid, :get_queue_stats)
  end
  
  # Callbacks
  
  def handle_call({:route, payload, routing_key, headers, priority}, _from, state) do
    # Parse message for routing decisions
    message = decode_payload(payload)
    
    # Apply routing rules to determine target
    {target_exchange, target_routing_key, final_priority} = 
      apply_routing_rules(message, routing_key, headers, priority, state)
    
    # Select queue based on load balancing
    target_queue = select_target_queue(target_routing_key, state)
    
    # Check circuit breaker
    if should_route?(target_queue, state) do
      # Route the message
      result = perform_routing(
        state.channel,
        payload,
        target_exchange,
        target_queue,
        headers,
        final_priority
      )
      
      # Update metrics
      state = update_routing_metrics(state, final_priority, result)
      
      {:reply, result, state}
    else
      # Circuit breaker open
      Logger.warn("Circuit breaker open for queue: #{target_queue}")
      {:reply, {:error, :circuit_breaker_open}, state}
    end
  end
  
  def handle_call({:add_rule, rule}, _from, state) do
    rule = struct(RoutingRule, rule)
    state = put_in(state.routing_rules[rule.id], rule)
    Logger.info("Added routing rule: #{rule.name}")
    {:reply, :ok, state}
  end
  
  def handle_call({:remove_rule, rule_id}, _from, state) do
    state = update_in(state.routing_rules, &Map.delete(&1, rule_id))
    {:reply, :ok, state}
  end
  
  def handle_call({:update_rule, rule_id, updates}, _from, state) do
    state = update_in(state.routing_rules[rule_id], fn rule ->
      struct(rule, updates)
    end)
    {:reply, :ok, state}
  end
  
  def handle_call(:get_metrics, _from, state) do
    {:reply, {:ok, state.metrics}, state}
  end
  
  def handle_call(:get_queue_stats, _from, state) do
    {:reply, {:ok, state.queue_stats}, state}
  end
  
  def handle_cast({:register_consumer, queue_name, consumer_info}, state) do
    state = update_in(state.consumer_registry[queue_name], fn
      nil -> [consumer_info]
      consumers -> [consumer_info | consumers]
    end)
    
    # Initialize queue stats if needed
    state = ensure_queue_stats(state, queue_name)
    
    {:noreply, state}
  end
  
  def handle_info(:collect_metrics, state) do
    # Collect queue metrics from AMQP
    state = update_queue_metrics(state)
    
    # Reset circuit breakers if needed
    state = check_circuit_breakers(state)
    
    schedule_metrics_collection()
    {:noreply, state}
  end
  
  def handle_info({:circuit_breaker_timeout, queue_name}, state) do
    # Reset circuit breaker
    state = reset_circuit_breaker(state, queue_name)
    Logger.info("Circuit breaker reset for queue: #{queue_name}")
    {:noreply, state}
  end
  
  # Routing Logic
  
  defp apply_routing_rules(message, default_routing_key, headers, priority, state) do
    # Start with defaults
    initial = {state.config.default_exchange, default_routing_key, priority}
    
    # Apply each enabled rule
    state.routing_rules
    |> Map.values()
    |> Enum.filter(& &1.enabled)
    |> Enum.reduce(initial, fn rule, {exchange, routing_key, prio} ->
      if evaluate_rule_condition(rule, message, headers) do
        new_exchange = rule.target_exchange || exchange
        new_routing_key = apply_routing_pattern(rule.routing_key_pattern, routing_key, message)
        new_priority = apply_priority_modifier(prio, rule.priority_modifier)
        
        {new_exchange, new_routing_key, new_priority}
      else
        {exchange, routing_key, prio}
      end
    end)
  end
  
  defp evaluate_rule_condition(rule, message, headers) do
    case rule.condition do
      {:message_type, type} ->
        message["type"] == type
      
      {:header_match, header_name, value} ->
        get_header_value(headers, header_name) == value
      
      {:priority_range, min, max} ->
        priority = get_header_value(headers, "priority", @default_priority)
        priority >= min && priority <= max
      
      {:custom, fun} when is_function(fun) ->
        fun.(message, headers)
      
      _ ->
        true
    end
  end
  
  defp apply_routing_pattern(nil, routing_key, _message), do: routing_key
  defp apply_routing_pattern(pattern, routing_key, message) do
    # Simple pattern substitution
    pattern
    |> String.replace("{routing_key}", routing_key)
    |> String.replace("{message_type}", message["type"] || "unknown")
    |> String.replace("{timestamp}", to_string(System.system_time(:second)))
  end
  
  defp apply_priority_modifier(priority, nil), do: priority
  defp apply_priority_modifier(priority, modifier) when is_integer(modifier) do
    new_priority = priority + modifier
    max(0, min(@max_priority - 1, new_priority))
  end
  defp apply_priority_modifier(priority, {:multiply, factor}) do
    new_priority = round(priority * factor)
    max(0, min(@max_priority - 1, new_priority))
  end
  
  # Load Balancing
  
  defp select_target_queue(routing_key, state) do
    # Get candidate queues
    candidates = get_candidate_queues(routing_key, state)
    
    case state.config.load_balance_algorithm do
      :round_robin ->
        select_round_robin(candidates, state)
      
      :least_loaded ->
        select_least_loaded(candidates, state)
      
      :random ->
        Enum.random(candidates)
      
      :sticky ->
        select_sticky(routing_key, candidates, state)
      
      _ ->
        # Default to first candidate
        hd(candidates)
    end
  end
  
  defp get_candidate_queues(routing_key, state) do
    # For now, return queues that match the routing pattern
    # In production, this would use more sophisticated matching
    state.consumer_registry
    |> Map.keys()
    |> Enum.filter(fn queue ->
      matches_routing_pattern?(queue, routing_key)
    end)
    |> case do
      [] -> [routing_key]  # Default to routing key as queue name
      queues -> queues
    end
  end
  
  defp matches_routing_pattern?(queue, routing_key) do
    # Simple pattern matching - can be enhanced
    String.contains?(queue, String.split(routing_key, ".") |> hd())
  end
  
  defp select_round_robin(candidates, state) do
    # Simple round-robin selection
    index = rem(state.metrics.total_routed, length(candidates))
    Enum.at(candidates, index)
  end
  
  defp select_least_loaded(candidates, state) do
    # Select queue with lowest message count
    candidates
    |> Enum.min_by(fn queue ->
      case state.queue_stats[queue] do
        nil -> 0
        stats -> stats.message_count
      end
    end)
  end
  
  defp select_sticky(routing_key, candidates, _state) do
    # Use consistent hashing for sticky routing
    hash = :erlang.phash2(routing_key, length(candidates))
    Enum.at(candidates, hash)
  end
  
  # Circuit Breaker
  
  defp should_route?(queue_name, state) do
    if state.config.enable_circuit_breaker do
      case state.circuit_breakers[queue_name] do
        nil -> true
        %{state: :open} -> false
        %{state: :closed} -> true
        %{state: :half_open, attempts: attempts} -> attempts < 3
      end
    else
      true
    end
  end
  
  defp trip_circuit_breaker(state, queue_name) do
    Process.send_after(self(), {:circuit_breaker_timeout, queue_name}, @circuit_breaker_timeout)
    
    put_in(state.circuit_breakers[queue_name], %{
      state: :open,
      tripped_at: DateTime.utc_now(),
      failures: 0
    })
  end
  
  defp reset_circuit_breaker(state, queue_name) do
    put_in(state.circuit_breakers[queue_name], %{
      state: :half_open,
      attempts: 0
    })
  end
  
  defp check_circuit_breakers(state) do
    Enum.reduce(state.circuit_breakers, state, fn {queue, breaker}, acc ->
      case breaker do
        %{state: :half_open, attempts: attempts} when attempts >= 3 ->
          # Success - fully close the breaker
          put_in(acc.circuit_breakers[queue], %{state: :closed, failures: 0})
        
        _ ->
          acc
      end
    end)
  end
  
  # Message Routing
  
  defp perform_routing(channel, payload, exchange, routing_key, headers, priority) do
    options = [
      headers: headers,
      priority: priority,
      persistent: true
    ]
    
    try do
      AMQP.Basic.publish(channel, exchange, routing_key, payload, options)
      {:ok, %{exchange: exchange, routing_key: routing_key, priority: priority}}
    rescue
      error ->
        Logger.error("Routing failed: #{inspect(error)}")
        {:error, error}
    end
  end
  
  # Metrics and Monitoring
  
  defp update_routing_metrics(state, priority, result) do
    state
    |> update_in([:metrics, :total_routed], &(&1 + 1))
    |> update_in([:metrics, :by_priority, priority], &((&1 || 0) + 1))
    |> update_routing_result_metrics(result)
  end
  
  defp update_routing_result_metrics(state, {:ok, _}), do: state
  defp update_routing_result_metrics(state, {:error, _}) do
    update_in(state, [:metrics, :failures], &(&1 + 1))
  end
  
  defp update_queue_metrics(state) do
    # In production, query actual queue stats from AMQP
    # For now, simulate with timestamps
    Enum.reduce(state.queue_stats, state, fn {queue, stats}, acc ->
      updated_stats = %{stats | last_routed: DateTime.utc_now()}
      put_in(acc.queue_stats[queue], updated_stats)
    end)
  end
  
  defp ensure_queue_stats(state, queue_name) do
    if state.queue_stats[queue_name] do
      state
    else
      stats = %QueueStats{
        queue_name: queue_name,
        message_count: 0,
        consumer_count: 1,
        average_processing_time: 0,
        last_routed: DateTime.utc_now(),
        circuit_breaker_state: :closed,
        failures: 0
      }
      
      put_in(state.queue_stats[queue_name], stats)
    end
  end
  
  # Default Rules
  
  defp load_default_rules(state) do
    default_rules = [
      %RoutingRule{
        id: "emergency_priority",
        name: "Emergency Message Priority Boost",
        condition: {:message_type, "emergency"},
        priority_modifier: 5,
        enabled: true
      },
      %RoutingRule{
        id: "algedonic_routing",
        name: "Algedonic Signal Fast Track",
        condition: {:message_type, "algedonic"},
        target_exchange: "vsm.algedonic",
        routing_key_pattern: "algedonic.{message_type}",
        priority_modifier: 4,
        enabled: true
      },
      %RoutingRule{
        id: "meta_learning_distribution",
        name: "Meta Learning Distribution",
        condition: {:message_type, "meta_learning"},
        load_balance_strategy: :round_robin,
        enabled: true
      },
      %RoutingRule{
        id: "low_priority_throttle",
        name: "Low Priority Throttling",
        condition: {:priority_range, 0, 2},
        priority_modifier: -1,
        enabled: true
      }
    ]
    
    rules_map = Enum.reduce(default_rules, %{}, fn rule, acc ->
      Map.put(acc, rule.id, rule)
    end)
    
    %{state | routing_rules: rules_map}
  end
  
  # Utilities
  
  defp initialize_priority_queues do
    0..(@max_priority - 1)
    |> Enum.map(fn priority -> {priority, :queue.new()} end)
    |> Enum.into(%{})
  end
  
  defp decode_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, message} -> message
      _ -> %{}
    end
  end
  defp decode_payload(_), do: %{}
  
  defp get_header_value(headers, key, default \\ nil) do
    case List.keyfind(headers, key, 0) do
      {^key, _type, value} -> value
      nil -> default
    end
  end
  
  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, 30_000)  # 30 seconds
  end
end