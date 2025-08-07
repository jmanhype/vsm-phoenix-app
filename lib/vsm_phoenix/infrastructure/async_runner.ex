defmodule VsmPhoenix.Infrastructure.AsyncRunner do
  @moduledoc """
  Async task runner for external calls to prevent GenServer blocking.
  Provides fire-and-forget and supervised async execution.
  """

  require Logger
  alias VsmPhoenix.Infrastructure.DynamicConfig

  @doc """
  Run a function asynchronously without blocking the caller.
  Returns immediately with :ok.
  """
  def run_async(fun, opts \\ []) when is_function(fun, 0) do
    # Get dynamic configuration
    config = DynamicConfig.get_component(:async_runner)
    timeout = Keyword.get(opts, :timeout, config[:timeout] || 30_000)
    on_error = Keyword.get(opts, :on_error, :log)
    metadata = Keyword.get(opts, :metadata, %{})
    
    # Track task start time
    start_time = System.monotonic_time(:millisecond)
    
    Task.Supervisor.start_child(VsmPhoenix.TaskSupervisor, fn ->
      try do
        # Add timeout protection
        task = Task.async(fun)
        
        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, result} ->
            # Report completion time
            completion_time = System.monotonic_time(:millisecond) - start_time
            DynamicConfig.report_metric(:async_runner, :completion_time, completion_time)
            DynamicConfig.report_outcome(:async_runner, :task, :success)
            emit_telemetry(:success, metadata, result)
            result
            
          nil ->
            DynamicConfig.report_outcome(:async_runner, :task, :timeout)
            handle_error(:timeout, on_error, metadata)
            {:error, :timeout}
            
          {:exit, reason} ->
            handle_error({:exit, reason}, on_error, metadata)
            {:error, {:exit, reason}}
        end
      rescue
        error ->
          handle_error({:exception, error}, on_error, metadata)
          {:error, {:exception, error}}
      end
    end)
    
    :ok
  end

  @doc """
  Run a function asynchronously and send result to a process.
  """
  def run_async_with_callback(fun, callback_pid, callback_msg, opts \\ []) do
    run_async(fn ->
      result = fun.()
      send(callback_pid, {callback_msg, result})
      result
    end, opts)
  end

  @doc """
  Run multiple async tasks with a maximum concurrency limit.
  """
  def run_async_stream(enumerable, fun, opts \\ []) do
    # Get dynamic configuration
    config = DynamicConfig.get_component(:async_runner)
    max_concurrency = Keyword.get(opts, :max_concurrency, config[:max_concurrency] || System.schedulers_online() * 2)
    timeout = Keyword.get(opts, :timeout, config[:timeout] || 30_000)
    ordered = Keyword.get(opts, :ordered, false)
    on_timeout = Keyword.get(opts, :on_timeout, :kill_task)
    
    # Report queue size
    queue_size = Enum.count(enumerable)
    DynamicConfig.report_metric(:async_runner, :queue_size, queue_size)
    
    stream_opts = [
      max_concurrency: max_concurrency,
      timeout: timeout,
      ordered: ordered,
      on_timeout: on_timeout
    ]
    
    Task.Supervisor.async_stream(
      VsmPhoenix.TaskSupervisor,
      enumerable,
      fun,
      stream_opts
    )
    |> Enum.map(fn
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, {:exit, reason}}
    end)
  end

  @doc """
  Run an HTTP request asynchronously without blocking.
  """
  def async_http_request(method, url, body \\ "", headers \\ [], opts \\ []) do
    http_opts = Keyword.get(opts, :http_opts, [])
    callback = Keyword.get(opts, :callback)
    
    run_async(fn ->
      result = case method do
        :get -> HTTPoison.get(url, headers, http_opts)
        :post -> HTTPoison.post(url, body, headers, http_opts)
        :put -> HTTPoison.put(url, body, headers, http_opts)
        :delete -> HTTPoison.delete(url, headers, http_opts)
        :patch -> HTTPoison.patch(url, body, headers, http_opts)
      end
      
      # Handle callback if provided
      if callback && is_function(callback, 1) do
        callback.(result)
      end
      
      result
    end, opts)
  end

  @doc """
  Run a potentially slow database query asynchronously.
  """
  def async_query(query_fun, opts \\ []) do
    # Use dynamic timeout for database queries
    config = DynamicConfig.get_component(:async_runner)
    base_timeout = config[:timeout] || 30_000
    timeout = Keyword.get(opts, :timeout, min(base_timeout, 5_000))
    
    run_async(fn ->
      # Run in a transaction with timeout
      Ecto.Adapters.SQL.query(
        VsmPhoenix.Repo,
        "SET LOCAL statement_timeout = #{timeout}",
        []
      )
      
      query_fun.()
    end, opts)
  end

  # Private functions

  defp handle_error(error, :log, metadata) do
    Logger.error("Async task failed: #{inspect(error)}, metadata: #{inspect(metadata)}")
  end

  defp handle_error(error, :ignore, _metadata) do
    # Silently ignore
    :ok
  end

  defp handle_error(error, {:function, fun}, metadata) when is_function(fun) do
    try do
      fun.(error, metadata)
    rescue
      e -> Logger.error("Error handler failed: #{inspect(e)}")
    end
  end

  defp handle_error(error, handler, metadata) do
    Logger.warning("Unknown error handler: #{inspect(handler)}, error: #{inspect(error)}, metadata: #{inspect(metadata)}")
  end

  defp emit_telemetry(event, metadata, result \\ nil) do
    :telemetry.execute(
      [:vsm_phoenix, :async_runner, event],
      %{count: 1},
      Map.put(metadata, :result, result)
    )
  rescue
    _ -> :ok
  end
end