defmodule VsmPhoenix.Infrastructure.CausalityAMQP do
  @moduledoc """
  AMQP wrapper that automatically adds causality tracking to all messages.
  
  This module provides drop-in replacements for AMQP.Basic.publish that
  automatically add event_id and parent_event_id to messages for event
  causality chain tracking.
  """
  
  alias VsmPhoenix.Infrastructure.CausalityTracker
  require Logger
  
  @doc """
  Publishes a message with automatic causality tracking.
  
  If the message is a map, it will be enhanced with event_id and parent_event_id.
  If it's a JSON string, it will be decoded, enhanced, and re-encoded.
  """
  def publish(channel, exchange, routing_key, message, options \\ []) do
    # Extract parent event ID from options or current process dictionary
    parent_event_id = Keyword.get(options, :parent_event_id) || Process.get(:current_event_id)
    
    # Enhance message with causality data
    enhanced_message = add_causality_to_message(message, parent_event_id)
    
    # Extract the event_id for tracking
    event_id = extract_event_id(enhanced_message)
    
    # Track the event
    if event_id do
      CausalityTracker.track_event(event_id, parent_event_id, %{
        exchange: exchange,
        routing_key: routing_key,
        message_type: extract_message_type(enhanced_message)
      })
      
      # Store in process dictionary for child events in same process
      Process.put(:current_event_id, event_id)
    end
    
    # Convert back to string if needed
    final_message = prepare_message_for_publish(enhanced_message, message)
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm, :amqp, :message, :sent],
      %{count: 1},
      %{
        event_id: event_id,
        parent_event_id: parent_event_id,
        exchange: exchange,
        routing_key: routing_key
      }
    )
    
    # Publish with original AMQP
    AMQP.Basic.publish(channel, exchange, routing_key, final_message, options)
  end
  
  @doc """
  Publishes a message and waits for RPC response with causality tracking.
  """
  def publish_and_wait(channel, exchange, routing_key, message, options \\ []) do
    # Generate correlation ID if not provided
    correlation_id = Keyword.get(options, :correlation_id, generate_correlation_id())
    
    # Set up reply queue
    {:ok, %{queue: reply_queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
    
    # Enhanced options with reply_to and correlation_id
    enhanced_options = options
    |> Keyword.put(:reply_to, reply_queue)
    |> Keyword.put(:correlation_id, correlation_id)
    
    # Publish with causality
    :ok = publish(channel, exchange, routing_key, message, enhanced_options)
    
    # Wait for response
    # Note: In production, you'd want proper timeout handling
    {:ok, reply_message, _meta} = AMQP.Basic.consume(channel, reply_queue, nil, no_ack: true)
    
    reply_message
  end
  
  @doc """
  Processes an incoming AMQP message and extracts causality information.
  
  Returns {message, causality_info} tuple.
  """
  def receive_message(payload, meta) do
    # Parse message
    message = parse_message(payload)
    
    # Extract causality info
    event_id = extract_event_id(message)
    parent_event_id = extract_parent_event_id(message)
    
    # Track reception
    if event_id do
      CausalityTracker.track_event(event_id, parent_event_id, %{
        delivery_tag: meta.delivery_tag,
        routing_key: meta.routing_key,
        exchange: meta.exchange,
        message_type: extract_message_type(message)
      })
      
      # Set current event ID for any child events
      Process.put(:current_event_id, event_id)
    end
    
    # Emit telemetry
    :telemetry.execute(
      [:vsm, :amqp, :message, :received],
      %{count: 1},
      %{
        event_id: event_id,
        parent_event_id: parent_event_id,
        routing_key: meta.routing_key,
        exchange: meta.exchange
      }
    )
    
    causality_info = %{
      event_id: event_id,
      parent_event_id: parent_event_id,
      chain_depth: get_chain_depth(event_id)
    }
    
    {message, causality_info}
  end
  
  # Private functions
  
  defp add_causality_to_message(message, parent_event_id) when is_map(message) do
    CausalityTracker.add_causality_to_message(message, parent_event_id)
  end
  
  defp add_causality_to_message(message, parent_event_id) when is_binary(message) do
    case Jason.decode(message) do
      {:ok, decoded} ->
        CausalityTracker.add_causality_to_message(decoded, parent_event_id)
      {:error, _} ->
        # Not JSON, wrap in a map
        CausalityTracker.add_causality_to_message(%{"body" => message}, parent_event_id)
    end
  end
  
  defp add_causality_to_message(message, parent_event_id) do
    # For other types, wrap in a map
    CausalityTracker.add_causality_to_message(%{"body" => inspect(message)}, parent_event_id)
  end
  
  defp extract_event_id(%{"event_id" => event_id}), do: event_id
  defp extract_event_id(%{event_id: event_id}), do: event_id
  defp extract_event_id(_), do: nil
  
  defp extract_parent_event_id(%{"parent_event_id" => parent_id}), do: parent_id
  defp extract_parent_event_id(%{parent_event_id: parent_id}), do: parent_id
  defp extract_parent_event_id(_), do: nil
  
  defp extract_message_type(%{"type" => type}), do: type
  defp extract_message_type(%{type: type}), do: type
  defp extract_message_type(%{"message_type" => type}), do: type
  defp extract_message_type(%{message_type: type}), do: type
  defp extract_message_type(_), do: "unknown"
  
  defp prepare_message_for_publish(enhanced_message, original_message) when is_binary(original_message) do
    # Original was string, encode back
    Jason.encode!(enhanced_message)
  end
  
  defp prepare_message_for_publish(enhanced_message, _original_message) do
    # Original was map or other, return enhanced map
    enhanced_message
  end
  
  defp parse_message(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{"body" => payload}
    end
  end
  
  defp parse_message(payload), do: payload
  
  defp generate_correlation_id do
    "CORR-#{System.system_time(:microsecond)}-#{:rand.uniform(999999)}"
  end
  
  defp get_chain_depth(nil), do: 0
  defp get_chain_depth(event_id) do
    case CausalityTracker.get_chain_depth(event_id) do
      {:ok, depth} -> depth
      _ -> 0
    end
  end
  
  @doc """
  Clears the current event ID from process dictionary.
  Useful when starting a new causal chain.
  """
  def clear_current_event do
    Process.delete(:current_event_id)
  end
  
  @doc """
  Sets the current event ID in process dictionary.
  Useful when continuing a causal chain from a specific event.
  """
  def set_current_event(event_id) do
    Process.put(:current_event_id, event_id)
  end
  
  @doc """
  Gets the current event ID from process dictionary.
  """
  def get_current_event do
    Process.get(:current_event_id)
  end
end