defmodule VsmPhoenix.HealthChecker do
  @moduledoc """
  System health checker for the VSM hierarchy
  
  Monitors the health of all VSM systems and triggers interventions
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def run_system_audit do
    GenServer.call(@name, :run_system_audit)
  end
  
  def get_health_status do
    GenServer.call(@name, :get_health_status)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Health Checker initializing...")
    
    state = %{
      system_health: %{},
      audit_history: [],
      interventions: [],
      metrics_cache: %{},
      health_thresholds: %{
        process_memory: 100_000_000,  # 100MB per process
        message_queue: 1000,          # Max messages in queue
        error_rate: 0.05,             # 5% error rate
        response_time: 5000           # 5 second response time
      }
    }
    
    # Subscribe to system metrics
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety_metrics")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety_balance")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:telemetry:metrics")
    
    # Run initial health check immediately
    initial_audit = perform_system_audit(state)
    state_with_health = %{state | system_health: initial_audit.health_summary}
    
    # Schedule periodic health checks
    Process.send_after(self(), :periodic_health_check, 10_000)
    
    {:ok, state_with_health}
  end
  
  @impl true
  def handle_call(:run_system_audit, _from, state) do
    audit_result = perform_system_audit(state)
    
    new_history = [audit_result | state.audit_history] |> Enum.take(50)
    new_state = %{state | 
      audit_history: new_history,
      system_health: audit_result.health_summary
    }
    
    {:reply, audit_result, new_state}
  end
  
  @impl true
  def handle_call(:get_health_status, _from, state) do
    {:reply, state.system_health, state}
  end
  
  @impl true
  def handle_info(:periodic_health_check, state) do
    # Perform health check
    audit_result = perform_system_audit(state)
    
    # Update state
    new_state = %{state |
      system_health: audit_result.health_summary,
      audit_history: [audit_result | state.audit_history] |> Enum.take(100)
    }
    
    # Check for critical issues
    check_and_intervene(audit_result, new_state)
    
    # Schedule next check
    Process.send_after(self(), :periodic_health_check, 10_000)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:variety_update, metrics}, state) do
    # Cache variety metrics for health calculations
    new_cache = Map.put(state.metrics_cache, :variety_metrics, metrics)
    {:noreply, %{state | metrics_cache: new_cache}}
  end
  
  @impl true
  def handle_info({:balance_update, balance}, state) do
    # Cache balance status for health calculations
    new_cache = Map.put(state.metrics_cache, :balance_status, balance)
    {:noreply, %{state | metrics_cache: new_cache}}
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  defp perform_system_audit(state) do
    # Gather real metrics for each system
    health_data = %{
      system5: check_system_health(:system5, state),
      system4: check_system_health(:system4, state),
      system3: check_system_health(:system3, state),
      system2: check_system_health(:system2, state),
      system1: check_system_health(:system1, state)
    }
    
    # Calculate overall health
    overall = calculate_overall_health(health_data)
    
    %{
      timestamp: DateTime.utc_now(),
      health_summary: health_data,
      overall_health: overall,
      recommendations: generate_recommendations(health_data),
      metrics_snapshot: state.metrics_cache
    }
  end
  
  defp check_system_health(system, state) do
    # Get process info for the system
    process_health = check_process_health(system)
    
    # Get variety metrics if available
    variety_health = check_variety_health(system, state.metrics_cache[:variety_metrics])
    
    # Get balance status if available
    balance_health = check_balance_health(system, state.metrics_cache[:balance_status])
    
    # Check message queues
    queue_health = check_message_queue_health(system)
    
    # Aggregate health scores
    scores = [
      process_health.score * 0.3,
      variety_health.score * 0.3,
      balance_health.score * 0.2,
      queue_health.score * 0.2
    ]
    
    overall_score = Enum.sum(scores)
    
    %{
      status: determine_status(overall_score),
      score: Float.round(overall_score, 2),
      details: %{
        process: process_health,
        variety: variety_health,
        balance: balance_health,
        queue: queue_health
      }
    }
  end
  
  defp check_process_health(system) do
    # Try to get the process for this system
    process_name = case system do
      :system5 -> VsmPhoenix.System5.Queen
      :system4 -> VsmPhoenix.System4.Intelligence
      :system3 -> VsmPhoenix.System3.Control
      :system2 -> VsmPhoenix.System2.Coordinator
      :system1 -> :operations_context  # Operations uses :operations_context as its name
    end
    
    case Process.whereis(process_name) do
      nil ->
        %{
          status: :down, 
          score: 0.0, 
          message: "Process not running",
          memory_mb: 0,
          queue_len: 0,
          reductions: 0
        }
        
      pid ->
        info = Process.info(pid, [:memory, :message_queue_len, :reductions])
        
        if info do
          memory_mb = info[:memory] / 1_000_000
          queue_len = info[:message_queue_len]
          
          # Score based on memory and queue
          memory_score = if memory_mb < 50, do: 1.0, else: max(0, 1.0 - (memory_mb - 50) / 100)
          queue_score = if queue_len < 100, do: 1.0, else: max(0, 1.0 - queue_len / 1000)
          
          %{
            status: :running,
            score: (memory_score + queue_score) / 2,
            memory_mb: Float.round(memory_mb, 1),
            message_queue: queue_len,
            reductions: info[:reductions]
          }
        else
          %{status: :unknown, score: 0.5, message: "Could not get process info"}
        end
    end
  end
  
  defp check_variety_health(system, nil), do: %{status: :no_data, score: 0.5}
  defp check_variety_health(system, variety_metrics) do
    level = system_to_level(system)
    
    case Map.get(variety_metrics, level) do
      nil ->
        %{status: :no_data, score: 0.5}
        
      metrics ->
        # Score based on variety ratio and velocity
        ratio = Map.get(metrics, :ratio, 0)
        velocity = Map.get(metrics, :velocity, 0)
        
        # Ideal ratio is close to 1.0
        ratio_score = 1.0 - min(abs(ratio - 1.0), 1.0)
        
        # Low velocity is good (stable)
        velocity_score = 1.0 - min(abs(velocity), 1.0)
        
        score = (ratio_score * 0.7 + velocity_score * 0.3)
        
        %{
          status: :measured,
          score: score,
          ratio: if(is_number(ratio), do: Float.round(ratio * 1.0, 2), else: 0.0),
          velocity: if(is_number(velocity), do: Float.round(velocity * 1.0, 2), else: 0.0),
          input_variety: Map.get(metrics, :input_variety, 0),
          output_variety: Map.get(metrics, :output_variety, 0)
        }
    end
  end
  
  defp check_balance_health(system, nil), do: %{status: :no_data, score: 0.5}
  defp check_balance_health(system, balance_status) do
    level = system_to_level(system)
    
    case Map.get(balance_status, level) do
      nil ->
        %{status: :no_data, score: 0.5}
        
      %{status: status} = level_status ->
        score = case status do
          :balanced -> 1.0
          :unstable -> 0.7
          :underloaded -> 0.5
          :overloaded -> 0.3
          :critical_overload -> 0.1
          _ -> 0.5
        end
        
        %{
          status: status,
          score: score,
          details: Map.take(level_status, [:entropy_ratio, :volume_ratio, :velocity])
        }
        
      status when is_atom(status) ->
        # Old format compatibility
        score = case status do
          :balanced -> 1.0
          :underloaded -> 0.5
          :overloaded -> 0.3
          _ -> 0.5
        end
        
        %{status: status, score: score}
    end
  end
  
  defp check_message_queue_health(system) do
    # Check PubSub subscription health
    topic = "vsm:#{system}"
    
    # This is a simplified check - Phoenix.PubSub doesn't expose subscriber counts
    # In production you'd want more sophisticated monitoring
    %{
      status: :operational,
      score: 0.9,
      topic: topic,
      note: "PubSub operational for #{system}"
    }
  end
  
  defp system_to_level(system) do
    case system do
      :system1 -> :s1
      :system2 -> :s2
      :system3 -> :s3
      :system4 -> :s4
      :system5 -> :s5
      _ -> nil
    end
  end
  
  defp determine_status(score) do
    cond do
      score >= 0.9 -> :excellent
      score >= 0.7 -> :healthy
      score >= 0.5 -> :degraded
      score >= 0.3 -> :unhealthy
      true -> :critical
    end
  end
  
  defp calculate_overall_health(health_data) do
    scores = health_data
    |> Map.values()
    |> Enum.map(& &1.score)
    
    if length(scores) > 0 do
      # Weighted average with penalty for any critical systems
      avg = Enum.sum(scores) / length(scores)
      critical_count = Enum.count(health_data, fn {_, h} -> h.status == :critical end)
      
      avg * (1.0 - critical_count * 0.2)
      |> max(0.0)
      |> Float.round(2)
    else
      0.0
    end
  end
  
  defp generate_recommendations(health_data) when is_map(health_data) do
    health_data
    |> Enum.flat_map(fn {system, health} ->
      generate_system_recommendations(system, health)
    end)
    |> Enum.sort_by(& &1.priority, :desc)
    |> Enum.take(5)
  end
  
  defp generate_recommendations(_), do: []
  
  defp generate_system_recommendations(system, health) when is_map(health) do
    recommendations = []
    
    # Process health recommendations
    if is_map(health.details) && health.details[:process] && 
       is_map(health.details.process) && health.details.process[:memory_mb] &&
       health.details.process.memory_mb > 100 do
      recommendations = [%{
        system: system,
        issue: :high_memory,
        recommendation: "Consider restarting #{system} - memory usage at #{health.details.process.memory_mb}MB",
        priority: :high
      } | recommendations]
    end
    
    # Variety health recommendations
    if is_map(health.details) && health.details[:variety] && health.details.variety[:ratio] < 0.5 do
      recommendations = [%{
        system: system,
        issue: :low_variety_ratio,
        recommendation: "#{system} is underutilized - consider reducing filtering",
        priority: :medium
      } | recommendations]
    end
    
    # Balance recommendations
    if is_map(health.details) && health.details[:balance] && health.details.balance[:status] == :critical_overload do
      recommendations = [%{
        system: system,
        issue: :critical_overload,
        recommendation: "#{system} is critically overloaded - immediate intervention required",
        priority: :critical
      } | recommendations]
    end
    
    recommendations
  end
  
  defp generate_system_recommendations(_system, _health), do: []
  
  defp check_and_intervene(audit_result, state) do
    # Check for critical issues requiring intervention
    critical_systems = audit_result.health_summary
    |> Enum.filter(fn {_, health} -> health.status in [:critical, :unhealthy] end)
    
    if length(critical_systems) > 0 do
      Logger.error("🚨 Critical health issues detected: #{inspect(critical_systems)}")
      
      # Trigger interventions
      Enum.each(critical_systems, fn {system, _health} ->
        trigger_intervention(system, state)
      end)
    end
  end
  
  defp trigger_intervention(system, state) do
    Logger.warning("🏥 Triggering health intervention for #{system}")
    
    # System-specific interventions
    case system do
      :system1 ->
        # Reduce load on S1
        VsmPhoenix.VarietyEngineering.Filters.S1ToS2.increase_filtering()
        
      :system2 ->
        # Stabilize coordination
        VsmPhoenix.System2.Coordinator.emergency_stabilize()
        
      :system3 ->
        # Reduce control overhead
        VsmPhoenix.System3.Control.reduce_monitoring()
        
      _ ->
        # Generic intervention
        Logger.warning("No specific intervention available for #{system}")
    end
    
    # Record intervention
    intervention = %{
      timestamp: DateTime.utc_now(),
      system: system,
      action: :automatic_intervention
    }
    
    new_interventions = [intervention | state.interventions] |> Enum.take(50)
    Map.put(state, :interventions, new_interventions)
  end
end