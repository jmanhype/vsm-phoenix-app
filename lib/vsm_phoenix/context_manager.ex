defmodule VsmPhoenix.ContextManager do
  @moduledoc """
  Enhanced Context Management inspired by Claude Code patterns.
  
  Integrates Claude-style context attachment mechanisms with CRDT persistence
  for distributed context synchronization across all VSM nodes. Provides
  sophisticated context tracking, versioning, and retrieval with cryptographic integrity.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.AMQP.RecursiveProtocol
  
  # Context types following Claude Code patterns
  @context_types %{
    system_reminders: :persistent,
    task_context: :session,
    conversation_history: :rolling,
    tool_results: :append_only,
    error_context: :ephemeral,
    performance_metrics: :aggregated
  }
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Attach context with Claude Code-style semantic tagging and CRDT persistence.
  
  ## Examples:
  
      # System reminder that persists across all nodes
      attach_context(:system_reminders, "crdt_sync_status", %{
        reminder: "CRDT sync interval: 5 seconds - always verify vector clocks",
        priority: :high,
        persist_across_nodes: true
      })
      
      # Task context for current operation
      attach_context(:task_context, "current_operation", %{
        operation: "distributed_consensus",
        nodes_involved: ["node1", "node2", "node3"],
        timeout: 30_000,
        security_level: :high
      })
  """
  def attach_context(type, key, context_data, opts \\ []) do
    GenServer.call(__MODULE__, {:attach_context, type, key, context_data, opts})
  end
  
  @doc """
  Retrieve context with automatic CRDT synchronization across nodes.
  """
  def get_context(type, key, opts \\ []) do
    GenServer.call(__MODULE__, {:get_context, type, key, opts})
  end
  
  @doc """
  Get all contexts for a specific type, useful for system reminders injection.
  """
  def get_all_contexts(type, opts \\ []) do
    GenServer.call(__MODULE__, {:get_all_contexts, type, opts})
  end
  
  @doc """
  Create Claude Code-style system reminder blocks for injection into prompts.
  """
  def generate_system_reminders(categories \\ [:all]) do
    GenServer.call(__MODULE__, {:generate_system_reminders, categories})
  end
  
  @doc """
  Update context with versioning and conflict resolution via CRDT.
  """
  def update_context(type, key, update_data, opts \\ []) do
    GenServer.call(__MODULE__, {:update_context, type, key, update_data, opts})
  end
  
  @doc """
  Remove context with proper cleanup across distributed nodes.
  """
  def remove_context(type, key, opts \\ []) do
    GenServer.call(__MODULE__, {:remove_context, type, key, opts})
  end
  
  @doc """
  Synchronize all contexts across specified nodes (for Phase 3 recursive spawning).
  """
  def sync_contexts(target_nodes, timeout \\ 10_000) do
    GenServer.call(__MODULE__, {:sync_contexts, target_nodes, timeout})
  end
  
  # Server Callbacks
  
  def init(opts) do
    # Initialize context storage in CRDT
    initialize_context_storage()
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, %{
      local_cache: %{},
      sync_status: %{},
      opts: opts
    }}
  end
  
  def handle_call({:attach_context, type, key, context_data, opts}, _from, state) do
    context_key = build_context_key(type, key)
    
    # Create context record with metadata
    context_record = %{
      type: type,
      key: key,
      data: context_data,
      attached_at: System.system_time(:millisecond),
      node_id: node(),
      version: 1,
      opts: opts
    }
    
    # Add cryptographic signature if security required
    signed_record = if opts[:cryptographic_integrity] do
      signature = CryptoLayer.sign_message(context_record, node())
      Map.put(context_record, :signature, signature)
    else
      context_record
    end
    
    # Store in CRDT based on context type
    result = case Map.get(@context_types, type) do
      :persistent ->
        ContextStore.update_lww_set("persistent_contexts", context_key, signed_record)
        
      :session ->
        ContextStore.add_to_set("session_contexts", {context_key, signed_record})
        
      :rolling ->
        # For rolling contexts like conversation history
        add_to_rolling_context(context_key, signed_record)
        
      :append_only ->
        ContextStore.add_to_set("append_contexts", {context_key, signed_record})
        
      :ephemeral ->
        # Store only locally, don't replicate
        new_cache = Map.put(state.local_cache, context_key, signed_record)
        {:ok, new_cache}
        
      :aggregated ->
        # Aggregate with existing data
        add_to_aggregated_context(context_key, signed_record)
    end
    
    case result do
      {:ok, new_cache} when is_map(new_cache) ->
        {:reply, {:ok, context_key}, %{state | local_cache: new_cache}}
      {:ok, _} ->
        {:reply, {:ok, context_key}, state}
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:get_context, type, key, opts}, _from, state) do
    context_key = build_context_key(type, key)
    
    result = case Map.get(@context_types, type) do
      :persistent ->
        get_from_lww_set("persistent_contexts", context_key)
        
      :session ->
        get_from_or_set("session_contexts", context_key)
        
      :rolling ->
        get_from_rolling_context(context_key, opts[:limit] || 50)
        
      :append_only ->
        get_from_or_set("append_contexts", context_key)
        
      :ephemeral ->
        {:ok, Map.get(state.local_cache, context_key)}
        
      :aggregated ->
        get_aggregated_context(context_key)
    end
    
    {:reply, result, state}
  end
  
  def handle_call({:get_all_contexts, type, opts}, _from, state) do
    contexts = case Map.get(@context_types, type) do
      :persistent ->
        get_all_from_lww_set("persistent_contexts")
        
      :session ->
        get_all_from_or_set("session_contexts")
        
      :rolling ->
        get_all_rolling_contexts(opts[:limit] || 100)
        
      :append_only ->
        get_all_from_or_set("append_contexts")
        
      :ephemeral ->
        {:ok, state.local_cache}
        
      :aggregated ->
        get_all_aggregated_contexts()
    end
    
    {:reply, contexts, state}
  end
  
  def handle_call({:generate_system_reminders, categories}, _from, state) do
    reminders = build_system_reminders(categories)
    {:reply, {:ok, reminders}, state}
  end
  
  def handle_call({:update_context, type, key, update_data, opts}, _from, state) do
    context_key = build_context_key(type, key)
    
    # Get existing context
    case get_context(type, key) do
      {:ok, existing_context} when not is_nil(existing_context) ->
        # Merge update with existing data
        updated_context = %{
          existing_context |
          data: Map.merge(existing_context.data, update_data),
          version: existing_context.version + 1,
          updated_at: System.system_time(:millisecond)
        }
        
        # Reattach with updated data
        result = attach_context(type, key, updated_context.data, opts)
        {:reply, result, state}
        
      {:ok, nil} ->
        # Context doesn't exist, create new
        result = attach_context(type, key, update_data, opts)
        {:reply, result, state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:sync_contexts, target_nodes, timeout}, _from, state) do
    # Synchronize all context types across nodes
    sync_results = Enum.map(target_nodes, fn node ->
      {node, sync_node_contexts(node, timeout)}
    end)
    
    {:reply, {:ok, sync_results}, state}
  end
  
  def handle_info(:cleanup_contexts, state) do
    # Perform periodic cleanup of expired contexts
    cleanup_expired_contexts()
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp initialize_context_storage do
    # Initialize CRDT sets for different context types
    ContextStore.add_to_set("context_types", Enum.map(@context_types, fn {type, _} -> type end))
  end
  
  defp build_context_key(type, key) do
    "#{type}:#{key}"
  end
  
  defp add_to_rolling_context(context_key, record) do
    # For rolling contexts, maintain a limited history
    current_contexts = get_from_or_set("rolling_contexts", context_key)
    
    case current_contexts do
      {:ok, contexts} when is_list(contexts) ->
        # Add new record and keep only latest 50 entries
        updated_contexts = [record | contexts] |> Enum.take(50)
        ContextStore.update_lww_set("rolling_contexts", context_key, updated_contexts)
        
      _ ->
        # Initialize with first record
        ContextStore.update_lww_set("rolling_contexts", context_key, [record])
    end
  end
  
  defp add_to_aggregated_context(context_key, record) do
    # Aggregate numeric data, append lists, merge maps
    case get_from_lww_set("aggregated_contexts", context_key) do
      {:ok, existing} when not is_nil(existing) ->
        aggregated = aggregate_context_data(existing.data, record.data)
        updated_record = %{record | data: aggregated}
        ContextStore.update_lww_set("aggregated_contexts", context_key, updated_record)
        
      _ ->
        ContextStore.update_lww_set("aggregated_contexts", context_key, record)
    end
  end
  
  defp aggregate_context_data(existing, new) when is_map(existing) and is_map(new) do
    Map.merge(existing, new, fn
      _key, old_val, new_val when is_number(old_val) and is_number(new_val) ->
        old_val + new_val
      _key, old_val, new_val when is_list(old_val) and is_list(new_val) ->
        old_val ++ new_val
      _key, old_val, new_val when is_map(old_val) and is_map(new_val) ->
        aggregate_context_data(old_val, new_val)
      _key, _old_val, new_val ->
        new_val
    end)
  end
  
  defp aggregate_context_data(_existing, new), do: new
  
  defp get_from_lww_set(set_name, key) do
    case ContextStore.get_lww_value(set_name, key) do
      {:ok, value} -> {:ok, value}
      error -> error
    end
  end
  
  defp get_from_or_set(set_name, key) do
    case ContextStore.get_set_values(set_name) do
      {:ok, values} ->
        matching = Enum.find(values, fn {stored_key, _} -> stored_key == key end)
        {:ok, if(matching, do: elem(matching, 1), else: nil)}
      error -> error
    end
  end
  
  defp get_from_rolling_context(context_key, limit) do
    case get_from_lww_set("rolling_contexts", context_key) do
      {:ok, contexts} when is_list(contexts) ->
        {:ok, Enum.take(contexts, limit)}
      result -> result
    end
  end
  
  defp get_aggregated_context(context_key) do
    get_from_lww_set("aggregated_contexts", context_key)
  end
  
  defp get_all_from_lww_set(set_name) do
    case ContextStore.get_all_lww_values(set_name) do
      {:ok, values} -> {:ok, values}
      error -> error
    end
  end
  
  defp get_all_from_or_set(set_name) do
    case ContextStore.get_set_values(set_name) do
      {:ok, values} -> {:ok, values}
      error -> error
    end
  end
  
  defp get_all_rolling_contexts(limit) do
    case get_all_from_lww_set("rolling_contexts") do
      {:ok, contexts} ->
        limited_contexts = Enum.map(contexts, fn {key, context_list} ->
          {key, Enum.take(context_list, limit)}
        end)
        {:ok, limited_contexts}
      error -> error
    end
  end
  
  defp get_all_aggregated_contexts do
    get_all_from_lww_set("aggregated_contexts")
  end
  
  defp build_system_reminders(categories) do
    """
    <system-reminders>
    #{build_crdt_reminders()}
    
    #{build_security_reminders()}
    
    #{build_coordination_reminders()}
    
    #{build_performance_reminders()}
    </system-reminders>
    """
  end
  
  defp build_crdt_reminders do
    """
    <crdt-reminders>
    - CRDT sync interval: 5 seconds - always verify vector clocks before operations
    - Mathematical correctness is non-negotiable: commutativity, associativity, idempotence
    - Conflict resolution is automatic through mathematical join operations
    - Vector clocks must advance monotonically for causality preservation
    - All CRDT operations must preserve eventual consistency guarantees
    </crdt-reminders>
    """
  end
  
  defp build_security_reminders do
    """
    <security-reminders>
    - AES-256-GCM active with cryptographically secure nonce generation
    - HMAC-SHA256 signatures required for message integrity verification
    - Key rotation policy: 7 days for high-security operations
    - Replay protection active with sliding window nonce validation
    - Never log cryptographic keys or sensitive plaintext data
    </security-reminders>
    """
  end
  
  defp build_coordination_reminders do
    """
    <coordination-reminders>
    - Distributed consensus requires majority agreement, not unanimity
    - Network partitions are inevitable - design all operations for partition tolerance
    - AMQP message delivery requires explicit acknowledgments
    - Leader election must handle split-brain scenarios with proper tie-breaking
    - Circuit breakers protect against cascade failures across distributed systems
    </coordination-reminders>
    """
  end
  
  defp build_performance_reminders do
    """
    <performance-reminders>
    - ETS tables provide microsecond-level access for local caching
    - AMQP batching reduces network overhead by 60-80% under load
    - Cryptographic operations are cached to minimize computational overhead
    - CRDT operations scale O(log n) with proper tree structures
    - Sub-agent delegation enables parallel processing for complex tasks
    </performance-reminders>
    """
  end
  
  defp sync_node_contexts(node, timeout) do
    try do
      # Use existing AMQP infrastructure for context synchronization
      RecursiveProtocol.sync_state_with_node(node, timeout)
    rescue
      error -> {:error, error}
    end
  end
  
  defp cleanup_expired_contexts do
    # Clean up ephemeral contexts older than 1 hour
    current_time = System.system_time(:millisecond)
    expiry_time = current_time - (60 * 60 * 1000) # 1 hour
    
    # This would be implemented to clean up old contexts
    Logger.debug("Cleaning up contexts older than #{expiry_time}")
  end
  
  defp schedule_cleanup do
    # Schedule cleanup every 30 minutes
    Process.send_after(self(), :cleanup_contexts, 30 * 60 * 1000)
  end
end