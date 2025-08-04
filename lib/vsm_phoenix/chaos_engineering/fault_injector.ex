defmodule VsmPhoenix.ChaosEngineering.FaultInjector do
  @moduledoc """
  Fault injection system for chaos engineering.
  Introduces controlled failures to test system resilience.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.ChaosEngineering.{ChaosMetrics, FaultRegistry}

  @fault_types [
    :network_latency,
    :network_partition,
    :process_crash,
    :memory_pressure,
    :cpu_throttle,
    :disk_failure,
    :byzantine_fault,
    :clock_skew,
    :resource_exhaustion,
    :data_corruption
  ]

  defmodule Fault do
    @enforce_keys [:id, :type, :target, :severity, :duration]
    defstruct [
      :id,
      :type,
      :target,
      :severity,
      :duration,
      :probability,
      :metadata,
      activated_at: nil,
      deactivated_at: nil,
      impact_metrics: %{}
    ]
  end

  defmodule InjectionPolicy do
    @enforce_keys [:name, :fault_types, :targets]
    defstruct [
      :name,
      :fault_types,
      :targets,
      :schedule,
      :conditions,
      :max_concurrent: 3,
      :cooldown_ms: 5000,
      enabled: true
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def inject_fault(fault_type, target, opts \\ []) do
    GenServer.call(__MODULE__, {:inject_fault, fault_type, target, opts})
  end

  def inject_random_fault(opts \\ []) do
    GenServer.call(__MODULE__, {:inject_random, opts})
  end

  def inject_cascade(initial_target, opts \\ []) do
    GenServer.call(__MODULE__, {:inject_cascade, initial_target, opts})
  end

  def clear_fault(fault_id) do
    GenServer.call(__MODULE__, {:clear_fault, fault_id})
  end

  def clear_all_faults do
    GenServer.call(__MODULE__, :clear_all_faults)
  end

  def list_active_faults do
    GenServer.call(__MODULE__, :list_active_faults)
  end

  def apply_policy(policy) do
    GenServer.call(__MODULE__, {:apply_policy, policy})
  end

  def get_fault_history(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_history, limit})
  end

  # Server Callbacks

  def init(opts) do
    state = %{
      active_faults: %{},
      fault_history: [],
      policies: [],
      fault_counter: 0,
      injection_enabled: Keyword.get(opts, :enabled, true),
      max_concurrent_faults: Keyword.get(opts, :max_concurrent, 5),
      fault_probability: Keyword.get(opts, :probability, 0.1),
      severity_weights: %{
        low: 0.5,
        medium: 0.3,
        high: 0.15,
        critical: 0.05
      }
    }

    schedule_random_injection()
    {:ok, state}
  end

  def handle_call({:inject_fault, type, target, opts}, _from, state) do
    case inject_fault_impl(type, target, opts, state) do
      {:ok, fault, new_state} ->
        {:reply, {:ok, fault}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:inject_random, opts}, _from, state) do
    if state.injection_enabled do
      fault = generate_random_fault(opts, state)
      case inject_fault_impl(fault.type, fault.target, Map.from_struct(fault), state) do
        {:ok, fault, new_state} ->
          {:reply, {:ok, fault}, new_state}
        
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :injection_disabled}, state}
    end
  end

  def handle_call({:inject_cascade, initial_target, opts}, _from, state) do
    cascade_faults = generate_cascade_faults(initial_target, opts)
    
    results = Enum.map(cascade_faults, fn fault_spec ->
      case inject_fault_impl(fault_spec.type, fault_spec.target, Map.from_struct(fault_spec), state) do
        {:ok, fault, _new_state} -> {:ok, fault}
        {:error, reason} -> {:error, reason}
      end
    end)
    
    successful_faults = Enum.filter(results, &match?({:ok, _}, &1))
    {:reply, {:ok, successful_faults}, state}
  end

  def handle_call({:clear_fault, fault_id}, _from, state) do
    case Map.get(state.active_faults, fault_id) do
      nil ->
        {:reply, {:error, :fault_not_found}, state}
      
      fault ->
        new_state = clear_fault_impl(fault, state)
        {:reply, :ok, new_state}
    end
  end

  def handle_call(:clear_all_faults, _from, state) do
    Enum.each(state.active_faults, fn {_id, fault} ->
      clear_fault_impl(fault, state)
    end)
    
    new_state = %{state | active_faults: %{}}
    {:reply, :ok, new_state}
  end

  def handle_call(:list_active_faults, _from, state) do
    {:reply, Map.values(state.active_faults), state}
  end

  def handle_call({:apply_policy, policy}, _from, state) do
    new_state = %{state | policies: [policy | state.policies]}
    schedule_policy_execution(policy)
    {:reply, :ok, new_state}
  end

  def handle_call({:get_history, limit}, _from, state) do
    history = Enum.take(state.fault_history, limit)
    {:reply, history, state}
  end

  def handle_info({:execute_fault, fault}, state) do
    new_state = execute_fault(fault, state)
    {:noreply, new_state}
  end

  def handle_info({:clear_expired_fault, fault_id}, state) do
    case Map.get(state.active_faults, fault_id) do
      nil ->
        {:noreply, state}
      
      fault ->
        new_state = clear_fault_impl(fault, state)
        {:noreply, new_state}
    end
  end

  def handle_info(:inject_random, state) do
    if should_inject_fault?(state) do
      fault = generate_random_fault(%{}, state)
      case inject_fault_impl(fault.type, fault.target, Map.from_struct(fault), state) do
        {:ok, _fault, new_state} ->
          schedule_random_injection()
          {:noreply, new_state}
        
        {:error, _reason} ->
          schedule_random_injection()
          {:noreply, state}
      end
    else
      schedule_random_injection()
      {:noreply, state}
    end
  end

  def handle_info({:execute_policy, policy}, state) do
    if policy.enabled do
      execute_policy(policy, state)
    end
    
    schedule_policy_execution(policy)
    {:noreply, state}
  end

  # Private Functions

  defp inject_fault_impl(type, target, opts, state) do
    if map_size(state.active_faults) >= state.max_concurrent_faults do
      {:error, :max_concurrent_faults_reached}
    else
      fault = create_fault(type, target, opts, state)
      
      case execute_fault(fault, state) do
        {:ok, executed_fault} ->
          new_state = %{state |
            active_faults: Map.put(state.active_faults, fault.id, executed_fault),
            fault_history: [executed_fault | state.fault_history],
            fault_counter: state.fault_counter + 1
          }
          
          if fault.duration && fault.duration > 0 do
            Process.send_after(self(), {:clear_expired_fault, fault.id}, fault.duration)
          end
          
          log_fault_injection(executed_fault)
          ChaosMetrics.record_fault_injection(executed_fault)
          
          {:ok, executed_fault, new_state}
        
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp create_fault(type, target, opts, state) do
    %Fault{
      id: "fault_#{state.fault_counter}",
      type: type,
      target: target,
      severity: Keyword.get(opts, :severity, :medium),
      duration: Keyword.get(opts, :duration, 30_000),
      probability: Keyword.get(opts, :probability, 1.0),
      metadata: Keyword.get(opts, :metadata, %{}),
      activated_at: DateTime.utc_now()
    }
  end

  defp execute_fault(fault, _state) do
    case fault.type do
      :network_latency ->
        inject_network_latency(fault)
      
      :network_partition ->
        inject_network_partition(fault)
      
      :process_crash ->
        inject_process_crash(fault)
      
      :memory_pressure ->
        inject_memory_pressure(fault)
      
      :cpu_throttle ->
        inject_cpu_throttle(fault)
      
      :disk_failure ->
        inject_disk_failure(fault)
      
      :byzantine_fault ->
        inject_byzantine_fault(fault)
      
      :clock_skew ->
        inject_clock_skew(fault)
      
      :resource_exhaustion ->
        inject_resource_exhaustion(fault)
      
      :data_corruption ->
        inject_data_corruption(fault)
      
      _ ->
        {:error, :unknown_fault_type}
    end
  end

  defp inject_network_latency(fault) do
    latency_ms = calculate_latency(fault.severity)
    
    # Simulate network latency by intercepting messages
    :ets.new(:chaos_latency_#{fault.id}, [:named_table, :public])
    :ets.insert(:chaos_latency_#{fault.id}, {:latency, latency_ms})
    
    {:ok, %{fault | impact_metrics: %{latency_ms: latency_ms}}}
  end

  defp inject_network_partition(fault) do
    # Simulate network partition by blocking communication
    partition_nodes = identify_partition_targets(fault.target)
    
    Enum.each(partition_nodes, fn node ->
      :net_kernel.disconnect(node)
    end)
    
    {:ok, %{fault | impact_metrics: %{partitioned_nodes: partition_nodes}}}
  end

  defp inject_process_crash(fault) do
    case fault.target do
      {:pid, pid} when is_pid(pid) ->
        Process.exit(pid, :chaos_kill)
        {:ok, %{fault | impact_metrics: %{killed_pid: pid}}}
      
      {:name, name} ->
        case Process.whereis(name) do
          nil -> {:error, :process_not_found}
          pid ->
            Process.exit(pid, :chaos_kill)
            {:ok, %{fault | impact_metrics: %{killed_process: name}}}
        end
      
      _ ->
        {:error, :invalid_target}
    end
  end

  defp inject_memory_pressure(fault) do
    memory_mb = calculate_memory_pressure(fault.severity)
    
    # Allocate memory to create pressure
    Task.start(fn ->
      _data = :binary.copy(<<0>>, memory_mb * 1024 * 1024)
      Process.sleep(fault.duration || 30_000)
    end)
    
    {:ok, %{fault | impact_metrics: %{allocated_mb: memory_mb}}}
  end

  defp inject_cpu_throttle(fault) do
    cpu_load = calculate_cpu_load(fault.severity)
    
    # Create CPU-intensive tasks
    Enum.each(1..cpu_load, fn _ ->
      Task.start(fn ->
        burn_cpu(fault.duration || 30_000)
      end)
    end)
    
    {:ok, %{fault | impact_metrics: %{cpu_threads: cpu_load}}}
  end

  defp inject_disk_failure(fault) do
    # Simulate disk failure by making filesystem operations fail
    :ets.new(:chaos_disk_#{fault.id}, [:named_table, :public])
    :ets.insert(:chaos_disk_#{fault.id}, {:fail_rate, severity_to_fail_rate(fault.severity)})
    
    {:ok, %{fault | impact_metrics: %{disk_fail_rate: severity_to_fail_rate(fault.severity)}}}
  end

  defp inject_byzantine_fault(fault) do
    # Simulate Byzantine behavior with random incorrect responses
    :ets.new(:chaos_byzantine_#{fault.id}, [:named_table, :public])
    :ets.insert(:chaos_byzantine_#{fault.id}, {:corruption_rate, severity_to_corruption_rate(fault.severity)})
    
    {:ok, %{fault | impact_metrics: %{byzantine_rate: severity_to_corruption_rate(fault.severity)}}}
  end

  defp inject_clock_skew(fault) do
    skew_ms = calculate_clock_skew(fault.severity)
    
    # Note: Real clock skew would require system-level changes
    # This simulates it at application level
    :ets.new(:chaos_clock_#{fault.id}, [:named_table, :public])
    :ets.insert(:chaos_clock_#{fault.id}, {:skew_ms, skew_ms})
    
    {:ok, %{fault | impact_metrics: %{clock_skew_ms: skew_ms}}}
  end

  defp inject_resource_exhaustion(fault) do
    # Exhaust specific resources based on target
    resource_type = fault.metadata[:resource_type] || :connections
    
    case resource_type do
      :connections ->
        exhaust_connections(fault)
      
      :file_descriptors ->
        exhaust_file_descriptors(fault)
      
      :processes ->
        exhaust_processes(fault)
      
      _ ->
        {:error, :unknown_resource_type}
    end
  end

  defp inject_data_corruption(fault) do
    corruption_rate = severity_to_corruption_rate(fault.severity)
    
    :ets.new(:chaos_corruption_#{fault.id}, [:named_table, :public])
    :ets.insert(:chaos_corruption_#{fault.id}, {:rate, corruption_rate})
    
    {:ok, %{fault | impact_metrics: %{corruption_rate: corruption_rate}}}
  end

  defp clear_fault_impl(fault, state) do
    # Clean up fault-specific resources
    case fault.type do
      :network_latency ->
        :ets.delete(:chaos_latency_#{fault.id})
      
      :network_partition ->
        # Reconnect partitioned nodes
        Enum.each(fault.impact_metrics[:partitioned_nodes] || [], fn node ->
          :net_kernel.connect_node(node)
        end)
      
      :disk_failure ->
        :ets.delete(:chaos_disk_#{fault.id})
      
      :byzantine_fault ->
        :ets.delete(:chaos_byzantine_#{fault.id})
      
      :clock_skew ->
        :ets.delete(:chaos_clock_#{fault.id})
      
      :data_corruption ->
        :ets.delete(:chaos_corruption_#{fault.id})
      
      _ ->
        :ok
    end
    
    updated_fault = %{fault | deactivated_at: DateTime.utc_now()}
    
    %{state |
      active_faults: Map.delete(state.active_faults, fault.id),
      fault_history: [updated_fault | state.fault_history]
    }
  end

  defp generate_random_fault(opts, state) do
    type = Enum.random(@fault_types)
    target = select_random_target(type)
    severity = select_random_severity(state.severity_weights)
    
    %Fault{
      id: "fault_#{state.fault_counter}",
      type: type,
      target: target,
      severity: severity,
      duration: Keyword.get(opts, :duration, random_duration()),
      probability: :rand.uniform(),
      metadata: %{auto_generated: true}
    }
  end

  defp generate_cascade_faults(initial_target, opts) do
    cascade_depth = Keyword.get(opts, :depth, 3)
    spread_factor = Keyword.get(opts, :spread, 2)
    
    generate_cascade_level([initial_target], cascade_depth, spread_factor, [])
  end

  defp generate_cascade_level([], _depth, _spread, acc), do: acc
  defp generate_cascade_level(_targets, 0, _spread, acc), do: acc
  
  defp generate_cascade_level(targets, depth, spread, acc) do
    new_faults = Enum.flat_map(targets, fn target ->
      Enum.map(1..spread, fn _ ->
        %Fault{
          id: "cascade_#{System.unique_integer([:positive])}",
          type: Enum.random(@fault_types),
          target: mutate_target(target),
          severity: cascade_severity(depth),
          duration: cascade_duration(depth),
          probability: 1.0,
          metadata: %{cascade: true, depth: depth}
        }
      end)
    end)
    
    new_targets = Enum.map(new_faults, & &1.target)
    generate_cascade_level(new_targets, depth - 1, spread, acc ++ new_faults)
  end

  defp should_inject_fault?(state) do
    state.injection_enabled and
    map_size(state.active_faults) < state.max_concurrent_faults and
    :rand.uniform() < state.fault_probability
  end

  defp execute_policy(policy, state) do
    Enum.each(policy.fault_types, fn fault_type ->
      Enum.each(policy.targets, fn target ->
        if meets_conditions?(policy.conditions, state) do
          inject_fault_impl(fault_type, target, %{}, state)
        end
      end)
    end)
  end

  defp meets_conditions?(nil, _state), do: true
  defp meets_conditions?(conditions, state) do
    Enum.all?(conditions, fn condition ->
      evaluate_condition(condition, state)
    end)
  end

  defp evaluate_condition({:time_range, {start_time, end_time}}, _state) do
    current_time = Time.utc_now()
    Time.compare(current_time, start_time) != :lt and
    Time.compare(current_time, end_time) != :gt
  end

  defp evaluate_condition({:load_threshold, threshold}, _state) do
    # Check system load
    :cpu_sup.util() < threshold
  end

  defp evaluate_condition(_, _state), do: true

  # Helper Functions

  defp calculate_latency(:low), do: 100
  defp calculate_latency(:medium), do: 500
  defp calculate_latency(:high), do: 2000
  defp calculate_latency(:critical), do: 10000

  defp calculate_memory_pressure(:low), do: 50
  defp calculate_memory_pressure(:medium), do: 200
  defp calculate_memory_pressure(:high), do: 500
  defp calculate_memory_pressure(:critical), do: 1000

  defp calculate_cpu_load(:low), do: 2
  defp calculate_cpu_load(:medium), do: 4
  defp calculate_cpu_load(:high), do: 8
  defp calculate_cpu_load(:critical), do: 16

  defp calculate_clock_skew(:low), do: 100
  defp calculate_clock_skew(:medium), do: 1000
  defp calculate_clock_skew(:high), do: 10000
  defp calculate_clock_skew(:critical), do: 60000

  defp severity_to_fail_rate(:low), do: 0.1
  defp severity_to_fail_rate(:medium), do: 0.3
  defp severity_to_fail_rate(:high), do: 0.6
  defp severity_to_fail_rate(:critical), do: 0.9

  defp severity_to_corruption_rate(:low), do: 0.05
  defp severity_to_corruption_rate(:medium), do: 0.15
  defp severity_to_corruption_rate(:high), do: 0.3
  defp severity_to_corruption_rate(:critical), do: 0.5

  defp random_duration do
    Enum.random([5_000, 10_000, 30_000, 60_000])
  end

  defp select_random_target(:process_crash) do
    # Select a random process
    processes = Process.list()
    {:pid, Enum.random(processes)}
  end

  defp select_random_target(:network_partition) do
    # Select random nodes
    nodes = Node.list()
    if length(nodes) > 0 do
      {:nodes, Enum.take_random(nodes, div(length(nodes), 2))}
    else
      {:local, node()}
    end
  end

  defp select_random_target(_type) do
    # Generic target
    {:system, :random}
  end

  defp select_random_severity(weights) do
    total = Enum.sum(Map.values(weights))
    random = :rand.uniform() * total
    
    weights
    |> Enum.reduce_while({0, nil}, fn {severity, weight}, {acc, _} ->
      new_acc = acc + weight
      if new_acc >= random do
        {:halt, {new_acc, severity}}
      else
        {:cont, {new_acc, nil}}
      end
    end)
    |> elem(1)
  end

  defp mutate_target({:pid, _pid}) do
    {:pid, Enum.random(Process.list())}
  end

  defp mutate_target({:name, name}) do
    {:name, :"#{name}_cascade"}
  end

  defp mutate_target(target), do: target

  defp cascade_severity(depth) when depth > 2, do: :low
  defp cascade_severity(depth) when depth > 1, do: :medium
  defp cascade_severity(_), do: :high

  defp cascade_duration(depth), do: depth * 5000

  defp burn_cpu(duration) do
    end_time = System.monotonic_time(:millisecond) + duration
    burn_cpu_loop(end_time)
  end

  defp burn_cpu_loop(end_time) do
    if System.monotonic_time(:millisecond) < end_time do
      # Intensive computation
      Enum.reduce(1..1000, 0, fn i, acc ->
        :math.sqrt(i) + acc
      end)
      burn_cpu_loop(end_time)
    end
  end

  defp exhaust_connections(fault) do
    connection_count = calculate_connection_count(fault.severity)
    
    Task.start(fn ->
      connections = Enum.map(1..connection_count, fn _ ->
        {:ok, socket} = :gen_tcp.connect('localhost', 80, [])
        socket
      end)
      
      Process.sleep(fault.duration || 30_000)
      
      Enum.each(connections, &:gen_tcp.close/1)
    end)
    
    {:ok, %{fault | impact_metrics: %{exhausted_connections: connection_count}}}
  end

  defp exhaust_file_descriptors(fault) do
    fd_count = calculate_fd_count(fault.severity)
    
    Task.start(fn ->
      files = Enum.map(1..fd_count, fn i ->
        path = "/tmp/chaos_fd_#{i}"
        {:ok, file} = File.open(path, [:write])
        file
      end)
      
      Process.sleep(fault.duration || 30_000)
      
      Enum.each(files, &File.close/1)
    end)
    
    {:ok, %{fault | impact_metrics: %{exhausted_fds: fd_count}}}
  end

  defp exhaust_processes(fault) do
    process_count = calculate_process_count(fault.severity)
    
    Task.start(fn ->
      processes = Enum.map(1..process_count, fn _ ->
        spawn(fn -> Process.sleep(:infinity) end)
      end)
      
      Process.sleep(fault.duration || 30_000)
      
      Enum.each(processes, &Process.exit(&1, :normal))
    end)
    
    {:ok, %{fault | impact_metrics: %{exhausted_processes: process_count}}}
  end

  defp calculate_connection_count(:low), do: 50
  defp calculate_connection_count(:medium), do: 200
  defp calculate_connection_count(:high), do: 500
  defp calculate_connection_count(:critical), do: 1000

  defp calculate_fd_count(:low), do: 100
  defp calculate_fd_count(:medium), do: 500
  defp calculate_fd_count(:high), do: 1000
  defp calculate_fd_count(:critical), do: 2000

  defp calculate_process_count(:low), do: 100
  defp calculate_process_count(:medium), do: 500
  defp calculate_process_count(:high), do: 2000
  defp calculate_process_count(:critical), do: 5000

  defp identify_partition_targets({:nodes, nodes}), do: nodes
  defp identify_partition_targets(_), do: []

  defp schedule_random_injection do
    interval = :rand.uniform(60_000) + 30_000  # 30-90 seconds
    Process.send_after(self(), :inject_random, interval)
  end

  defp schedule_policy_execution(policy) do
    interval = policy.schedule || 60_000  # Default 1 minute
    Process.send_after(self(), {:execute_policy, policy}, interval)
  end

  defp log_fault_injection(fault) do
    Logger.warning("[Chaos] Injected #{fault.type} fault on #{inspect(fault.target)} with severity #{fault.severity}")
  end
end