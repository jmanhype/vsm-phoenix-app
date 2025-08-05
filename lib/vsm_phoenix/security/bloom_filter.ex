defmodule VsmPhoenix.Security.BloomFilter do
  @moduledoc """
  High-performance Bloom filter implementation for nonce tracking and replay attack prevention.
  Uses multiple hash functions and automatic cleanup for efficient memory usage.
  """

  use GenServer
  require Logger

  # Configuration
  @default_size 1_000_000  # 1M bits ~ 125KB
  @default_hash_count 3
  @default_ttl_ms :timer.minutes(5)
  @cleanup_interval_ms :timer.minutes(1)
  @false_positive_rate 0.01

  defstruct [
    :bit_array,
    :size,
    :hash_count,
    :element_count,
    :ttl_ms,
    :entries,
    :created_at
  ]

  # Client API

  @doc """
  Starts the Bloom filter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Adds an element to the Bloom filter.
  Returns {:ok, :new} if element was not present, {:ok, :duplicate} if possibly present.
  """
  def add(server \\ __MODULE__, element) do
    GenServer.call(server, {:add, element})
  end

  @doc """
  Checks if an element might be in the Bloom filter.
  Returns true if possibly present (may be false positive), false if definitely not present.
  """
  def contains?(server \\ __MODULE__, element) do
    GenServer.call(server, {:contains, element})
  end

  @doc """
  Gets current filter statistics.
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Calculates optimal Bloom filter parameters for given capacity and false positive rate.
  """
  def calculate_optimal_params(expected_elements, false_positive_rate \\ @false_positive_rate) do
    # Calculate optimal bit array size
    m = -expected_elements * :math.log(false_positive_rate) / :math.pow(:math.log(2), 2)
    size = round(m)
    
    # Calculate optimal number of hash functions
    k = size / expected_elements * :math.log(2)
    hash_count = round(k)
    
    %{
      size: size,
      hash_count: max(1, hash_count),
      memory_kb: size / 8 / 1024
    }
  end

  # Server callbacks

  @impl true
  def init(opts) do
    size = opts[:size] || @default_size
    hash_count = opts[:hash_count] || @default_hash_count
    ttl_ms = opts[:ttl_ms] || @default_ttl_ms

    # Use atomics for high-performance bit operations
    bit_array = :atomics.new(div(size, 64) + 1, signed: false)
    
    state = %__MODULE__{
      bit_array: bit_array,
      size: size,
      hash_count: hash_count,
      element_count: 0,
      ttl_ms: ttl_ms,
      entries: %{},  # Track entries with timestamps for TTL
      created_at: System.monotonic_time(:millisecond)
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:add, element}, _from, state) do
    now = System.monotonic_time(:millisecond)
    hash_values = compute_hashes(element, state.hash_count, state.size)
    
    # Check if already present
    was_present = all_bits_set?(state.bit_array, hash_values, state.size)
    
    # Set bits
    Enum.each(hash_values, fn hash ->
      set_bit(state.bit_array, hash, state.size)
    end)
    
    # Track entry with timestamp for TTL
    entries = Map.put(state.entries, element, now)
    
    new_state = %{state | 
      entries: entries,
      element_count: if(was_present, do: state.element_count, else: state.element_count + 1)
    }
    
    result = if was_present, do: :duplicate, else: :new
    {:reply, {:ok, result}, new_state}
  end

  @impl true
  def handle_call({:contains, element}, _from, state) do
    hash_values = compute_hashes(element, state.hash_count, state.size)
    result = all_bits_set?(state.bit_array, hash_values, state.size)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    now = System.monotonic_time(:millisecond)
    uptime_ms = now - state.created_at
    
    # Calculate fill ratio
    set_bits = count_set_bits(state.bit_array, state.size)
    fill_ratio = set_bits / state.size
    
    # Estimate false positive rate
    estimated_fpr = :math.pow(fill_ratio, state.hash_count)
    
    stats = %{
      size: state.size,
      hash_count: state.hash_count,
      element_count: state.element_count,
      tracked_entries: map_size(state.entries),
      fill_ratio: fill_ratio,
      estimated_false_positive_rate: estimated_fpr,
      memory_kb: state.size / 8 / 1024,
      uptime_seconds: div(uptime_ms, 1000)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - state.ttl_ms
    
    # Remove expired entries
    active_entries = Map.filter(state.entries, fn {_element, timestamp} ->
      timestamp > cutoff
    end)
    
    expired_count = map_size(state.entries) - map_size(active_entries)
    
    if expired_count > 0 do
      Logger.debug("Bloom filter cleaned up #{expired_count} expired entries")
    end
    
    # If too many entries expired, consider resetting the filter
    new_state = if map_size(active_entries) < state.element_count * 0.5 do
      reset_filter(state, active_entries)
    else
      %{state | entries: active_entries}
    end
    
    schedule_cleanup()
    {:noreply, new_state}
  end

  # Private functions

  defp compute_hashes(element, hash_count, size) do
    # Use murmur3 hash with different seeds for multiple hash functions
    data = :erlang.term_to_binary(element)
    
    for i <- 0..(hash_count - 1) do
      <<hash::unsigned-32>> = :crypto.hash(:md5, data <> <<i::32>>)
      rem(hash, size)
    end
  end

  defp set_bit(atomics, position, size) do
    word_index = div(position, 64) + 1
    bit_position = rem(position, 64)
    mask = 1 <<< bit_position
    
    :atomics.put(atomics, word_index, 
      :atomics.get(atomics, word_index) ||| mask)
  end

  defp get_bit(atomics, position, size) do
    word_index = div(position, 64) + 1
    bit_position = rem(position, 64)
    mask = 1 <<< bit_position
    
    (:atomics.get(atomics, word_index) &&& mask) != 0
  end

  defp all_bits_set?(atomics, positions, size) do
    Enum.all?(positions, fn pos ->
      get_bit(atomics, pos, size)
    end)
  end

  defp count_set_bits(atomics, size) do
    word_count = div(size, 64) + 1
    
    Enum.reduce(1..word_count, 0, fn word_index, acc ->
      word = :atomics.get(atomics, word_index)
      acc + count_bits_in_word(word)
    end)
  end

  defp count_bits_in_word(0), do: 0
  defp count_bits_in_word(word) do
    # Brian Kernighan's algorithm
    count_bits_in_word(word &&& (word - 1)) + 1
  end

  defp reset_filter(state, active_entries) do
    Logger.info("Resetting Bloom filter with #{map_size(active_entries)} active entries")
    
    # Create new bit array
    bit_array = :atomics.new(div(state.size, 64) + 1, signed: false)
    
    # Re-add active entries
    Enum.each(active_entries, fn {element, _timestamp} ->
      hash_values = compute_hashes(element, state.hash_count, state.size)
      Enum.each(hash_values, fn hash ->
        set_bit(bit_array, hash, state.size)
      end)
    end)
    
    %{state | 
      bit_array: bit_array,
      entries: active_entries,
      element_count: map_size(active_entries)
    }
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end
end