defmodule VsmPhoenix.Infrastructure.SecurityIntegration do
  @moduledoc """
  Integration module that demonstrates how to use the security layer
  with existing VSM components.
  
  Provides secure wrappers for:
  - System commands
  - Inter-system communication
  - Audit trails with cryptographic proof
  - Secure telemetry events
  """
  
  alias VsmPhoenix.Infrastructure.Security
  alias VsmPhoenix.AMQP.SecureCommandRouter
  alias Phoenix.PubSub
  
  require Logger
  
  # System Command Security
  
  @doc """
  Send a secure command from one system to another
  """
  def send_secure_system_command(from_system, to_system, command, opts \\ []) do
    # Get system-specific key (in production, each system would have its own key)
    secret_key = get_system_key(from_system)
    
    # Build command with metadata
    full_command = %{
      from: from_system,
      to: to_system,
      command: command,
      correlation_id: generate_correlation_id()
    }
    
    # Send through secure router
    SecureCommandRouter.send_secure_command(full_command, Keyword.put(opts, :sender_id, from_system))
  end
  
  @doc """
  Secure wrapper for Queen decisions
  """
  def secure_queen_decision(decision_params) do
    secret_key = get_system_key(:system5)
    
    # Wrap decision with security
    wrapped = Security.wrap_secure_message(decision_params, secret_key, sender_id: :system5_queen)
    
    # Log for audit trail
    log_secure_event(:queen_decision, wrapped)
    
    wrapped
  end
  
  @doc """
  Secure wrapper for Control resource allocations
  """
  def secure_resource_allocation(allocation_params) do
    secret_key = get_system_key(:system3)
    
    wrapped = Security.wrap_secure_message(allocation_params, secret_key, sender_id: :system3_control)
    
    # Broadcast secure allocation
    PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:secure:allocations",
      {:secure_allocation, wrapped}
    )
    
    wrapped
  end
  
  @doc """
  Verify and process secure inter-system message
  """
  def process_secure_message(wrapped_message, receiving_system) do
    secret_key = get_system_key(receiving_system)
    
    case Security.unwrap_secure_message(wrapped_message, secret_key) do
      {:ok, message} ->
        # Log successful verification
        log_secure_event(:message_verified, %{
          from: message[:from],
          to: receiving_system,
          correlation_id: message[:correlation_id]
        })
        
        {:ok, message}
        
      {:error, reason} ->
        # Log security failure
        log_security_failure(reason, wrapped_message, receiving_system)
        {:error, reason}
    end
  end
  
  # Audit Trail with Cryptographic Proof
  
  @doc """
  Create cryptographically signed audit entry
  """
  def create_secure_audit_entry(event_type, event_data, metadata \\ %{}) do
    audit_key = get_audit_key()
    
    audit_entry = %{
      event_type: event_type,
      event_data: event_data,
      metadata: metadata,
      timestamp: :erlang.system_time(:millisecond),
      node: node()
    }
    
    # Create signed audit entry
    Security.wrap_secure_message(audit_entry, audit_key, sender_id: :audit_system)
  end
  
  @doc """
  Verify audit trail integrity
  """
  def verify_audit_trail(audit_entries) do
    audit_key = get_audit_key()
    
    results = Enum.map(audit_entries, fn entry ->
      case Security.unwrap_secure_message(entry, audit_key) do
        {:ok, _} -> {:valid, entry}
        {:error, reason} -> {:invalid, entry, reason}
      end
    end)
    
    %{
      total: length(audit_entries),
      valid: Enum.count(results, fn {status, _} -> status == :valid end),
      invalid: Enum.filter(results, fn {status, _, _} -> status == :invalid end)
    }
  end
  
  # Secure Telemetry
  
  @doc """
  Emit secure telemetry event with cryptographic proof
  """
  def emit_secure_telemetry(event_name, measurements, metadata \\ %{}) do
    telemetry_key = get_telemetry_key()
    
    # Create telemetry packet
    packet = %{
      event: event_name,
      measurements: measurements,
      metadata: metadata,
      emitted_at: :erlang.system_time(:millisecond)
    }
    
    # Sign the packet
    wrapped = Security.wrap_secure_message(packet, telemetry_key, sender_id: :telemetry_system)
    
    # Emit both regular and secure versions
    :telemetry.execute(event_name, measurements, metadata)
    :telemetry.execute([:vsm, :secure, :telemetry], %{}, wrapped)
    
    wrapped
  end
  
  # Key Management Helpers
  
  defp get_system_key(system) do
    # In production, this would retrieve system-specific keys from secure storage
    base_key = System.get_env("VSM_MASTER_KEY", "development-key-do-not-use-in-production")
    
    # Derive system-specific key
    system_salt = "vsm-#{system}" |> :crypto.hash(:sha256)
    :crypto.pbkdf2_hmac(:sha256, base_key, system_salt, 10_000, 32)
    |> Base.encode64(padding: false)
  end
  
  defp get_audit_key do
    get_system_key(:audit)
  end
  
  defp get_telemetry_key do
    get_system_key(:telemetry)
  end
  
  defp generate_correlation_id do
    "CORR-#{:erlang.system_time(:millisecond)}-#{:crypto.strong_rand_bytes(4) |> Base.encode16()}"
  end
  
  defp log_secure_event(event_type, data) do
    Logger.info("🔐 Secure Event: #{event_type}", secure_event: data)
  end
  
  defp log_security_failure(reason, wrapped_message, system) do
    Logger.error("🚨 Security Failure: #{reason} for system #{system}", 
      security_failure: %{
        reason: reason,
        system: system,
        timestamp: :erlang.system_time(:millisecond)
      }
    )
  end
  
  # Example Usage Functions
  
  @doc """
  Example: Secure command from Queen to Control
  """
  def example_queen_to_control_command do
    command = %{
      type: :adjust_resources,
      parameters: %{
        system1_allocation: 0.4,
        system2_allocation: 0.3,
        system3_allocation: 0.3
      },
      priority: :high
    }
    
    send_secure_system_command(:system5, :system3, command)
  end
  
  @doc """
  Example: Secure algedonic signal
  """
  def example_secure_algedonic_signal(signal_type, intensity) do
    signal = %{
      type: signal_type,
      intensity: intensity,
      source: :system1,
      timestamp: DateTime.utc_now()
    }
    
    # Get algedonic channel key
    key = get_system_key(:algedonic)
    
    Security.wrap_secure_message(signal, key, sender_id: :algedonic_channel)
  end
end