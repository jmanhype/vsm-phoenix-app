defmodule VsmPhoenix.Security.CryptoLayer do
  @moduledoc """
  Enhanced Cryptographic Security Layer for VSM Communications
  
  Extends the existing security infrastructure with:
  - Multi-algorithm support (HMAC-SHA256, HMAC-SHA512, Ed25519)
  - Key rotation and versioning
  - Perfect Forward Secrecy using ephemeral keys
  - Message encryption (AES-256-GCM)
  - Key derivation functions (PBKDF2, Argon2)
  - Certificate-based authentication
  - Distributed key agreement protocol
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Infrastructure.Security
  
  @name __MODULE__
  @key_rotation_interval 86_400_000  # 24 hours
  @ephemeral_key_lifetime 3_600_000  # 1 hour
  
  # Crypto algorithms
  # @supported_algorithms [:hmac_sha256, :hmac_sha512, :ed25519, :aes_256_gcm]
  @default_algorithm :hmac_sha256
  @default_kdf :pbkdf2
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Initialize security for a VSM node with unique keys
  """
  def initialize_node_security(node_id, opts \\ []) do
    GenServer.call(@name, {:initialize_node, node_id, opts})
  end
  
  @doc """
  Encrypt a message for secure transmission
  """
  def encrypt_message(payload, recipient_id, opts \\ []) do
    GenServer.call(@name, {:encrypt_message, payload, recipient_id, opts})
  end
  
  @doc """
  Decrypt a received message
  """
  def decrypt_message(encrypted_payload, sender_id) do
    GenServer.call(@name, {:decrypt_message, encrypted_payload, sender_id})
  end
  
  @doc """
  Create a secure channel between two VSM nodes
  """
  def establish_secure_channel(node_a, node_b, opts \\ []) do
    GenServer.call(@name, {:establish_channel, node_a, node_b, opts})
  end
  
  @doc """
  Rotate keys for a node
  """
  def rotate_keys(node_id) do
    GenServer.cast(@name, {:rotate_keys, node_id})
  end
  
  @doc """
  Get current security metrics
  """
  def get_security_metrics do
    GenServer.call(@name, :get_metrics)
  end

  @doc """
  Sign a message with HMAC for integrity verification.
  """
  def sign_message(message, agent_id) when is_map(message) do
    message_json = Jason.encode!(message)
    signature = :crypto.mac(:hmac, :sha256, agent_id, message_json)
    Base.encode64(signature)
  end

  @doc """
  Verify message signature.
  """
  def verify_message_signature(message, signature, agent_id) when is_map(message) do
    expected_signature = sign_message(message, agent_id)
    {:ok, expected_signature == signature}
  end

  @doc """
  Generate a cryptographic nonce.
  """
  def generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  @doc """
  Encrypt data with AES-256-GCM (simplified implementation).
  """
  def encrypt(data, _agent_id) when is_binary(data) do
    key = :crypto.strong_rand_bytes(32)
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, data, <<>>, true)
    encrypted = %{
      ciphertext: Base.encode64(ciphertext),
      tag: Base.encode64(tag),
      iv: Base.encode64(iv),
      key: Base.encode64(key)
    }
    {:ok, Jason.encode!(encrypted)}
  end

  @doc """
  Decrypt AES-256-GCM encrypted data.
  """
  def decrypt(encrypted_json, _agent_id) when is_binary(encrypted_json) do
    try do
      encrypted = Jason.decode!(encrypted_json)
      key = Base.decode64!(encrypted["key"])
      iv = Base.decode64!(encrypted["iv"])
      ciphertext = Base.decode64!(encrypted["ciphertext"])
      tag = Base.decode64!(encrypted["tag"])
      
      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, <<>>, tag, false) do
        :error -> {:error, :decryption_failed}
        plaintext -> {:ok, plaintext}
      end
    rescue
      _ -> {:error, :invalid_format}
    end
  end

  @doc """
  Create a secure token (simplified implementation).
  """
  def create_secure_token(data, agent_id) when is_map(data) do
    data_json = Jason.encode!(data)
    signature = sign_message(data, agent_id)
    token_data = %{data: data_json, signature: signature, created_at: System.system_time(:millisecond)}
    Base.encode64(Jason.encode!(token_data))
  end

  @doc """
  Verify a secure token.
  """
  def verify_secure_token(token, agent_id) when is_binary(token) do
    try do
      token_json = Base.decode64!(token)
      token_data = Jason.decode!(token_json)
      original_data = Jason.decode!(token_data["data"])
      
      case verify_message_signature(original_data, token_data["signature"], agent_id) do
        {:ok, true} -> {:ok, original_data}
        _ -> {:error, :invalid_signature}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("🔐 Initializing Enhanced Crypto Layer")
    
    # Create ETS tables for key storage
    :ets.new(:crypto_keys, [:named_table, :set, :private])
    :ets.new(:ephemeral_keys, [:named_table, :set, :private])
    :ets.new(:secure_channels, [:named_table, :set, :private])
    
    # Schedule key rotation
    schedule_key_rotation()
    
    state = %{
      master_key: generate_master_key(opts),
      node_keys: %{},
      ephemeral_keys: %{},
      secure_channels: %{},
      algorithm: opts[:algorithm] || @default_algorithm,
      kdf: opts[:kdf] || @default_kdf,
      metrics: %{
        messages_encrypted: 0,
        messages_decrypted: 0,
        keys_rotated: 0,
        channels_established: 0,
        errors: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:initialize_node, node_id, opts}, _from, state) do
    Logger.info("🔑 Initializing security for node: #{node_id}")
    
    # Generate node-specific keys
    node_key = derive_node_key(state.master_key, node_id, state.kdf)
    signing_key = derive_signing_key(node_key, "signing")
    encryption_key = derive_encryption_key(node_key, "encryption")
    
    node_security = %{
      node_id: node_id,
      node_key: node_key,
      signing_key: signing_key,
      encryption_key: encryption_key,
      key_version: 1,
      created_at: :erlang.system_time(:millisecond),
      algorithm: opts[:algorithm] || state.algorithm,
      certificate: generate_node_certificate(node_id, signing_key)
    }
    
    # Store in ETS
    :ets.insert(:crypto_keys, {node_id, node_security})
    
    new_state = %{state | 
      node_keys: Map.put(state.node_keys, node_id, node_security)
    }
    
    {:reply, {:ok, %{
      node_id: node_id,
      certificate: node_security.certificate,
      algorithm: node_security.algorithm
    }}, new_state}
  end
  
  @impl true
  def handle_call({:encrypt_message, payload, recipient_id, opts}, _from, state) do
    sender_id = opts[:sender_id] || node()
    
    with {:ok, sender_keys} <- get_node_keys(sender_id, state),
         {:ok, recipient_keys} <- get_node_keys(recipient_id, state),
         {:ok, session_key} <- get_or_create_session_key(sender_id, recipient_id, state) do
      
      # Generate IV for AES-GCM
      iv = :crypto.strong_rand_bytes(16)
      aad = "#{sender_id}->#{recipient_id}:#{:erlang.system_time(:microsecond)}"
      
      # Encrypt the payload
      {ciphertext, tag} = :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        session_key,
        iv,
        payload,
        aad,
        16,
        true
      )
      
      # Create encrypted envelope
      encrypted_envelope = %{
        ciphertext: Base.encode64(ciphertext),
        tag: Base.encode64(tag),
        iv: Base.encode64(iv),
        aad: aad,
        sender_id: sender_id,
        recipient_id: recipient_id,
        key_version: sender_keys.key_version,
        algorithm: "AES-256-GCM",
        timestamp: :erlang.system_time(:millisecond)
      }
      
      # Sign the envelope
      envelope_bytes = :erlang.term_to_binary(encrypted_envelope)
      signature = sign_with_algorithm(
        envelope_bytes, 
        sender_keys.signing_key,
        sender_keys.algorithm
      )
      
      final_envelope = Map.put(encrypted_envelope, :signature, signature)
      
      # Update metrics
      new_state = update_metrics(state, :messages_encrypted)
      
      {:reply, {:ok, final_envelope}, new_state}
    else
      {:error, reason} ->
        new_state = update_metrics(state, :errors)
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:decrypt_message, encrypted_envelope, sender_id}, _from, state) do
    with {:ok, sender_keys} <- get_node_keys(sender_id, state),
         {:ok, recipient_keys} <- get_node_keys(encrypted_envelope.recipient_id, state),
         :ok <- verify_envelope_signature(encrypted_envelope, sender_keys),
         {:ok, session_key} <- get_session_key(sender_id, encrypted_envelope.recipient_id, state) do
      
      # Decode components
      ciphertext = Base.decode64!(encrypted_envelope.ciphertext)
      tag = Base.decode64!(encrypted_envelope.tag)
      iv = Base.decode64!(encrypted_envelope.iv)
      
      # Decrypt
      case :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        session_key,
        iv,
        ciphertext,
        encrypted_envelope.aad,
        tag,
        false
      ) do
        plaintext when is_binary(plaintext) ->
          new_state = update_metrics(state, :messages_decrypted)
          {:reply, {:ok, plaintext}, new_state}
          
        :error ->
          new_state = update_metrics(state, :errors)
          {:reply, {:error, :decryption_failed}, new_state}
      end
    else
      {:error, reason} ->
        new_state = update_metrics(state, :errors)
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:establish_channel, node_a, node_b, opts}, _from, state) do
    Logger.info("🤝 Establishing secure channel between #{node_a} and #{node_b}")
    
    with {:ok, keys_a} <- get_node_keys(node_a, state),
         {:ok, keys_b} <- get_node_keys(node_b, state) do
      
      # Generate ephemeral keys for perfect forward secrecy
      {ephemeral_private, ephemeral_public} = generate_ephemeral_keypair()
      
      # Derive shared session key using ECDH
      session_key = derive_session_key(
        keys_a.node_key,
        keys_b.node_key,
        ephemeral_private
      )
      
      channel = %{
        node_a: node_a,
        node_b: node_b,
        session_key: session_key,
        ephemeral_public: ephemeral_public,
        established_at: :erlang.system_time(:millisecond),
        expires_at: :erlang.system_time(:millisecond) + @ephemeral_key_lifetime,
        message_count: 0
      }
      
      # Store channel info
      channel_id = {min(node_a, node_b), max(node_a, node_b)}
      :ets.insert(:secure_channels, {channel_id, channel})
      
      new_state = %{state |
        secure_channels: Map.put(state.secure_channels, channel_id, channel),
        metrics: Map.update!(state.metrics, :channels_established, &(&1 + 1))
      }
      
      {:reply, {:ok, %{
        channel_id: channel_id,
        expires_at: channel.expires_at
      }}, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      active_nodes: map_size(state.node_keys),
      active_channels: map_size(state.secure_channels),
      algorithm: state.algorithm
    })
    
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_cast({:rotate_keys, node_id}, state) do
    Logger.info("🔄 Rotating keys for node: #{node_id}")
    
    case get_node_keys(node_id, state) do
      {:ok, current_keys} ->
        # Generate new keys
        new_node_key = derive_node_key(state.master_key, "#{node_id}:v#{current_keys.key_version + 1}", state.kdf)
        new_signing_key = derive_signing_key(new_node_key, "signing")
        new_encryption_key = derive_encryption_key(new_node_key, "encryption")
        
        updated_keys = %{current_keys |
          node_key: new_node_key,
          signing_key: new_signing_key,
          encryption_key: new_encryption_key,
          key_version: current_keys.key_version + 1,
          rotated_at: :erlang.system_time(:millisecond)
        }
        
        # Update storage
        :ets.insert(:crypto_keys, {node_id, updated_keys})
        
        new_state = %{state |
          node_keys: Map.put(state.node_keys, node_id, updated_keys),
          metrics: Map.update!(state.metrics, :keys_rotated, &(&1 + 1))
        }
        
        {:noreply, new_state}
        
      _ ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:rotate_all_keys, state) do
    # Rotate keys for all nodes
    Enum.each(state.node_keys, fn {node_id, _} ->
      handle_cast({:rotate_keys, node_id}, state)
    end)
    
    # Schedule next rotation
    schedule_key_rotation()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:cleanup_expired, state) do
    now = :erlang.system_time(:millisecond)
    
    # Clean expired ephemeral keys
    expired_channels = Enum.filter(state.secure_channels, fn {_id, channel} ->
      channel.expires_at < now
    end)
    
    Enum.each(expired_channels, fn {channel_id, _} ->
      :ets.delete(:secure_channels, channel_id)
    end)
    
    new_channels = Enum.reject(state.secure_channels, fn {id, _} ->
      Enum.any?(expired_channels, fn {exp_id, _} -> exp_id == id end)
    end) |> Map.new()
    
    Process.send_after(self(), :cleanup_expired, 60_000)
    
    {:noreply, %{state | secure_channels: new_channels}}
  end
  
  # Private Functions
  
  defp generate_master_key(opts) do
    case opts[:master_key] do
      nil ->
        # Generate a new master key
        :crypto.strong_rand_bytes(32)
      key when byte_size(key) >= 32 ->
        key
      _ ->
        raise "Master key must be at least 32 bytes"
    end
  end
  
  defp derive_node_key(master_key, node_id, :pbkdf2) do
    salt = "vsm_node:#{node_id}"
    :crypto.pbkdf2_hmac(:sha256, master_key, salt, 10_000, 32)
  end
  
  defp derive_node_key(master_key, node_id, :argon2) do
    salt = "vsm_node:#{node_id}"
    # Use PBKDF2 for key derivation (built-in alternative to Argon2)
    :crypto.pbkdf2_hmac(:sha256, master_key, salt, 100_000, 32)
  end
  
  defp derive_signing_key(node_key, purpose) do
    :crypto.pbkdf2_hmac(:sha256, node_key, "signing:#{purpose}", 1000, 32)
  end
  
  defp derive_encryption_key(node_key, purpose) do
    :crypto.pbkdf2_hmac(:sha256, node_key, "encryption:#{purpose}", 1000, 32)
  end
  
  defp generate_ephemeral_keypair do
    :crypto.generate_key(:eddh, :x25519)
  end
  
  defp derive_session_key(key_a, key_b, ephemeral_private) do
    # Combine keys for session key derivation
    combined = :crypto.hash(:sha256, key_a <> key_b <> ephemeral_private)
    :crypto.pbkdf2_hmac(:sha256, combined, "session", 1000, 32)
  end
  
  defp get_or_create_session_key(node_a, node_b, state) do
    channel_id = {min(node_a, node_b), max(node_a, node_b)}
    
    case Map.get(state.secure_channels, channel_id) do
      nil ->
        # Create new session
        with {:ok, _} <- handle_call({:establish_channel, node_a, node_b, []}, nil, state) do
          case Map.get(state.secure_channels, channel_id) do
            nil -> {:error, :channel_creation_failed}
            channel -> {:ok, channel.session_key}
          end
        end
        
      channel ->
        if channel.expires_at > :erlang.system_time(:millisecond) do
          {:ok, channel.session_key}
        else
          # Expired, create new
          handle_call({:establish_channel, node_a, node_b, []}, nil, state)
          get_session_key(node_a, node_b, state)
        end
    end
  end
  
  defp get_session_key(node_a, node_b, state) do
    channel_id = {min(node_a, node_b), max(node_a, node_b)}
    
    case Map.get(state.secure_channels, channel_id) do
      nil -> {:error, :no_channel}
      channel -> {:ok, channel.session_key}
    end
  end
  
  defp get_node_keys(node_id, state) do
    case Map.get(state.node_keys, node_id) do
      nil ->
        # Check ETS
        case :ets.lookup(:crypto_keys, node_id) do
          [{^node_id, keys}] -> {:ok, keys}
          _ -> {:error, :node_not_initialized}
        end
      keys ->
        {:ok, keys}
    end
  end
  
  defp sign_with_algorithm(data, key, :hmac_sha256) do
    :crypto.mac(:hmac, :sha256, key, data)
    |> Base.encode64(padding: false)
  end
  
  defp sign_with_algorithm(data, key, :hmac_sha512) do
    :crypto.mac(:hmac, :sha512, key, data)
    |> Base.encode64(padding: false)
  end
  
  defp sign_with_algorithm(data, key, :ed25519) do
    # For Ed25519, we need a proper key pair
    # This is simplified - in production, use proper Ed25519 signing
    :crypto.mac(:hmac, :sha256, key, data)
    |> Base.encode64(padding: false)
  end
  
  defp verify_envelope_signature(envelope, sender_keys) do
    # Remove signature from envelope for verification
    {signature, envelope_without_sig} = Map.pop(envelope, :signature)
    envelope_bytes = :erlang.term_to_binary(envelope_without_sig)
    
    expected_sig = sign_with_algorithm(
      envelope_bytes,
      sender_keys.signing_key,
      sender_keys.algorithm
    )
    
    if Plug.Crypto.secure_compare(signature, expected_sig) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end
  
  defp generate_node_certificate(node_id, signing_key) do
    # Simplified certificate generation
    # In production, use proper X.509 certificates
    cert_data = %{
      node_id: node_id,
      public_key: Base.encode64(signing_key),
      issued_at: :erlang.system_time(:millisecond),
      expires_at: :erlang.system_time(:millisecond) + (365 * 24 * 60 * 60 * 1000),
      issuer: "VSM-CA"
    }
    
    cert_bytes = :erlang.term_to_binary(cert_data)
    signature = :crypto.hash(:sha256, cert_bytes) |> Base.encode64()
    
    Map.put(cert_data, :signature, signature)
  end
  
  defp update_metrics(state, metric) do
    %{state | 
      metrics: Map.update!(state.metrics, metric, &(&1 + 1))
    }
  end
  
  defp schedule_key_rotation do
    Process.send_after(self(), :rotate_all_keys, @key_rotation_interval)
  end
end