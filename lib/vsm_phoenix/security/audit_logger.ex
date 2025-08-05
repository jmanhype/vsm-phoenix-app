defmodule VsmPhoenix.Security.AuditLogger do
  @moduledoc """
  High-performance security audit logging with intrusion detection and compliance reporting.
  Uses circular buffers and async writes for minimal performance impact.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.Security.CryptoUtils

  @table_name :security_audit_log
  @max_buffer_size 10_000
  @flush_interval_ms :timer.seconds(5)
  @archive_interval_ms :timer.hours(1)
  @anomaly_detection_window_ms :timer.minutes(5)

  defstruct [
    :ets_table,
    :buffer,
    :buffer_size,
    :event_counts,
    :anomaly_thresholds,
    :archive_path,
    :log_encryption_key,
    :stats
  ]

  # Event types
  @event_types [
    :auth_success,
    :auth_failure,
    :message_validated,
    :message_rejected,
    :replay_attack,
    :signature_failure,
    :nonce_reuse,
    :suspicious_activity,
    :system_access,
    :configuration_change,
    :key_rotation,
    :intrusion_detected
  ]

  # Severity levels
  @severity_levels [:debug, :info, :warning, :error, :critical]

  defmodule Event do
    @enforce_keys [:id, :type, :timestamp, :severity]
    defstruct [
      :id,
      :type,
      :timestamp,
      :severity,
      :actor,
      :resource,
      :action,
      :result,
      :metadata,
      :ip_address,
      :user_agent,
      :correlation_id
    ]
  end

  # Client API

  @doc """
  Starts the audit logger GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Logs a security event.
  """
  def log_event(server \\ __MODULE__, type, severity, details \\ %{}) do
    GenServer.cast(server, {:log_event, type, severity, details})
  end

  @doc """
  Logs an authentication event.
  """
  def log_auth(server \\ __MODULE__, success?, actor, details \\ %{}) do
    type = if success?, do: :auth_success, else: :auth_failure
    severity = if success?, do: :info, else: :warning
    
    log_event(server, type, severity, Map.merge(details, %{actor: actor}))
  end

  @doc """
  Logs a message validation event.
  """
  def log_message_validation(server \\ __MODULE__, valid?, reason \\ nil, details \\ %{}) do
    {type, severity} = case {valid?, reason} do
      {true, _} -> {:message_validated, :debug}
      {false, :replay_attack} -> {:replay_attack, :critical}
      {false, :signature_failure} -> {:signature_failure, :error}
      {false, :nonce_reuse} -> {:nonce_reuse, :error}
      {false, _} -> {:message_rejected, :warning}
    end
    
    log_event(server, type, severity, details)
  end

  @doc """
  Queries audit logs with filters.
  """
  def query_logs(server \\ __MODULE__, filters \\ %{}) do
    GenServer.call(server, {:query_logs, filters})
  end

  @doc """
  Generates compliance report.
  """
  def generate_compliance_report(server \\ __MODULE__, opts \\ []) do
    GenServer.call(server, {:generate_compliance_report, opts})
  end

  @doc """
  Gets current statistics and anomaly detection status.
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Create ETS table for fast queries
    table = :ets.new(@table_name, [
      :ordered_set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
    
    # Initialize circular buffer for batched writes
    buffer = :queue.new()
    
    # Initialize anomaly detection thresholds
    anomaly_thresholds = %{
      auth_failure: opts[:auth_failure_threshold] || 5,
      replay_attack: opts[:replay_attack_threshold] || 3,
      signature_failure: opts[:signature_failure_threshold] || 10
    }
    
    # Generate encryption key for sensitive log data
    log_encryption_key = opts[:encryption_key] || CryptoUtils.generate_key()
    
    state = %__MODULE__{
      ets_table: table,
      buffer: buffer,
      buffer_size: 0,
      event_counts: init_event_counts(),
      anomaly_thresholds: anomaly_thresholds,
      archive_path: opts[:archive_path] || "priv/security_logs",
      log_encryption_key: log_encryption_key,
      stats: %{
        total_events: 0,
        events_by_type: %{},
        events_by_severity: %{},
        anomalies_detected: 0,
        last_archive: nil
      }
    }
    
    # Schedule periodic tasks
    schedule_flush()
    schedule_archive()
    schedule_anomaly_detection()
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:log_event, type, severity, details}, state) do
    event = create_event(type, severity, details)
    
    # Add to buffer
    new_buffer = :queue.in(event, state.buffer)
    new_buffer_size = state.buffer_size + 1
    
    # Update event counts for anomaly detection
    new_event_counts = update_event_counts(state.event_counts, type)
    
    # Update stats
    new_stats = update_stats(state.stats, event)
    
    # Check if buffer needs flushing
    new_state = %{state | 
      buffer: new_buffer,
      buffer_size: new_buffer_size,
      event_counts: new_event_counts,
      stats: new_stats
    }
    
    if new_buffer_size >= @max_buffer_size do
      {:noreply, flush_buffer(new_state)}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call({:query_logs, filters}, _from, state) do
    # Ensure buffer is flushed before querying
    state = flush_buffer(state)
    
    results = query_ets(state.ets_table, filters)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:generate_compliance_report, opts}, _from, state) do
    # Ensure buffer is flushed
    state = flush_buffer(state)
    
    report = generate_report(state, opts)
    {:reply, {:ok, report}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    anomaly_status = check_anomalies(state.event_counts, state.anomaly_thresholds)
    
    stats = Map.merge(state.stats, %{
      buffer_size: state.buffer_size,
      anomaly_status: anomaly_status,
      table_size: :ets.info(state.ets_table, :size)
    })
    
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:flush_buffer, state) do
    new_state = flush_buffer(state)
    schedule_flush()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:archive_logs, state) do
    new_state = archive_old_logs(state)
    schedule_archive()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_anomalies, state) do
    anomalies = check_anomalies(state.event_counts, state.anomaly_thresholds)
    
    Enum.each(anomalies, fn {type, status} ->
      if status[:anomaly] do
        log_event(self(), :intrusion_detected, :critical, %{
          anomaly_type: type,
          count: status[:count],
          threshold: status[:threshold],
          window_ms: @anomaly_detection_window_ms
        })
      end
    end)
    
    # Reset event counts after checking
    new_state = %{state | event_counts: init_event_counts()}
    {:noreply, new_state}
  end

  # Private functions

  defp create_event(type, severity, details) do
    %Event{
      id: generate_event_id(),
      type: type,
      timestamp: System.os_time(:microsecond),
      severity: severity,
      actor: details[:actor],
      resource: details[:resource],
      action: details[:action],
      result: details[:result],
      metadata: details[:metadata] || %{},
      ip_address: details[:ip_address],
      user_agent: details[:user_agent],
      correlation_id: details[:correlation_id]
    }
  end

  defp generate_event_id do
    # Combine timestamp with random bytes for unique, sortable IDs
    timestamp = System.os_time(:nanosecond)
    random = :crypto.strong_rand_bytes(8)
    Base.encode64(<<timestamp::64, random::binary>>, padding: false)
  end

  defp flush_buffer(state) do
    if state.buffer_size > 0 do
      # Convert queue to list and insert all at once
      events = :queue.to_list(state.buffer)
      
      # Batch insert into ETS
      Enum.each(events, fn event ->
        key = {event.timestamp, event.id}
        :ets.insert(state.ets_table, {key, event})
      end)
      
      Logger.debug("Flushed #{state.buffer_size} audit events to storage")
      
      %{state | buffer: :queue.new(), buffer_size: 0}
    else
      state
    end
  end

  defp query_ets(table, filters) do
    # Build match spec from filters
    match_spec = build_match_spec(filters)
    
    # Execute query with limit
    limit = filters[:limit] || 1000
    
    :ets.select(table, match_spec, limit)
    |> Enum.map(fn {_key, event} -> event end)
  end

  defp build_match_spec(filters) do
    # Start with basic pattern
    pattern = {{:"$1", :"$2"}, :"$3"}
    
    # Build conditions
    conditions = []
    
    # Add time range condition
    if filters[:start_time] do
      conditions = [{:>=, {:element, 1, :"$1"}, filters[:start_time]} | conditions]
    end
    
    if filters[:end_time] do
      conditions = [{:<=, {:element, 1, :"$1"}, filters[:end_time]} | conditions]
    end
    
    # Add type filter
    if filters[:type] do
      conditions = [{:==, {:element, 2, :"$3"}, filters[:type]} | conditions]
    end
    
    # Add severity filter
    if filters[:severity] do
      conditions = [{:==, {:element, 4, :"$3"}, filters[:severity]} | conditions]
    end
    
    # Build final match spec
    guard = if conditions == [], do: [], else: [conditions]
    [{pattern, guard, [:"$3"]}]
  end

  defp init_event_counts do
    Map.new(@event_types, fn type -> {type, %{count: 0, first_seen: nil}} end)
  end

  defp update_event_counts(counts, type) do
    Map.update!(counts, type, fn info ->
      %{info | 
        count: info.count + 1,
        first_seen: info.first_seen || System.os_time(:millisecond)
      }
    end)
  end

  defp check_anomalies(event_counts, thresholds) do
    now = System.os_time(:millisecond)
    
    Map.new([:auth_failure, :replay_attack, :signature_failure], fn type ->
      info = event_counts[type]
      threshold = thresholds[type]
      
      # Check if count exceeds threshold within time window
      in_window = info.first_seen && (now - info.first_seen) <= @anomaly_detection_window_ms
      anomaly = in_window && info.count >= threshold
      
      {type, %{
        count: info.count,
        threshold: threshold,
        anomaly: anomaly
      }}
    end)
  end

  defp update_stats(stats, event) do
    stats
    |> Map.update!(:total_events, &(&1 + 1))
    |> Map.update!(:events_by_type, fn by_type ->
      Map.update(by_type, event.type, 1, &(&1 + 1))
    end)
    |> Map.update!(:events_by_severity, fn by_severity ->
      Map.update(by_severity, event.severity, 1, &(&1 + 1))
    end)
  end

  defp archive_old_logs(state) do
    # Archive logs older than 24 hours
    cutoff = System.os_time(:microsecond) - :timer.hours(24)
    
    # Query old events
    old_events = :ets.select(state.ets_table, [
      {{{:"$1", :"$2"}, :"$3"}, [{:<, :"$1", cutoff}], [:"$3"]}
    ])
    
    if length(old_events) > 0 do
      # Archive to file
      archive_file = generate_archive_filename(state.archive_path)
      write_archive(archive_file, old_events, state.log_encryption_key)
      
      # Delete from ETS
      :ets.select_delete(state.ets_table, [
        {{{:"$1", :"$2"}, :"$3"}, [{:<, :"$1", cutoff}], [true]}
      ])
      
      Logger.info("Archived #{length(old_events)} audit events to #{archive_file}")
    end
    
    %{state | stats: Map.put(state.stats, :last_archive, System.os_time(:second))}
  end

  defp generate_archive_filename(base_path) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    Path.join(base_path, "audit_log_#{timestamp}.enc")
  end

  defp write_archive(filename, events, encryption_key) do
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(filename))
    
    # Serialize and encrypt
    data = :erlang.term_to_binary(events)
    {:ok, encrypted} = CryptoUtils.encrypt(data, encryption_key)
    
    # Write to file
    File.write!(filename, encrypted)
  end

  defp generate_report(state, opts) do
    period = opts[:period] || :last_24_hours
    
    # Calculate time range
    end_time = System.os_time(:microsecond)
    start_time = case period do
      :last_24_hours -> end_time - :timer.hours(24)
      :last_7_days -> end_time - :timer.hours(24 * 7)
      :last_30_days -> end_time - :timer.hours(24 * 30)
      _ -> 0
    end
    
    # Query events in time range
    events = query_ets(state.ets_table, %{
      start_time: start_time,
      end_time: end_time
    })
    
    # Generate report
    %{
      period: period,
      total_events: length(events),
      events_by_type: count_by(events, & &1.type),
      events_by_severity: count_by(events, & &1.severity),
      critical_events: Enum.filter(events, & &1.severity == :critical),
      unique_actors: events |> Enum.map(& &1.actor) |> Enum.uniq() |> length(),
      compliance_status: analyze_compliance(events)
    }
  end

  defp count_by(enumerable, fun) do
    Enum.reduce(enumerable, %{}, fn item, acc ->
      key = fun.(item)
      Map.update(acc, key, 1, &(&1 + 1))
    end)
  end

  defp analyze_compliance(events) do
    # Basic compliance checks
    %{
      authentication_tracking: check_auth_compliance(events),
      audit_completeness: check_audit_completeness(events),
      security_incidents: check_incident_response(events)
    }
  end

  defp check_auth_compliance(events) do
    auth_events = Enum.filter(events, & &1.type in [:auth_success, :auth_failure])
    
    %{
      total_auth_events: length(auth_events),
      has_actor_info: Enum.all?(auth_events, & &1.actor),
      has_ip_tracking: Enum.all?(auth_events, & &1.ip_address)
    }
  end

  defp check_audit_completeness(events) do
    %{
      has_correlation_ids: Enum.count(events, & &1.correlation_id) / max(length(events), 1),
      has_metadata: Enum.count(events, & map_size(&1.metadata || %{}) > 0) / max(length(events), 1)
    }
  end

  defp check_incident_response(events) do
    critical_events = Enum.filter(events, & &1.severity == :critical)
    
    %{
      critical_event_count: length(critical_events),
      intrusion_attempts: Enum.count(events, & &1.type == :intrusion_detected),
      replay_attacks: Enum.count(events, & &1.type == :replay_attack)
    }
  end

  defp schedule_flush do
    Process.send_after(self(), :flush_buffer, @flush_interval_ms)
  end

  defp schedule_archive do
    Process.send_after(self(), :archive_logs, @archive_interval_ms)
  end

  defp schedule_anomaly_detection do
    Process.send_after(self(), :check_anomalies, @anomaly_detection_window_ms)
  end
end