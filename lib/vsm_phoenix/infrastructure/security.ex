defmodule VsmPhoenix.Infrastructure.Security do
  @moduledoc """
  Comprehensive security layer for VSM Phoenix with cryptographic nonce validation,
  HMAC SHA256 message signing, and replay attack protection.
  
  Features:
  - Cryptographic nonce generation and verification
  - HMAC SHA256 message signing and verification
  - Replay attack protection using ETS-based nonce storage with TTL
  - Timestamp validation to prevent old message replay
  - Automatic cleanup of expired nonces
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @nonce_table :security_nonce_store
  @nonce_ttl_ms 300_000  # 5 minutes
  @timestamp_tolerance_ms 60_000  # 1 minute
  @cleanup_interval_ms 60_000  # Clean every minute
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Generate a cryptographically secure nonce
  """
  def generate_nonce do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
  end
  
  @doc """
  Generate HMAC SHA256 signature for a message
  """
  def sign_message(message, secret_key) when is_binary(message) and is_binary(secret_key) do
    :crypto.mac(:hmac, :sha256, secret_key, message)
    |> Base.encode64(padding: false)
  end
  
  @doc """
  Verify HMAC SHA256 signature
  """
  def verify_signature(message, signature, secret_key) when is_binary(message) and is_binary(signature) and is_binary(secret_key) do
    expected_signature = sign_message(message, secret_key)
    Plug.Crypto.secure_compare(signature, expected_signature)
  end
  
  @doc """
  Wrap a message with security envelope including nonce, timestamp, and signature
  """
  def wrap_secure_message(payload, secret_key, opts \\ []) do
    nonce = generate_nonce()
    timestamp = :erlang.system_time(:millisecond)
    sender_id = Keyword.get(opts, :sender_id, node())
    
    # Create canonical message for signing
    canonical_message = create_canonical_message(payload, nonce, timestamp, sender_id)
    signature = sign_message(canonical_message, secret_key)
    
    # Store nonce to prevent replay
    store_nonce(nonce, timestamp)
    
    %{
      payload: payload,
      security: %{
        nonce: nonce,
        timestamp: timestamp,
        sender_id: sender_id,
        signature: signature,
        algorithm: "HMAC-SHA256"
      }
    }
  end
  
  @doc """
  Unwrap and verify a secure message
  Returns {:ok, payload} or {:error, reason}
  """
  def unwrap_secure_message(wrapped_message, secret_key) do
    with {:ok, security} <- validate_security_fields(wrapped_message),
         :ok <- validate_timestamp(security.timestamp),
         :ok <- validate_nonce(security.nonce),
         :ok <- validate_signature(wrapped_message, security, secret_key) do
      {:ok, wrapped_message.payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Check if a nonce has been used (for replay detection)
  """
  def nonce_used?(nonce) do
    GenServer.call(@name, {:check_nonce, nonce})
  end
  
  @doc """
  Get security metrics
  """
  def get_metrics do
    GenServer.call(@name, :get_metrics)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🔐 Starting Security Infrastructure...")
    
    # Create ETS table for nonce storage
    :ets.new(@nonce_table, [:set, :public, :named_table, {:read_concurrency, true}])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    state = %{
      started_at: :erlang.system_time(:millisecond),
      metrics: %{
        messages_signed: 0,
        messages_verified: 0,
        replay_attempts_blocked: 0,
        expired_nonces_cleaned: 0,
        invalid_signatures: 0,
        timestamp_violations: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:check_nonce, nonce}, _from, state) do
    exists = case :ets.lookup(@nonce_table, nonce) do
      [{^nonce, _timestamp}] -> true
      [] -> false
    end
    
    {:reply, exists, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      active_nonces: :ets.info(@nonce_table, :size),
      uptime_ms: :erlang.system_time(:millisecond) - state.started_at
    })
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_info(:cleanup_expired_nonces, state) do
    cleaned_count = cleanup_expired_nonces()
    
    new_metrics = Map.update(state.metrics, :expired_nonces_cleaned, cleaned_count, &(&1 + cleaned_count))
    
    schedule_cleanup()
    {:noreply, %{state | metrics: new_metrics}}
  end
  
  # Private Functions
  
  defp validate_security_fields(%{security: security} = message) when is_map(security) do
    required_fields = [:nonce, :timestamp, :signature, :sender_id]
    
    if Enum.all?(required_fields, &Map.has_key?(security, &1)) do
      {:ok, security}
    else
      {:error, :missing_security_fields}
    end
  end
  defp validate_security_fields(_), do: {:error, :invalid_security_envelope}
  
  defp validate_timestamp(timestamp) when is_integer(timestamp) do
    now = :erlang.system_time(:millisecond)
    age = abs(now - timestamp)
    
    if age <= @timestamp_tolerance_ms do
      :ok
    else
      update_metric(:timestamp_violations)
      {:error, :timestamp_too_old}
    end
  end
  defp validate_timestamp(_), do: {:error, :invalid_timestamp}
  
  defp validate_nonce(nonce) when is_binary(nonce) do
    case :ets.lookup(@nonce_table, nonce) do
      [{^nonce, _}] ->
        update_metric(:replay_attempts_blocked)
        {:error, :nonce_already_used}
      [] ->
        # Store nonce with current timestamp
        store_nonce(nonce, :erlang.system_time(:millisecond))
        :ok
    end
  end
  defp validate_nonce(_), do: {:error, :invalid_nonce}
  
  defp validate_signature(wrapped_message, security, secret_key) do
    # Recreate canonical message
    canonical_message = create_canonical_message(
      wrapped_message.payload,
      security.nonce,
      security.timestamp,
      security.sender_id
    )
    
    if verify_signature(canonical_message, security.signature, secret_key) do
      update_metric(:messages_verified)
      :ok
    else
      update_metric(:invalid_signatures)
      {:error, :invalid_signature}
    end
  end
  
  defp create_canonical_message(payload, nonce, timestamp, sender_id) do
    # Create deterministic message for signing
    # Using Jason to ensure consistent JSON encoding
    payload_json = Jason.encode!(payload, keys: :atoms!)
    
    "#{nonce}|#{timestamp}|#{sender_id}|#{payload_json}"
  end
  
  defp store_nonce(nonce, timestamp) do
    :ets.insert(@nonce_table, {nonce, timestamp})
    update_metric(:messages_signed)
  end
  
  defp cleanup_expired_nonces do
    now = :erlang.system_time(:millisecond)
    cutoff = now - @nonce_ttl_ms
    
    # Find and delete expired nonces
    expired = :ets.select(@nonce_table, [
      {{'$1', '$2'}, [{:'<', '$2', cutoff}], ['$1']}
    ])
    
    Enum.each(expired, fn nonce ->
      :ets.delete(@nonce_table, nonce)
    end)
    
    length(expired)
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired_nonces, @cleanup_interval_ms)
  end
  
  defp update_metric(metric) do
    GenServer.cast(@name, {:update_metric, metric})
  end
  
  @impl true
  def handle_cast({:update_metric, metric}, state) do
    new_metrics = Map.update(state.metrics, metric, 1, &(&1 + 1))
    {:noreply, %{state | metrics: new_metrics}}
  end
  
  # AMQP Integration Functions
  
  @doc """
  Wrap AMQP command with security layer
  """
  def wrap_amqp_command(command, secret_key, opts \\ []) do
    # Add command metadata
    enhanced_command = Map.merge(command, %{
      command_id: generate_command_id(),
      issued_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    wrap_secure_message(enhanced_command, secret_key, opts)
  end
  
  @doc """
  Unwrap and verify AMQP command
  """
  def unwrap_amqp_command(wrapped_command, secret_key) do
    case unwrap_secure_message(wrapped_command, secret_key) do
      {:ok, command} ->
        # Additional AMQP-specific validation could go here
        {:ok, command}
      error ->
        error
    end
  end
  
  defp generate_command_id do
    "CMD-#{:erlang.system_time(:millisecond)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end
  
  # Key Management Functions
  
  @doc """
  Generate a secure secret key
  """
  def generate_secret_key do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
  end
  
  @doc """
  Derive a key from a password using PBKDF2
  """
  def derive_key_from_password(password, salt \\ nil) do
    salt = salt || :crypto.strong_rand_bytes(16)
    iterations = 100_000
    
    key = :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, 32)
    
    %{
      key: Base.encode64(key, padding: false),
      salt: Base.encode64(salt, padding: false),
      algorithm: "PBKDF2-HMAC-SHA256",
      iterations: iterations
    }
  end
end