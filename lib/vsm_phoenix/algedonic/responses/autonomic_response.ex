defmodule VsmPhoenix.Algedonic.AutonomicResponse do
  @moduledoc """
  Autonomic Response System for immediate, reflexive reactions to critical conditions.
  
  Provides instant responses to critical signals without waiting for 
  hierarchical processing, similar to biological autonomic nervous system.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System1.Registry, as: S1Registry
  alias VsmPhoenix.System3.Control
  
  @type response_type :: :defensive | :adaptive | :protective | :restorative
  @type response_speed :: :instant | :rapid | :normal
  
  @type autonomic_action :: %{
    type: response_type(),
    speed: response_speed(),
    target: String.t(),
    action: atom(),
    parameters: map(),
    bypass_approval: boolean()
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Trigger emergency autonomic response
  """
  def trigger_emergency(signal) do
    GenServer.cast(__MODULE__, {:emergency_response, signal})
  end
  
  @doc """
  Execute autonomic response based on signal and configured responses
  """
  def execute(signal, configured_responses) do
    GenServer.cast(__MODULE__, {:execute_response, signal, configured_responses})
  end
  
  @doc """
  Configure autonomic response for specific conditions
  """
  def configure_response(condition, response) do
    GenServer.call(__MODULE__, {:configure, condition, response})
  end
  
  @doc """
  Get current autonomic state
  """
  def autonomic_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  @doc """
  Test autonomic reflexes
  """
  def test_reflexes do
    GenServer.call(__MODULE__, :test_reflexes)
  end
  
  # Server Callbacks
  
  def init(_opts) do
    state = %{
      responses: configure_default_responses(),
      active_responses: %{},
      response_history: [],
      reflexes: configure_reflexes(),
      emergency_mode: false,
      metrics: %{
        total_responses: 0,
        emergency_responses: 0,
        successful_responses: 0,
        response_time_ms: []
      }
    }
    
    {:ok, state}
  end
  
  def handle_cast({:emergency_response, signal}, state) do
    start_time = System.monotonic_time(:millisecond)
    Logger.error("🚨 AUTONOMIC EMERGENCY RESPONSE TRIGGERED")
    
    # Enter emergency mode
    state = %{state | emergency_mode: true}
    
    # Identify appropriate responses
    responses = identify_emergency_responses(signal, state)
    
    # Execute all responses in parallel
    response_ids = Enum.map(responses, fn response ->
      execute_autonomic_action(response, signal, :instant)
    end)
    
    # Track active responses
    state = Enum.reduce(response_ids, state, fn id, acc ->
      put_in(acc, [:active_responses, id], :executing)
    end)
    
    # Record response time
    response_time = System.monotonic_time(:millisecond) - start_time
    state = update_response_metrics(state, response_time, :emergency)
    
    {:noreply, state}
  end
  
  def handle_cast({:execute_response, signal, configured_responses}, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Match signal to configured responses
    matched_responses = match_responses(signal, configured_responses, state)
    
    # Execute matched responses
    response_ids = Enum.map(matched_responses, fn response ->
      execute_autonomic_action(response, signal, :rapid)
    end)
    
    # Track responses
    state = Enum.reduce(response_ids, state, fn id, acc ->
      put_in(acc, [:active_responses, id], :executing)
    end)
    
    # Record response time
    response_time = System.monotonic_time(:millisecond) - start_time
    state = update_response_metrics(state, response_time, :normal)
    
    {:noreply, state}
  end
  
  def handle_call({:configure, condition, response}, _from, state) do
    responses = Map.put(state.responses, condition, response)
    {:reply, :ok, %{state | responses: responses}}
  end
  
  def handle_call(:get_state, _from, state) do
    autonomic_state = %{
      emergency_mode: state.emergency_mode,
      active_responses: map_size(state.active_responses),
      configured_responses: map_size(state.responses),
      avg_response_time: calculate_avg_response_time(state.metrics.response_time_ms),
      total_responses: state.metrics.total_responses
    }
    
    {:reply, autonomic_state, state}
  end
  
  def handle_call(:test_reflexes, _from, state) do
    results = test_all_reflexes(state.reflexes)
    {:reply, results, state}
  end
  
  def handle_info({:response_complete, response_id, result}, state) do
    # Handle response completion
    state = case result do
      :success ->
        %{state | 
          active_responses: Map.delete(state.active_responses, response_id),
          metrics: Map.update!(state.metrics, :successful_responses, &(&1 + 1))
        }
        
      :failure ->
        Logger.error("Autonomic response #{response_id} failed")
        handle_failed_response(response_id, state)
    end
    
    # Check if we can exit emergency mode
    state = if state.emergency_mode and map_size(state.active_responses) == 0 do
      Logger.info("Exiting emergency mode")
      %{state | emergency_mode: false}
    else
      state
    end
    
    {:noreply, state}
  end
  
  def handle_info(:reflex_check, state) do
    # Periodic reflex testing
    test_results = test_all_reflexes(state.reflexes)
    
    if any_reflex_degraded?(test_results) do
      Logger.warning("Autonomic reflexes degraded: #{inspect(test_results)}")
      repair_reflexes(test_results, state)
    end
    
    # Schedule next check
    Process.send_after(self(), :reflex_check, 300_000)  # 5 minutes
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp configure_default_responses do
    %{
      # Resource exhaustion responses
      memory_critical: %{
        type: :defensive,
        action: :emergency_gc,
        parameters: %{force: true, compact: true}
      },
      
      cpu_overload: %{
        type: :protective,
        action: :throttle_operations,
        parameters: %{reduction: 0.5, duration_ms: 60000}
      },
      
      # Security responses
      security_breach: %{
        type: :defensive,
        action: :lockdown,
        parameters: %{isolate: true, alert: true}
      },
      
      unauthorized_access: %{
        type: :protective,
        action: :block_and_audit,
        parameters: %{duration_ms: 300000}
      },
      
      # Cascade prevention
      cascade_detected: %{
        type: :protective,
        action: :circuit_break,
        parameters: %{break_cascading_operations: true}
      },
      
      # System failure responses
      critical_failure: %{
        type: :restorative,
        action: :failover,
        parameters: %{activate_backup: true}
      },
      
      # Variety imbalance
      variety_crisis: %{
        type: :adaptive,
        action: :rebalance_variety,
        parameters: %{emergency_rebalance: true}
      }
    }
  end
  
  defp configure_reflexes do
    %{
      defensive: %{
        trigger_time_ms: 10,
        actions: [:isolate, :protect, :alert]
      },
      
      adaptive: %{
        trigger_time_ms: 50,
        actions: [:adjust, :rebalance, :optimize]
      },
      
      protective: %{
        trigger_time_ms: 20,
        actions: [:throttle, :limit, :buffer]
      },
      
      restorative: %{
        trigger_time_ms: 100,
        actions: [:heal, :recover, :rebuild]
      }
    }
  end
  
  defp identify_emergency_responses(signal, state) do
    # Identify all applicable emergency responses
    data = Map.get(signal, :data, %{})
    
    responses = []
    
    # Check each condition
    responses = if Map.get(data, :memory_usage, 0) > 0.95 do
      [state.responses.memory_critical | responses]
    else
      responses
    end
    
    responses = if Map.get(data, :cpu_usage, 0) > 0.95 do
      [state.responses.cpu_overload | responses]
    else
      responses
    end
    
    responses = if Map.get(data, :security_breach, false) do
      [state.responses.security_breach | responses]
    else
      responses
    end
    
    responses = if Map.get(data, :cascade_risk, false) do
      [state.responses.cascade_detected | responses]
    else
      responses
    end
    
    responses = if Map.get(data, :system_failure, false) do
      [state.responses.critical_failure | responses]
    else
      responses
    end
    
    responses = if Map.get(data, :variety_imbalance, 0) > 3.0 do
      [state.responses.variety_crisis | responses]
    else
      responses
    end
    
    Enum.filter(responses, & &1)  # Remove nils
  end
  
  defp match_responses(signal, configured_responses, _state) do
    # Match signal to configured responses
    configured_responses
    |> Map.values()
    |> Enum.filter(fn response ->
      response_applicable?(response, signal)
    end)
  end
  
  defp response_applicable?(response, signal) do
    # Check if response is applicable to signal
    signal_type = Map.get(signal, :type)
    signal_intensity = Map.get(signal, :intensity)
    
    case response.type do
      :defensive -> signal_type == :pain and signal_intensity in [:high, :critical]
      :protective -> signal_type == :pain and signal_intensity in [:medium, :high, :critical]
      :adaptive -> true  # Always applicable
      :restorative -> signal_type == :pain
    end
  end
  
  defp execute_autonomic_action(response, signal, speed) do
    response_id = generate_response_id()
    
    Task.start(fn ->
      # Add speed-based delay if not instant
      if speed != :instant do
        Process.sleep(speed_to_delay(speed))
      end
      
      result = try do
        execute_action(response.action, response.parameters, signal)
        :success
      rescue
        e ->
          Logger.error("Autonomic action failed: #{inspect(e)}")
          :failure
      end
      
      send(self(), {:response_complete, response_id, result})
    end)
    
    response_id
  end
  
  defp speed_to_delay(:instant), do: 0
  defp speed_to_delay(:rapid), do: 10
  defp speed_to_delay(:normal), do: 100
  
  defp execute_action(:emergency_gc, params, _signal) do
    Logger.info("Executing emergency garbage collection")
    
    if params.force do
      :erlang.garbage_collect()
    end
    
    if params.compact do
      # Trigger memory compaction across all processes
      Process.list()
      |> Enum.each(&:erlang.garbage_collect/1)
    end
  end
  
  defp execute_action(:throttle_operations, params, _signal) do
    Logger.warning("Throttling operations by #{params.reduction * 100}%")
    
    # Notify S1 operations to reduce load
    S1Registry.list_agents()
    |> Enum.each(fn {_name, pid} ->
      GenServer.cast(pid, {:throttle, params.reduction, params.duration_ms})
    end)
  end
  
  defp execute_action(:lockdown, params, _signal) do
    Logger.error("SECURITY LOCKDOWN INITIATED")
    
    if params.isolate do
      # Isolate system from external connections
      :telemetry.execute(
        [:vsm, :security, :lockdown],
        %{severity: 1.0},
        %{action: :isolate}
      )
    end
    
    if params.alert do
      # Alert all systems
      broadcast_security_alert()
    end
  end
  
  defp execute_action(:block_and_audit, params, signal) do
    Logger.warning("Blocking and auditing unauthorized access")
    
    # Create audit record
    :telemetry.execute(
      [:vsm, :security, :audit],
      %{duration: params.duration_ms},
      %{signal: signal}
    )
  end
  
  defp execute_action(:circuit_break, params, _signal) do
    Logger.warning("Circuit breaker activated - stopping cascade")
    
    if params.break_cascading_operations do
      # Stop all non-critical operations
      Control.emergency_stop(:cascade_prevention)
    end
  end
  
  defp execute_action(:failover, params, _signal) do
    Logger.error("Initiating failover to backup systems")
    
    if params.activate_backup do
      # Activate backup systems
      :telemetry.execute(
        [:vsm, :failover, :activate],
        %{},
        %{timestamp: DateTime.utc_now()}
      )
    end
  end
  
  defp execute_action(:rebalance_variety, params, _signal) do
    Logger.warning("Emergency variety rebalancing")
    
    if params.emergency_rebalance do
      # Trigger emergency variety rebalance
      GenServer.cast(VsmPhoenix.VarietyEngineering.Supervisor, :emergency_rebalance)
    end
  end
  
  defp execute_action(action, params, signal) do
    Logger.info("Executing autonomic action: #{action}")
    
    # Generic action execution
    :telemetry.execute(
      [:vsm, :autonomic, :action],
      %{action: action},
      %{params: params, signal: signal}
    )
  end
  
  defp broadcast_security_alert do
    # Broadcast security alert to all systems
    :telemetry.execute(
      [:vsm, :security, :alert],
      %{severity: 1.0},
      %{timestamp: DateTime.utc_now()}
    )
  end
  
  defp update_response_metrics(state, response_time, type) do
    metrics = state.metrics
    |> Map.update!(:total_responses, &(&1 + 1))
    |> Map.update!(:response_time_ms, &[response_time | Enum.take(&1, 99)])
    
    metrics = if type == :emergency do
      Map.update!(metrics, :emergency_responses, &(&1 + 1))
    else
      metrics
    end
    
    %{state | metrics: metrics}
  end
  
  defp calculate_avg_response_time([]), do: 0
  defp calculate_avg_response_time(times) do
    Enum.sum(times) / length(times)
  end
  
  defp handle_failed_response(response_id, state) do
    # Handle failed autonomic response
    # Could escalate or retry
    %{state | active_responses: Map.delete(state.active_responses, response_id)}
  end
  
  defp test_all_reflexes(reflexes) do
    reflexes
    |> Enum.map(fn {type, config} ->
      {type, test_reflex(config)}
    end)
    |> Map.new()
  end
  
  defp test_reflex(config) do
    start = System.monotonic_time(:millisecond)
    
    # Simulate reflex action
    Process.sleep(1)
    
    response_time = System.monotonic_time(:millisecond) - start
    
    %{
      healthy: response_time <= config.trigger_time_ms,
      response_time: response_time,
      expected: config.trigger_time_ms
    }
  end
  
  defp any_reflex_degraded?(test_results) do
    Enum.any?(test_results, fn {_, result} ->
      not result.healthy
    end)
  end
  
  defp repair_reflexes(test_results, _state) do
    # Attempt to repair degraded reflexes
    degraded = Enum.filter(test_results, fn {_, result} ->
      not result.healthy
    end)
    
    Enum.each(degraded, fn {type, _} ->
      Logger.info("Repairing #{type} reflex")
      # Repair logic here
    end)
  end
  
  defp generate_response_id do
    "response_#{:erlang.unique_integer([:positive])}"
  end
end