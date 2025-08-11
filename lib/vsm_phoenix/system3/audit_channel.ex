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
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔍 S3 Audit Channel initializing...")
    
    state = %{
      channel: nil,
      pending_audits: %{},
      audit_history: [],
      correlation_counter: 0
    }
    
    # Setup AMQP for audit operations
    state = if System.get_env("DISABLE_AMQP") == "true" do
      state
    else
      setup_audit_amqp(state)
    end
    
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
      audit_type: audit_request[:operation] || "state_dump",
      correlation_id: correlation_id,
      reply_to: "vsm.audit.responses",
      target: target_s1,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    payload = Jason.encode!(audit_message)
    
    if state[:channel] && System.get_env("DISABLE_AMQP") != "true" do
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
      
      # Set timeout for response
      Process.send_after(self(), {:audit_timeout, correlation_id}, @audit_timeout)
      
      new_state = %{state | 
        pending_audits: new_pending,
        correlation_counter: state.correlation_counter + 1
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
              correlation_id: correlation_id
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
            
            # Reply to caller
            GenServer.reply(pending.from, {:ok, response})
            
            # Update state
            new_state = %{state |
              pending_audits: Map.delete(state.pending_audits, correlation_id),
              audit_history: [audit_entry | state.audit_history] |> Enum.take(1000)
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
        
        # Reply with timeout error
        GenServer.reply(pending.from, {:error, :timeout})
        
        # Clean up
        new_state = %{state |
          pending_audits: Map.delete(state.pending_audits, correlation_id)
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
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Audit Channel: Retrying AMQP setup...")
    new_state = setup_audit_amqp(state)
    {:noreply, new_state}
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
end