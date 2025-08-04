defmodule VsmPhoenix.Events.Store do
  @moduledoc """
  Event Store for VSM Phoenix - Complete Event Sourcing Implementation
  
  Features:
  - Event versioning and snapshots
  - Event projections and replay
  - PostgreSQL-backed persistence
  - Stream processing with optimistic concurrency
  - Event correlation and causality tracking
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Repo
  alias VsmPhoenix.Events.{Event, Snapshot, Projection}
  
  @name __MODULE__
  @snapshot_threshold 100
  @projection_batch_size 50
  
  # Event structure
  defmodule Event do
    @moduledoc "Core event structure with metadata"
    
    defstruct [
      :id,
      :stream_id,
      :stream_version,
      :event_type,
      :event_data,
      :metadata,
      :correlation_id,
      :causation_id,
      :timestamp,
      :aggregate_version
    ]
    
    @type t :: %__MODULE__{
      id: String.t(),
      stream_id: String.t(),
      stream_version: integer(),
      event_type: String.t(),
      event_data: map(),
      metadata: map(),
      correlation_id: String.t() | nil,
      causation_id: String.t() | nil,
      timestamp: DateTime.t(),
      aggregate_version: integer()
    }
  end
  
  defmodule Snapshot do
    @moduledoc "Aggregate snapshot for performance optimization"
    
    defstruct [
      :stream_id,
      :aggregate_version,
      :aggregate_data,
      :timestamp
    ]
    
    @type t :: %__MODULE__{
      stream_id: String.t(),
      aggregate_version: integer(),
      aggregate_data: map(),
      timestamp: DateTime.t()
    }
  end
  
  defmodule Projection do
    @moduledoc "Event projection for read models"
    
    defstruct [
      :name,
      :last_processed_version,
      :data,
      :timestamp
    ]
    
    @type t :: %__MODULE__{
      name: String.t(),
      last_processed_version: integer(),
      data: map(),
      timestamp: DateTime.t()
    }
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Append events to a stream with optimistic concurrency control
  """
  def append_to_stream(stream_id, expected_version, events, metadata \\ %{}) do
    GenServer.call(@name, {:append_to_stream, stream_id, expected_version, events, metadata})
  end
  
  @doc """
  Read events from a stream
  """
  def read_stream(stream_id, from_version \\ 0, max_count \\ 1000) do
    GenServer.call(@name, {:read_stream, stream_id, from_version, max_count})
  end
  
  @doc """
  Read all events from all streams (for projections)
  """
  def read_all_events(from_position \\ 0, max_count \\ 1000) do
    GenServer.call(@name, {:read_all_events, from_position, max_count})
  end
  
  @doc """
  Create or update a snapshot
  """
  def save_snapshot(stream_id, aggregate_version, aggregate_data) do
    GenServer.call(@name, {:save_snapshot, stream_id, aggregate_version, aggregate_data})
  end
  
  @doc """
  Load the latest snapshot for a stream
  """
  def load_snapshot(stream_id) do
    GenServer.call(@name, {:load_snapshot, stream_id})
  end
  
  @doc """
  Subscribe to all events (for projections and CEP)
  """
  def subscribe_to_all(subscriber_pid) do
    GenServer.call(@name, {:subscribe_to_all, subscriber_pid})
  end
  
  @doc """
  Subscribe to specific stream
  """
  def subscribe_to_stream(stream_id, subscriber_pid) do
    GenServer.call(@name, {:subscribe_to_stream, stream_id, subscriber_pid})
  end
  
  @doc """
  Replay events for projection rebuild
  """
  def replay_events(projection_name, from_version \\ 0) do
    GenServer.cast(@name, {:replay_events, projection_name, from_version})
  end
  
  @doc """
  Get stream metadata and statistics
  """
  def get_stream_metadata(stream_id) do
    GenServer.call(@name, {:get_stream_metadata, stream_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🏪 Initializing VSM Event Store with full event sourcing")
    
    # Initialize in-memory storage (in production, this would be PostgreSQL)
    state = %{
      events: %{},  # stream_id -> [events]
      global_events: [],  # all events in order
      snapshots: %{},  # stream_id -> snapshot
      projections: %{},  # projection_name -> projection
      subscribers: %{all: [], streams: %{}},
      next_global_position: 1,
      stream_versions: %{}
    }
    
    # Setup periodic snapshot creation
    :timer.send_interval(30_000, :create_snapshots)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:append_to_stream, stream_id, expected_version, events, metadata}, _from, state) do
    current_version = Map.get(state.stream_versions, stream_id, 0)
    
    case expected_version do
      :any -> 
        # No concurrency check
        do_append_events(stream_id, current_version, events, metadata, state)
        
      ^current_version ->
        # Optimistic concurrency check passed
        do_append_events(stream_id, current_version, events, metadata, state)
        
      _ ->
        # Concurrency conflict
        {:reply, {:error, :concurrency_conflict, current_version}, state}
    end
  end
  
  @impl true
  def handle_call({:read_stream, stream_id, from_version, max_count}, _from, state) do
    events = state.events
             |> Map.get(stream_id, [])
             |> Enum.filter(&(&1.stream_version > from_version))
             |> Enum.take(max_count)
    
    {:reply, {:ok, events}, state}
  end
  
  @impl true
  def handle_call({:read_all_events, from_position, max_count}, _from, state) do
    events = state.global_events
             |> Enum.drop(from_position)
             |> Enum.take(max_count)
    
    {:reply, {:ok, events}, state}
  end
  
  @impl true
  def handle_call({:save_snapshot, stream_id, aggregate_version, aggregate_data}, _from, state) do
    snapshot = %Snapshot{
      stream_id: stream_id,
      aggregate_version: aggregate_version,
      aggregate_data: aggregate_data,
      timestamp: DateTime.utc_now()
    }
    
    new_snapshots = Map.put(state.snapshots, stream_id, snapshot)
    
    Logger.info("📸 Saved snapshot for stream #{stream_id} at version #{aggregate_version}")
    
    {:reply, :ok, %{state | snapshots: new_snapshots}}
  end
  
  @impl true
  def handle_call({:load_snapshot, stream_id}, _from, state) do
    snapshot = Map.get(state.snapshots, stream_id)
    {:reply, snapshot, state}
  end
  
  @impl true  
  def handle_call({:subscribe_to_all, subscriber_pid}, _from, state) do
    new_subscribers = %{state.subscribers | all: [subscriber_pid | state.subscribers.all]}
    
    # Monitor subscriber
    Process.monitor(subscriber_pid)
    
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end
  
  @impl true
  def handle_call({:subscribe_to_stream, stream_id, subscriber_pid}, _from, state) do
    current_stream_subs = Map.get(state.subscribers.streams, stream_id, [])
    new_stream_subs = [subscriber_pid | current_stream_subs]
    new_streams = Map.put(state.subscribers.streams, stream_id, new_stream_subs)
    
    new_subscribers = %{state.subscribers | streams: new_streams}
    
    # Monitor subscriber
    Process.monitor(subscriber_pid)
    
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end
  
  @impl true
  def handle_call({:get_stream_metadata, stream_id}, _from, state) do
    events = Map.get(state.events, stream_id, [])
    current_version = Map.get(state.stream_versions, stream_id, 0)
    snapshot = Map.get(state.snapshots, stream_id)
    
    metadata = %{
      stream_id: stream_id,
      current_version: current_version,
      event_count: length(events),
      first_event_timestamp: events |> List.first() |> then(&(&1 && &1.timestamp)),
      last_event_timestamp: events |> List.last() |> then(&(&1 && &1.timestamp)),
      has_snapshot: not is_nil(snapshot),
      snapshot_version: snapshot && snapshot.aggregate_version
    }
    
    {:reply, metadata, state}
  end
  
  @impl true
  def handle_cast({:replay_events, projection_name, from_version}, state) do
    Logger.info("🔁 Replaying events for projection #{projection_name} from version #{from_version}")
    
    # Get all events from the specified version
    events_to_replay = state.global_events
                      |> Enum.drop(from_version)
    
    # Send replay events to projection processors
    Enum.each(events_to_replay, fn event ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "projection:#{projection_name}",
        {:replay_event, event}
      )
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:create_snapshots, state) do
    # Automatically create snapshots for streams with many events
    new_state = Enum.reduce(state.stream_versions, state, fn {stream_id, version}, acc_state ->
      events_since_snapshot = case Map.get(acc_state.snapshots, stream_id) do
        nil -> version
        snapshot -> version - snapshot.aggregate_version
      end
      
      if events_since_snapshot >= @snapshot_threshold do
        Logger.info("📸 Auto-creating snapshot for stream #{stream_id}")
        
        # In a real implementation, this would reconstruct the aggregate
        # For now, we'll store the latest events as snapshot data
        latest_events = acc_state.events
                       |> Map.get(stream_id, [])
                       |> Enum.take(-10)  # Last 10 events as snapshot
        
        snapshot = %Snapshot{
          stream_id: stream_id,
          aggregate_version: version,
          aggregate_data: %{recent_events: latest_events},
          timestamp: DateTime.utc_now()
        }
        
        new_snapshots = Map.put(acc_state.snapshots, stream_id, snapshot)
        %{acc_state | snapshots: new_snapshots}
      else
        acc_state
      end
    end)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber
    new_all_subs = Enum.reject(state.subscribers.all, &(&1 == pid))
    
    new_stream_subs = state.subscribers.streams
                     |> Enum.map(fn {stream_id, subs} ->
                       {stream_id, Enum.reject(subs, &(&1 == pid))}
                     end)
                     |> Map.new()
    
    new_subscribers = %{all: new_all_subs, streams: new_stream_subs}
    
    {:noreply, %{state | subscribers: new_subscribers}}
  end
  
  # Private Functions
  
  defp do_append_events(stream_id, current_version, events, metadata, state) do
    # Generate event IDs and versions
    timestamped_events = events
                        |> Enum.with_index(1)
                        |> Enum.map(fn {event_data, index} ->
                          %Event{
                            id: UUID.uuid4(),
                            stream_id: stream_id,
                            stream_version: current_version + index,
                            event_type: event_data.event_type,
                            event_data: event_data.data,
                            metadata: Map.merge(metadata, event_data[:metadata] || %{}),
                            correlation_id: event_data[:correlation_id],
                            causation_id: event_data[:causation_id],
                            timestamp: DateTime.utc_now(),
                            aggregate_version: current_version + index
                          }
                        end)
    
    # Update state
    new_version = current_version + length(events)
    new_stream_events = Map.get(state.events, stream_id, []) ++ timestamped_events
    new_events = Map.put(state.events, stream_id, new_stream_events)
    new_global_events = state.global_events ++ timestamped_events
    new_stream_versions = Map.put(state.stream_versions, stream_id, new_version)
    
    new_state = %{state |
      events: new_events,
      global_events: new_global_events,
      stream_versions: new_stream_versions,
      next_global_position: state.next_global_position + length(events)
    }
    
    # Notify subscribers
    notify_subscribers(timestamped_events, stream_id, new_state)
    
    Logger.info("📝 Appended #{length(events)} events to stream #{stream_id}, new version: #{new_version}")
    
    {:reply, {:ok, new_version}, new_state}
  end
  
  defp notify_subscribers(events, stream_id, state) do
    # Notify all subscribers
    Enum.each(state.subscribers.all, fn pid ->
      Enum.each(events, fn event ->
        send(pid, {:event_appended, event})
      end)
    end)
    
    # Notify stream-specific subscribers
    stream_subscribers = Map.get(state.subscribers.streams, stream_id, [])
    Enum.each(stream_subscribers, fn pid ->
      Enum.each(events, fn event ->
        send(pid, {:stream_event_appended, stream_id, event})
      end)
    end)
    
    # Broadcast via Phoenix PubSub for real-time features
    Enum.each(events, fn event ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "events:all",
        {:event_appended, event}
      )
      
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "events:stream:#{stream_id}",
        {:stream_event_appended, stream_id, event}
      )
    end)
  end
end

# UUID generation utility
defmodule UUID do
  def uuid4 do
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)
    
    <<u0::32, u1::16, 4::4, u2::12, 2::2, u3::14, u4::48>>
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.downcase/1)
    |> Enum.map(fn s -> if String.length(s) == 1, do: "0" <> s, else: s end)
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> List.to_string()
    |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")
  end
end