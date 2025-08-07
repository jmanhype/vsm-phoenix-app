defmodule VsmPhoenix.Infrastructure.CausalityTracker do
  @moduledoc """
  Event Causality Chain Tracking System
  
  Tracks parent-child relationships between events in the VSM system,
  enabling reconstruction of event lineages and calculation of chain depths.
  Uses ETS for high-performance event storage and retrieval.
  """
  
  use GenServer
  require Logger
  
  @table_name :vsm_event_causality
  @event_ttl 3_600_000  # 1 hour in milliseconds
  @cleanup_interval 300_000  # 5 minutes
  @max_chain_depth 100  # Maximum depth to prevent infinite loops
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Records a new event with optional parent reference
  """
  def track_event(event_id, parent_event_id \\ nil, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:track_event, event_id, parent_event_id, metadata})
  end
  
  @doc """
  Retrieves the complete lineage chain for an event
  """
  def get_event_lineage(event_id) do
    GenServer.call(__MODULE__, {:get_lineage, event_id})
  end
  
  @doc """
  Calculates the depth of an event's causality chain
  """
  def get_chain_depth(event_id) do
    GenServer.call(__MODULE__, {:get_chain_depth, event_id})
  end
  
  @doc """
  Gets all child events for a given parent
  """
  def get_child_events(parent_event_id) do
    GenServer.call(__MODULE__, {:get_children, parent_event_id})
  end
  
  @doc """
  Retrieves complete event information including causality data
  """
  def get_event_info(event_id) do
    GenServer.call(__MODULE__, {:get_event_info, event_id})
  end
  
  @doc """
  Generates a unique event ID
  """
  def generate_event_id do
    "EVT-#{System.system_time(:microsecond)}-#{:rand.uniform(999999)}"
  end
  
  @doc """
  Adds causality information to AMQP message
  """
  def add_causality_to_message(message, parent_event_id \\ nil) do
    event_id = generate_event_id()
    
    message
    |> Map.put("event_id", event_id)
    |> Map.put("parent_event_id", parent_event_id)
    |> Map.put("causality_timestamp", DateTime.utc_now() |> DateTime.to_iso8601())
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔗 Starting Causality Tracker...")
    
    # Create ETS table for event storage
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    # Subscribe to telemetry events
    :telemetry.attach_many(
      "causality-tracker",
      [
        [:vsm, :event, :created],
        [:vsm, :amqp, :message, :sent],
        [:vsm, :amqp, :message, :received]
      ],
      &handle_telemetry_event/4,
      nil
    )
    
    state = %{
      event_count: 0,
      chain_stats: %{
        max_depth: 0,
        average_depth: 0.0,
        total_chains: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:track_event, event_id, parent_event_id, metadata}, state) do
    timestamp = System.system_time(:millisecond)
    
    event_record = %{
      event_id: event_id,
      parent_event_id: parent_event_id,
      metadata: metadata,
      timestamp: timestamp,
      children: []
    }
    
    # Store event in ETS
    :ets.insert(@table_name, {event_id, event_record})
    
    # Update parent's children list if parent exists
    if parent_event_id do
      case :ets.lookup(@table_name, parent_event_id) do
        [{_, parent_record}] ->
          updated_parent = Map.update(parent_record, :children, [event_id], &[event_id | &1])
          :ets.insert(@table_name, {parent_event_id, updated_parent})
        _ ->
          # Parent doesn't exist, might have been cleaned up
          :ok
      end
    end
    
    # Update statistics
    new_state = %{state | event_count: state.event_count + 1}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get_lineage, event_id}, _from, state) do
    lineage = reconstruct_lineage(event_id)
    {:reply, {:ok, lineage}, state}
  end
  
  @impl true
  def handle_call({:get_chain_depth, event_id}, _from, state) do
    depth = calculate_chain_depth(event_id, 0)
    {:reply, {:ok, depth}, state}
  end
  
  @impl true
  def handle_call({:get_children, parent_event_id}, _from, state) do
    children = get_all_children(parent_event_id)
    {:reply, {:ok, children}, state}
  end
  
  @impl true
  def handle_call({:get_event_info, event_id}, _from, state) do
    case :ets.lookup(@table_name, event_id) do
      [{_, event_record}] ->
        # Add computed fields
        event_info = event_record
        |> Map.put(:chain_depth, calculate_chain_depth(event_id, 0))
        |> Map.put(:descendant_count, count_descendants(event_id))
        
        {:reply, {:ok, event_info}, state}
      [] ->
        {:reply, {:error, :event_not_found}, state}
    end
  end
  
  @impl true
  def handle_info(:cleanup_old_events, state) do
    current_time = System.system_time(:millisecond)
    cutoff_time = current_time - @event_ttl
    
    # Find and delete old events
    old_events = :ets.foldl(
      fn {event_id, event_record}, acc ->
        if event_record.timestamp < cutoff_time do
          [event_id | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    
    # Remove old events
    Enum.each(old_events, &:ets.delete(@table_name, &1))
    
    Logger.debug("🧹 Cleaned up #{length(old_events)} old events")
    
    # Update chain statistics
    new_stats = calculate_chain_statistics()
    new_state = %{state | chain_stats: new_stats}
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp reconstruct_lineage(event_id) do
    reconstruct_lineage(event_id, [], 0)
  end
  
  defp reconstruct_lineage(_event_id, acc, depth) when depth >= @max_chain_depth do
    # Prevent infinite loops
    Enum.reverse(acc)
  end
  
  defp reconstruct_lineage(event_id, acc, depth) do
    case :ets.lookup(@table_name, event_id) do
      [{_, event_record}] ->
        new_acc = [format_lineage_entry(event_record, depth) | acc]
        
        if event_record.parent_event_id do
          reconstruct_lineage(event_record.parent_event_id, new_acc, depth + 1)
        else
          Enum.reverse(new_acc)
        end
      [] ->
        Enum.reverse(acc)
    end
  end
  
  defp format_lineage_entry(event_record, depth) do
    %{
      event_id: event_record.event_id,
      depth: depth,
      timestamp: event_record.timestamp,
      metadata: event_record.metadata,
      child_count: length(event_record.children)
    }
  end
  
  defp calculate_chain_depth(event_id, current_depth) when current_depth >= @max_chain_depth do
    current_depth
  end
  
  defp calculate_chain_depth(event_id, current_depth) do
    case :ets.lookup(@table_name, event_id) do
      [{_, event_record}] ->
        if event_record.parent_event_id do
          calculate_chain_depth(event_record.parent_event_id, current_depth + 1)
        else
          current_depth
        end
      [] ->
        current_depth
    end
  end
  
  defp get_all_children(parent_event_id) do
    case :ets.lookup(@table_name, parent_event_id) do
      [{_, event_record}] ->
        # Get immediate children
        immediate_children = event_record.children
        
        # Recursively get all descendants
        all_descendants = immediate_children
        |> Enum.flat_map(fn child_id ->
          [child_id | get_all_children(child_id)]
        end)
        
        %{
          immediate: immediate_children,
          all_descendants: all_descendants,
          total_count: length(all_descendants)
        }
      [] ->
        %{immediate: [], all_descendants: [], total_count: 0}
    end
  end
  
  defp count_descendants(event_id) do
    case :ets.lookup(@table_name, event_id) do
      [{_, event_record}] ->
        event_record.children
        |> Enum.map(fn child_id -> 1 + count_descendants(child_id) end)
        |> Enum.sum()
      [] ->
        0
    end
  end
  
  defp calculate_chain_statistics do
    # Calculate statistics across all chains
    stats = :ets.foldl(
      fn {_event_id, event_record}, acc ->
        if event_record.parent_event_id == nil do
          # This is a root event
          depth = calculate_max_depth_from_root(event_record.event_id)
          
          %{
            max_depth: max(acc.max_depth, depth),
            total_depth: acc.total_depth + depth,
            chain_count: acc.chain_count + 1
          }
        else
          acc
        end
      end,
      %{max_depth: 0, total_depth: 0, chain_count: 0},
      @table_name
    )
    
    avg_depth = if stats.chain_count > 0 do
      stats.total_depth / stats.chain_count
    else
      0.0
    end
    
    %{
      max_depth: stats.max_depth,
      average_depth: Float.round(avg_depth, 2),
      total_chains: stats.chain_count
    }
  end
  
  defp calculate_max_depth_from_root(root_event_id) do
    case :ets.lookup(@table_name, root_event_id) do
      [{_, event_record}] ->
        if Enum.empty?(event_record.children) do
          0
        else
          event_record.children
          |> Enum.map(fn child_id -> 1 + calculate_max_depth_from_root(child_id) end)
          |> Enum.max()
        end
      [] ->
        0
    end
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_events, @cleanup_interval)
  end
  
  # Telemetry Integration
  
  def handle_telemetry_event([:vsm, :event, :created], measurements, metadata, _config) do
    event_id = metadata[:event_id] || generate_event_id()
    parent_id = metadata[:parent_event_id]
    
    track_event(event_id, parent_id, %{
      type: :vsm_event,
      measurements: measurements,
      metadata: metadata
    })
  end
  
  def handle_telemetry_event([:vsm, :amqp, :message, :sent], measurements, metadata, _config) do
    if metadata[:event_id] do
      track_event(metadata[:event_id], metadata[:parent_event_id], %{
        type: :amqp_sent,
        measurements: measurements,
        metadata: metadata
      })
    end
  end
  
  def handle_telemetry_event([:vsm, :amqp, :message, :received], measurements, metadata, _config) do
    if metadata[:event_id] do
      track_event(metadata[:event_id], metadata[:parent_event_id], %{
        type: :amqp_received,
        measurements: measurements,
        metadata: metadata
      })
    end
  end
  
  def handle_telemetry_event(_event_name, _measurements, _metadata, _config) do
    # Ignore other telemetry events
    :ok
  end
end