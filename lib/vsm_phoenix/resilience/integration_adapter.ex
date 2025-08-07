defmodule VsmPhoenix.Resilience.IntegrationAdapter do
  @moduledoc """
  Adapter module to integrate resilience patterns with existing VSM Phoenix code.

  This module provides compatibility functions to allow gradual migration
  from the existing connection managers to the resilient versions.
  """

  alias VsmPhoenix.Resilience.{ResilientAMQPConnection, ResilientHTTPClient, Bulkhead}

  @doc """
  Get AMQP channel with bulkhead protection
  """
  def get_amqp_channel(purpose \\ :default) do
    with {:ok, _resource} <- Bulkhead.checkout(:bulkhead_amqp_channels),
         {:ok, channel} <-
           ResilientAMQPConnection.get_channel(VsmPhoenix.AMQP.ConnectionManager, purpose) do
      {:ok, channel}
    else
      {:error, :bulkhead_full} ->
        {:error, :too_many_connections}

      error ->
        error
    end
  end

  @doc """
  Release AMQP channel back to bulkhead pool
  """
  def release_amqp_channel(_channel) do
    Bulkhead.checkin(:bulkhead_amqp_channels, :channel)
  end

  @doc """
  Execute AMQP operation with bulkhead protection
  """
  def with_amqp_channel(purpose, fun) do
    Bulkhead.with_resource(:bulkhead_amqp_channels, fn _resource ->
      case ResilientAMQPConnection.get_channel(VsmPhoenix.AMQP.ConnectionManager, purpose) do
        {:ok, channel} ->
          try do
            fun.(channel)
          after
            # Channel cleanup if needed
            :ok
          end

        error ->
          error
      end
    end)
  end

  @doc """
  Make HTTP request with resilience patterns
  """
  def resilient_http_request(client_name, method, url, body \\ "", headers \\ [], opts \\ []) do
    client = :"http_client_#{client_name}"

    Bulkhead.with_resource(:bulkhead_http_connections, fn _resource ->
      ResilientHTTPClient.request(client, method, url, body, headers, opts)
    end)
  end

  @doc """
  Execute LLM request with bulkhead protection
  """
  def with_llm_request(fun) do
    Bulkhead.with_resource(:bulkhead_llm_requests, fun, 30_000)
  end
end
