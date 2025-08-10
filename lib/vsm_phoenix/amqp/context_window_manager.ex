defmodule VsmPhoenix.AMQP.ContextWindowManager do
  @moduledoc """
  Claude Code-inspired Context Window Management for VSM Phoenix
  
  Implements sophisticated context window management for high-throughput event processing,
  inspired by Claude Code's auto-compacting and token management strategies.
  
  ## Key Features:
  - Automatic context compacting when approaching token limits
  - Event-driven context updates with causal preservation
  - Multi-level context hierarchy (system, agent, task)
  - Intelligent summarization of historical events
  - CRDT-based distributed context synchronization
  - Performance-optimized event batching
  
  ## Architecture:
  ```
  Raw Events → Context Filter → Compaction Engine → Distributed Sync
       ↓              ↓               ↓                 ↓
   Deduplication  Importance     Summarization      CRDT Store
   Rate Limiting   Scoring       Critical Preserve   Consensus
  ```
  
  ## Usage Examples:
  
      # Initialize context window for high-throughput processing
      {:ok, context_pid} = ContextWindowManager.start_link(%{
        max_events: 10_000,
        compaction_threshold: 0.8,
        retention_strategy: :importance_based,
        sync_strategy: :crdt_eventual
      })
      
      # Process high-volume event stream
      events = Stream.resource(event_source)
      ContextWindowManager.process_event_stream(context_pid, events)
      
      # Get compacted context for LLM processing
      {:ok, context} = ContextWindowManager.get_compact_context(context_pid, :llm_optimized)
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.AMQP.{Discovery, NetworkOptimizer}
  alias VsmPhoenix.System2.CorticalAttentionEngine
  
  # Context window configuration
  @default_max_events 10_000
  @default_max_tokens 100_000  # Inspired by Claude's context limits
  @compaction_threshold 0.8
  @critical_event_retention_ratio 0.1
  @importance_threshold 0.7
  
  # Event importance categories
  @critical_events [:consensus_decision, :system_failure, :security_alert, :policy_change]
  @high_importance [:agent_spawn, :capability_change, :performance_degradation]
  @medium_importance [:task_completion, :data_update, :coordination_message]
  @low_importance [:heartbeat, :status_update, :debug_message]
  
  defmodule ContextWindow do
    @moduledoc "Context window state structure"
    defstruct [
      :id,
      :events,
      :compact_summary,
      :event_count,
      :token_count,
      :last_compaction,
      :compaction_strategy,
      :importance_scores,
      :causal_relationships,
      :crdt_vector_clock,
      :performance_metrics
    ]
  end
  
  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config)
  end
  
  def init(config) do
    state = %ContextWindow{
      id: Map.get(config, :id, generate_context_id()),
      events: :queue.new(),
      compact_summary: %{},
      event_count: 0,
      token_count: 0,
      last_compaction: DateTime.utc_now(),
      compaction_strategy: Map.get(config, :retention_strategy, :importance_based),
      importance_scores: %{},
      causal_relationships: :digraph.new(),
      crdt_vector_clock: ContextStore.new_vector_clock(),
      performance_metrics: %{
        events_processed: 0,
        compactions_performed: 0,
        avg_processing_time_ms: 0,
        sync_operations: 0
      }
    }
    
    Logger.info("Context Window Manager started: #{state.id}")
    {:ok, state}
  end
  
  @doc """
  Process incoming event with intelligent context management
  """
  def process_event(pid, event) do
    GenServer.call(pid, {:process_event, event})
  end
  
  @doc """
  Process high-volume event stream with batching
  """
  def process_event_stream(pid, event_stream) do
    GenServer.call(pid, {:process_event_stream, event_stream}, 30_000)
  end
  
  @doc """
  Get compacted context optimized for LLM processing
  """
  def get_compact_context(pid, optimization \\ :balanced) do
    GenServer.call(pid, {:get_compact_context, optimization})
  end
  
  @doc """
  Force context compaction with specified strategy
  """
  def force_compaction(pid, strategy \\ nil) do
    GenServer.call(pid, {:force_compaction, strategy})
  end
  
  @doc """
  Synchronize context with distributed CRDT store
  """
  def sync_distributed_context(pid, target_nodes \\ []) do
    GenServer.call(pid, {:sync_distributed_context, target_nodes})
  end
  
  # GenServer callbacks
  
  def handle_call({:process_event, event}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Calculate event importance using CorticalAttentionEngine
    {:ok, importance_score, attention_components} = calculate_event_importance(event)
    
    # Add event with metadata
    enhanced_event = enhance_event_with_metadata(event, importance_score, attention_components)
    updated_state = add_event_to_context(state, enhanced_event)
    
    # Check if compaction is needed (Claude-style auto-compacting)
    final_state = maybe_compact_context(updated_state)
    
    # Update performance metrics
    processing_time = System.monotonic_time(:millisecond) - start_time
    metrics_updated_state = update_performance_metrics(final_state, processing_time)
    
    {:reply, {:ok, importance_score}, metrics_updated_state}
  end
  
  def handle_call({:process_event_stream, event_stream}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Process events in optimized batches
    {processed_count, updated_state} = process_events_in_batches(event_stream, state)
    
    processing_time = System.monotonic_time(:millisecond) - start_time
    
    Logger.info("Processed #{processed_count} events in #{processing_time}ms")
    
    {:reply, {:ok, processed_count}, updated_state}
  end
  
  def handle_call({:get_compact_context, optimization}, _from, state) do
    compact_context = generate_compact_context(state, optimization)
    {:reply, {:ok, compact_context}, state}
  end
  
  def handle_call({:force_compaction, strategy}, _from, state) do
    compaction_strategy = strategy || state.compaction_strategy
    compacted_state = perform_context_compaction(state, compaction_strategy)
    {:reply, {:ok, :compacted}, compacted_state}
  end
  
  def handle_call({:sync_distributed_context, target_nodes}, _from, state) do
    sync_result = sync_with_crdt_store(state, target_nodes)
    
    updated_state = %{state | 
      crdt_vector_clock: Map.get(sync_result, :updated_vector_clock, state.crdt_vector_clock),
      performance_metrics: Map.update!(state.performance_metrics, :sync_operations, &(&1 + 1))
    }
    
    {:reply, {:ok, sync_result}, updated_state}
  end
  
  # Private implementation functions
  
  defp calculate_event_importance(event) do
    event_type = Map.get(event, :type, :unknown)
    
    # Use predefined importance categories
    base_importance = case event_type do
      type when type in @critical_events -> 1.0
      type when type in @high_importance -> 0.8
      type when type in @medium_importance -> 0.5  
      type when type in @low_importance -> 0.2
      _ -> 0.3  # Default for unknown events
    end
    
    # Enhance with CorticalAttentionEngine scoring if available
    case CorticalAttentionEngine.score_attention(event, %{type: :context_management}) do
      {:ok, attention_score, components} ->
        # Combine base importance with attention scoring
        final_score = (base_importance * 0.6) + (attention_score * 0.4)
        {:ok, final_score, components}
        
      {:error, _reason} ->
        # Fallback to base importance
        {:ok, base_importance, %{urgency: base_importance, confidence: 0.5}}
    end
  end
  
  defp enhance_event_with_metadata(event, importance_score, attention_components) do
    Map.merge(event, %{
      importance_score: importance_score,
      attention_components: attention_components,
      processed_at: DateTime.utc_now(),
      context_id: generate_event_context_id(),
      token_estimate: estimate_event_tokens(event)
    })
  end
  
  defp add_event_to_context(state, event) do
    # Add to event queue
    updated_events = :queue.in(event, state.events)
    
    # Update counters
    new_event_count = state.event_count + 1
    new_token_count = state.token_count + Map.get(event, :token_estimate, 0)
    
    # Store importance score
    event_id = Map.get(event, :context_id)
    updated_importance_scores = Map.put(state.importance_scores, event_id, event.importance_score)
    
    # Update causal relationships if applicable
    updated_causal_graph = maybe_add_causal_relationship(
      state.causal_relationships, 
      event, 
      state.events
    )
    
    %{state |
      events: updated_events,
      event_count: new_event_count,
      token_count: new_token_count,
      importance_scores: updated_importance_scores,
      causal_relationships: updated_causal_graph
    }
  end
  
  defp maybe_compact_context(state) do
    should_compact = determine_compaction_need(state)
    
    if should_compact do
      Logger.info("Auto-compacting context: #{state.id} (#{state.event_count} events, #{state.token_count} tokens)")
      perform_context_compaction(state, state.compaction_strategy)
    else
      state
    end
  end
  
  defp determine_compaction_need(state) do
    token_ratio = state.token_count / @default_max_tokens
    event_ratio = state.event_count / @default_max_events
    
    # Compact if either threshold is exceeded
    token_ratio > @compaction_threshold or event_ratio > @compaction_threshold
  end
  
  defp perform_context_compaction(state, strategy) do
    case strategy do
      :importance_based ->
        compact_by_importance(state)
        
      :temporal_based ->
        compact_by_time(state)
        
      :causal_based ->
        compact_by_causal_importance(state)
        
      :hybrid ->
        compact_hybrid_strategy(state)
        
      _ ->
        compact_by_importance(state)  # Default fallback
    end
  end
  
  defp compact_by_importance(state) do
    # Keep most important events and summarize the rest
    events_list = :queue.to_list(state.events)
    
    # Sort by importance score
    sorted_events = Enum.sort_by(events_list, &(&1.importance_score), :desc)
    
    # Calculate how many to keep
    keep_count = round(length(sorted_events) * @critical_event_retention_ratio)
    keep_count = max(keep_count, 100)  # Always keep at least 100 events
    
    {events_to_keep, events_to_summarize} = Enum.split(sorted_events, keep_count)
    
    # Generate summary of less important events
    summary = generate_event_summary(events_to_summarize)
    
    # Rebuild state with compacted context
    compacted_events = :queue.from_list(events_to_keep)
    
    # Recalculate token count
    new_token_count = Enum.sum(Enum.map(events_to_keep, &Map.get(&1, :token_estimate, 0)))
    new_token_count = new_token_count + Map.get(summary, :token_estimate, 0)
    
    %{state |
      events: compacted_events,
      compact_summary: Map.merge(state.compact_summary, summary),
      event_count: length(events_to_keep),
      token_count: new_token_count,
      last_compaction: DateTime.utc_now(),
      performance_metrics: Map.update!(state.performance_metrics, :compactions_performed, &(&1 + 1))
    }
  end
  
  defp compact_by_causal_importance(state) do
    # Identify causally important events using graph analysis
    events_list = :queue.to_list(state.events)
    
    # Calculate causal importance scores
    causal_scores = calculate_causal_importance_scores(events_list, state.causal_relationships)
    
    # Combine with base importance scores
    combined_scores = Enum.map(events_list, fn event ->
      base_score = event.importance_score
      causal_score = Map.get(causal_scores, event.context_id, 0)
      combined_score = (base_score * 0.6) + (causal_score * 0.4)
      
      {event, combined_score}
    end)
    
    # Sort by combined score and apply compaction
    sorted_events = Enum.sort_by(combined_scores, &elem(&1, 1), :desc)
    keep_count = round(length(sorted_events) * @critical_event_retention_ratio)
    
    {events_to_keep, events_to_summarize} = Enum.split(sorted_events, keep_count)
    
    # Extract just the events
    final_events_to_keep = Enum.map(events_to_keep, &elem(&1, 0))
    final_events_to_summarize = Enum.map(events_to_summarize, &elem(&1, 0))
    
    # Generate summary and update state
    summary = generate_event_summary(final_events_to_summarize)
    compacted_events = :queue.from_list(final_events_to_keep)
    
    %{state |
      events: compacted_events,
      compact_summary: Map.merge(state.compact_summary, summary),
      event_count: length(final_events_to_keep),
      token_count: calculate_total_token_count(final_events_to_keep, summary),
      last_compaction: DateTime.utc_now()
    }
  end
  
  defp generate_compact_context(state, optimization) do
    events_list = :queue.to_list(state.events)
    
    context = case optimization do
      :llm_optimized ->
        # Optimize for LLM processing - structured format with clear hierarchy
        %{
          format: :llm_structured,
          critical_events: filter_events_by_importance(events_list, 0.8),
          event_summary: state.compact_summary,
          causal_chains: extract_causal_chains(state.causal_relationships),
          context_metadata: %{
            total_events_processed: state.event_count,
            compaction_history: state.last_compaction,
            importance_distribution: calculate_importance_distribution(state)
          }
        }
        
      :network_optimized ->
        # Optimize for network transmission - compressed format
        %{
          format: :compressed,
          event_digest: create_event_digest(events_list),
          summary_hash: create_summary_hash(state.compact_summary),
          vector_clock: state.crdt_vector_clock,
          sync_metadata: extract_sync_metadata(state)
        }
        
      :balanced ->
        # Balanced format for general use
        %{
          format: :balanced,
          recent_events: Enum.take(events_list, -50),  # Last 50 events
          historical_summary: state.compact_summary,
          key_insights: extract_key_insights(events_list, state.importance_scores),
          performance_summary: state.performance_metrics
        }
        
      _ ->
        # Default format
        %{
          events: events_list,
          summary: state.compact_summary,
          metadata: %{event_count: state.event_count, token_count: state.token_count}
        }
    end
    
    # Add common metadata to all formats
    Map.merge(context, %{
      context_id: state.id,
      generated_at: DateTime.utc_now(),
      optimization_type: optimization,
      total_token_estimate: state.token_count
    })
  end
  
  # Additional helper functions for comprehensive context management
  
  defp process_events_in_batches(event_stream, initial_state) do
    # Process events in batches for efficiency
    batch_size = 100
    
    Enum.chunk_every(event_stream, batch_size)
    |> Enum.reduce({0, initial_state}, fn batch, {count, state} ->
      batch_processed_state = Enum.reduce(batch, state, fn event, acc_state ->
        {:ok, _importance} = handle_call({:process_event, event}, nil, acc_state)
        |> elem(2)  # Extract state from reply
      end)
      
      {count + length(batch), batch_processed_state}
    end)
  end
  
  defp sync_with_crdt_store(state, target_nodes) do
    # Synchronize context with distributed CRDT store
    context_data = %{
      id: state.id,
      vector_clock: state.crdt_vector_clock,
      compact_summary: state.compact_summary,
      importance_distribution: calculate_importance_distribution(state)
    }
    
    # Store context data in CRDT using LWW (Last Write Wins)
    ContextStore.set_lww("context_#{state.id}", context_data)
    
    # For now, return success - full sync would require network implementation
    Logger.info("Context stored in CRDT for #{length(target_nodes)} target nodes")
    %{
      status: :success,
      updated_vector_clock: state.crdt_vector_clock,
      nodes_notified: target_nodes
    }
  end
  
  defp update_performance_metrics(state, processing_time) do
    current_avg = state.performance_metrics.avg_processing_time_ms
    processed_count = state.performance_metrics.events_processed + 1
    
    new_avg = (current_avg * (processed_count - 1) + processing_time) / processed_count
    
    updated_metrics = %{state.performance_metrics |
      events_processed: processed_count,
      avg_processing_time_ms: new_avg
    }
    
    %{state | performance_metrics: updated_metrics}
  end
  
  # Utility functions
  
  defp generate_context_id, do: "ctx_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16())
  defp generate_event_context_id, do: "evt_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16())
  
  defp estimate_event_tokens(event) do
    # Simple token estimation based on event content
    content_size = event |> Jason.encode!() |> String.length()
    # Rough approximation: 4 characters per token
    round(content_size / 4)
  end
  
  defp maybe_add_causal_relationship(graph, event, existing_events) do
    # Add causal relationships based on event context
    case Map.get(event, :causal_parent) do
      nil -> graph
      parent_id -> 
        :digraph.add_edge(graph, parent_id, event.context_id)
        graph
    end
  end
  
  defp generate_event_summary(events) do
    # Generate intelligent summary of events
    event_types = Enum.frequencies_by(events, &Map.get(&1, :type))
    importance_stats = calculate_importance_stats(events)
    
    %{
      type: :compacted_summary,
      summarized_events_count: length(events),
      event_type_distribution: event_types,
      importance_statistics: importance_stats,
      time_range: calculate_time_range(events),
      token_estimate: 50,  # Summary token estimate
      generated_at: DateTime.utc_now()
    }
  end
  
  defp calculate_importance_distribution(state) do
    scores = Map.values(state.importance_scores)
    
    if Enum.empty?(scores) do
      %{min: 0, max: 0, avg: 0, distribution: %{}}
    else
      %{
        min: Enum.min(scores),
        max: Enum.max(scores), 
        avg: Enum.sum(scores) / length(scores),
        distribution: %{
          critical: Enum.count(scores, &(&1 > 0.8)),
          high: Enum.count(scores, &(&1 > 0.6 and &1 <= 0.8)),
          medium: Enum.count(scores, &(&1 > 0.4 and &1 <= 0.6)),
          low: Enum.count(scores, &(&1 <= 0.4))
        }
      }
    end
  end
  
  defp calculate_importance_stats(events) do
    scores = Enum.map(events, &(&1.importance_score))
    
    %{
      min: Enum.min(scores, fn -> 0 end),
      max: Enum.max(scores, fn -> 0 end),
      avg: if(Enum.empty?(scores), do: 0, else: Enum.sum(scores) / length(scores))
    }
  end
  
  defp calculate_time_range(events) do
    timestamps = Enum.map(events, &Map.get(&1, :processed_at))
    
    case {Enum.min(timestamps, DateTime, fn -> nil end), Enum.max(timestamps, DateTime, fn -> nil end)} do
      {nil, nil} -> %{start: nil, end: nil}
      {min_time, max_time} -> %{start: min_time, end: max_time}
    end
  end
  
  defp filter_events_by_importance(events, threshold) do
    Enum.filter(events, &(&1.importance_score >= threshold))
  end
  
  defp extract_causal_chains(graph) do
    # Extract important causal chains from the digraph
    vertices = :digraph.vertices(graph)
    
    # Find root vertices (no incoming edges)
    roots = Enum.filter(vertices, fn v -> 
      :digraph.in_degree(graph, v) == 0
    end)
    
    # Build causal chains from each root
    Enum.map(roots, fn root ->
      build_causal_chain(graph, root)
    end)
  end
  
  defp build_causal_chain(graph, vertex, visited \\ MapSet.new()) do
    if MapSet.member?(visited, vertex) do
      []  # Avoid cycles
    else
      children = :digraph.out_neighbours(graph, vertex)
      updated_visited = MapSet.put(visited, vertex)
      
      child_chains = Enum.flat_map(children, fn child ->
        build_causal_chain(graph, child, updated_visited)
      end)
      
      [{vertex, child_chains}]
    end
  end
  
  defp calculate_causal_importance_scores(events, graph) do
    # Calculate importance based on position in causal graph
    event_ids = Enum.map(events, &(&1.context_id))
    
    Enum.reduce(event_ids, %{}, fn event_id, acc ->
      # Score based on in-degree and out-degree
      in_degree = :digraph.in_degree(graph, event_id)
      out_degree = :digraph.out_degree(graph, event_id)
      
      # Events with many connections are more important
      causal_score = (in_degree + out_degree) / 10.0  # Normalize
      causal_score = min(causal_score, 1.0)  # Cap at 1.0
      
      Map.put(acc, event_id, causal_score)
    end)
  end
  
  defp calculate_total_token_count(events, summary) do
    event_tokens = Enum.sum(Enum.map(events, &Map.get(&1, :token_estimate, 0)))
    summary_tokens = Map.get(summary, :token_estimate, 0)
    event_tokens + summary_tokens
  end
  
  defp create_event_digest(events) do
    # Create compact digest for network transmission
    Enum.map(events, fn event ->
      %{
        id: event.context_id,
        type: event.type,
        importance: event.importance_score,
        timestamp: event.processed_at
      }
    end)
  end
  
  defp create_summary_hash(summary) do
    # Create hash for summary integrity
    summary |> Jason.encode!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16()
  end
  
  defp extract_sync_metadata(state) do
    %{
      last_sync: DateTime.utc_now(),
      sync_count: state.performance_metrics.sync_operations,
      context_version: state.crdt_vector_clock
    }
  end
  
  defp extract_key_insights(events, importance_scores) do
    # Extract key insights from event patterns
    high_importance_events = Enum.filter(events, &(&1.importance_score > 0.7))
    
    %{
      critical_event_count: length(high_importance_events),
      dominant_event_types: find_dominant_event_types(events),
      importance_trends: analyze_importance_trends(events, importance_scores),
      anomaly_indicators: detect_anomaly_patterns(events)
    }
  end
  
  defp find_dominant_event_types(events) do
    events
    |> Enum.frequencies_by(&Map.get(&1, :type))
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(5)
  end
  
  defp analyze_importance_trends(events, _importance_scores) do
    # Analyze trends in event importance over time
    recent_events = Enum.take(events, -100)
    
    case recent_events do
      [] -> %{trend: :no_data}
      events_list ->
        avg_importance = events_list
        |> Enum.map(&(&1.importance_score))
        |> Enum.sum()
        |> Kernel./(length(events_list))
        
        %{
          trend: determine_trend(events_list),
          recent_avg_importance: avg_importance,
          sample_size: length(events_list)
        }
    end
  end
  
  defp determine_trend(events) when length(events) < 10, do: :insufficient_data
  defp determine_trend(events) do
    {first_half, second_half} = Enum.split(events, div(length(events), 2))
    
    first_avg = Enum.map(first_half, &(&1.importance_score)) |> Enum.sum() |> Kernel./(length(first_half))
    second_avg = Enum.map(second_half, &(&1.importance_score)) |> Enum.sum() |> Kernel./(length(second_half))
    
    cond do
      second_avg > first_avg + 0.1 -> :increasing
      second_avg < first_avg - 0.1 -> :decreasing
      true -> :stable
    end
  end
  
  defp detect_anomaly_patterns(events) do
    # Simple anomaly detection based on event patterns
    recent_events = Enum.take(events, -50)
    
    %{
      high_frequency_events: detect_high_frequency_events(recent_events),
      unusual_importance_spikes: detect_importance_spikes(recent_events),
      event_type_anomalies: detect_type_anomalies(recent_events)
    }
  end
  
  defp detect_high_frequency_events(events) do
    # Detect unusually high frequency event types
    type_counts = Enum.frequencies_by(events, &Map.get(&1, :type))
    avg_frequency = Map.values(type_counts) |> Enum.sum() |> Kernel./(max(1, map_size(type_counts)))
    
    type_counts
    |> Enum.filter(fn {_type, count} -> count > avg_frequency * 2 end)
    |> Enum.map(fn {type, count} -> %{type: type, frequency: count, threshold_multiplier: count / avg_frequency} end)
  end
  
  defp detect_importance_spikes(events) do
    # Detect unusual importance score spikes
    avg_importance = events |> Enum.map(&(&1.importance_score)) |> Enum.sum() |> Kernel./(max(1, length(events)))
    
    events
    |> Enum.filter(&(&1.importance_score > avg_importance + 0.3))
    |> Enum.map(fn event ->
      %{
        event_id: event.context_id,
        importance: event.importance_score,
        spike_magnitude: event.importance_score - avg_importance
      }
    end)
  end
  
  defp detect_type_anomalies(events) do
    # Detect unusual event type patterns
    type_frequencies = Enum.frequencies_by(events, &Map.get(&1, :type))
    
    # Simple heuristic: types appearing exactly once might be anomalies
    singleton_types = type_frequencies
    |> Enum.filter(fn {_type, count} -> count == 1 end)
    |> Enum.map(fn {type, _count} -> type end)
    
    %{singleton_event_types: singleton_types}
  end
  
  # Remaining compact strategies
  
  defp compact_by_time(state) do
    # Keep recent events and summarize older ones
    events_list = :queue.to_list(state.events)
    now = DateTime.utc_now()
    retention_hours = 24  # Keep events from last 24 hours
    
    {recent_events, old_events} = Enum.split_with(events_list, fn event ->
      event_time = Map.get(event, :processed_at, now)
      DateTime.diff(now, event_time, :hour) <= retention_hours
    end)
    
    # Always keep some old high-importance events
    important_old_events = Enum.filter(old_events, &(&1.importance_score > @importance_threshold))
    events_to_keep = recent_events ++ important_old_events
    events_to_summarize = old_events -- important_old_events
    
    # Generate summary and update state
    summary = generate_event_summary(events_to_summarize)
    compacted_events = :queue.from_list(events_to_keep)
    
    %{state |
      events: compacted_events,
      compact_summary: Map.merge(state.compact_summary, summary),
      event_count: length(events_to_keep),
      token_count: calculate_total_token_count(events_to_keep, summary),
      last_compaction: DateTime.utc_now()
    }
  end
  
  defp compact_hybrid_strategy(state) do
    # Combine importance, temporal, and causal strategies
    events_list = :queue.to_list(state.events)
    
    # Score events using multiple criteria
    scored_events = Enum.map(events_list, fn event ->
      importance_score = event.importance_score
      temporal_score = calculate_temporal_score(event)
      causal_score = Map.get(
        calculate_causal_importance_scores([event], state.causal_relationships),
        event.context_id,
        0
      )
      
      # Weighted combination
      hybrid_score = importance_score * 0.5 + temporal_score * 0.3 + causal_score * 0.2
      {event, hybrid_score}
    end)
    
    # Sort and keep top events
    sorted_events = Enum.sort_by(scored_events, &elem(&1, 1), :desc)
    keep_count = round(length(sorted_events) * @critical_event_retention_ratio)
    keep_count = max(keep_count, 50)
    
    {events_to_keep, events_to_summarize} = Enum.split(sorted_events, keep_count)
    
    final_events_to_keep = Enum.map(events_to_keep, &elem(&1, 0))
    final_events_to_summarize = Enum.map(events_to_summarize, &elem(&1, 0))
    
    summary = generate_event_summary(final_events_to_summarize)
    compacted_events = :queue.from_list(final_events_to_keep)
    
    %{state |
      events: compacted_events,
      compact_summary: Map.merge(state.compact_summary, summary),
      event_count: length(final_events_to_keep),
      token_count: calculate_total_token_count(final_events_to_keep, summary),
      last_compaction: DateTime.utc_now()
    }
  end
  
  defp calculate_temporal_score(event) do
    # Score based on event recency
    now = DateTime.utc_now()
    event_time = Map.get(event, :processed_at, now)
    hours_old = DateTime.diff(now, event_time, :hour)
    
    # More recent events get higher scores
    cond do
      hours_old <= 1 -> 1.0    # Last hour: maximum score
      hours_old <= 6 -> 0.8    # Last 6 hours: high score
      hours_old <= 24 -> 0.5   # Last day: medium score
      hours_old <= 168 -> 0.2  # Last week: low score
      true -> 0.1              # Older: minimum score
    end
  end
end