defmodule VsmPhoenix.Goldrush.ActionHandler do
  @moduledoc """
  Pattern Match Action Execution for GoldRush
  
  Handles:
  - Action execution when patterns match
  - Integration with VSM systems (1-5)
  - Algedonic signal generation
  - Action chaining and workflows
  - Error handling and retries
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System1.Coordinator, as: System1
  alias VsmPhoenix.System2.Coordination, as: System2
  alias VsmPhoenix.System3.Operations, as: System3
  alias VsmPhoenix.System4.Intelligence, as: System4
  alias VsmPhoenix.System5.Policy, as: System5
  alias VsmPhoenix.Algedonic.Channel
  alias Phoenix.PubSub
  
  @name __MODULE__
  @max_retries 3
  @retry_delay 1000  # 1 second
  
  # Action types
  @action_types %{
    "trigger_algedonic" => :algedonic,
    "scale_resources" => :scaling,
    "notify_system3" => :system_notification,
    "update_policy" => :policy_update,
    "spawn_meta_vsm" => :meta_vsm,
    "execute_workflow" => :workflow,
    "send_alert" => :alert,
    "log_event" => :logging,
    "update_variety" => :variety_update,
    "trigger_adaptation" => :adaptation
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Execute an action based on pattern match
  """
  def execute_action(action_name, pattern, event) do
    GenServer.cast(@name, {:execute_action, action_name, pattern, event})
  end
  
  @doc """
  Execute multiple actions in sequence
  """
  def execute_action_chain(actions, pattern, event) do
    GenServer.cast(@name, {:execute_chain, actions, pattern, event})
  end
  
  @doc """
  Register a custom action handler
  """
  def register_custom_action(action_name, handler_fn) do
    GenServer.call(@name, {:register_custom, action_name, handler_fn})
  end
  
  @doc """
  Get action execution statistics
  """
  def get_statistics do
    GenServer.call(@name, :get_statistics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("⚡ Initializing GoldRush Action Handler")
    
    state = %{
      custom_actions: %{},
      statistics: %{
        total_executions: 0,
        successful: 0,
        failed: 0,
        by_type: %{},
        by_action: %{}
      },
      active_workflows: %{},
      action_history: :queue.new()  # Keep last 1000 actions
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:execute_action, action_name, pattern, event}, state) do
    Logger.info("🎯 Executing action: #{action_name} for pattern: #{pattern.name}")
    
    # Record start time
    start_time = System.monotonic_time(:millisecond)
    
    # Execute action
    result = execute_single_action(action_name, pattern, event, state)
    
    # Record execution time
    execution_time = System.monotonic_time(:millisecond) - start_time
    
    # Update statistics
    new_state = update_statistics(state, action_name, result, execution_time)
    
    # Add to history
    new_state = add_to_history(new_state, action_name, pattern.id, result, execution_time)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:execute_chain, actions, pattern, event}, state) do
    Task.start(fn ->
      execute_action_chain_async(actions, pattern, event, state)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:register_custom, action_name, handler_fn}, _from, state) do
    new_custom = Map.put(state.custom_actions, action_name, handler_fn)
    {:reply, :ok, %{state | custom_actions: new_custom}}
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    stats = Map.put(state.statistics, :recent_actions, 
      :queue.to_list(state.action_history) |> Enum.take(-10)
    )
    {:reply, stats, state}
  end
  
  # Private Functions
  
  defp execute_single_action(action_name, pattern, event, state) do
    action_type = Map.get(@action_types, action_name, :custom)
    
    try do
      case action_type do
        :algedonic ->
          execute_algedonic_action(pattern, event)
          
        :scaling ->
          execute_scaling_action(pattern, event)
          
        :system_notification ->
          execute_system_notification(pattern, event)
          
        :policy_update ->
          execute_policy_update(pattern, event)
          
        :meta_vsm ->
          execute_meta_vsm_spawn(pattern, event)
          
        :workflow ->
          execute_workflow(pattern, event, state)
          
        :alert ->
          execute_alert(pattern, event)
          
        :logging ->
          execute_logging(pattern, event)
          
        :variety_update ->
          execute_variety_update(pattern, event)
          
        :adaptation ->
          execute_adaptation(pattern, event)
          
        :custom ->
          execute_custom_action(action_name, pattern, event, state)
      end
      
      {:ok, action_type}
    rescue
      error ->
        Logger.error("Action execution failed: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp execute_algedonic_action(pattern, event) do
    # Generate algedonic signal based on pattern severity
    signal_type = determine_signal_type(pattern, event)
    
    algedonic_signal = %{
      type: signal_type,
      source: "goldrush_pattern_#{pattern.id}",
      intensity: calculate_intensity(pattern, event),
      pattern: pattern.name,
      event_data: event,
      timestamp: DateTime.utc_now()
    }
    
    # Send through algedonic channel
    Channel.transmit(algedonic_signal)
    
    # Broadcast to interested systems
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "algedonic:signals",
      {:algedonic_triggered, algedonic_signal}
    )
    
    Logger.warn("🚨 Algedonic signal transmitted: #{signal_type} - #{pattern.name}")
  end
  
  defp execute_scaling_action(pattern, event) do
    scaling_params = %{
      direction: determine_scaling_direction(event),
      magnitude: calculate_scaling_magnitude(pattern, event),
      resource_type: Map.get(event, :resource_type, :cpu),
      reason: "Pattern match: #{pattern.name}"
    }
    
    # Send to System1 for resource management
    System1.request_scaling(scaling_params)
    
    Logger.info("📈 Scaling action initiated: #{inspect(scaling_params)}")
  end
  
  defp execute_system_notification(pattern, event) do
    notification = %{
      system: :system3,
      type: :pattern_match,
      pattern: pattern.name,
      event: event,
      timestamp: DateTime.utc_now(),
      priority: determine_priority(pattern)
    }
    
    # Notify System3
    System3.handle_notification(notification)
    
    # Also broadcast
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "system:notifications",
      {:pattern_notification, notification}
    )
  end
  
  defp execute_policy_update(pattern, event) do
    policy_update = %{
      trigger: "pattern_#{pattern.id}",
      suggested_changes: analyze_policy_implications(pattern, event),
      evidence: %{
        pattern: pattern.name,
        event: event,
        timestamp: DateTime.utc_now()
      }
    }
    
    # Send to System5 for policy consideration
    System5.suggest_policy_update(policy_update)
    
    Logger.info("📋 Policy update suggested based on pattern: #{pattern.name}")
  end
  
  defp execute_meta_vsm_spawn(pattern, event) do
    meta_config = %{
      trigger: "pattern_#{pattern.id}",
      complexity_level: calculate_complexity(pattern, event),
      initial_subsystems: determine_required_subsystems(pattern, event),
      parent_context: %{
        pattern: pattern.name,
        event: event
      }
    }
    
    # Request meta-VSM spawn through appropriate channel
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "meta_vsm:spawn_requests",
      {:spawn_meta_vsm, meta_config}
    )
    
    Logger.info("🔄 Meta-VSM spawn requested for pattern: #{pattern.name}")
  end
  
  defp execute_workflow(pattern, event, state) do
    workflow_id = Map.get(pattern, :workflow_id, "default_workflow")
    
    workflow = %{
      id: generate_workflow_id(),
      pattern_id: pattern.id,
      steps: get_workflow_steps(workflow_id),
      context: %{pattern: pattern, event: event},
      status: :running
    }
    
    # Start workflow execution
    Task.start(fn ->
      execute_workflow_steps(workflow)
    end)
    
    Logger.info("🔄 Workflow started: #{workflow.id} for pattern: #{pattern.name}")
  end
  
  defp execute_alert(pattern, event) do
    alert = %{
      id: generate_alert_id(),
      severity: determine_severity(pattern, event),
      title: "Pattern Matched: #{pattern.name}",
      description: format_alert_description(pattern, event),
      timestamp: DateTime.utc_now(),
      acknowledged: false
    }
    
    # Send alert through various channels
    send_alert_notifications(alert)
    
    Logger.warn("🔔 Alert sent: #{alert.title}")
  end
  
  defp execute_logging(pattern, event) do
    log_entry = %{
      pattern_id: pattern.id,
      pattern_name: pattern.name,
      event: event,
      timestamp: DateTime.utc_now(),
      context: get_system_context()
    }
    
    # Log to various destinations
    Logger.info("Pattern match logged: #{Jason.encode!(log_entry)}")
    
    # Could also log to external systems, files, etc.
  end
  
  defp execute_variety_update(pattern, event) do
    variety_change = %{
      source: "pattern_#{pattern.id}",
      change_type: analyze_variety_impact(pattern, event),
      magnitude: calculate_variety_change(pattern, event),
      affected_systems: identify_affected_systems(pattern, event)
    }
    
    # Update variety calculations
    System4.update_variety_assessment(variety_change)
    
    Logger.info("🎯 Variety update triggered by pattern: #{pattern.name}")
  end
  
  defp execute_adaptation(pattern, event) do
    adaptation_request = %{
      trigger: "pattern_#{pattern.id}",
      adaptation_type: determine_adaptation_type(pattern, event),
      parameters: calculate_adaptation_parameters(pattern, event),
      urgency: determine_urgency(pattern, event)
    }
    
    # Trigger system adaptation
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "system:adaptation",
      {:adaptation_requested, adaptation_request}
    )
    
    Logger.info("🔧 Adaptation triggered by pattern: #{pattern.name}")
  end
  
  defp execute_custom_action(action_name, pattern, event, state) do
    case Map.get(state.custom_actions, action_name) do
      nil ->
        Logger.warn("Unknown action: #{action_name}")
        {:error, :unknown_action}
        
      handler_fn ->
        handler_fn.(pattern, event)
        {:ok, :custom}
    end
  end
  
  defp execute_action_chain_async(actions, pattern, event, state) do
    Enum.reduce_while(actions, {:ok, []}, fn action, {:ok, results} ->
      case execute_single_action(action, pattern, event, state) do
        {:ok, result} ->
          {:cont, {:ok, [result | results]}}
          
        {:error, reason} ->
          Logger.error("Action chain failed at #{action}: #{inspect(reason)}")
          {:halt, {:error, {action, reason}}}
      end
    end)
  end
  
  # Helper Functions
  
  defp determine_signal_type(pattern, event) do
    cond do
      Map.get(pattern, :critical, false) -> :pain
      Map.get(event, :severity, :normal) == :high -> :discomfort
      true -> :alert
    end
  end
  
  defp calculate_intensity(pattern, event) do
    base_intensity = Map.get(pattern, :base_intensity, 0.5)
    event_modifier = Map.get(event, :intensity_modifier, 1.0)
    
    min(1.0, base_intensity * event_modifier)
  end
  
  defp determine_scaling_direction(event) do
    if Map.get(event, :value, 0) > Map.get(event, :threshold, 0) do
      :up
    else
      :down
    end
  end
  
  defp calculate_scaling_magnitude(pattern, event) do
    # Calculate how much to scale based on pattern and event data
    overage = Map.get(event, :value, 0) - Map.get(event, :threshold, 0)
    scaling_factor = Map.get(pattern, :scaling_factor, 0.1)
    
    abs(overage * scaling_factor)
  end
  
  defp determine_priority(pattern) do
    Map.get(pattern, :priority, :normal)
  end
  
  defp analyze_policy_implications(pattern, event) do
    # Analyze what policy changes might be needed
    %{
      suggested_action: "Review thresholds",
      rationale: "Pattern #{pattern.name} triggered by #{inspect(event)}",
      confidence: 0.7
    }
  end
  
  defp calculate_complexity(pattern, event) do
    # Determine complexity level for meta-VSM
    conditions_count = length(Map.get(pattern, :conditions, []))
    event_complexity = map_size(event)
    
    cond do
      conditions_count > 5 or event_complexity > 10 -> :high
      conditions_count > 3 or event_complexity > 5 -> :medium
      true -> :low
    end
  end
  
  defp determine_required_subsystems(pattern, event) do
    # Determine which subsystems the meta-VSM needs
    base_systems = [:system1, :system2, :system3]
    
    additional = []
    |> add_if(involves_intelligence?(pattern, event), :system4)
    |> add_if(involves_policy?(pattern, event), :system5)
    
    base_systems ++ additional
  end
  
  defp add_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end
  
  defp involves_intelligence?(pattern, _event) do
    Enum.any?(pattern.actions, &String.contains?(&1, "intelligence"))
  end
  
  defp involves_policy?(pattern, _event) do
    Enum.any?(pattern.actions, &String.contains?(&1, "policy"))
  end
  
  defp get_workflow_steps(workflow_id) do
    # Define workflow steps based on ID
    case workflow_id do
      "default_workflow" ->
        ["log_event", "send_alert", "trigger_adaptation"]
      _ ->
        ["log_event"]
    end
  end
  
  defp execute_workflow_steps(workflow) do
    Enum.each(workflow.steps, fn step ->
      execute_single_action(step, workflow.context.pattern, workflow.context.event, %{})
      Process.sleep(100)  # Small delay between steps
    end)
  end
  
  defp determine_severity(pattern, event) do
    cond do
      Map.get(pattern, :critical, false) -> :critical
      Map.get(event, :severity, :normal) == :high -> :high
      true -> :normal
    end
  end
  
  defp format_alert_description(pattern, event) do
    """
    Pattern: #{pattern.name}
    Conditions: #{inspect(pattern.conditions)}
    Event: #{inspect(event)}
    Time: #{DateTime.utc_now()}
    """
  end
  
  defp send_alert_notifications(alert) do
    # Send through various channels
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "alerts:all",
      {:new_alert, alert}
    )
  end
  
  defp get_system_context do
    %{
      node: node(),
      timestamp: System.system_time(:millisecond),
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count)
    }
  end
  
  defp analyze_variety_impact(pattern, event) do
    if Map.get(event, :variety_increase, false) do
      :increase
    else
      :decrease
    end
  end
  
  defp calculate_variety_change(pattern, event) do
    Map.get(event, :variety_delta, 0.1)
  end
  
  defp identify_affected_systems(pattern, _event) do
    # Identify which systems are affected by the variety change
    pattern.actions
    |> Enum.map(&extract_system_from_action/1)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_system_from_action(action) do
    cond do
      String.contains?(action, "system1") -> :system1
      String.contains?(action, "system2") -> :system2
      String.contains?(action, "system3") -> :system3
      String.contains?(action, "system4") -> :system4
      String.contains?(action, "system5") -> :system5
      true -> nil
    end
  end
  
  defp determine_adaptation_type(pattern, event) do
    cond do
      involves_resources?(event) -> :resource_adaptation
      involves_structure?(pattern) -> :structural_adaptation
      true -> :behavioral_adaptation
    end
  end
  
  defp involves_resources?(event) do
    Map.has_key?(event, :cpu_usage) or Map.has_key?(event, :memory_usage)
  end
  
  defp involves_structure?(pattern) do
    Enum.any?(pattern.actions, &String.contains?(&1, "spawn"))
  end
  
  defp calculate_adaptation_parameters(pattern, event) do
    %{
      adaptation_strength: Map.get(pattern, :adaptation_strength, 0.5),
      target_metrics: extract_metrics_from_event(event),
      constraints: Map.get(pattern, :constraints, [])
    }
  end
  
  defp extract_metrics_from_event(event) do
    event
    |> Map.take([:cpu_usage, :memory_usage, :response_time, :error_rate])
    |> Map.to_list()
  end
  
  defp determine_urgency(pattern, event) do
    cond do
      Map.get(pattern, :critical, false) -> :immediate
      Map.get(event, :severity, :normal) == :high -> :high
      true -> :normal
    end
  end
  
  defp update_statistics(state, action_name, result, execution_time) do
    new_stats = state.statistics
    |> Map.update(:total_executions, 1, &(&1 + 1))
    |> Map.update(:by_action, %{}, fn by_action ->
      Map.update(by_action, action_name, 1, &(&1 + 1))
    end)
    
    new_stats = case result do
      {:ok, action_type} ->
        new_stats
        |> Map.update(:successful, 1, &(&1 + 1))
        |> Map.update(:by_type, %{}, fn by_type ->
          Map.update(by_type, action_type, 1, &(&1 + 1))
        end)
        
      {:error, _} ->
        Map.update(new_stats, :failed, 1, &(&1 + 1))
    end
    
    %{state | statistics: new_stats}
  end
  
  defp add_to_history(state, action_name, pattern_id, result, execution_time) do
    history_entry = %{
      action: action_name,
      pattern_id: pattern_id,
      result: result,
      execution_time: execution_time,
      timestamp: DateTime.utc_now()
    }
    
    # Keep only last 1000 entries
    new_history = :queue.in(history_entry, state.action_history)
    new_history = if :queue.len(new_history) > 1000 do
      {_, trimmed} = :queue.out(new_history)
      trimmed
    else
      new_history
    end
    
    %{state | action_history: new_history}
  end
  
  defp generate_workflow_id do
    "workflow_#{:erlang.unique_integer([:positive])}"
  end
  
  defp generate_alert_id do
    "alert_#{:erlang.unique_integer([:positive])}"
  end
end