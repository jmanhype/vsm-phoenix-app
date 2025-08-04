defmodule VsmPhoenix.ChaosEngineering.FaultRegistry do
  @moduledoc """
  Registry for tracking and managing chaos engineering faults.
  Maintains a catalog of fault types and their configurations.
  """

  use GenServer
  require Logger

  defmodule FaultDefinition do
    @enforce_keys [:id, :name, :type, :category]
    defstruct [
      :id,
      :name,
      :type,
      :category,
      :description,
      :parameters,
      :severity_levels,
      :impact_assessment,
      :mitigation_strategies,
      :recovery_procedures,
      :prerequisites,
      :contraindications,
      enabled: true
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_fault_type(fault_definition) do
    GenServer.call(__MODULE__, {:register_fault, fault_definition})
  end

  def get_fault_definition(fault_id) do
    GenServer.call(__MODULE__, {:get_fault, fault_id})
  end

  def list_fault_types(category \\ nil) do
    GenServer.call(__MODULE__, {:list_faults, category})
  end

  def get_fault_catalog do
    GenServer.call(__MODULE__, :get_catalog)
  end

  def enable_fault_type(fault_id) do
    GenServer.call(__MODULE__, {:enable_fault, fault_id})
  end

  def disable_fault_type(fault_id) do
    GenServer.call(__MODULE__, {:disable_fault, fault_id})
  end

  # Server Callbacks

  def init(_opts) do
    state = %{
      fault_definitions: initialize_fault_catalog(),
      custom_faults: %{},
      fault_statistics: %{}
    }

    {:ok, state}
  end

  def handle_call({:register_fault, fault_definition}, _from, state) do
    new_state = %{state |
      custom_faults: Map.put(state.custom_faults, fault_definition.id, fault_definition)
    }
    
    {:reply, :ok, new_state}
  end

  def handle_call({:get_fault, fault_id}, _from, state) do
    fault = Map.get(state.fault_definitions, fault_id) ||
            Map.get(state.custom_faults, fault_id)
    
    if fault do
      {:reply, {:ok, fault}, state}
    else
      {:reply, {:error, :fault_not_found}, state}
    end
  end

  def handle_call({:list_faults, category}, _from, state) do
    all_faults = Map.merge(state.fault_definitions, state.custom_faults)
    
    filtered_faults = if category do
      Enum.filter(all_faults, fn {_id, fault} -> 
        fault.category == category
      end)
      |> Map.new()
    else
      all_faults
    end
    
    {:reply, {:ok, filtered_faults}, state}
  end

  def handle_call(:get_catalog, _from, state) do
    catalog = build_fault_catalog(state)
    {:reply, {:ok, catalog}, state}
  end

  def handle_call({:enable_fault, fault_id}, _from, state) do
    new_state = update_fault_status(state, fault_id, true)
    {:reply, :ok, new_state}
  end

  def handle_call({:disable_fault, fault_id}, _from, state) do
    new_state = update_fault_status(state, fault_id, false)
    {:reply, :ok, new_state}
  end

  # Private Functions

  defp initialize_fault_catalog do
    %{
      # Network Faults
      network_latency: %FaultDefinition{
        id: :network_latency,
        name: "Network Latency",
        type: :network,
        category: :infrastructure,
        description: "Introduces artificial network latency between components",
        parameters: %{
          latency_ms: {100, 10000},
          jitter_ms: {0, 1000},
          packet_loss: {0.0, 0.5}
        },
        severity_levels: %{
          low: %{latency_ms: 100, jitter_ms: 10, packet_loss: 0.01},
          medium: %{latency_ms: 500, jitter_ms: 50, packet_loss: 0.05},
          high: %{latency_ms: 2000, jitter_ms: 200, packet_loss: 0.1},
          critical: %{latency_ms: 10000, jitter_ms: 1000, packet_loss: 0.3}
        },
        impact_assessment: "Affects request response times and throughput",
        mitigation_strategies: ["Implement timeouts", "Add retry logic", "Use circuit breakers"],
        recovery_procedures: ["Clear network rules", "Reset connections"]
      },

      network_partition: %FaultDefinition{
        id: :network_partition,
        name: "Network Partition",
        type: :network,
        category: :infrastructure,
        description: "Simulates network split between nodes or services",
        parameters: %{
          partition_type: [:symmetric, :asymmetric, :partial],
          affected_nodes: :list,
          duration_ms: {1000, 300000}
        },
        severity_levels: %{
          low: %{partition_type: :partial, duration_ms: 5000},
          medium: %{partition_type: :asymmetric, duration_ms: 30000},
          high: %{partition_type: :symmetric, duration_ms: 60000},
          critical: %{partition_type: :symmetric, duration_ms: 300000}
        },
        impact_assessment: "Can cause split-brain scenarios and data inconsistency",
        mitigation_strategies: ["Implement quorum-based consensus", "Use partition-tolerant algorithms"],
        recovery_procedures: ["Reconnect nodes", "Reconcile data", "Verify consistency"]
      },

      # Process Faults
      process_crash: %FaultDefinition{
        id: :process_crash,
        name: "Process Crash",
        type: :process,
        category: :application,
        description: "Terminates a process or service abruptly",
        parameters: %{
          target_type: [:pid, :name, :group],
          exit_reason: [:normal, :kill, :chaos],
          restart_after: {0, 60000}
        },
        severity_levels: %{
          low: %{exit_reason: :normal, restart_after: 5000},
          medium: %{exit_reason: :kill, restart_after: 10000},
          high: %{exit_reason: :kill, restart_after: 30000},
          critical: %{exit_reason: :kill, restart_after: 0}
        },
        impact_assessment: "Service unavailability, potential data loss",
        mitigation_strategies: ["Implement supervisors", "Use process monitoring"],
        recovery_procedures: ["Restart process", "Restore state", "Verify functionality"]
      },

      # Resource Faults
      memory_pressure: %FaultDefinition{
        id: :memory_pressure,
        name: "Memory Pressure",
        type: :resource,
        category: :infrastructure,
        description: "Creates artificial memory pressure on the system",
        parameters: %{
          allocation_mb: {50, 2000},
          allocation_pattern: [:gradual, :sudden, :oscillating],
          duration_ms: {5000, 120000}
        },
        severity_levels: %{
          low: %{allocation_mb: 100, allocation_pattern: :gradual},
          medium: %{allocation_mb: 500, allocation_pattern: :sudden},
          high: %{allocation_mb: 1000, allocation_pattern: :sudden},
          critical: %{allocation_mb: 2000, allocation_pattern: :oscillating}
        },
        impact_assessment: "Performance degradation, OOM errors, service crashes",
        mitigation_strategies: ["Set memory limits", "Implement backpressure"],
        recovery_procedures: ["Release allocated memory", "Trigger garbage collection"]
      },

      cpu_throttle: %FaultDefinition{
        id: :cpu_throttle,
        name: "CPU Throttling",
        type: :resource,
        category: :infrastructure,
        description: "Consumes CPU resources to simulate high load",
        parameters: %{
          cpu_percentage: {10, 100},
          core_count: {1, 16},
          pattern: [:constant, :burst, :wave]
        },
        severity_levels: %{
          low: %{cpu_percentage: 25, core_count: 1},
          medium: %{cpu_percentage: 50, core_count: 2},
          high: %{cpu_percentage: 75, core_count: 4},
          critical: %{cpu_percentage: 95, core_count: 8}
        },
        impact_assessment: "Slow response times, request timeouts",
        mitigation_strategies: ["Implement load shedding", "Use rate limiting"],
        recovery_procedures: ["Stop CPU-intensive tasks", "Rebalance load"]
      },

      # Storage Faults
      disk_failure: %FaultDefinition{
        id: :disk_failure,
        name: "Disk Failure",
        type: :storage,
        category: :infrastructure,
        description: "Simulates disk I/O failures",
        parameters: %{
          failure_rate: {0.1, 1.0},
          operation_types: [:read, :write, :both],
          error_type: [:io_error, :corruption, :slowdown]
        },
        severity_levels: %{
          low: %{failure_rate: 0.1, error_type: :slowdown},
          medium: %{failure_rate: 0.3, error_type: :io_error},
          high: %{failure_rate: 0.6, error_type: :io_error},
          critical: %{failure_rate: 0.9, error_type: :corruption}
        },
        impact_assessment: "Data loss, service unavailability, corruption",
        mitigation_strategies: ["Use RAID", "Implement checksums", "Regular backups"],
        recovery_procedures: ["Switch to backup storage", "Restore from backups"]
      },

      # Byzantine Faults
      byzantine_fault: %FaultDefinition{
        id: :byzantine_fault,
        name: "Byzantine Fault",
        type: :byzantine,
        category: :distributed,
        description: "Simulates Byzantine behavior with incorrect or malicious responses",
        parameters: %{
          corruption_rate: {0.05, 0.5},
          behavior_type: [:random, :adversarial, :delayed],
          target_operations: [:consensus, :replication, :communication]
        },
        severity_levels: %{
          low: %{corruption_rate: 0.05, behavior_type: :delayed},
          medium: %{corruption_rate: 0.15, behavior_type: :random},
          high: %{corruption_rate: 0.3, behavior_type: :random},
          critical: %{corruption_rate: 0.5, behavior_type: :adversarial}
        },
        impact_assessment: "Consensus failures, data inconsistency, trust issues",
        mitigation_strategies: ["Use Byzantine fault-tolerant algorithms", "Implement voting mechanisms"],
        recovery_procedures: ["Isolate faulty nodes", "Rebuild consensus", "Verify data integrity"]
      },

      # Time Faults
      clock_skew: %FaultDefinition{
        id: :clock_skew,
        name: "Clock Skew",
        type: :time,
        category: :distributed,
        description: "Introduces clock skew between nodes",
        parameters: %{
          skew_ms: {100, 60000},
          drift_rate: {0.0, 0.1},
          affected_nodes: :list
        },
        severity_levels: %{
          low: %{skew_ms: 100, drift_rate: 0.001},
          medium: %{skew_ms: 1000, drift_rate: 0.01},
          high: %{skew_ms: 10000, drift_rate: 0.05},
          critical: %{skew_ms: 60000, drift_rate: 0.1}
        },
        impact_assessment: "Ordering violations, timeout issues, synchronization problems",
        mitigation_strategies: ["Use logical clocks", "Implement NTP", "Use hybrid clocks"],
        recovery_procedures: ["Resync clocks", "Adjust timestamps", "Rebuild ordering"]
      },

      # Data Faults
      data_corruption: %FaultDefinition{
        id: :data_corruption,
        name: "Data Corruption",
        type: :data,
        category: :application,
        description: "Corrupts data in transit or at rest",
        parameters: %{
          corruption_rate: {0.01, 0.5},
          corruption_type: [:bit_flip, :truncation, :duplication],
          target_data: [:messages, :storage, :cache]
        },
        severity_levels: %{
          low: %{corruption_rate: 0.01, corruption_type: :bit_flip},
          medium: %{corruption_rate: 0.05, corruption_type: :truncation},
          high: %{corruption_rate: 0.15, corruption_type: :truncation},
          critical: %{corruption_rate: 0.3, corruption_type: :duplication}
        },
        impact_assessment: "Data integrity issues, application errors, cascading failures",
        mitigation_strategies: ["Use checksums", "Implement error correction", "Data validation"],
        recovery_procedures: ["Restore from backups", "Rebuild corrupted data", "Verify integrity"]
      },

      # Load Faults
      thundering_herd: %FaultDefinition{
        id: :thundering_herd,
        name: "Thundering Herd",
        type: :load,
        category: :application,
        description: "Simulates thundering herd problem with simultaneous requests",
        parameters: %{
          request_count: {100, 10000},
          burst_duration_ms: {100, 5000},
          target_endpoint: :string
        },
        severity_levels: %{
          low: %{request_count: 100, burst_duration_ms: 1000},
          medium: %{request_count: 500, burst_duration_ms: 500},
          high: %{request_count: 2000, burst_duration_ms: 200},
          critical: %{request_count: 10000, burst_duration_ms: 100}
        },
        impact_assessment: "Service overload, cascading failures, resource exhaustion",
        mitigation_strategies: ["Implement jitter", "Use request coalescing", "Add caching"],
        recovery_procedures: ["Rate limit requests", "Scale resources", "Clear backlogs"]
      }
    }
  end

  defp build_fault_catalog(state) do
    all_faults = Map.merge(state.fault_definitions, state.custom_faults)
    
    categories = all_faults
    |> Enum.group_by(fn {_id, fault} -> fault.category end)
    |> Enum.map(fn {category, faults} ->
      %{
        category: category,
        faults: Enum.map(faults, fn {id, fault} ->
          %{
            id: id,
            name: fault.name,
            type: fault.type,
            description: fault.description,
            enabled: fault.enabled
          }
        end)
      }
    end)
    
    %{
      total_faults: map_size(all_faults),
      enabled_faults: Enum.count(all_faults, fn {_id, fault} -> fault.enabled end),
      categories: categories,
      fault_types: Enum.uniq(Enum.map(all_faults, fn {_id, fault} -> fault.type end))
    }
  end

  defp update_fault_status(state, fault_id, enabled) do
    cond do
      Map.has_key?(state.fault_definitions, fault_id) ->
        updated_fault = %{Map.get(state.fault_definitions, fault_id) | enabled: enabled}
        %{state | fault_definitions: Map.put(state.fault_definitions, fault_id, updated_fault)}
      
      Map.has_key?(state.custom_faults, fault_id) ->
        updated_fault = %{Map.get(state.custom_faults, fault_id) | enabled: enabled}
        %{state | custom_faults: Map.put(state.custom_faults, fault_id, updated_fault)}
      
      true ->
        state
    end
  end
end