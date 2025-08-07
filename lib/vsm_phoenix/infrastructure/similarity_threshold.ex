defmodule VsmPhoenix.Infrastructure.SimilarityThreshold do
  @moduledoc """
  Similarity threshold implementation for performance optimization.
  Prevents redundant processing of similar messages, events, or data.
  """

  require Logger
  alias VsmPhoenix.Infrastructure.DynamicConfig

  @doc """
  Check if data is similar to recently processed data.
  Returns true if similar (should skip), false if different (should process).
  """
  def is_similar?(key, data, opts \\ []) do
    # Get dynamic configuration
    config = DynamicConfig.get_component(:similarity)
    threshold = Keyword.get(opts, :threshold, config[:threshold] || 0.95)
    ttl = Keyword.get(opts, :ttl, config[:ttl] || 60_000)
    
    # Generate hash for comparison
    hash = generate_hash(data)
    cache_key = {key, hash}
    
    # Check cache
    case check_cache(cache_key, ttl) do
      {:hit, _cached_data} ->
        emit_telemetry(:cache_hit, key)
        true  # Similar, skip processing
        
      :miss ->
        # Not similar, store in cache
        store_in_cache(cache_key, data, ttl)
        emit_telemetry(:cache_miss, key)
        false  # Different, process it
    end
  end

  @doc """
  Check similarity between two data structures with configurable threshold.
  """
  def compare(data1, data2, threshold \\ nil) do
    # Use dynamic threshold if not provided
    threshold = threshold || DynamicConfig.get([:similarity, :threshold]) || 0.95
    similarity = calculate_similarity(data1, data2)
    
    %{
      similar: similarity >= threshold,
      score: similarity,
      threshold: threshold
    }
  end

  @doc """
  Batch deduplication - filters out similar items from a list.
  """
  def deduplicate_batch(items, opts \\ []) do
    config = DynamicConfig.get_component(:similarity)
    threshold = Keyword.get(opts, :threshold, config[:threshold] || 0.95)
    key_fun = Keyword.get(opts, :key_fun, & &1)
    
    items
    |> Enum.reduce({[], MapSet.new()}, fn item, {unique, seen_hashes} ->
      item_key = key_fun.(item)
      hash = generate_hash(item_key)
      
      if MapSet.member?(seen_hashes, hash) do
        {unique, seen_hashes}
      else
        {[item | unique], MapSet.put(seen_hashes, hash)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @doc """
  Rate limiting based on similarity - prevents processing similar requests too frequently.
  """
  def rate_limit_similar(key, data, opts \\ []) do
    window = Keyword.get(opts, :window, 1_000)  # 1 second default
    max_similar = Keyword.get(opts, :max_similar, 1)
    
    cache_key = {:rate_limit, key, generate_hash(data)}
    
    case increment_counter(cache_key, window) do
      count when count <= max_similar ->
        :ok
      count ->
        {:error, {:rate_limited, count, max_similar}}
    end
  end

  @doc """
  Fuzzy matching for text-based similarity.
  """
  def fuzzy_match(text1, text2, threshold \\ 0.8) do
    # Simple Levenshtein distance-based similarity
    distance = String.jaro_distance(text1, text2)
    
    %{
      match: distance >= threshold,
      score: distance,
      threshold: threshold
    }
  end

  @doc """
  Semantic similarity for structured data (maps, lists).
  """
  def semantic_similarity(data1, data2) when is_map(data1) and is_map(data2) do
    # Calculate similarity based on key overlap and value similarity
    keys1 = MapSet.new(Map.keys(data1))
    keys2 = MapSet.new(Map.keys(data2))
    
    common_keys = MapSet.intersection(keys1, keys2)
    all_keys = MapSet.union(keys1, keys2)
    
    if MapSet.size(all_keys) == 0 do
      1.0  # Both empty maps are identical
    else
      key_similarity = MapSet.size(common_keys) / MapSet.size(all_keys)
      
      # Calculate value similarity for common keys
      value_similarity = if MapSet.size(common_keys) > 0 do
        common_keys
        |> Enum.map(fn key ->
          val1 = Map.get(data1, key)
          val2 = Map.get(data2, key)
          calculate_value_similarity(val1, val2)
        end)
        |> Enum.sum()
        |> Kernel./(MapSet.size(common_keys))
      else
        0.0
      end
      
      # Weighted average
      (key_similarity * 0.3 + value_similarity * 0.7)
    end
  end

  def semantic_similarity(data1, data2) when is_list(data1) and is_list(data2) do
    # List similarity based on content overlap
    set1 = MapSet.new(data1)
    set2 = MapSet.new(data2)
    
    intersection = MapSet.intersection(set1, set2)
    union = MapSet.union(set1, set2)
    
    if MapSet.size(union) == 0 do
      1.0
    else
      MapSet.size(intersection) / MapSet.size(union)
    end
  end

  def semantic_similarity(data1, data2) do
    # Fallback to exact match
    if data1 == data2, do: 1.0, else: 0.0
  end

  @doc """
  Clear similarity cache for a specific key or all keys.
  """
  def clear_cache(key \\ :all) do
    if key == :all do
      :ets.delete_all_objects(:similarity_cache)
    else
      :ets.match_delete(:similarity_cache, {{key, :_}, :_, :_})
    end
    :ok
  end

  # Private functions

  defp generate_hash(data) do
    data
    |> :erlang.term_to_binary()
    |> :crypto.hash(:sha256)
    |> Base.encode16()
  end

  defp check_cache(cache_key, ttl) do
    case :ets.lookup(:similarity_cache, cache_key) do
      [{^cache_key, data, timestamp}] ->
        if timestamp + ttl > System.monotonic_time(:millisecond) do
          {:hit, data}
        else
          # Expired
          :ets.delete(:similarity_cache, cache_key)
          :miss
        end
      [] ->
        :miss
    end
  end

  defp store_in_cache(cache_key, data, ttl) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(:similarity_cache, {cache_key, data, timestamp})
    
    # Schedule cleanup
    Process.send_after(self(), {:cleanup_cache, cache_key}, ttl)
  end

  defp increment_counter(cache_key, window) do
    timestamp = System.monotonic_time(:millisecond)
    
    # Clean old entries
    :ets.select_delete(:similarity_counters, [
      {
        {{:_, :_, :_}, :_, :"$1"},
        [{:<, {:+, :"$1", window}, timestamp}],
        [true]
      }
    ])
    
    # Increment counter
    :ets.update_counter(:similarity_counters, cache_key, {2, 1}, {cache_key, 0, timestamp})
  end

  defp calculate_similarity(data1, data2) do
    cond do
      data1 == data2 -> 1.0
      is_binary(data1) and is_binary(data2) -> String.jaro_distance(data1, data2)
      is_map(data1) and is_map(data2) -> semantic_similarity(data1, data2)
      is_list(data1) and is_list(data2) -> semantic_similarity(data1, data2)
      true -> 0.0
    end
  end

  defp calculate_value_similarity(val1, val2) do
    cond do
      val1 == val2 -> 1.0
      is_binary(val1) and is_binary(val2) -> String.jaro_distance(val1, val2)
      is_number(val1) and is_number(val2) -> 1.0 - abs(val1 - val2) / Enum.max([abs(val1), abs(val2), 1])
      true -> 0.0
    end
  end

  defp emit_telemetry(event, key) do
    # Report metrics to dynamic config for adaptive tuning
    case event do
      :cache_hit -> DynamicConfig.report_metric(:similarity, :cache_hit, 1)
      :cache_miss -> DynamicConfig.report_metric(:similarity, :cache_miss, 1)
      _ -> :ok
    end
    
    :telemetry.execute(
      [:vsm_phoenix, :similarity, event],
      %{count: 1},
      %{key: key}
    )
  rescue
    _ -> :ok
  end

  # Initialize ETS tables on startup
  def init do
    :ets.new(:similarity_cache, [:set, :public, :named_table])
    :ets.new(:similarity_counters, [:set, :public, :named_table])
    :ok
  end
end