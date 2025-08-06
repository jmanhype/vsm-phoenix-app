defmodule VsmPhoenix.System5.Persistence.AdaptationStore do
  @moduledoc """
  ETS-based persistence store for adaptation patterns and learning.

  Features:
  - Store successful adaptation patterns
  - Track adaptation effectiveness over time
  - Pattern matching and retrieval
  - Machine learning integration support
  - Cross-domain adaptation knowledge transfer
  """

  use GenServer
  require Logger

  @table_name :system5_adaptation_store
  @pattern_table :system5_adaptation_patterns
  @learning_table :system5_adaptation_learning

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def store_adaptation(adaptation_id, adaptation_data, outcome \\ nil) do
    GenServer.call(__MODULE__, {:store_adaptation, adaptation_id, adaptation_data, outcome})
  end

  def get_adaptation(adaptation_id) do
    GenServer.call(__MODULE__, {:get_adaptation, adaptation_id})
  end

  def record_outcome(adaptation_id, outcome_data) do
    GenServer.call(__MODULE__, {:record_outcome, adaptation_id, outcome_data})
  end

  def find_similar_adaptations(context, limit \\ 10) do
    GenServer.call(__MODULE__, {:find_similar, context, limit})
  end

  def extract_patterns(min_occurrences \\ 3) do
    GenServer.call(__MODULE__, {:extract_patterns, min_occurrences})
  end

  def store_learned_pattern(pattern_id, pattern_data) do
    GenServer.call(__MODULE__, {:store_pattern, pattern_id, pattern_data})
  end

  def get_successful_adaptations(threshold \\ 0.7) do
    GenServer.call(__MODULE__, {:get_successful, threshold})
  end

  def get_adaptation_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def transfer_knowledge(from_domain, to_domain) do
    GenServer.call(__MODULE__, {:transfer_knowledge, from_domain, to_domain})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("AdaptationStore: Initializing ETS-based adaptation persistence")

    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@pattern_table, [:set, :public, :named_table])
    :ets.new(@learning_table, [:bag, :public, :named_table])

    state = %{
      adaptation_count: 0,
      pattern_count: 0,
      success_rate: 1.0,
      domains: MapSet.new()
    }

    # Schedule periodic pattern extraction
    schedule_pattern_extraction()

    {:ok, state}
  end

  @impl true
  def handle_call({:store_adaptation, adaptation_id, adaptation_data, outcome}, _from, state) do
    Logger.info("AdaptationStore: Storing adaptation #{adaptation_id}")

    timestamp = DateTime.utc_now()

    adaptation_record = %{
      id: adaptation_id,
      data: adaptation_data,
      anomaly_context: Map.get(adaptation_data, :anomaly_context, %{}),
      policy_changes: Map.get(adaptation_data, :policy_changes, []),
      domain: Map.get(adaptation_data, :domain, :general),
      outcome: outcome,
      created_at: timestamp,
      updated_at: timestamp,
      effectiveness: nil,
      applied_count: 0
    }

    # Store adaptation
    :ets.insert(@table_name, {adaptation_id, adaptation_record})

    # Update domains
    new_domains = MapSet.put(state.domains, adaptation_record.domain)

    # Store initial learning record
    learning_record = %{
      adaptation_id: adaptation_id,
      timestamp: timestamp,
      context_vector: vectorize_context(adaptation_record.anomaly_context),
      # Initial neutral probability
      success_probability: 0.5
    }

    :ets.insert(@learning_table, {adaptation_id, learning_record})

    new_state = %{state | adaptation_count: state.adaptation_count + 1, domains: new_domains}

    {:reply, {:ok, adaptation_record}, new_state}
  end

  @impl true
  def handle_call({:get_adaptation, adaptation_id}, _from, state) do
    case :ets.lookup(@table_name, adaptation_id) do
      [{^adaptation_id, adaptation}] ->
        {:reply, {:ok, adaptation}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:record_outcome, adaptation_id, outcome_data}, _from, state) do
    case :ets.lookup(@table_name, adaptation_id) do
      [{^adaptation_id, adaptation}] ->
        # Calculate effectiveness based on outcome
        effectiveness = calculate_effectiveness(outcome_data)

        updated_adaptation = %{
          adaptation
          | outcome: outcome_data,
            effectiveness: effectiveness,
            updated_at: DateTime.utc_now(),
            applied_count: adaptation.applied_count + 1
        }

        :ets.insert(@table_name, {adaptation_id, updated_adaptation})

        # Update learning record
        update_learning_record(adaptation_id, effectiveness)

        # Update overall success rate
        new_success_rate = update_success_rate(state.success_rate, effectiveness)

        {:reply, :ok, %{state | success_rate: new_success_rate}}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:find_similar, context, limit}, _from, state) do
    # Vectorize the search context
    search_vector = vectorize_context(context)

    # Find similar adaptations using vector similarity
    similar =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, adaptation} -> adaptation end)
      |> Enum.map(fn adaptation ->
        similarity =
          calculate_similarity(search_vector, vectorize_context(adaptation.anomaly_context))

        {adaptation, similarity}
      end)
      |> Enum.sort_by(fn {_adaptation, similarity} -> similarity end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {adaptation, _similarity} -> adaptation end)

    {:reply, {:ok, similar}, state}
  end

  @impl true
  def handle_call({:extract_patterns, min_occurrences}, _from, state) do
    Logger.info("AdaptationStore: Extracting patterns (min_occurrences: #{min_occurrences})")

    # Group adaptations by similar contexts
    patterns = extract_adaptation_patterns(min_occurrences)

    # Store extracted patterns
    Enum.each(patterns, fn pattern ->
      pattern_id = generate_pattern_id()
      :ets.insert(@pattern_table, {pattern_id, pattern})
    end)

    new_state = %{state | pattern_count: state.pattern_count + length(patterns)}

    {:reply, {:ok, patterns}, new_state}
  end

  @impl true
  def handle_call({:store_pattern, pattern_id, pattern_data}, _from, state) do
    pattern_record =
      Map.merge(pattern_data, %{
        id: pattern_id,
        created_at: DateTime.utc_now(),
        usage_count: 0,
        success_rate: 1.0
      })

    :ets.insert(@pattern_table, {pattern_id, pattern_record})

    new_state = %{state | pattern_count: state.pattern_count + 1}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_successful, threshold}, _from, state) do
    successful =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, adaptation} -> adaptation end)
      |> Enum.filter(fn adaptation ->
        adaptation.effectiveness && adaptation.effectiveness >= threshold
      end)
      |> Enum.sort_by(& &1.effectiveness, :desc)

    {:reply, {:ok, successful}, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      total_adaptations: state.adaptation_count,
      total_patterns: state.pattern_count,
      overall_success_rate: state.success_rate,
      domains: MapSet.to_list(state.domains),
      pattern_effectiveness: calculate_pattern_effectiveness()
    }

    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:transfer_knowledge, from_domain, to_domain}, _from, state) do
    Logger.info("AdaptationStore: Transferring knowledge from #{from_domain} to #{to_domain}")

    # Find successful adaptations from source domain
    source_adaptations =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, adaptation} -> adaptation end)
      |> Enum.filter(fn adaptation ->
        adaptation.domain == from_domain &&
          adaptation.effectiveness &&
          adaptation.effectiveness > 0.7
      end)

    # Extract transferable patterns
    transferred_patterns =
      Enum.map(source_adaptations, fn adaptation ->
        %{
          source_domain: from_domain,
          target_domain: to_domain,
          pattern_type: :transferred,
          base_pattern: extract_core_pattern(adaptation),
          adaptation_hints: generate_domain_hints(from_domain, to_domain),
          # Reduce confidence for transfer
          confidence: adaptation.effectiveness * 0.8
        }
      end)

    # Store transferred patterns
    Enum.each(transferred_patterns, fn pattern ->
      pattern_id =
        "transfer_#{from_domain}_to_#{to_domain}_#{:erlang.unique_integer([:positive])}"

      :ets.insert(@pattern_table, {pattern_id, pattern})
    end)

    {:reply, {:ok, length(transferred_patterns)}, state}
  end

  @impl true
  def handle_info(:extract_patterns, state) do
    # Automatic pattern extraction
    {:ok, patterns} = handle_call({:extract_patterns, 3}, self(), state)

    Logger.info("AdaptationStore: Auto-extracted #{length(patterns)} patterns")

    # Schedule next extraction
    schedule_pattern_extraction()

    {:noreply, state}
  end

  # Private Functions

  defp vectorize_context(context) do
    # Simple context vectorization - in production would use proper embeddings
    context
    |> Map.to_list()
    |> Enum.sort()
    |> Enum.map(fn {k, v} ->
      :erlang.phash2({k, v}, 1000) / 1000
    end)
  end

  defp calculate_similarity(vector1, vector2) do
    # Cosine similarity approximation
    if length(vector1) == 0 or length(vector2) == 0 do
      0.0
    else
      # Pad vectors to same length
      max_len = max(length(vector1), length(vector2))
      v1 = vector1 ++ List.duplicate(0.0, max_len - length(vector1))
      v2 = vector2 ++ List.duplicate(0.0, max_len - length(vector2))

      # Calculate dot product and magnitudes
      {dot_product, mag1, mag2} =
        Enum.zip(v1, v2)
        |> Enum.reduce({0.0, 0.0, 0.0}, fn {a, b}, {dot, m1, m2} ->
          {dot + a * b, m1 + a * a, m2 + b * b}
        end)

      if mag1 == 0 or mag2 == 0 do
        0.0
      else
        dot_product / (:math.sqrt(mag1) * :math.sqrt(mag2))
      end
    end
  end

  defp calculate_effectiveness(outcome_data) do
    # Calculate effectiveness score based on outcome
    base_score = (Map.get(outcome_data, :success, false) && 1.0) || 0.0

    # Adjust based on metrics
    performance_impact = Map.get(outcome_data, :performance_impact, 0.0)
    stability_impact = Map.get(outcome_data, :stability_impact, 0.0)

    (base_score * 0.5 + performance_impact * 0.3 + stability_impact * 0.2)
    |> max(0.0)
    |> min(1.0)
  end

  defp update_learning_record(adaptation_id, effectiveness) do
    case :ets.lookup(@learning_table, adaptation_id) do
      [{^adaptation_id, learning_record}] ->
        # Update success probability using exponential moving average
        alpha = 0.3

        new_probability =
          alpha * effectiveness + (1 - alpha) * learning_record.success_probability

        updated_record = %{
          learning_record
          | success_probability: new_probability,
            last_updated: DateTime.utc_now()
        }

        :ets.insert(@learning_table, {adaptation_id, updated_record})

      _ ->
        :ok
    end
  end

  defp update_success_rate(current_rate, new_effectiveness) do
    # Exponential moving average
    alpha = 0.1
    alpha * new_effectiveness + (1 - alpha) * current_rate
  end

  defp extract_adaptation_patterns(min_occurrences) do
    # Group adaptations by similar contexts
    adaptations =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, adaptation} -> adaptation end)
      |> Enum.filter(&(&1.effectiveness && &1.effectiveness > 0.6))

    # Cluster by context similarity
    clusters = cluster_adaptations(adaptations)

    # Extract patterns from clusters
    clusters
    |> Enum.filter(fn cluster -> length(cluster) >= min_occurrences end)
    |> Enum.map(&extract_cluster_pattern/1)
  end

  defp cluster_adaptations(adaptations) do
    # Simple clustering - in production would use proper ML clustering
    adaptations
    |> Enum.group_by(fn adaptation ->
      # Group by domain and rough context hash
      {adaptation.domain, :erlang.phash2(adaptation.anomaly_context, 100)}
    end)
    |> Map.values()
  end

  defp extract_cluster_pattern(cluster) do
    total_effectiveness = Enum.map(cluster, & &1.effectiveness) |> Enum.sum()
    avg_effectiveness = total_effectiveness / length(cluster)

    %{
      pattern_type: :recurring_adaptation,
      occurrences: length(cluster),
      avg_effectiveness: avg_effectiveness,
      common_context: extract_common_context(cluster),
      recommended_actions: extract_common_actions(cluster),
      created_at: DateTime.utc_now()
    }
  end

  defp extract_common_context(cluster) do
    # Find common context elements
    cluster
    |> Enum.map(& &1.anomaly_context)
    |> Enum.reduce(&Map.take(&1, Map.keys(&2)))
  end

  defp extract_common_actions(cluster) do
    # Find common policy changes
    cluster
    |> Enum.flat_map(& &1.policy_changes)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_action, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {action, _count} -> action end)
  end

  defp generate_pattern_id do
    "pattern_#{:erlang.unique_integer([:positive, :monotonic])}"
  end

  defp calculate_pattern_effectiveness do
    case :ets.tab2list(@pattern_table) do
      [] ->
        1.0

      patterns ->
        patterns
        |> Enum.map(fn {_id, pattern} -> Map.get(pattern, :success_rate, 1.0) end)
        |> Enum.sum()
        |> Kernel./(length(patterns))
    end
  end

  defp extract_core_pattern(adaptation) do
    %{
      context_type: classify_context(adaptation.anomaly_context),
      action_type: classify_actions(adaptation.policy_changes),
      effectiveness: adaptation.effectiveness
    }
  end

  defp classify_context(context) do
    # Simple classification - in production would be more sophisticated
    cond do
      Map.has_key?(context, :performance) -> :performance_anomaly
      Map.has_key?(context, :security) -> :security_anomaly
      Map.has_key?(context, :resource) -> :resource_anomaly
      true -> :general_anomaly
    end
  end

  defp classify_actions(policy_changes) do
    # Classify the type of policy changes
    policy_changes
    |> Enum.map(fn change ->
      cond do
        String.contains?(to_string(change), "scale") -> :scaling
        String.contains?(to_string(change), "limit") -> :rate_limiting
        String.contains?(to_string(change), "route") -> :routing
        true -> :general
      end
    end)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_type, count} -> count end, fn -> {:general, 0} end)
    |> elem(0)
  end

  defp generate_domain_hints(from_domain, to_domain) do
    # Generate hints for adapting patterns between domains
    %{
      scaling_factor: calculate_domain_scaling(from_domain, to_domain),
      context_mapping: suggest_context_mapping(from_domain, to_domain),
      caution_areas: identify_domain_differences(from_domain, to_domain)
    }
  end

  defp calculate_domain_scaling(from, to) do
    # Simple heuristic - in production would be learned
    case {from, to} do
      {:web, :api} -> 0.8
      {:api, :web} -> 1.2
      _ -> 1.0
    end
  end

  defp suggest_context_mapping(_from, _to) do
    # Suggest how to map contexts between domains
    %{
      performance: :latency,
      security: :authentication,
      resource: :capacity
    }
  end

  defp identify_domain_differences(_from, _to) do
    # Identify areas that need special attention
    [:state_management, :concurrency_model, :error_handling]
  end

  defp schedule_pattern_extraction do
    # Extract patterns every 30 minutes
    Process.send_after(self(), :extract_patterns, :timer.minutes(30))
  end
end
