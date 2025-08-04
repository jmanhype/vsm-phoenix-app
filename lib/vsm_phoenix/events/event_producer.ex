defmodule VsmPhoenix.Events.EventProducer do
  @moduledoc """
  GenStage Producer for Broadway Event Processing Pipeline
  
  Produces events from:
  - Event Store subscriptions
  - Real-time Phoenix PubSub messages
  - External event sources (AMQP, WebSockets, etc.)
  - Scheduled event generation
  """
  
  use GenStage
  require Logger
  
  alias VsmPhoenix.Events.Store
  alias Broadway.Message
  
  @name __MODULE__
  @buffer_size 1000
  @poll_interval 100  # Poll every 100ms
  
  # Client API
  
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Manually inject an event into the pipeline
  """
  def inject_event(event, metadata \\ %{}) do
    GenStage.cast(@name, {:inject_event, event, metadata})
  end
  
  @doc """
  Subscribe to specific event streams
  """
  def subscribe_to_stream(stream_id) do
    GenStage.call(@name, {:subscribe_to_stream, stream_id})
  end
  
  # GenStage Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🎭 Starting Event Producer for Broadway pipeline")
    
    # Subscribe to event store notifications
    Store.subscribe_to_all(self())
    
    # Subscribe to Phoenix PubSub channels
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "events:all")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:events")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "algedonic:events")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "system:events")
    
    # Setup periodic event polling for external sources
    :timer.send_interval(@poll_interval, :poll_external_sources)
    
    state = %{
      demand: 0,
      events_buffer: :queue.new(),
      buffer_size: 0,
      subscribed_streams: MapSet.new(),
      metrics: %{
        total_produced: 0,
        events_per_second: 0,
        last_second_count: 0,
        last_second_timestamp: :erlang.system_time(:second)
      }
    }
    
    {:producer, state}
  end
  
  @impl true
  def handle_demand(incoming_demand, state) when incoming_demand > 0 do
    Logger.debug("📈 Event producer received demand: #{incoming_demand}")
    
    new_demand = state.demand + incoming_demand
    {events, new_state} = take_events_from_buffer(%{state | demand: new_demand})
    
    {:noreply, events, new_state}
  end
  
  @impl true
  def handle_cast({:inject_event, event, metadata}, state) do
    Logger.debug("💉 Injecting event: #{event.event_type}")
    
    message = create_broadway_message(event, metadata)
    new_state = add_event_to_buffer(message, state)
    
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_call({:subscribe_to_stream, stream_id}, _from, state) do
    Logger.info("📡 Subscribing to event stream: #{stream_id}")
    
    # Subscribe to the stream in event store
    Store.subscribe_to_stream(stream_id, self())
    
    # Add to subscribed streams
    new_subscribed = MapSet.put(state.subscribed_streams, stream_id)
    
    {:reply, :ok, [], %{state | subscribed_streams: new_subscribed}}
  end
  
  @impl true
  def handle_info({:event_appended, event}, state) do
    Logger.debug("📥 Received event from store: #{event.id}")
    
    message = create_broadway_message(event, %{source: :event_store})
    new_state = add_event_to_buffer(message, state)
    
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info({:stream_event_appended, stream_id, event}, state) do
    Logger.debug("📥 Received stream event: #{stream_id}/#{event.id}")
    
    message = create_broadway_message(event, %{
      source: :event_store,
      stream_id: stream_id
    })
    
    new_state = add_event_to_buffer(message, state)
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info({:vsm_event, event_type, data}, state) do
    Logger.debug("📥 Received VSM event: #{event_type}")
    
    # Create VSM event
    event = %VsmPhoenix.Events.Store.Event{
      id: UUID.uuid4(),
      stream_id: "vsm_live_events",
      stream_version: 0,
      event_type: event_type,
      event_data: data,
      metadata: %{source: :vsm_pubsub},
      timestamp: DateTime.utc_now()
    }
    
    message = create_broadway_message(event, %{source: :pubsub_vsm})
    new_state = add_event_to_buffer(message, state)
    
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info({:algedonic_event, pain_level, pleasure_level, context}, state) do
    Logger.debug("⚡ Received algedonic event: pain=#{pain_level}, pleasure=#{pleasure_level}")
    
    # Create algedonic event
    event = %VsmPhoenix.Events.Store.Event{
      id: UUID.uuid4(),
      stream_id: "algedonic_live_events",
      stream_version: 0,
      event_type: "algedonic.stimulus",
      event_data: %{
        pain_level: pain_level,
        pleasure_level: pleasure_level,
        context: context,
        urgency: max(pain_level, 1.0 - pleasure_level)
      },
      metadata: %{source: :algedonic_system},
      timestamp: DateTime.utc_now()
    }
    
    message = create_broadway_message(event, %{
      source: :pubsub_algedonic,
      priority: if(event.event_data.urgency > 0.8, do: :high, else: :normal)
    })
    
    new_state = add_event_to_buffer(message, state)
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info({:system_event, system, metric_name, value}, state) do
    Logger.debug("🖥️ Received system event: #{system}.#{metric_name} = #{value}")
    
    # Create system event
    event = %VsmPhoenix.Events.Store.Event{
      id: UUID.uuid4(),
      stream_id: "system_#{system}_events",
      stream_version: 0,
      event_type: "system.#{system}.#{metric_name}",
      event_data: %{
        system: system,
        metric: metric_name,
        value: value,
        threshold_exceeded: check_threshold(system, metric_name, value)
      },
      metadata: %{source: :system_monitoring},
      timestamp: DateTime.utc_now()
    }
    
    message = create_broadway_message(event, %{source: :pubsub_system})
    new_state = add_event_to_buffer(message, state)
    
    {events, final_state} = take_events_from_buffer(new_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info(:poll_external_sources, state) do
    # Poll external event sources
    external_events = poll_external_events()
    
    # Add external events to buffer
    new_state = Enum.reduce(external_events, state, fn event, acc_state ->
      message = create_broadway_message(event, %{source: :external})
      add_event_to_buffer(message, acc_state)
    end)
    
    # Update metrics
    updated_state = update_metrics(new_state)
    
    {events, final_state} = take_events_from_buffer(updated_state)
    
    {:noreply, events, final_state}
  end
  
  @impl true
  def handle_info(:update_metrics, state) do
    # Update events per second metric
    current_second = :erlang.system_time(:second)
    
    new_metrics = if current_second > state.metrics.last_second_timestamp do
      %{state.metrics |
        events_per_second: state.metrics.last_second_count,
        last_second_count: 0,
        last_second_timestamp: current_second
      }
    else
      state.metrics
    end
    
    # Log metrics every 10 seconds
    if rem(current_second, 10) == 0 do
      Logger.info("📊 Event Producer Metrics: #{new_metrics.events_per_second} events/sec, " <>
                  "#{new_metrics.total_produced} total, buffer: #{state.buffer_size}")
    end
    
    {:noreply, [], %{state | metrics: new_metrics}}
  end
  
  # Private Functions
  
  defp create_broadway_message(event, metadata) do
    %Message{
      data: %{event: event, metadata: Map.put(metadata, :received_at, :erlang.system_time(:millisecond))},
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end
  
  defp add_event_to_buffer(message, state) do
    if state.buffer_size >= @buffer_size do
      # Buffer full, drop oldest event
      {_dropped, new_queue} = :queue.out(state.events_buffer)
      new_queue = :queue.in(message, new_queue)
      
      Logger.warn("⚠️ Event buffer full, dropping oldest event")
      
      %{state | events_buffer: new_queue}
    else
      # Add to buffer
      new_queue = :queue.in(message, state.events_buffer)
      
      %{state | 
        events_buffer: new_queue,
        buffer_size: state.buffer_size + 1
      }
    end
  end
  
  defp take_events_from_buffer(state) do
    {events, new_queue, new_size} = take_events_recursive(
      state.events_buffer, 
      state.demand, 
      [], 
      state.buffer_size
    )
    
    # Update metrics
    new_metrics = %{state.metrics |
      total_produced: state.metrics.total_produced + length(events),
      last_second_count: state.metrics.last_second_count + length(events)
    }
    
    new_state = %{state |
      events_buffer: new_queue,
      buffer_size: new_size,
      demand: state.demand - length(events),
      metrics: new_metrics
    }
    
    {events, new_state}
  end
  
  defp take_events_recursive(queue, demand, acc, buffer_size) when demand > 0 and buffer_size > 0 do
    case :queue.out(queue) do
      {{:value, event}, new_queue} ->
        take_events_recursive(new_queue, demand - 1, [event | acc], buffer_size - 1)
      {:empty, new_queue} ->
        {Enum.reverse(acc), new_queue, buffer_size}
    end
  end
  
  defp take_events_recursive(queue, _demand, acc, buffer_size) do
    {Enum.reverse(acc), queue, buffer_size}
  end
  
  defp poll_external_events do
    # In a real implementation, this would poll:
    # - AMQP queues
    # - External APIs
    # - File system watchers
    # - Database change streams
    # - WebSocket connections
    
    # Generate some synthetic events for demonstration
    generate_synthetic_events()
  end
  
  defp generate_synthetic_events do
    # Generate 0-3 synthetic events per poll
    count = :rand.uniform(4) - 1
    
    for _i <- 1..count do
      event_types = [
        "variety.amplified",
        "variety.filtered", 
        "system1.operation.completed",
        "system2.coordination.adjusted",
        "system3.control.executed",
        "system4.intelligence.analyzed",
        "system5.policy.updated",
        "algedonic.pain.detected",
        "algedonic.pleasure.experienced",
        "recursion.meta_vsm.spawned"
      ]
      
      event_type = Enum.random(event_types)
      
      %VsmPhoenix.Events.Store.Event{
        id: UUID.uuid4(),
        stream_id: "synthetic_events",
        stream_version: 0,
        event_type: event_type,
        event_data: generate_synthetic_data(event_type),
        metadata: %{source: :synthetic, generated_at: DateTime.utc_now()},
        timestamp: DateTime.utc_now()
      }
    end
  end
  
  defp generate_synthetic_data(event_type) do
    case event_type do
      "variety." <> _ ->
        %{
          input_variety: :rand.uniform() * 100,
          output_variety: :rand.uniform() * 100,
          balance_ratio: :rand.uniform()
        }
        
      "system" <> _ ->
        %{
          performance_metric: :rand.uniform(),
          resource_usage: :rand.uniform() * 100,
          efficiency_score: :rand.uniform()
        }
        
      "algedonic." <> type ->
        intensity = :rand.uniform()
        %{
          intensity: intensity,
          context: "synthetic_#{type}",
          requires_action: intensity > 0.7
        }
        
      "recursion." <> _ ->
        %{
          depth_level: :rand.uniform(5),
          spawning_trigger: "complexity_threshold",
          meta_system_required: :rand.uniform() > 0.5
        }
        
      _ ->
        %{
          value: :rand.uniform() * 100,
          category: "general"
        }
    end
  end
  
  defp check_threshold(system, metric, value) do
    # Define some basic thresholds
    thresholds = %{
      "system1" => %{"cpu_usage" => 80.0, "memory_usage" => 90.0},
      "system2" => %{"coordination_lag" => 1000.0},
      "system3" => %{"control_effectiveness" => 0.7},
      "system4" => %{"analysis_accuracy" => 0.8},
      "system5" => %{"policy_compliance" => 0.9}
    }
    
    system_thresholds = Map.get(thresholds, system, %{})
    threshold = Map.get(system_thresholds, metric, :infinity)
    
    case threshold do
      :infinity -> false
      t when is_number(t) -> value > t
      _ -> false
    end
  end
  
  defp update_metrics(state) do
    # Schedule metrics update
    Process.send_after(self(), :update_metrics, 1000)
    state
  end
end

# UUID helper (reuse from Store)
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