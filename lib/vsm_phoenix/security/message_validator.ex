defmodule VsmPhoenix.Security.MessageValidator do
  @moduledoc """
  High-performance message validation with cryptographic security.
  Provides nonce validation, message signing/verification, and replay attack protection.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.Security.{CryptoUtils, BloomFilter}

  @default_nonce_ttl_ms :timer.minutes(5)
  @default_signature_algorithm :hmac  # :hmac or :rsa
  @max_message_age_ms :timer.minutes(1)
  @max_clock_skew_ms :timer.seconds(30)

  defstruct [
    :bloom_filter,
    :signing_key,
    :verification_key,
    :signature_algorithm,
    :nonce_ttl_ms,
    :stats
  ]

  # Message structure
  defmodule Message do
    @enforce_keys [:payload, :nonce, :timestamp]
    defstruct [:payload, :nonce, :timestamp, :signature, :sender_id]
  end

  # Client API

  @doc """
  Starts the message validator GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Signs a message payload and returns a signed message structure.
  """
  def sign_message(server \\ __MODULE__, payload, sender_id \\ nil) do
    GenServer.call(server, {:sign_message, payload, sender_id})
  end

  @doc """
  Verifies a signed message, checking signature, timestamp, and nonce.
  Returns {:ok, payload} if valid, {:error, reason} otherwise.
  """
  def verify_message(server \\ __MODULE__, message) do
    GenServer.call(server, {:verify_message, message})
  end

  @doc """
  Validates just the nonce without full message verification.
  """
  def validate_nonce(server \\ __MODULE__, nonce) do
    GenServer.call(server, {:validate_nonce, nonce})
  end

  @doc """
  Gets validation statistics.
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Initialize Bloom filter for nonce tracking
    bloom_opts = [
      size: opts[:bloom_filter_size] || 10_000_000,  # 10M bits for high throughput
      hash_count: 4,
      ttl_ms: opts[:nonce_ttl_ms] || @default_nonce_ttl_ms
    ]
    
    {:ok, bloom_filter} = BloomFilter.start_link(bloom_opts)
    
    # Initialize keys based on algorithm
    algorithm = opts[:signature_algorithm] || @default_signature_algorithm
    
    {signing_key, verification_key} = case algorithm do
      :hmac ->
        key = opts[:signing_key] || CryptoUtils.generate_key()
        {key, key}
        
      :rsa ->
        case opts[:keypair] do
          %{private_key: priv, public_key: pub} ->
            {priv, pub}
          _ ->
            {:ok, keypair} = CryptoUtils.generate_rsa_keypair()
            {keypair.private_key, keypair.public_key}
        end
    end
    
    state = %__MODULE__{
      bloom_filter: bloom_filter,
      signing_key: signing_key,
      verification_key: verification_key,
      signature_algorithm: algorithm,
      nonce_ttl_ms: opts[:nonce_ttl_ms] || @default_nonce_ttl_ms,
      stats: %{
        messages_signed: 0,
        messages_verified: 0,
        verification_failures: 0,
        replay_attacks_prevented: 0
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:sign_message, payload, sender_id}, _from, state) do
    # Generate secure nonce
    nonce = CryptoUtils.generate_nonce()
    timestamp = System.os_time(:millisecond)
    
    # Create message structure
    message = %Message{
      payload: payload,
      nonce: nonce,
      timestamp: timestamp,
      sender_id: sender_id
    }
    
    # Sign the message
    signed_message = sign_message_internal(message, state)
    
    # Pre-register nonce to prevent self-replay
    BloomFilter.add(state.bloom_filter, nonce)
    
    new_stats = Map.update!(state.stats, :messages_signed, &(&1 + 1))
    {:reply, {:ok, signed_message}, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:verify_message, message}, _from, state) do
    result = verify_message_internal(message, state)
    
    {reply, stats_update} = case result do
      {:ok, _} = success ->
        {success, %{messages_verified: 1}}
        
      {:error, :replay_attack} ->
        {result, %{verification_failures: 1, replay_attacks_prevented: 1}}
        
      {:error, _} ->
        {result, %{verification_failures: 1}}
    end
    
    new_stats = Enum.reduce(stats_update, state.stats, fn {key, inc}, stats ->
      Map.update!(stats, key, &(&1 + inc))
    end)
    
    {:reply, reply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:validate_nonce, nonce}, _from, state) do
    case BloomFilter.add(state.bloom_filter, nonce) do
      {:ok, :new} -> {:reply, :ok, state}
      {:ok, :duplicate} -> {:reply, {:error, :duplicate_nonce}, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    bloom_stats = BloomFilter.stats(state.bloom_filter)
    
    stats = Map.merge(state.stats, %{
      bloom_filter: bloom_stats,
      signature_algorithm: state.signature_algorithm
    })
    
    {:reply, stats, state}
  end

  # Private functions

  defp sign_message_internal(message, state) do
    # Create canonical representation for signing
    canonical = canonicalize_message(message)
    
    signature = case state.signature_algorithm do
      :hmac ->
        CryptoUtils.hmac_sign(canonical, state.signing_key)
        
      :rsa ->
        {:ok, sig} = CryptoUtils.rsa_sign(canonical, state.signing_key)
        sig
    end
    
    %{message | signature: signature}
  end

  defp verify_message_internal(%Message{} = message, state) do
    with :ok <- verify_timestamp(message.timestamp),
         :ok <- verify_nonce(message.nonce, state),
         :ok <- verify_signature(message, state) do
      {:ok, message.payload}
    end
  end
  defp verify_message_internal(_, _state), do: {:error, :invalid_message_format}

  defp verify_timestamp(timestamp) do
    now = System.os_time(:millisecond)
    age = now - timestamp
    
    cond do
      age < -@max_clock_skew_ms ->
        {:error, :future_timestamp}
        
      age > @max_message_age_ms ->
        {:error, :expired_message}
        
      true ->
        :ok
    end
  end

  defp verify_nonce(nonce, state) do
    case BloomFilter.add(state.bloom_filter, nonce) do
      {:ok, :new} -> :ok
      {:ok, :duplicate} -> {:error, :replay_attack}
    end
  end

  defp verify_signature(%Message{signature: nil}, _state), do: {:error, :missing_signature}
  defp verify_signature(message, state) do
    canonical = canonicalize_message(%{message | signature: nil})
    
    case state.signature_algorithm do
      :hmac ->
        if CryptoUtils.hmac_verify(canonical, message.signature, state.verification_key) do
          :ok
        else
          {:error, :invalid_signature}
        end
        
      :rsa ->
        case CryptoUtils.rsa_verify(canonical, message.signature, state.verification_key) do
          {:ok, true} -> :ok
          {:ok, false} -> {:error, :invalid_signature}
          {:error, _} -> {:error, :signature_verification_failed}
        end
    end
  end

  defp canonicalize_message(message) do
    # Create deterministic binary representation
    fields = [
      message.payload,
      message.nonce,
      message.timestamp,
      message.sender_id || ""
    ]
    
    # Use erlang term_to_binary for consistent serialization
    :erlang.term_to_binary(fields, [:deterministic])
  end
end