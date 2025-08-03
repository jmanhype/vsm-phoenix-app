defmodule VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1 do
  @moduledoc """
  Coordination Amplification: S2 → S1
  
  Expands coordination rules from System 2 into
  specific operational tasks for System 1 contexts.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def increase_amplification do
    GenServer.cast(@name, :increase_amplification)
  end
  
  def set_factor(factor) do
    GenServer.call(@name, {:set_factor, factor})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔼 Starting S2→S1 Coordination Amplifier...")
    
    # Subscribe to S2 coordination rules
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system2")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:coordination")
    
    {:ok, %{amplification_factor: 5}}
  end
  
  @impl true
  def handle_call({:set_factor, factor}, _from, state) do
    {:reply, :ok, %{state | amplification_factor: factor}}
  end
  
  @impl true
  def handle_cast(:increase_amplification, state) do
    {:noreply, %{state | amplification_factor: min(state.amplification_factor * 1.5, 15)}}
  end
  
  @impl true
  def handle_info({:coordination_rule, rule}, state) do
    # Amplify coordination rule into operational tasks
    tasks = amplify_to_tasks(rule, state.amplification_factor)
    
    # Group tasks by context
    tasks_by_context = Enum.group_by(tasks, & &1.target_context)
    
    # Send to appropriate S1 contexts
    Enum.each(tasks_by_context, fn {context, context_tasks} ->
      Enum.each(context_tasks, fn task ->
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "vsm:system1:#{context}",
          {:operational_task, task}
        )
        
        VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s1, :inbound, :task)
      end)
    end)
    
    {:noreply, state}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp amplify_to_tasks(rule, factor) do
    base_tasks = generate_base_tasks(rule)
    
    # Expand tasks based on amplification factor
    base_tasks
    |> Enum.flat_map(fn task ->
      1..round(factor)
      |> Enum.map(fn i ->
        specialize_task(task, rule, i)
      end)
    end)
    |> add_context_variations(rule)
  end
  
  defp generate_base_tasks(rule) do
    case rule.type do
      :rate_limiting ->
        [
          %{type: :configure_throttle, category: :control},
          %{type: :monitor_rate, category: :sensing},
          %{type: :enforce_limit, category: :action}
        ]
      
      :synchronization ->
        [
          %{type: :sync_state, category: :coordination},
          %{type: :share_context, category: :communication},
          %{type: :resolve_conflicts, category: :decision}
        ]
      
      :priority_routing ->
        [
          %{type: :classify_priority, category: :analysis},
          %{type: :route_by_priority, category: :action},
          %{type: :monitor_queue, category: :sensing}
        ]
      
      _ ->
        [%{type: :generic_task, category: :general}]
    end
  end
  
  defp specialize_task(base_task, rule, variant) do
    Map.merge(base_task, %{
      variant: variant,
      target_context: select_target_context(rule, variant),
      parameters: generate_task_parameters(base_task.type, rule, variant),
      execution: determine_execution_mode(base_task, rule),
      schedule: generate_schedule(base_task, variant)
    })
  end
  
  defp generate_task_parameters(:configure_throttle, rule, variant) do
    %{
      rate_limit: Map.get(rule.parameters || %{}, :max_rate, 100) / variant,
      window_size: 1000 * variant,
      queue_size: 100,
      drop_policy: :tail_drop
    }
  end
  
  defp generate_task_parameters(:monitor_rate, _rule, variant) do
    %{
      sample_interval: 100 * variant,
      metrics: [:throughput, :latency, :drops],
      alert_threshold: 0.8
    }
  end
  
  defp generate_task_parameters(:sync_state, rule, variant) do
    %{
      sync_interval: Map.get(rule.parameters || %{}, :sync_interval, 1000),
      state_keys: select_state_keys(variant),
      conflict_resolution: :last_write_wins
    }
  end
  
  defp generate_task_parameters(_, _rule, variant) do
    %{variant: variant, generic: true}
  end
  
  defp select_target_context(rule, variant) do
    contexts = rule[:contexts] || [:operations, :sensor_1, :worker_1, :api_1]
    Enum.at(contexts, rem(variant - 1, length(contexts)))
  end
  
  defp determine_execution_mode(task, rule) do
    cond do
      rule.enforcement == :strict -> :immediate
      task.category == :sensing -> :continuous
      task.category == :action -> :on_demand
      true -> :scheduled
    end
  end
  
  defp generate_schedule(task, variant) do
    case task.category do
      :sensing -> %{type: :periodic, interval_ms: 1000 * variant}
      :control -> %{type: :reactive, trigger: :threshold}
      :action -> %{type: :on_demand}
      _ -> %{type: :periodic, interval_ms: 5000}
    end
  end
  
  defp add_context_variations(tasks, rule) do
    # Add variations for different operational contexts
    contexts = rule[:contexts] || [:operations]
    
    tasks
    |> Enum.flat_map(fn task ->
      if task.type in [:monitor_rate, :sync_state] do
        # These tasks should run in multiple contexts
        Enum.map(contexts, fn ctx ->
          Map.put(task, :target_context, ctx)
        end)
      else
        [task]
      end
    end)
  end
  
  defp select_state_keys(variant) do
    all_keys = [:status, :metrics, :configuration, :workload, :errors]
    Enum.take(Enum.drop(all_keys, variant - 1), 3)
  end
end