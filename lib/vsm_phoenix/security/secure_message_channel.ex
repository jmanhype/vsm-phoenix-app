defmodule VsmPhoenix.Security.SecureMessageChannel do
  @moduledoc """
  Secure message channel that integrates with VSM systems.
  Provides encrypted, authenticated messaging with audit trails.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.Security.{MessageValidator, AuditLogger, CryptoUtils}

  defstruct [
    :channel_id,
    :encryption_key,
    :participants,
    :message_validator,
    :audit_logger,
    :stats
  ]

  # Client API

  @doc """
  Starts a secure message channel.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Sends a secure message through the channel.
  """
  def send_message(channel, from_system, to_system, message, metadata \\ %{}) do
    GenServer.call(channel, {:send_message, from_system, to_system, message, metadata})
  end

  @doc """
  Receives and validates a secure message.
  """
  def receive_message(channel, encrypted_message, from_system) do
    GenServer.call(channel, {:receive_message, encrypted_message, from_system})
  end

  @doc """
  Adds a new participant to the secure channel.
  """
  def add_participant(channel, system_id, public_key) do
    GenServer.call(channel, {:add_participant, system_id, public_key})
  end

  @doc """
  Gets channel statistics and security metrics.
  """
  def get_stats(channel) do
    GenServer.call(channel, :get_stats)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    channel_id = opts[:channel_id] || generate_channel_id()
    
    state = %__MODULE__{
      channel_id: channel_id,
      encryption_key: opts[:encryption_key] || CryptoUtils.generate_key(),
      participants: opts[:participants] || %{},
      message_validator: opts[:message_validator] || MessageValidator,
      audit_logger: opts[:audit_logger] || AuditLogger,
      stats: %{
        messages_sent: 0,
        messages_received: 0,
        encryption_time_ms: 0,
        validation_time_ms: 0,
        failed_validations: 0
      }
    }
    
    # Log channel creation
    AuditLogger.log_event(state.audit_logger, :secure_channel_created, :info, %{
      channel_id: channel_id,
      participants: Map.keys(state.participants)
    })
    
    {:ok, state}
  end

  @impl true
  def handle_call({:send_message, from_system, to_system, message, metadata}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Validate participant
    if not Map.has_key?(state.participants, to_system) do
      {:reply, {:error, :unknown_recipient}, state}
    else
      # Create secure envelope
      envelope = %{
        channel_id: state.channel_id,
        from: from_system,
        to: to_system,
        message: message,
        metadata: metadata,
        sent_at: DateTime.utc_now()
      }
      
      # Sign the envelope
      {:ok, signed_envelope} = MessageValidator.sign_message(
        state.message_validator,
        envelope,
        from_system
      )
      
      # Encrypt the signed envelope
      envelope_binary = :erlang.term_to_binary(signed_envelope)
      {:ok, encrypted} = CryptoUtils.encrypt(envelope_binary, state.encryption_key)
      
      # Calculate encryption time
      end_time = System.monotonic_time(:microsecond)
      encryption_time = div(end_time - start_time, 1000)
      
      # Log the message send
      AuditLogger.log_event(state.audit_logger, :secure_message_sent, :info, %{
        channel_id: state.channel_id,
        from: from_system,
        to: to_system,
        correlation_id: signed_envelope.nonce,
        metadata: metadata
      })
      
      # Update stats
      new_stats = state.stats
      |> Map.update!(:messages_sent, &(&1 + 1))
      |> Map.update!(:encryption_time_ms, &(&1 + encryption_time))
      
      {:reply, {:ok, encrypted, signed_envelope.nonce}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:receive_message, encrypted_message, from_system}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Decrypt the message
    case CryptoUtils.decrypt(encrypted_message, state.encryption_key) do
      {:error, reason} ->
        log_failed_validation(state, from_system, :decryption_failed)
        {:reply, {:error, reason}, update_failed_stats(state)}
        
      {:ok, decrypted} ->
        # Deserialize
        try do
          signed_envelope = :erlang.binary_to_term(decrypted, [:safe])
          
          # Verify the message
          case MessageValidator.verify_message(state.message_validator, signed_envelope) do
            {:error, reason} ->
              log_failed_validation(state, from_system, reason)
              {:reply, {:error, reason}, update_failed_stats(state)}
              
            {:ok, envelope} ->
              # Validate channel and participants
              cond do
                envelope.channel_id != state.channel_id ->
                  log_failed_validation(state, from_system, :wrong_channel)
                  {:reply, {:error, :wrong_channel}, update_failed_stats(state)}
                  
                envelope.from != from_system ->
                  log_failed_validation(state, from_system, :sender_mismatch)
                  {:reply, {:error, :sender_mismatch}, update_failed_stats(state)}
                  
                not Map.has_key?(state.participants, envelope.from) ->
                  log_failed_validation(state, from_system, :unknown_sender)
                  {:reply, {:error, :unknown_sender}, update_failed_stats(state)}
                  
                true ->
                  # Message is valid!
                  end_time = System.monotonic_time(:microsecond)
                  validation_time = div(end_time - start_time, 1000)
                  
                  # Log successful receipt
                  AuditLogger.log_event(state.audit_logger, :secure_message_received, :info, %{
                    channel_id: state.channel_id,
                    from: envelope.from,
                    to: envelope.to,
                    correlation_id: signed_envelope.nonce,
                    metadata: envelope.metadata
                  })
                  
                  # Update stats
                  new_stats = state.stats
                  |> Map.update!(:messages_received, &(&1 + 1))
                  |> Map.update!(:validation_time_ms, &(&1 + validation_time))
                  
                  {:reply, {:ok, envelope}, %{state | stats: new_stats}}
              end
          end
        rescue
          _ ->
            log_failed_validation(state, from_system, :deserialization_failed)
            {:reply, {:error, :invalid_message_format}, update_failed_stats(state)}
        end
    end
  end

  @impl true
  def handle_call({:add_participant, system_id, public_key}, _from, state) do
    new_participants = Map.put(state.participants, system_id, public_key)
    
    AuditLogger.log_event(state.audit_logger, :participant_added, :info, %{
      channel_id: state.channel_id,
      system_id: system_id,
      actor: "channel_admin"
    })
    
    {:reply, :ok, %{state | participants: new_participants}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    avg_encryption_time = if state.stats.messages_sent > 0 do
      state.stats.encryption_time_ms / state.stats.messages_sent
    else
      0
    end
    
    avg_validation_time = if state.stats.messages_received > 0 do
      state.stats.validation_time_ms / state.stats.messages_received
    else
      0
    end
    
    stats = Map.merge(state.stats, %{
      channel_id: state.channel_id,
      participant_count: map_size(state.participants),
      avg_encryption_time_ms: avg_encryption_time,
      avg_validation_time_ms: avg_validation_time,
      success_rate: calculate_success_rate(state.stats)
    })
    
    {:reply, stats, state}
  end

  # Private functions

  defp generate_channel_id do
    "channel_#{:crypto.strong_rand_bytes(16) |> Base.encode64(padding: false)}"
  end

  defp log_failed_validation(state, from_system, reason) do
    AuditLogger.log_event(state.audit_logger, :message_validation_failed, :warning, %{
      channel_id: state.channel_id,
      from_system: from_system,
      reason: reason,
      metadata: %{security_alert: true}
    })
  end

  defp update_failed_stats(state) do
    new_stats = Map.update!(state.stats, :failed_validations, &(&1 + 1))
    %{state | stats: new_stats}
  end

  defp calculate_success_rate(stats) do
    total_attempts = stats.messages_received + stats.failed_validations
    if total_attempts > 0 do
      stats.messages_received / total_attempts * 100
    else
      100.0
    end
  end
end