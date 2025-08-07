defmodule VsmPhoenix.Infrastructure.SafePubSub do
  @moduledoc """
  Safe PubSub broadcasting with error handling and metrics.
  Prevents GenServer crashes from PubSub failures.
  """

  require Logger
  alias Phoenix.PubSub
  alias VsmPhoenix.Infrastructure.DynamicConfig

  @default_pubsub VsmPhoenix.PubSub

  @doc """
  Safely broadcast a message with error handling and optional retry.
  Returns :ok or {:error, reason}.
  """
  def broadcast(topic, message, opts \\ []) do
    # Get dynamic configuration
    config = DynamicConfig.get_component(:pubsub)
    pubsub = Keyword.get(opts, :pubsub, @default_pubsub)
    retry_count = Keyword.get(opts, :retry_count, config[:retry_count] || 3)
    log_errors = Keyword.get(opts, :log_errors, true)
    
    start_time = System.monotonic_time(:millisecond)
    
    try do
      case PubSub.broadcast(pubsub, topic, message) do
        :ok -> 
          publish_time = System.monotonic_time(:millisecond) - start_time
          DynamicConfig.report_metric(:pubsub, :publish_time, publish_time)
          DynamicConfig.report_outcome(:pubsub, :broadcast, :success)
          emit_telemetry(:success, topic)
          :ok
          
        {:error, reason} = error ->
          if log_errors do
            Logger.error("PubSub broadcast failed for topic #{topic}: #{inspect(reason)}")
          end
          emit_telemetry(:failure, topic, reason)
          
          if retry_count > 0 do
            retry_delay = config[:retry_delay] || 100
            Process.sleep(retry_delay)
            result = broadcast(topic, message, Keyword.put(opts, :retry_count, retry_count - 1))
            # Report retry outcome
            case result do
              :ok -> DynamicConfig.report_outcome(:pubsub, :broadcast, :retry_success)
              _ -> DynamicConfig.report_outcome(:pubsub, :broadcast, :failure)
            end
            result
          else
            DynamicConfig.report_outcome(:pubsub, :broadcast, :failure)
            error
          end
      end
    rescue
      error ->
        if log_errors do
          Logger.error("PubSub broadcast exception for topic #{topic}: #{inspect(error)}")
        end
        emit_telemetry(:exception, topic, error)
        {:error, {:exception, error}}
    end
  end

  @doc """
  Safely broadcast a message, logging errors but always returning :ok.
  Use when broadcast failure should not affect the caller.
  """
  def broadcast!(topic, message, opts \\ []) do
    case broadcast(topic, message, opts) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Broadcast with a callback on failure.
  """
  def broadcast_with_fallback(topic, message, fallback_fn, opts \\ []) do
    case broadcast(topic, message, opts) do
      :ok -> :ok
      {:error, reason} = error ->
        try do
          fallback_fn.(reason)
        rescue
          _ -> :ok
        end
        error
    end
  end

  @doc """
  Broadcast to multiple topics, collecting results.
  """
  def multi_broadcast(topics_and_messages, opts \\ []) do
    results = Enum.map(topics_and_messages, fn {topic, message} ->
      {topic, broadcast(topic, message, opts)}
    end)
    
    failures = Enum.filter(results, fn {_topic, result} -> 
      match?({:error, _}, result)
    end)
    
    if Enum.empty?(failures) do
      :ok
    else
      {:error, {:partial_failure, failures}}
    end
  end

  @doc """
  Local broadcast that only goes to the current node.
  """
  def local_broadcast(topic, message, opts \\ []) do
    pubsub = Keyword.get(opts, :pubsub, @default_pubsub)
    
    try do
      PubSub.local_broadcast(pubsub, topic, message)
    rescue
      error ->
        if Keyword.get(opts, :log_errors, true) do
          Logger.error("Local broadcast failed for topic #{topic}: #{inspect(error)}")
        end
        {:error, {:exception, error}}
    end
  end

  # Private functions

  defp emit_telemetry(event, topic, reason \\ nil) do
    :telemetry.execute(
      [:vsm_phoenix, :pubsub, event],
      %{count: 1},
      %{topic: topic, reason: reason}
    )
  rescue
    _ -> :ok
  end
end