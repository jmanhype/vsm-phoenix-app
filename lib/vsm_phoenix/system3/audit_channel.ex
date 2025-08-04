defmodule VsmPhoenix.System3.AuditChannel do
  @moduledoc """
  System 3 Audit Channel - Direct S1 inspection bypass
  
  This module provides a secure bypass mechanism for System 3 to directly
  audit any System 1 agent without going through System 2 coordination.
  
  WARNING: This is a privileged operation that bypasses normal coordination.
  It should only be used for:
  - Emergency diagnostics
  - Resource auditing
  - Viability assessments
  - Security inspections
  
  All audit operations are logged and emit telemetry events.
  """
  
  use GenServer
  require Logger
  
  alias AMQP
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @name __MODULE__
  @exchange "vsm.audit"
  @audit_timeout 5_000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Send a direct audit command to an S1 agent, bypassing S2 coordination.
  
  ## Parameters
    - target_s1: The name/atom of the S1 agent to audit (e.g., :operations_context)
    - audit_request: Map containing audit details
  
  ## Returns
    - {:ok, response} - The audit response from the S1 agent
    - {:error, reason} - If the audit fails
  """
  def send_audit_command(target_s1, audit_request) do
    GenServer.call(@name, {:send_audit, target_s1, audit_request}, @audit_timeout + 1000)
  end
  
  @doc """
  Perform a bulk audit of multiple S1 agents
  """
  def bulk_audit(targets, operation \\ :dump_state) do
    GenServer.call(@name, {:bulk_audit, targets, operation}, @audit_timeout * 2)
  end
  
  @doc """
  Get audit history for a specific S1 agent
  """
  def get_audit_history(target_s1, limit \\ 10) do
    GenServer.call(@name, {:get_history, target_s1, limit})
  end
  
  @doc """
  Schedule a compliance audit for specific S1 agent
  """
  def schedule_compliance_audit(target_s1, schedule_opts \\ []) do
    GenServer.cast(@name, {:schedule_audit, target_s1, :compliance, schedule_opts})
  end
  
  @doc """
  Get audit trail for reporting to S5
  """
  def get_audit_trail(options \\ []) do
    GenServer.call(@name, {:get_audit_trail, options})
  end
  
  @doc """
  Perform emergency audit - highest priority
  """
  def emergency_audit(target_s1, reason) do
    GenServer.call(@name, {:emergency_audit, target_s1, reason}, @audit_timeout * 2)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔍 S3 Audit Channel initializing...")
    
    state = %{
      channel: nil,
      pending_audits: %{},
      audit_history: [],
      audit_trail: [],
      scheduled_audits: [],
      compliance_cache: %{},
      correlation_counter: 0,
      audit_metrics: %{
        total_audits: 0,
        successful_audits: 0,
        failed_audits: 0,
        avg_response_time: 0,
        compliance_checks: 0,
        emergency_audits: 0
      }
    }
    
    # Setup AMQP for audit operations
    state = setup_audit_amqp(state)
    
    # Schedule periodic audit metrics reporting
    schedule_metrics_report()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_audit, target_s1, audit_request}, from, state) do
    correlation_id = generate_correlation_id(state.correlation_counter)
    
    # Store pending audit
    pending = %{
      from: from,
      target: target_s1,
      request: audit_request,
      started_at: System.monotonic_time(:millisecond)
    }
    
    new_pending = Map.put(state.pending_audits, correlation_id, pending)
    
    # Send audit command directly to S1 via AMQP
    # Use direct queue routing via default exchange for bypass
    target_queue = "vsm.s1.#{target_s1}.command"
    
    # Prepare audit payload with proper field mapping
    audit_message = %{
      type: "audit_command",
      audit_type: map_audit_operation(audit_request[:operation]) || "state_dump",
      correlation_id: correlation_id,
      reply_to: "vsm.audit.responses",
      target: target_s1,
      compliance_check: audit_request[:operation] == :compliance_check,
      priority: audit_request[:priority] || 5,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    payload = Jason.encode!(audit_message)
    
    if state.channel do
      :ok = AMQP.Basic.publish(
        state.channel,
        "",  # Use default exchange for direct queue routing
        target_queue,
        payload,
        correlation_id: correlation_id,
        reply_to: "vsm.audit.responses",
        content_type: "application/json",
        headers: [
          {"x-audit-bypass", "true"},
          {"x-requester", "system3_control"},
          {"x-priority", 10}
        ]
      )
      
      Logger.info("🔍 Audit command sent to #{target_s1} via #{target_queue}")
      
      # Update metrics
      new_metrics = Map.update!(state.audit_metrics, :total_audits, &(&1 + 1))
      
      # Set timeout for response
      Process.send_after(self(), {:audit_timeout, correlation_id}, @audit_timeout)
      
      new_state = %{state | 
        pending_audits: new_pending,
        correlation_counter: state.correlation_counter + 1,
        audit_metrics: new_metrics
      }
      
      {:noreply, new_state}
    else
      Logger.error("Audit Channel: No AMQP channel available")
      {:reply, {:error, :no_channel}, state}
    end
  end
  
  @impl true
  def handle_call({:bulk_audit, targets, operation}, from, state) do
    # Spawn parallel audits
    task_supervisor = Task.Supervisor
    
    tasks = Enum.map(targets, fn target ->
      Task.Supervisor.async_nolink(task_supervisor, fn ->
        audit_request = %{
          type: "audit_command",
          operation: operation,
          target: target,
          requester: "system3_bulk_audit",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          bypass_coordination: true
        }
        
        send_audit_command(target, audit_request)
      end)
    end)
    
    # Collect results with timeout
    results = tasks
    |> Task.yield_many(@audit_timeout)
    |> Enum.map(fn {task, res} ->
      case res do
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:exit, reason}}
        nil -> 
          Task.shutdown(task, :brutal_kill)
          {:error, :timeout}
      end
    end)
    
    {:reply, {:ok, Enum.zip(targets, results)}, state}
  end
  
  @impl true
  def handle_call({:emergency_audit, target_s1, reason}, from, state) do
    Logger.warning("🚨 EMERGENCY AUDIT: #{target_s1} - Reason: #{reason}")
    
    # Create high-priority audit request
    audit_request = %{
      operation: :emergency_inspection,
      priority: 10,  # Highest priority
      reason: reason,
      timestamp: DateTime.utc_now()
    }
    
    # Update metrics
    new_metrics = Map.update!(state.audit_metrics, :emergency_audits, &(&1 + 1))
    
    # Perform audit with high priority
    handle_call(
      {:send_audit, target_s1, audit_request},
      from,
      %{state | audit_metrics: new_metrics}
    )
  end
  
  @impl true
  def handle_call({:get_audit_trail, options}, _from, state) do
    limit = Keyword.get(options, :limit, 100)
    filter = Keyword.get(options, :filter, :all)
    
    trail = case filter do
      :compliance -> 
        Enum.filter(state.audit_trail, &(&1.type == :compliance))
      :emergency ->
        Enum.filter(state.audit_trail, &(&1.type == :emergency))
      :sporadic ->
        Enum.filter(state.audit_trail, &(&1.type == :sporadic))
      _ ->
        state.audit_trail
    end
    |> Enum.take(limit)
    
    {:reply, {:ok, trail}, state}
  end
  
  @impl true
  def handle_call({:get_history, target_s1, limit}, _from, state) do
    history = state.audit_history
    |> Enum.filter(fn entry -> entry.target == target_s1 end)
    |> Enum.take(limit)
    
    {:reply, {:ok, history}, state}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle audit response from S1
    case Jason.decode(payload) do
      {:ok, response} ->
        correlation_id = meta.correlation_id
        
        case Map.get(state.pending_audits, correlation_id) do
          nil ->
            Logger.warning("Received audit response for unknown correlation ID: #{correlation_id}")
            {:noreply, state}
            
          pending ->
            # Calculate response time
            response_time = System.monotonic_time(:millisecond) - pending.started_at
            
            # Log audit completion
            audit_entry = %{
              target: pending.target,
              operation: pending.request.operation,
              response_time_ms: response_time,
              success: response["status"] == "success",
              timestamp: DateTime.utc_now(),
              correlation_id: correlation_id,
              type: categorize_audit_type(pending.request)
            }
            
            # Add to audit trail for S5 reporting
            trail_entry = %{
              timestamp: DateTime.utc_now(),
              target: pending.target,
              type: audit_entry.type,
              success: audit_entry.success,
              response_time_ms: response_time,
              compliance_result: response["compliance_result"]
            }
            
            # Emit telemetry
            :telemetry.execute(
              [:vsm, :system3, :audit, :complete],
              %{response_time: response_time},
              %{
                target: pending.target,
                operation: pending.request.operation,
                success: audit_entry.success
              }
            )
            
            # Update metrics
            new_metrics = state.audit_metrics
              |> Map.update!(:successful_audits, &(&1 + 1))
              |> update_avg_response_time(response_time)
            
            # Cache compliance results if applicable
            new_compliance_cache = if response["compliance_result"] do
              Map.put(state.compliance_cache, pending.target, %{
                result: response["compliance_result"],
                timestamp: DateTime.utc_now()
              })
            else
              state.compliance_cache
            end
            
            # Reply to caller
            GenServer.reply(pending.from, {:ok, response})
            
            # Update state
            new_state = %{state |
              pending_audits: Map.delete(state.pending_audits, correlation_id),
              audit_history: [audit_entry | state.audit_history] |> Enum.take(1000),
              audit_trail: [trail_entry | state.audit_trail] |> Enum.take(5000),
              audit_metrics: new_metrics,
              compliance_cache: new_compliance_cache
            }
            
            {:noreply, new_state}
        end
        
      {:error, reason} ->
        Logger.error("Failed to decode audit response: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:audit_timeout, correlation_id}, state) do
    case Map.get(state.pending_audits, correlation_id) do
      nil ->
        # Already handled
        {:noreply, state}
        
      pending ->
        Logger.error("Audit timeout for #{pending.target} (correlation: #{correlation_id})")
        
        # Update failed audit metrics
        new_metrics = Map.update!(state.audit_metrics, :failed_audits, &(&1 + 1))
        
        # Reply with timeout error
        GenServer.reply(pending.from, {:error, :timeout})
        
        # Clean up
        new_state = %{state |
          pending_audits: Map.delete(state.pending_audits, correlation_id),
          audit_metrics: new_metrics
        }
        
        # Emit telemetry for timeout
        :telemetry.execute(
          [:vsm, :system3, :audit, :timeout],
          %{count: 1},
          %{target: pending.target, operation: pending.request.operation}
        )
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🔍 Audit Channel: Consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Audit Channel: Consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Audit Channel: Consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:report_metrics, state) do
    # Report audit metrics to S5
    metrics_report = %{
      type: "audit_metrics",
      timestamp: DateTime.utc_now(),
      metrics: state.audit_metrics,
      compliance_cache_size: map_size(state.compliance_cache),
      pending_audits: map_size(state.pending_audits),
      recent_failures: Enum.count(state.audit_history, fn entry ->
        !entry.success && 
        DateTime.diff(DateTime.utc_now(), entry.timestamp) < 3600
      end)
    }
    
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:governance",
      {:audit_metrics, metrics_report}
    )
    
    # Schedule next report
    schedule_metrics_report()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Audit Channel: Retrying AMQP setup...")
    new_state = setup_audit_amqp(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:schedule_audit, target_s1, audit_type, schedule_opts}, state) do
    scheduled_audit = %{
      target: target_s1,
      type: audit_type,
      scheduled_for: calculate_schedule_time(schedule_opts),
      options: schedule_opts
    }
    
    new_scheduled = [scheduled_audit | state.scheduled_audits]
    
    # Set timer for scheduled audit
    delay = DateTime.diff(scheduled_audit.scheduled_for, DateTime.utc_now(), :millisecond)
    if delay > 0 do
      Process.send_after(self(), {:execute_scheduled_audit, scheduled_audit}, delay)
    end
    
    {:noreply, %{state | scheduled_audits: new_scheduled}}
  end
  
  @impl true
  def handle_info({:execute_scheduled_audit, scheduled_audit}, state) do
    Logger.info("🕒 Executing scheduled audit for #{scheduled_audit.target}")
    
    # Execute the scheduled audit
    audit_request = %{
      operation: scheduled_audit.type,
      scheduled: true,
      original_schedule: scheduled_audit.scheduled_for
    }
    
    Task.start(fn ->
      send_audit_command(scheduled_audit.target, audit_request)
    end)
    
    # Remove from scheduled list
    new_scheduled = Enum.reject(state.scheduled_audits, &(&1 == scheduled_audit))
    
    {:noreply, %{state | scheduled_audits: new_scheduled}}
  end
  
  # Private Functions
  
  defp setup_audit_amqp(state) do
    case ConnectionManager.get_channel(:audit) do
      {:ok, channel} ->
        try do
          # Declare audit exchange
          :ok = AMQP.Exchange.declare(channel, @exchange, :fanout, durable: true)
          
          # Create response queue for audit replies
          {:ok, %{queue: response_queue}} = AMQP.Queue.declare(
            channel, 
            "vsm.audit.responses",
            durable: true,
            arguments: [
              {"x-message-ttl", :long, 30_000},  # 30 second TTL
              {"x-max-length", :long, 1000}       # Max 1000 messages
            ]
          )
          
          # Bind response queue
          :ok = AMQP.Queue.bind(channel, response_queue, @exchange, routing_key: "audit.response")
          
          # Also bind to allow direct S1 routing
          :ok = AMQP.Queue.bind(channel, response_queue, @exchange, routing_key: "vsm.s1.*.response")
          
          # Start consuming responses
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, response_queue)
          
          Logger.info("🔍 Audit Channel: AMQP setup complete! Consumer: #{consumer_tag}")
          Logger.info("🔍 Listening for audit responses on #{response_queue}")
          
          Map.put(state, :channel, channel)
        rescue
          error ->
            Logger.error("Audit Channel: Failed to setup AMQP: #{inspect(error)}")
            Process.send_after(self(), :retry_amqp_setup, 5000)
            state
        end
        
      {:error, reason} ->
        Logger.error("Audit Channel: Could not get AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end
  
  defp generate_correlation_id(counter) do
    "audit-#{System.system_time(:microsecond)}-#{counter}"
  end
  
  defp map_audit_operation(operation) do
    case operation do
      :compliance_check -> "compliance_audit"
      :sporadic_inspection -> "sporadic_audit"
      :emergency_inspection -> "emergency_audit"
      :resource_audit -> "resource_usage"
      :performance_audit -> "performance_metrics"
      :security_audit -> "security_scan"
      _ -> to_string(operation)
    end
  end
  
  defp categorize_audit_type(request) do
    cond do
      request[:operation] == :emergency_inspection -> :emergency
      request[:operation] == :compliance_check -> :compliance
      request[:operation] == :sporadic_inspection -> :sporadic
      request[:scheduled] -> :scheduled
      true -> :manual
    end
  end
  
  defp update_avg_response_time(metrics, new_time) do
    total = metrics.successful_audits + metrics.failed_audits
    current_avg = metrics.avg_response_time
    
    new_avg = if total > 0 do
      ((current_avg * (total - 1)) + new_time) / total
    else
      new_time
    end
    
    Map.put(metrics, :avg_response_time, new_avg)
  end
  
  defp calculate_schedule_time(schedule_opts) do
    cond do
      schedule_opts[:at] ->
        schedule_opts[:at]
      schedule_opts[:in_seconds] ->
        DateTime.add(DateTime.utc_now(), schedule_opts[:in_seconds], :second)
      schedule_opts[:in_minutes] ->
        DateTime.add(DateTime.utc_now(), schedule_opts[:in_minutes] * 60, :second)
      true ->
        DateTime.add(DateTime.utc_now(), 60, :second)  # Default to 1 minute
    end
  end
  
  defp schedule_metrics_report do
    Process.send_after(self(), :report_metrics, 60_000)  # Every minute
  end
end