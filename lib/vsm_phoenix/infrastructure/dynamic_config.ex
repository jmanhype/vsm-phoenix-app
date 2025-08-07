defmodule VsmPhoenix.Infrastructure.DynamicConfig do
  @moduledoc """
  Dynamic configuration system that adapts infrastructure settings based on system performance.
  Provides adaptive configuration for timeouts, thresholds, and limits.
  """

  use GenServer
  require Logger

  @default_config %{
    # Similarity threshold configuration
    similarity: %{
      threshold: 0.95,
      ttl: 60_000,
      cache_size_limit: 10_000
    },
    
    # Async runner configuration
    async_runner: %{
      timeout: 30_000,
      max_concurrency: System.schedulers_online() * 2,
      task_queue_limit: 1_000
    },
    
    # Safe PubSub configuration
    pubsub: %{
      retry_count: 3,
      retry_delay: 100,
      timeout: 5_000
    },
    
    # AMQP configuration
    amqp: %{
      connection_timeout: 10_000,
      channel_timeout: 5_000,
      publish_timeout: 2_000,
      consume_timeout: 30_000,
      heartbeat: 60
    },
    
    # Circuit breaker configuration
    circuit_breaker: %{
      failure_threshold: 5,
      reset_timeout: 60_000,
      half_open_tries: 3,
      window_size: 60_000
    },
    
    # Bulkhead configuration
    bulkhead: %{
      pool_size: 10,
      queue_size: 50,
      timeout: 5_000
    }
  }

  @performance_window 300_000  # 5 minutes
  @adjustment_interval 60_000  # 1 minute

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get dynamic configuration value.
  """
  def get(path) when is_list(path) do
    GenServer.call(__MODULE__, {:get, path})
  end

  def get(key) when is_atom(key) do
    get([key])
  end

  @doc """
  Get all configuration for a component.
  """
  def get_component(component) when is_atom(component) do
    GenServer.call(__MODULE__, {:get_component, component})
  end

  @doc """
  Update performance metrics for adaptive tuning.
  """
  def report_metric(component, metric, value) do
    GenServer.cast(__MODULE__, {:report_metric, component, metric, value})
  end

  @doc """
  Report operation outcome for adaptive learning.
  """
  def report_outcome(component, operation, outcome) do
    GenServer.cast(__MODULE__, {:report_outcome, component, operation, outcome})
  end

  @doc """
  Get current performance snapshot.
  """
  def get_performance_snapshot do
    GenServer.call(__MODULE__, :get_performance_snapshot)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Load initial config from environment or use defaults
    initial_config = load_initial_config(opts)
    
    # Initialize performance tracking
    :ets.new(:dynamic_config_metrics, [:set, :public, :named_table])
    :ets.new(:dynamic_config_outcomes, [:set, :public, :named_table])
    
    # Schedule periodic adjustment
    schedule_adjustment()
    
    state = %{
      config: initial_config,
      performance_history: %{},
      adjustments_made: 0,
      last_adjustment: DateTime.utc_now()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:get, path}, _from, state) do
    value = get_in(state.config, path)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:get_component, component}, _from, state) do
    config = Map.get(state.config, component, %{})
    {:reply, config, state}
  end

  @impl true
  def handle_call(:get_performance_snapshot, _from, state) do
    metrics = collect_all_metrics()
    outcomes = collect_all_outcomes()
    
    snapshot = %{
      config: state.config,
      metrics: metrics,
      outcomes: outcomes,
      adjustments_made: state.adjustments_made,
      last_adjustment: state.last_adjustment
    }
    
    {:reply, snapshot, state}
  end

  @impl true
  def handle_cast({:report_metric, component, metric, value}, state) do
    # Store metric with timestamp
    key = {component, metric}
    timestamp = System.monotonic_time(:millisecond)
    
    # Get existing metrics and add new one
    existing = :ets.lookup(:dynamic_config_metrics, key)
    metrics = case existing do
      [{^key, metrics_list}] -> metrics_list
      [] -> []
    end
    
    # Keep only recent metrics (within performance window)
    cutoff = timestamp - @performance_window
    updated_metrics = [{timestamp, value} | metrics]
    |> Enum.filter(fn {ts, _} -> ts > cutoff end)
    |> Enum.take(1000)  # Limit history size
    
    :ets.insert(:dynamic_config_metrics, {key, updated_metrics})
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:report_outcome, component, operation, outcome}, state) do
    # Track operation outcomes for learning
    key = {component, operation}
    timestamp = System.monotonic_time(:millisecond)
    
    existing = :ets.lookup(:dynamic_config_outcomes, key)
    outcomes = case existing do
      [{^key, outcomes_list}] -> outcomes_list
      [] -> []
    end
    
    # Store outcome with current config
    outcome_data = %{
      timestamp: timestamp,
      outcome: outcome,
      config: Map.get(state.config, component, %{})
    }
    
    # Keep recent outcomes
    cutoff = timestamp - @performance_window
    updated_outcomes = [outcome_data | outcomes]
    |> Enum.filter(fn %{timestamp: ts} -> ts > cutoff end)
    |> Enum.take(500)
    
    :ets.insert(:dynamic_config_outcomes, {key, updated_outcomes})
    
    {:noreply, state}
  end

  @impl true
  def handle_info(:adjust_config, state) do
    # Perform adaptive adjustments
    new_state = perform_adjustments(state)
    
    # Schedule next adjustment
    schedule_adjustment()
    
    {:noreply, new_state}
  end

  # Private Functions

  defp load_initial_config(opts) do
    # Load from application environment
    app_config = Application.get_env(:vsm_phoenix, :dynamic_config, %{})
    
    # Merge with defaults
    DeepMerge.deep_merge(@default_config, app_config)
    |> DeepMerge.deep_merge(Keyword.get(opts, :config, %{}))
  end

  defp schedule_adjustment do
    Process.send_after(self(), :adjust_config, @adjustment_interval)
  end

  defp perform_adjustments(state) do
    Logger.debug("Performing dynamic config adjustments...")
    
    # Collect current performance data
    metrics = collect_all_metrics()
    outcomes = collect_all_outcomes()
    
    # Adjust each component's configuration
    new_config = state.config
    |> adjust_similarity_config(metrics, outcomes)
    |> adjust_async_runner_config(metrics, outcomes)
    |> adjust_pubsub_config(metrics, outcomes)
    |> adjust_amqp_config(metrics, outcomes)
    |> adjust_circuit_breaker_config(metrics, outcomes)
    |> adjust_bulkhead_config(metrics, outcomes)
    
    %{state | 
      config: new_config,
      adjustments_made: state.adjustments_made + 1,
      last_adjustment: DateTime.utc_now()
    }
  end

  defp adjust_similarity_config(config, metrics, outcomes) do
    similarity_metrics = get_component_metrics(metrics, :similarity)
    
    # Adjust threshold based on cache hit rate
    hit_rate = calculate_rate(similarity_metrics, :cache_hit, :cache_miss)
    new_threshold = cond do
      hit_rate > 0.95 -> min(config.similarity.threshold * 1.02, 0.99)  # Too many hits, increase threshold
      hit_rate < 0.70 -> max(config.similarity.threshold * 0.98, 0.80)  # Too few hits, decrease threshold
      true -> config.similarity.threshold
    end
    
    # Adjust TTL based on access patterns
    access_frequency = calculate_metric_average(similarity_metrics, :access_frequency)
    new_ttl = cond do
      access_frequency > 100 -> min(config.similarity.ttl * 1.1, 300_000)  # High frequency, increase TTL
      access_frequency < 10 -> max(config.similarity.ttl * 0.9, 10_000)    # Low frequency, decrease TTL
      true -> config.similarity.ttl
    end
    
    put_in(config, [:similarity, :threshold], new_threshold)
    |> put_in([:similarity, :ttl], round(new_ttl))
  end

  defp adjust_async_runner_config(config, metrics, outcomes) do
    runner_metrics = get_component_metrics(metrics, :async_runner)
    runner_outcomes = get_component_outcomes(outcomes, :async_runner)
    
    # Adjust timeout based on completion times
    avg_completion = calculate_metric_average(runner_metrics, :completion_time)
    timeout_rate = calculate_outcome_rate(runner_outcomes, :timeout)
    
    new_timeout = cond do
      timeout_rate > 0.05 -> min(config.async_runner.timeout * 1.2, 120_000)  # Too many timeouts
      timeout_rate < 0.01 && avg_completion < config.async_runner.timeout * 0.5 ->
        max(config.async_runner.timeout * 0.9, 5_000)  # Can reduce timeout
      true -> config.async_runner.timeout
    end
    
    # Adjust concurrency based on system load
    queue_size = calculate_metric_average(runner_metrics, :queue_size)
    cpu_usage = calculate_metric_average(runner_metrics, :cpu_usage)
    
    new_concurrency = cond do
      queue_size > 100 && cpu_usage < 0.7 -> 
        min(config.async_runner.max_concurrency + 2, System.schedulers_online() * 4)
      queue_size < 10 && cpu_usage > 0.8 ->
        max(config.async_runner.max_concurrency - 1, System.schedulers_online())
      true -> config.async_runner.max_concurrency
    end
    
    put_in(config, [:async_runner, :timeout], round(new_timeout))
    |> put_in([:async_runner, :max_concurrency], new_concurrency)
  end

  defp adjust_pubsub_config(config, metrics, outcomes) do
    pubsub_metrics = get_component_metrics(metrics, :pubsub)
    pubsub_outcomes = get_component_outcomes(outcomes, :pubsub)
    
    # Adjust retry count based on failure patterns
    failure_rate = calculate_outcome_rate(pubsub_outcomes, :failure)
    retry_success_rate = calculate_outcome_rate(pubsub_outcomes, :retry_success)
    
    new_retry_count = cond do
      failure_rate > 0.1 && retry_success_rate > 0.8 -> 
        min(config.pubsub.retry_count + 1, 5)  # Retries are helping
      failure_rate < 0.01 -> 
        max(config.pubsub.retry_count - 1, 1)  # Few failures, reduce retries
      true -> config.pubsub.retry_count
    end
    
    # Adjust retry delay based on congestion
    avg_publish_time = calculate_metric_average(pubsub_metrics, :publish_time)
    new_retry_delay = cond do
      avg_publish_time > 50 -> min(config.pubsub.retry_delay * 1.5, 1000)  # System is slow
      avg_publish_time < 10 -> max(config.pubsub.retry_delay * 0.8, 50)    # System is fast
      true -> config.pubsub.retry_delay
    end
    
    put_in(config, [:pubsub, :retry_count], new_retry_count)
    |> put_in([:pubsub, :retry_delay], round(new_retry_delay))
  end

  defp adjust_amqp_config(config, metrics, outcomes) do
    amqp_metrics = get_component_metrics(metrics, :amqp)
    amqp_outcomes = get_component_outcomes(outcomes, :amqp)
    
    # Adjust connection timeout based on connection establishment times
    avg_connect_time = calculate_metric_average(amqp_metrics, :connection_time)
    connect_timeout_rate = calculate_outcome_rate(amqp_outcomes, :connection_timeout)
    
    new_connection_timeout = cond do
      connect_timeout_rate > 0.05 -> min(config.amqp.connection_timeout * 1.2, 30_000)
      avg_connect_time < config.amqp.connection_timeout * 0.3 ->
        max(config.amqp.connection_timeout * 0.9, 5_000)
      true -> config.amqp.connection_timeout
    end
    
    # Adjust heartbeat based on network stability
    disconnect_rate = calculate_outcome_rate(amqp_outcomes, :unexpected_disconnect)
    new_heartbeat = cond do
      disconnect_rate > 0.02 -> max(config.amqp.heartbeat * 0.8, 30)  # More frequent heartbeats
      disconnect_rate < 0.001 -> min(config.amqp.heartbeat * 1.2, 120)  # Less frequent heartbeats
      true -> config.amqp.heartbeat
    end
    
    put_in(config, [:amqp, :connection_timeout], round(new_connection_timeout))
    |> put_in([:amqp, :heartbeat], round(new_heartbeat))
  end

  defp adjust_circuit_breaker_config(config, metrics, outcomes) do
    cb_metrics = get_component_metrics(metrics, :circuit_breaker)
    cb_outcomes = get_component_outcomes(outcomes, :circuit_breaker)
    
    # Adjust failure threshold based on system stability
    false_positive_rate = calculate_outcome_rate(cb_outcomes, :false_positive)
    recovery_time = calculate_metric_average(cb_metrics, :recovery_time)
    
    new_threshold = cond do
      false_positive_rate > 0.1 -> min(config.circuit_breaker.failure_threshold + 1, 10)
      recovery_time < 10_000 && false_positive_rate < 0.02 ->
        max(config.circuit_breaker.failure_threshold - 1, 3)
      true -> config.circuit_breaker.failure_threshold
    end
    
    # Adjust reset timeout based on recovery patterns
    new_reset_timeout = cond do
      recovery_time > config.circuit_breaker.reset_timeout * 0.8 ->
        min(config.circuit_breaker.reset_timeout * 1.2, 300_000)
      recovery_time < config.circuit_breaker.reset_timeout * 0.3 ->
        max(config.circuit_breaker.reset_timeout * 0.8, 30_000)
      true -> config.circuit_breaker.reset_timeout
    end
    
    put_in(config, [:circuit_breaker, :failure_threshold], new_threshold)
    |> put_in([:circuit_breaker, :reset_timeout], round(new_reset_timeout))
  end

  defp adjust_bulkhead_config(config, metrics, outcomes) do
    bh_metrics = get_component_metrics(metrics, :bulkhead)
    bh_outcomes = get_component_outcomes(outcomes, :bulkhead)
    
    # Adjust pool size based on utilization
    avg_utilization = calculate_metric_average(bh_metrics, :pool_utilization)
    rejection_rate = calculate_outcome_rate(bh_outcomes, :rejected)
    
    new_pool_size = cond do
      avg_utilization > 0.9 && rejection_rate > 0.05 ->
        min(config.bulkhead.pool_size + 2, 50)  # Need more capacity
      avg_utilization < 0.3 && rejection_rate < 0.01 ->
        max(config.bulkhead.pool_size - 1, 5)   # Can reduce capacity
      true -> config.bulkhead.pool_size
    end
    
    # Adjust queue size based on wait times
    avg_queue_time = calculate_metric_average(bh_metrics, :queue_wait_time)
    new_queue_size = cond do
      avg_queue_time > 1000 -> min(config.bulkhead.queue_size + 10, 200)
      avg_queue_time < 100 && rejection_rate < 0.01 ->
        max(config.bulkhead.queue_size - 5, 20)
      true -> config.bulkhead.queue_size
    end
    
    put_in(config, [:bulkhead, :pool_size], new_pool_size)
    |> put_in([:bulkhead, :queue_size], new_queue_size)
  end

  # Helper functions

  defp collect_all_metrics do
    :ets.tab2list(:dynamic_config_metrics)
    |> Enum.into(%{})
  end

  defp collect_all_outcomes do
    :ets.tab2list(:dynamic_config_outcomes)
    |> Enum.into(%{})
  end

  defp get_component_metrics(metrics, component) do
    metrics
    |> Enum.filter(fn {{comp, _}, _} -> comp == component end)
    |> Enum.into(%{})
  end

  defp get_component_outcomes(outcomes, component) do
    outcomes
    |> Enum.filter(fn {{comp, _}, _} -> comp == component end)
    |> Enum.into(%{})
  end

  defp calculate_rate(metrics, success_key, failure_key) do
    success_count = count_metric_occurrences(metrics, success_key)
    failure_count = count_metric_occurrences(metrics, failure_key)
    total = success_count + failure_count
    
    if total > 0 do
      success_count / total
    else
      0.5  # Default when no data
    end
  end

  defp calculate_outcome_rate(outcomes, outcome_type) do
    total = Enum.reduce(outcomes, 0, fn {_, outcome_list}, acc ->
      acc + length(outcome_list)
    end)
    
    matching = Enum.reduce(outcomes, 0, fn {_, outcome_list}, acc ->
      matches = Enum.count(outcome_list, fn %{outcome: outcome} ->
        outcome == outcome_type
      end)
      acc + matches
    end)
    
    if total > 0 do
      matching / total
    else
      0.0
    end
  end

  defp calculate_metric_average(metrics, metric_key) do
    case metrics[{:_, metric_key}] || metrics[metric_key] do
      nil -> 0
      metric_list when is_list(metric_list) ->
        if length(metric_list) > 0 do
          sum = Enum.reduce(metric_list, 0, fn {_, value}, acc -> acc + value end)
          sum / length(metric_list)
        else
          0
        end
      _ -> 0
    end
  end

  defp count_metric_occurrences(metrics, key) do
    case metrics[{:_, key}] || metrics[key] do
      nil -> 0
      metric_list when is_list(metric_list) -> length(metric_list)
      _ -> 0
    end
  end
end

defmodule DeepMerge do
  @moduledoc false
  
  def deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, &deep_resolve/3)
  end
  
  def deep_merge(_left, right), do: right
  
  defp deep_resolve(_key, left, right) when is_map(left) and is_map(right) do
    deep_merge(left, right)
  end
  
  defp deep_resolve(_key, _left, right), do: right
end