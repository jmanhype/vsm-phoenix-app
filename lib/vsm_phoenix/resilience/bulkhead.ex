defmodule VsmPhoenix.Resilience.Bulkhead do
  @moduledoc """
  Bulkhead pattern implementation for resource isolation.

  Features:
  - Resource pooling with size limits
  - Queue management for pending requests
  - Timeout handling for resource acquisition
  - Metrics and monitoring
  - Graceful degradation under load
  """

  use GenServer
  require Logger

  defstruct name: nil,
            max_concurrent: 10,
            max_waiting: 50,
            checkout_timeout: 5_000,
            # Internal state
            available: [],
            busy: %{},
            waiting_queue: :queue.new(),
            metrics: %{
              total_checkouts: 0,
              successful_checkouts: 0,
              rejected_checkouts: 0,
              timeouts: 0,
              current_usage: 0,
              peak_usage: 0,
              queue_size: 0,
              peak_queue_size: 0
            }

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Check out a resource from the bulkhead pool
  """
  def checkout(bulkhead, timeout \\ 5_000) do
    GenServer.call(bulkhead, {:checkout, self(), timeout}, timeout + 100)
  end

  @doc """
  Return a resource to the bulkhead pool
  """
  def checkin(bulkhead, resource) do
    GenServer.cast(bulkhead, {:checkin, resource})
  end

  @doc """
  Execute a function with a resource from the pool
  """
  def with_resource(bulkhead, fun, timeout \\ 5_000) do
    case checkout(bulkhead, timeout) do
      {:ok, resource} ->
        try do
          result = fun.(resource)
          {:ok, result}
        after
          checkin(bulkhead, resource)
        end

      error ->
        error
    end
  end

  @doc """
  Get current bulkhead metrics
  """
  def get_metrics(bulkhead) do
    GenServer.call(bulkhead, :get_metrics)
  end

  @doc """
  Get current bulkhead state
  """
  def get_state(bulkhead) do
    GenServer.call(bulkhead, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    max_concurrent = Keyword.get(opts, :max_concurrent, 10)
    max_waiting = Keyword.get(opts, :max_waiting, 50)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, 5_000)

    # Initialize resource pool
    resources = for i <- 1..max_concurrent, do: {name, i}

    state = %__MODULE__{
      name: name,
      max_concurrent: max_concurrent,
      max_waiting: max_waiting,
      checkout_timeout: checkout_timeout,
      available: resources
    }

    Logger.info("🛡️  Bulkhead #{name} initialized with #{max_concurrent} resources")

    {:ok, state}
  end

  @impl true
  def handle_call({:checkout, from_pid, timeout}, from, state) do
    state = update_metrics(state, :total_checkouts, 1)

    cond do
      # Resources available
      length(state.available) > 0 ->
        [resource | remaining] = state.available
        ref = Process.monitor(from_pid)

        busy = Map.put(state.busy, resource, {from_pid, ref})

        state =
          %{state | available: remaining, busy: busy}
          |> update_usage_metrics()
          |> update_metrics(:successful_checkouts, 1)

        # Resource checkout logged via telemetry events

        {:reply, {:ok, resource}, state}

      # Queue is full
      :queue.len(state.waiting_queue) >= state.max_waiting ->
        state = update_metrics(state, :rejected_checkouts, 1)
        Logger.warning("❌ Bulkhead #{state.name}: Queue full, rejecting request")
        {:reply, {:error, :bulkhead_full}, state}

      # Add to waiting queue
      true ->
        timer_ref = Process.send_after(self(), {:checkout_timeout, from}, timeout)
        queue_item = {from, from_pid, timer_ref}
        new_queue = :queue.in(queue_item, state.waiting_queue)

        state =
          %{state | waiting_queue: new_queue}
          |> update_queue_metrics()

        # Queue status logged via telemetry events

        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    info = %{
      available: length(state.available),
      busy: map_size(state.busy),
      waiting: :queue.len(state.waiting_queue),
      max_concurrent: state.max_concurrent,
      max_waiting: state.max_waiting
    }

    {:reply, info, state}
  end

  @impl true
  def handle_cast({:checkin, resource}, state) do
    case Map.get(state.busy, resource) do
      {_pid, ref} ->
        Process.demonitor(ref, [:flush])

        busy = Map.delete(state.busy, resource)

        # Check if anyone is waiting
        case :queue.out(state.waiting_queue) do
          {{:value, {from, from_pid, timer_ref}}, new_queue} ->
            # Cancel timeout timer
            Process.cancel_timer(timer_ref)

            # Give resource to waiting process
            new_ref = Process.monitor(from_pid)
            busy = Map.put(busy, resource, {from_pid, new_ref})

            GenServer.reply(from, {:ok, resource})

            state =
              %{state | busy: busy, waiting_queue: new_queue}
              |> update_queue_metrics()
              |> update_metrics(:successful_checkouts, 1)

            # Resource transfer logged via telemetry events

            {:noreply, state}

          {:empty, _} ->
            # Return resource to available pool
            state =
              %{state | available: [resource | state.available], busy: busy}
              |> update_usage_metrics()

            # Resource return logged via telemetry events

            {:noreply, state}
        end

      nil ->
        Logger.warning(
          "⚠️  Bulkhead #{state.name}: Unknown resource returned: #{inspect(resource)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find and release any resources held by the dead process
    resources_to_release =
      state.busy
      |> Enum.filter(fn {_, {owner_pid, _}} -> owner_pid == pid end)
      |> Enum.map(fn {resource, _} -> resource end)

    # Release all resources held by the dead process
    new_state =
      Enum.reduce(resources_to_release, state, fn resource, acc_state ->
        {:noreply, updated_state} = handle_cast({:checkin, resource}, acc_state)
        updated_state
      end)

    if length(resources_to_release) > 0 do
      Logger.info(
        "🔓 Bulkhead #{state.name}: Released #{length(resources_to_release)} resources from crashed process"
      )
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:checkout_timeout, from}, state) do
    # Remove from waiting queue
    new_queue =
      :queue.filter(
        fn {waiting_from, _, _} -> waiting_from != from end,
        state.waiting_queue
      )

    if :queue.len(new_queue) < :queue.len(state.waiting_queue) do
      GenServer.reply(from, {:error, :timeout})

      state =
        %{state | waiting_queue: new_queue}
        |> update_queue_metrics()
        |> update_metrics(:timeouts, 1)

      Logger.warning("⏱️  Bulkhead #{state.name}: Checkout timeout")

      {:noreply, state}
    else
      # Already handled
      {:noreply, state}
    end
  end

  # Private Functions

  defp update_metrics(state, metric, increment) do
    new_metrics = Map.update!(state.metrics, metric, &(&1 + increment))
    %{state | metrics: new_metrics}
  end

  defp update_usage_metrics(state) do
    current_usage = map_size(state.busy)
    peak_usage = max(current_usage, state.metrics.peak_usage)

    new_metrics = %{state.metrics | current_usage: current_usage, peak_usage: peak_usage}

    %{state | metrics: new_metrics}
  end

  defp update_queue_metrics(state) do
    queue_size = :queue.len(state.waiting_queue)
    peak_queue_size = max(queue_size, state.metrics.peak_queue_size)

    new_metrics = %{state.metrics | queue_size: queue_size, peak_queue_size: peak_queue_size}

    %{state | metrics: new_metrics}
  end
end
