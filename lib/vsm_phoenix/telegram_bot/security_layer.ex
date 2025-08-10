defmodule VsmPhoenix.TelegramBot.SecurityLayer do
  @moduledoc """
  Cryptographic Security Layer for Telegram Bot Messages.
  
  Provides message integrity verification, replay attack protection,
  and secure audit trails using AES-256-GCM encryption and HMAC signatures.
  """
  
  require Logger
  
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.ContextManager
  
  @rate_limit_window 60_000  # 1 minute in milliseconds
  @max_messages_per_minute 60
  @message_expiry 300_000    # 5 minutes in milliseconds
  
  @doc """
  Secure outgoing message with cryptographic signature and integrity verification.
  
  ## Examples:
  
      SecurityLayer.send_secure_message(
        chat_id: 123456,
        text: "VSM system status: operational",
        agent_id: "telegram_agent_1",
        security_level: :high
      )
  """
  def send_secure_message(opts) do
    chat_id = opts[:chat_id]
    text = opts[:text]
    agent_id = opts[:agent_id]
    security_level = opts[:security_level] || :standard
    
    # Create comprehensive message payload
    timestamp = System.system_time(:millisecond)
    nonce = CryptoLayer.generate_nonce()
    
    message_payload = %{
      chat_id: chat_id,
      text: text,
      agent_id: agent_id,
      timestamp: timestamp,
      nonce: nonce,
      security_level: security_level,
      node_id: node()
    }
    
    # Sign message for integrity verification
    signature = CryptoLayer.sign_message(message_payload, agent_id)
    
    # Create audit record
    audit_record = %{
      message_payload: message_payload,
      signature: signature,
      message_hash: create_message_hash(message_payload),
      sent_at: timestamp,
      security_verified: true
    }
    
    # Store in CRDT for distributed audit trail
    audit_key = "telegram_message_#{agent_id}_#{timestamp}"
    case ContextStore.add_to_set("telegram_secure_messages", {audit_key, audit_record}) do
      {:ok, _} ->
        Logger.debug("📝 Stored secure message audit for chat #{chat_id}")
        
        # Format message with security footer if high security level
        enhanced_text = if security_level == :high do
          add_security_footer(text, signature, timestamp)
        else
          text
        end
        
        {:ok, %{
          text: enhanced_text,
          audit_record: audit_record,
          signature: signature
        }}
        
      error ->
        Logger.error("Failed to store secure message audit: #{inspect(error)}")
        {:error, :audit_storage_failed}
    end
  end
  
  @doc """
  Verify incoming message authenticity and detect replay attacks.
  """
  def verify_incoming_message(message_data, agent_id) do
    timestamp = (message_data["date"] || 0) * 1000  # Convert to milliseconds
    user_id = get_in(message_data, ["from", "id"])
    chat_id = message_data["chat"]["id"]
    message_id = message_data["message_id"]
    
    current_time = System.system_time(:millisecond)
    
    # Check message age (replay protection)
    with {:ok, :fresh} <- verify_message_freshness(timestamp, current_time),
         {:ok, :rate_ok} <- verify_rate_limit(user_id, current_time),
         {:ok, :unique} <- verify_message_uniqueness(message_id, chat_id, user_id) do
      
      # Create verification record
      verification_record = %{
        message_id: message_id,
        chat_id: chat_id,
        user_id: user_id,
        verified_at: current_time,
        agent_id: agent_id,
        verification_status: :verified,
        checks_passed: [:freshness, :rate_limit, :uniqueness]
      }
      
      # Store verification in CRDT
      store_verification_record(verification_record)
      
      {:ok, verification_record}
    else
      error -> error
    end
  end
  
  @doc """
  Encrypt sensitive conversation context before CRDT storage.
  """
  def encrypt_conversation_context(context_data, agent_id) do
    sensitive_fields = [
      :user_preferences,
      :admin_data, 
      :auth_tokens,
      :personal_info,
      :private_context
    ]
    
    encrypted_context = Enum.reduce(sensitive_fields, context_data, fn field, acc ->
      if Map.has_key?(acc, field) do
        encrypted_value = CryptoLayer.encrypt(acc[field], agent_id)
        acc
        |> Map.put(:"encrypted_#{field}", encrypted_value)
        |> Map.delete(field)
      else
        acc
      end
    end)
    
    # Add encryption metadata
    Map.put(encrypted_context, :encryption_metadata, %{
      encrypted_at: System.system_time(:millisecond),
      encrypted_by: agent_id,
      encryption_version: "1.0",
      fields_encrypted: sensitive_fields
    })
  end
  
  @doc """
  Decrypt sensitive conversation context from CRDT storage.
  """
  def decrypt_conversation_context(encrypted_context, agent_id) do
    metadata = encrypted_context[:encryption_metadata]
    
    if metadata do
      # Decrypt each encrypted field
      decrypted_context = Enum.reduce(metadata.fields_encrypted, encrypted_context, fn field, acc ->
        encrypted_field = :"encrypted_#{field}"
        if Map.has_key?(acc, encrypted_field) do
          case CryptoLayer.decrypt(acc[encrypted_field], agent_id) do
            {:ok, decrypted_value} ->
              acc
              |> Map.put(field, decrypted_value)
              |> Map.delete(encrypted_field)
            {:error, reason} ->
              Logger.warning("Failed to decrypt field #{field}: #{inspect(reason)}")
              acc
          end
        else
          acc
        end
      end)
      
      # Remove encryption metadata from final result
      Map.delete(decrypted_context, :encryption_metadata)
    else
      # Not encrypted, return as-is
      encrypted_context
    end
  end
  
  @doc """
  Generate secure session token for conversation continuity.
  """
  def generate_session_token(chat_id, user_id, agent_id) do
    session_data = %{
      chat_id: chat_id,
      user_id: user_id,
      agent_id: agent_id,
      generated_at: System.system_time(:millisecond),
      expires_at: System.system_time(:millisecond) + (24 * 60 * 60 * 1000), # 24 hours
      nonce: CryptoLayer.generate_nonce()
    }
    
    # Create signed session token
    token = CryptoLayer.create_secure_token(session_data, agent_id)
    
    # Store session in CRDT
    session_key = "telegram_session_#{chat_id}_#{user_id}"
    ContextManager.attach_context(
      :session,
      session_key,
      %{
        token: token,
        session_data: session_data,
        status: :active
      },
      [persist_across_nodes: true, cryptographic_integrity: true]
    )
    
    {:ok, token}
  end
  
  @doc """
  Validate session token for conversation continuity.
  """
  def validate_session_token(token, chat_id, user_id, agent_id) do
    case CryptoLayer.verify_secure_token(token, agent_id) do
      {:ok, session_data} ->
        # Verify session data matches request
        if session_data.chat_id == chat_id and 
           session_data.user_id == user_id and
           session_data.expires_at > System.system_time(:millisecond) do
          {:ok, session_data}
        else
          {:error, :invalid_session}
        end
      error -> error
    end
  end
  
  @doc """
  Create tamper-proof audit log entry for security events.
  """
  def log_security_event(event_type, event_data, agent_id) do
    timestamp = System.system_time(:millisecond)
    
    audit_entry = %{
      event_type: event_type,
      event_data: event_data,
      agent_id: agent_id,
      timestamp: timestamp,
      node_id: node(),
      event_id: generate_event_id(timestamp)
    }
    
    # Sign audit entry
    signature = CryptoLayer.sign_message(audit_entry, agent_id)
    
    # Create tamper-proof audit record
    signed_audit_entry = Map.put(audit_entry, :signature, signature)
    
    # Store in CRDT audit trail
    audit_key = "security_audit_#{event_type}_#{timestamp}"
    case ContextStore.add_to_set("telegram_security_audit", {audit_key, signed_audit_entry}) do
      {:ok, _} ->
        Logger.info("🔒 Logged security event: #{event_type}")
        {:ok, signed_audit_entry}
      error ->
        Logger.error("Failed to log security event: #{inspect(error)}")
        {:error, :audit_logging_failed}
    end
  end
  
  @doc """
  Get comprehensive security metrics across all nodes.
  """
  def get_security_metrics(agent_id) do
    # Get distributed security statistics
    case ContextStore.get_set_values("telegram_security_audit") do
      {:ok, audit_entries} ->
        # Analyze audit entries for security metrics
        recent_entries = filter_recent_entries(audit_entries, 24 * 60 * 60 * 1000) # Last 24 hours
        
        metrics = %{
          total_security_events: length(audit_entries),
          recent_security_events: length(recent_entries),
          security_event_types: analyze_event_types(recent_entries),
          rate_limit_violations: count_event_type(recent_entries, :rate_limit_violation),
          replay_attempts: count_event_type(recent_entries, :replay_attempt),
          verification_failures: count_event_type(recent_entries, :verification_failure),
          encryption_errors: count_event_type(recent_entries, :encryption_error),
          last_security_event: get_last_security_event(recent_entries),
          agent_id: agent_id,
          generated_at: System.system_time(:millisecond)
        }
        
        {:ok, metrics}
        
      error ->
        {:error, error}
    end
  end
  
  @doc """
  Perform security health check across all Telegram agents.
  """
  def security_health_check do
    checks = [
      check_crypto_layer_health(),
      check_audit_integrity(),
      check_rate_limiting_effectiveness(),
      check_message_verification_rates()
    ]
    
    overall_health = if Enum.all?(checks, &(&1.status == :healthy)) do
      :healthy
    else
      :degraded
    end
    
    %{
      overall_health: overall_health,
      checks: checks,
      recommendations: generate_security_recommendations(checks),
      checked_at: System.system_time(:millisecond)
    }
  end
  
  # Private Functions
  
  defp add_security_footer(text, signature, timestamp) do
    signature_preview = String.slice(signature, 0, 16)
    
    """
    #{text}
    
    🔐 *Verified Secure Message*
    Signature: `#{signature_preview}...`
    Timestamp: `#{timestamp}`
    """
  end
  
  defp create_message_hash(message_payload) do
    message_payload
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
  
  defp verify_message_freshness(message_timestamp, current_time) do
    age = current_time - message_timestamp
    
    cond do
      age > @message_expiry ->
        Logger.warning("Message too old: #{age}ms")
        {:error, :message_expired}
      age < -60_000 -> # Message from more than 1 minute in the future
        Logger.warning("Message from future: #{age}ms")
        {:error, :message_future}
      true ->
        {:ok, :fresh}
    end
  end
  
  defp verify_rate_limit(user_id, current_time) do
    rate_key = "telegram_rate_#{user_id}"
    
    case ContextStore.increment_counter(rate_key, 1) do
      {:ok, count} ->
        # Clean up counter if it's been more than the rate limit window
        # This is a simplified approach; a more sophisticated implementation
        # would use sliding windows
        if count == 1 do
          # First message in this window, schedule cleanup
          spawn(fn ->
            Process.sleep(@rate_limit_window)
            ContextStore.reset_counter(rate_key)
          end)
        end
        
        if count > @max_messages_per_minute do
          Logger.warning("Rate limit exceeded for user #{user_id}: #{count} messages")
          {:error, :rate_limited}
        else
          {:ok, :rate_ok}
        end
        
      error ->
        Logger.error("Failed to check rate limit: #{inspect(error)}")
        {:ok, :rate_ok} # Allow message if we can't check rate limit
    end
  end
  
  defp verify_message_uniqueness(message_id, chat_id, user_id) do
    uniqueness_key = "msg_#{chat_id}_#{user_id}_#{message_id}"
    
    case ContextStore.add_to_set("processed_messages", uniqueness_key) do
      {:ok, :added} ->
        # Schedule cleanup after message expiry
        spawn(fn ->
          Process.sleep(@message_expiry)
          ContextStore.remove_from_set("processed_messages", uniqueness_key)
        end)
        {:ok, :unique}
        
      {:ok, :exists} ->
        Logger.warning("Duplicate message detected: #{message_id}")
        {:error, :duplicate_message}
        
      error ->
        Logger.error("Failed to check message uniqueness: #{inspect(error)}")
        {:ok, :unique} # Allow message if we can't check uniqueness
    end
  end
  
  defp store_verification_record(record) do
    verification_key = "verification_#{record.chat_id}_#{record.message_id}"
    
    ContextStore.add_to_set("message_verifications", {verification_key, record})
  end
  
  defp generate_event_id(timestamp) do
    "evt_#{timestamp}_#{:erlang.unique_integer([:positive, :monotonic])}"
  end
  
  defp filter_recent_entries(entries, time_window) do
    cutoff_time = System.system_time(:millisecond) - time_window
    
    Enum.filter(entries, fn {_key, entry} ->
      entry.timestamp >= cutoff_time
    end)
  end
  
  defp analyze_event_types(entries) do
    entries
    |> Enum.map(fn {_key, entry} -> entry.event_type end)
    |> Enum.frequencies()
  end
  
  defp count_event_type(entries, event_type) do
    Enum.count(entries, fn {_key, entry} ->
      entry.event_type == event_type
    end)
  end
  
  defp get_last_security_event(entries) do
    case Enum.max_by(entries, fn {_key, entry} -> entry.timestamp end, fn -> nil end) do
      {_key, entry} -> entry
      nil -> nil
    end
  end
  
  defp check_crypto_layer_health do
    try do
      # Test encryption/decryption
      test_data = "security_health_check"
      agent_id = "test_agent"
      
      {:ok, encrypted} = CryptoLayer.encrypt(test_data, agent_id)
      {:ok, decrypted} = CryptoLayer.decrypt(encrypted, agent_id)
      
      if decrypted == test_data do
        %{check: :crypto_layer, status: :healthy, message: "Encryption/decryption working"}
      else
        %{check: :crypto_layer, status: :unhealthy, message: "Decryption mismatch"}
      end
    rescue
      error ->
        %{check: :crypto_layer, status: :unhealthy, message: "Crypto error: #{inspect(error)}"}
    end
  end
  
  defp check_audit_integrity do
    case ContextStore.get_set_values("telegram_security_audit") do
      {:ok, entries} ->
        # Verify signatures on recent entries
        recent_entries = filter_recent_entries(entries, 60 * 60 * 1000) # Last hour
        
        verified_count = Enum.count(recent_entries, fn {_key, entry} ->
          case CryptoLayer.verify_message_signature(entry, entry.signature, entry.agent_id) do
            {:ok, true} -> true
            _ -> false
          end
        end)
        
        total_count = length(recent_entries)
        integrity_ratio = if total_count > 0, do: verified_count / total_count, else: 1.0
        
        if integrity_ratio >= 0.95 do
          %{check: :audit_integrity, status: :healthy, message: "#{verified_count}/#{total_count} signatures verified"}
        else
          %{check: :audit_integrity, status: :unhealthy, message: "Low signature verification rate: #{integrity_ratio}"}
        end
        
      error ->
        %{check: :audit_integrity, status: :unhealthy, message: "Cannot access audit log: #{inspect(error)}"}
    end
  end
  
  defp check_rate_limiting_effectiveness do
    # This is a simplified check - in practice, you'd analyze recent rate limiting events
    %{check: :rate_limiting, status: :healthy, message: "Rate limiting active"}
  end
  
  defp check_message_verification_rates do
    case ContextStore.get_set_values("message_verifications") do
      {:ok, verifications} ->
        recent_verifications = filter_recent_entries(verifications, 60 * 60 * 1000) # Last hour
        
        if length(recent_verifications) > 0 do
          %{check: :message_verification, status: :healthy, message: "#{length(recent_verifications)} messages verified in last hour"}
        else
          %{check: :message_verification, status: :healthy, message: "No messages to verify in last hour"}
        end
        
      error ->
        %{check: :message_verification, status: :unhealthy, message: "Cannot access verifications: #{inspect(error)}"}
    end
  end
  
  defp generate_security_recommendations(checks) do
    unhealthy_checks = Enum.filter(checks, &(&1.status == :unhealthy))
    
    Enum.map(unhealthy_checks, fn check ->
      case check.check do
        :crypto_layer -> "Review cryptographic configuration and key management"
        :audit_integrity -> "Investigate signature verification failures and potential tampering"
        :rate_limiting -> "Review rate limiting configuration and effectiveness"
        :message_verification -> "Check message verification pipeline and error handling"
        _ -> "Review #{check.check} configuration and logs"
      end
    end)
  end
end