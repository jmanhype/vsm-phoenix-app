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
  alias VsmPhoenix.Infrastructure.DynamicConfig

  defstruct name: nil,
            max_concurrent: 10,
            max_waiting: 50,
            checkout_timeout: 5_000,
            # Internal state
            available: [],
            busy: %{},
            waiting_queue: :queue.new(),
            # Claude-inspired workflow reliability patterns
            workflow_contexts: %{},
            multi_section_operations: %{},
            reliability_checkpoints: [],
            metrics: %{
              total_checkouts: 0,
              successful_checkouts: 0,
              rejected_checkouts: 0,
              timeouts: 0,
              current_usage: 0,
              peak_usage: 0,
              queue_size: 0,
              peak_queue_size: 0,
              # Claude-inspired reliability metrics
              workflow_success_rate: 1.0,
              checkpoint_rollbacks: 0,
              section_completion_rate: 1.0
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
  Execute a multi-section workflow with Claude-inspired reliability patterns
  """
  def with_workflow(bulkhead, workflow_id, sections, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    checkpoint_interval = Keyword.get(opts, :checkpoint_interval, 3)
    
    case checkout(bulkhead, timeout) do
      {:ok, resource} ->
        try do
          execute_workflow_sections(bulkhead, resource, workflow_id, sections, checkpoint_interval)
        after
          checkin(bulkhead, resource)
        end
      
      error ->
        error
    end
  end

  @doc """
  Create a reliability checkpoint for workflow rollback
  """
  def create_checkpoint(bulkhead, workflow_id, section_index, state) do
    GenServer.cast(bulkhead, {:create_checkpoint, workflow_id, section_index, state})
  end

  @doc """
  Rollback to a previous checkpoint
  """
  def rollback_to_checkpoint(bulkhead, workflow_id, checkpoint_index) do
    GenServer.call(bulkhead, {:rollback_to_checkpoint, workflow_id, checkpoint_index})
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
    
    # Get dynamic configuration
    config = DynamicConfig.get_component(:bulkhead)
    
    max_concurrent = Keyword.get(opts, :max_concurrent, config[:pool_size] || 10)
    max_waiting = Keyword.get(opts, :max_waiting, config[:queue_size] || 50)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, config[:timeout] || 5_000)

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
    start_time = System.monotonic_time(:millisecond)

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

        # Report metrics
        pool_utilization = map_size(busy) / state.max_concurrent
        DynamicConfig.report_metric(:bulkhead, :pool_utilization, pool_utilization)
        DynamicConfig.report_outcome(:bulkhead, state.name, :checkout_success)

        {:reply, {:ok, resource}, state}

      # Queue is full
      :queue.len(state.waiting_queue) >= state.max_waiting ->
        state = update_metrics(state, :rejected_checkouts, 1)
        Logger.warning("❌ Bulkhead #{state.name}: Queue full, rejecting request")
        
        # Report rejection
        DynamicConfig.report_outcome(:bulkhead, state.name, :rejected)
        
        {:reply, {:error, :bulkhead_full}, state}

      # Add to waiting queue
      true ->
        timer_ref = Process.send_after(self(), {:checkout_timeout, from}, timeout)
        queue_item = {from, from_pid, timer_ref, start_time}
        new_queue = :queue.in(queue_item, state.waiting_queue)

        state =
          %{state | waiting_queue: new_queue}
          |> update_queue_metrics()

        # Report queue metrics
        queue_size = :queue.len(new_queue)
        DynamicConfig.report_metric(:bulkhead, :queue_size, queue_size)

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
            
            # Report queue wait time if start_time is available
            case timer_ref do
              {_, _, _, start_time} ->
                wait_time = System.monotonic_time(:millisecond) - start_time
                DynamicConfig.report_metric(:bulkhead, :queue_wait_time, wait_time)
              _ -> :ok
            end

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

  # Claude-inspired workflow reliability functions

  @impl true
  def handle_cast({:create_checkpoint, workflow_id, section_index, state_data}, state) do
    checkpoint = %{
      workflow_id: workflow_id,
      section_index: section_index,
      state_data: state_data,
      timestamp: System.monotonic_time(:millisecond)
    }
    
    new_checkpoints = [checkpoint | state.reliability_checkpoints] |> Enum.take(10)  # Keep last 10
    
    Logger.info("📍 Created reliability checkpoint for workflow #{workflow_id} at section #{section_index}")
    
    {:noreply, %{state | reliability_checkpoints: new_checkpoints}}
  end

  @impl true  
  def handle_call({:rollback_to_checkpoint, workflow_id, checkpoint_index}, _from, state) do
    case find_checkpoint(state.reliability_checkpoints, workflow_id, checkpoint_index) do
      nil ->
        {:reply, {:error, :checkpoint_not_found}, state}
      
      checkpoint ->
        Logger.warning("⏪ Rolling back workflow #{workflow_id} to checkpoint #{checkpoint_index}")
        
        # Update rollback metrics
        new_metrics = Map.update!(state.metrics, :checkpoint_rollbacks, &(&1 + 1))
        new_state = %{state | metrics: new_metrics}
        
        {:reply, {:ok, checkpoint.state_data}, new_state}
    end
  end

  defp execute_workflow_sections(bulkhead, resource, workflow_id, sections, checkpoint_interval) do
    # Initialize workflow context
    GenServer.cast(bulkhead, {:init_workflow, workflow_id, length(sections)})
    
    # Execute sections with Claude's multi-section reliability approach
    {result, final_state} = sections
                           |> Enum.with_index(1)
                           |> Enum.reduce_while({:ok, nil}, fn {section, index}, {_acc, state} ->
                               # Create checkpoint periodically (Claude's systematic approach)
                               if rem(index, checkpoint_interval) == 0 do
                                 create_checkpoint(bulkhead, workflow_id, index, state)
                               end
                               
                               # Execute section with error handling
                               case execute_section_safely(section, resource, state) do
                                 {:ok, new_state} ->
                                   # Update section completion rate
                                   GenServer.cast(bulkhead, {:section_completed, workflow_id, index, true})
                                   {:cont, {:ok, new_state}}
                                 
                                 {:error, reason} = error ->
                                   Logger.error("❌ Workflow #{workflow_id} section #{index} failed: #{inspect(reason)}")
                                   GenServer.cast(bulkhead, {:section_completed, workflow_id, index, false})
                                   
                                   # Try rollback to last checkpoint (Claude's self-correction approach)
                                   case attempt_workflow_recovery(bulkhead, workflow_id, index) do
                                     {:ok, recovered_state} ->
                                       Logger.info("🔧 Workflow #{workflow_id} recovered from checkpoint")
                                       {:cont, {:ok, recovered_state}}
                                     
                                     {:error, _} ->
                                       {:halt, error}
                                   end
                               end
                             end)
    
    # Finalize workflow
    GenServer.cast(bulkhead, {:finalize_workflow, workflow_id, result})
    
    case result do
      {:ok, _} -> {:ok, final_state}
      error -> error
    end
  end

  defp execute_section_safely(section, resource, previous_state) do
    try do
      case section do
        {module, function, args} ->
          apply(module, function, [resource, previous_state | args])
        
        fun when is_function(fun, 2) ->
          fun.(resource, previous_state)
        
        fun when is_function(fun, 1) ->
          fun.(resource)
        
        _ ->
          {:error, :invalid_section_format}
      end
    rescue
      error ->
        {:error, {:section_execution_failed, error}}
    catch
      :exit, reason ->
        {:error, {:section_exit, reason}}
    end
  end

  defp attempt_workflow_recovery(bulkhead, workflow_id, failed_section_index) do
    # Find the most recent checkpoint before the failed section
    case GenServer.call(bulkhead, {:find_recovery_checkpoint, workflow_id, failed_section_index}) do
      {:ok, checkpoint_state} ->
        {:ok, checkpoint_state}
      
      {:error, :no_checkpoint} ->
        Logger.warning("⚠️ No recovery checkpoint available for workflow #{workflow_id}")
        {:error, :no_recovery_possible}
    end
  end

  @impl true
  def handle_call({:find_recovery_checkpoint, workflow_id, failed_section}, _from, state) do
    case find_latest_checkpoint_before(state.reliability_checkpoints, workflow_id, failed_section) do
      nil ->
        {:reply, {:error, :no_checkpoint}, state}
      
      checkpoint ->
        {:reply, {:ok, checkpoint.state_data}, state}
    end
  end

  @impl true
  def handle_cast({:init_workflow, workflow_id, total_sections}, state) do
    workflow_context = %{
      id: workflow_id,
      total_sections: total_sections,
      completed_sections: 0,
      failed_sections: 0,
      started_at: System.monotonic_time(:millisecond)
    }
    
    new_workflows = Map.put(state.workflow_contexts, workflow_id, workflow_context)
    
    {:noreply, %{state | workflow_contexts: new_workflows}}
  end

  @impl true
  def handle_cast({:section_completed, workflow_id, _section_index, success}, state) do
    case Map.get(state.workflow_contexts, workflow_id) do
      nil ->
        {:noreply, state}
      
      context ->
        updated_context = if success do
          %{context | completed_sections: context.completed_sections + 1}
        else
          %{context | failed_sections: context.failed_sections + 1}
        end
        
        new_workflows = Map.put(state.workflow_contexts, workflow_id, updated_context)
        
        # Update section completion rate metric
        total_attempts = updated_context.completed_sections + updated_context.failed_sections
        success_rate = if total_attempts > 0 do
          updated_context.completed_sections / total_attempts
        else
          1.0
        end
        
        new_metrics = %{state.metrics | section_completion_rate: success_rate}
        
        {:noreply, %{state | workflow_contexts: new_workflows, metrics: new_metrics}}
    end
  end

  @impl true
  def handle_cast({:finalize_workflow, workflow_id, result}, state) do
    case Map.get(state.workflow_contexts, workflow_id) do
      nil ->
        {:noreply, state}
      
      context ->
        duration = System.monotonic_time(:millisecond) - context.started_at
        success = match?({:ok, _}, result)
        
        Logger.info("🏁 Workflow #{workflow_id} completed in #{duration}ms, success: #{success}")
        
        # Update workflow success rate
        current_rate = state.metrics.workflow_success_rate
        new_rate = if success do
          min(1.0, current_rate * 0.95 + 0.05)  # Weighted average favoring recent success
        else
          current_rate * 0.95  # Decay on failure
        end
        
        new_metrics = %{state.metrics | workflow_success_rate: new_rate}
        new_workflows = Map.delete(state.workflow_contexts, workflow_id)
        
        {:noreply, %{state | workflow_contexts: new_workflows, metrics: new_metrics}}
    end
  end

  defp find_checkpoint(checkpoints, workflow_id, section_index) do
    Enum.find(checkpoints, fn checkpoint ->
      checkpoint.workflow_id == workflow_id and checkpoint.section_index == section_index
    end)
  end

  defp find_latest_checkpoint_before(checkpoints, workflow_id, section_index) do
    checkpoints
    |> Enum.filter(fn checkpoint ->
         checkpoint.workflow_id == workflow_id and checkpoint.section_index < section_index
       end)
    |> Enum.max_by(fn checkpoint -> checkpoint.section_index end, fn -> nil end)
  end
end
