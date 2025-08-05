defmodule VsmPhoenix.LLM.Cache do
  @moduledoc """
  Response caching for LLM operations with semantic similarity matching.
  Reduces API calls and costs by caching similar queries.
  """
  
  use GenServer
  require Logger
  
  @table_name :llm_cache
  @similarity_table :llm_similarity_index
  @default_ttl :timer.hours(24)  # 24 hours default TTL
  @similarity_threshold 0.85  # Cosine similarity threshold for cache hits
  @max_cache_size 10_000  # Maximum number of cached entries
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Gets a cached response for the given prompt.
  Returns {:ok, response} if found, :miss if not found.
  
  Options:
    - check_similarity: whether to check for semantically similar prompts (default: true)
    - similarity_threshold: minimum similarity score (default: 0.85)
  """
  def get(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:get, prompt, opts})
  end
  
  @doc """
  Stores a response in the cache with optional TTL.
  
  Options:
    - ttl: time to live in milliseconds (default: 24 hours)
    - embedding: pre-computed embedding vector for the prompt
    - metadata: additional metadata to store with the cache entry
  """
  def put(prompt, response, opts \\ []) do
    GenServer.cast(__MODULE__, {:put, prompt, response, opts})
  end
  
  @doc """
  Invalidates cache entries matching the given pattern or criteria.
  
  Options:
    - pattern: string pattern to match (uses simple substring matching)
    - older_than: invalidate entries older than this DateTime
    - metadata: invalidate entries with matching metadata
  """
  def invalidate(criteria \\ []) do
    GenServer.call(__MODULE__, {:invalidate, criteria})
  end
  
  @doc """
  Gets current cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end
  
  @doc """
  Clears the entire cache.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Create ETS tables for cache storage
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@similarity_table, [:ordered_set, :public, :named_table])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    state = %{
      hits: 0,
      misses: 0,
      evictions: 0,
      similarity_hits: 0
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:get, prompt, opts}, _from, state) do
    case lookup_exact(prompt) do
      {:ok, response} ->
        {:reply, {:ok, response}, %{state | hits: state.hits + 1}}
        
      :miss ->
        if Keyword.get(opts, :check_similarity, true) do
          case lookup_similar(prompt, opts) do
            {:ok, response} ->
              {:reply, {:ok, response}, %{state | 
                similarity_hits: state.similarity_hits + 1,
                hits: state.hits + 1
              }}
              
            :miss ->
              {:reply, :miss, %{state | misses: state.misses + 1}}
          end
        else
          {:reply, :miss, %{state | misses: state.misses + 1}}
        end
    end
  end
  
  @impl true
  def handle_call({:invalidate, criteria}, _from, state) do
    count = invalidate_entries(criteria)
    {:reply, {:ok, count}, state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    stats = Map.merge(state, %{
      total_entries: :ets.info(@table_name, :size),
      memory_usage: :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize),
      hit_rate: calculate_hit_rate(state)
    })
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@similarity_table)
    
    {:reply, :ok, %{state | hits: 0, misses: 0, evictions: 0, similarity_hits: 0}}
  end
  
  @impl true
  def handle_cast({:put, prompt, response, opts}, state) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = System.system_time(:millisecond) + ttl
    
    # Check cache size and evict if necessary
    new_state = if :ets.info(@table_name, :size) >= @max_cache_size do
      evict_oldest()
      %{state | evictions: state.evictions + 1}
    else
      state
    end
    
    # Generate cache key
    key = generate_key(prompt)
    
    # Store in main cache
    entry = %{
      prompt: prompt,
      response: response,
      created_at: DateTime.utc_now(),
      expires_at: expires_at,
      metadata: Keyword.get(opts, :metadata, %{}),
      access_count: 0
    }
    
    :ets.insert(@table_name, {key, entry})
    
    # Store embedding for similarity search if provided
    if embedding = Keyword.get(opts, :embedding) do
      store_embedding(key, embedding)
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries
    expired_count = cleanup_expired()
    
    # Schedule next cleanup
    schedule_cleanup()
    
    Logger.debug("Cache cleanup: removed #{expired_count} expired entries")
    
    {:noreply, state}
  end
  
  # Private functions
  
  defp lookup_exact(prompt) do
    key = generate_key(prompt)
    
    case :ets.lookup(@table_name, key) do
      [{^key, entry}] ->
        if entry.expires_at > System.system_time(:millisecond) do
          # Update access count
          :ets.update_counter(@table_name, key, {2, 1}, entry)
          {:ok, entry.response}
        else
          # Entry expired, remove it
          :ets.delete(@table_name, key)
          :miss
        end
        
      [] ->
        :miss
    end
  end
  
  defp lookup_similar(prompt, opts) do
    threshold = Keyword.get(opts, :similarity_threshold, @similarity_threshold)
    
    # This is a simplified version - in production, you'd compute
    # the embedding for the prompt and search for similar embeddings
    # For now, we'll do simple string similarity
    
    similar_entries = :ets.foldl(
      fn {key, entry}, acc ->
        similarity = calculate_string_similarity(prompt, entry.prompt)
        if similarity >= threshold and entry.expires_at > System.system_time(:millisecond) do
          [{similarity, key, entry} | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    
    case similar_entries do
      [] ->
        :miss
        
      entries ->
        # Get the most similar entry
        {_similarity, key, entry} = Enum.max_by(entries, fn {sim, _, _} -> sim end)
        
        # Update access count
        :ets.update_counter(@table_name, key, {2, 1}, entry)
        
        Logger.debug("Cache similarity hit for prompt similarity")
        {:ok, entry.response}
    end
  end
  
  defp calculate_string_similarity(str1, str2) do
    # Simple Jaccard similarity for demonstration
    # In production, use proper embedding-based similarity
    
    words1 = String.split(String.downcase(str1), ~r/\W+/, trim: true) |> MapSet.new()
    words2 = String.split(String.downcase(str2), ~r/\W+/, trim: true) |> MapSet.new()
    
    intersection_size = MapSet.intersection(words1, words2) |> MapSet.size()
    union_size = MapSet.union(words1, words2) |> MapSet.size()
    
    if union_size == 0, do: 0.0, else: intersection_size / union_size
  end
  
  defp store_embedding(key, embedding) do
    # Store embedding with its magnitude for fast cosine similarity search
    magnitude = :math.sqrt(Enum.reduce(embedding, 0, fn x, acc -> acc + x * x end))
    :ets.insert(@similarity_table, {key, embedding, magnitude})
  end
  
  defp invalidate_entries(criteria) do
    pattern = Keyword.get(criteria, :pattern)
    older_than = Keyword.get(criteria, :older_than)
    metadata_match = Keyword.get(criteria, :metadata, %{})
    
    keys_to_delete = :ets.foldl(
      fn {key, entry}, acc ->
        should_delete = 
          (pattern && String.contains?(entry.prompt, pattern)) ||
          (older_than && DateTime.compare(entry.created_at, older_than) == :lt) ||
          (map_size(metadata_match) > 0 && matches_metadata?(entry.metadata, metadata_match))
          
        if should_delete, do: [key | acc], else: acc
      end,
      [],
      @table_name
    )
    
    Enum.each(keys_to_delete, fn key ->
      :ets.delete(@table_name, key)
      :ets.delete(@similarity_table, key)
    end)
    
    length(keys_to_delete)
  end
  
  defp matches_metadata?(entry_metadata, match_criteria) do
    Enum.all?(match_criteria, fn {k, v} ->
      Map.get(entry_metadata, k) == v
    end)
  end
  
  defp evict_oldest do
    # Find entry with lowest access count and oldest creation time
    oldest = :ets.foldl(
      fn {key, entry}, acc ->
        case acc do
          nil -> 
            {key, entry}
            
          {_old_key, old_entry} ->
            if entry.access_count < old_entry.access_count ||
               (entry.access_count == old_entry.access_count && 
                DateTime.compare(entry.created_at, old_entry.created_at) == :lt) do
              {key, entry}
            else
              acc
            end
        end
      end,
      nil,
      @table_name
    )
    
    case oldest do
      {key, _entry} ->
        :ets.delete(@table_name, key)
        :ets.delete(@similarity_table, key)
        
      nil ->
        :ok
    end
  end
  
  defp cleanup_expired do
    current_time = System.system_time(:millisecond)
    
    expired_keys = :ets.foldl(
      fn {key, entry}, acc ->
        if entry.expires_at <= current_time do
          [key | acc]
        else
          acc
        end
      end,
      [],
      @table_name
    )
    
    Enum.each(expired_keys, fn key ->
      :ets.delete(@table_name, key)
      :ets.delete(@similarity_table, key)
    end)
    
    length(expired_keys)
  end
  
  defp calculate_hit_rate(%{hits: hits, misses: misses}) do
    total = hits + misses
    if total == 0, do: 0.0, else: hits / total
  end
  
  defp generate_key(prompt) do
    :crypto.hash(:sha256, prompt) |> Base.encode16(case: :lower)
  end
  
  defp schedule_cleanup do
    # Cleanup every hour
    Process.send_after(self(), :cleanup, :timer.hours(1))
  end
end