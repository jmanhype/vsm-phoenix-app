defmodule VsmPhoenix.Behaviors.Resilient do
  @moduledoc """
  DRY: Shared resilience patterns (Circuit Breaker, Bulkhead, Retry)
  Eliminates duplicate error handling code across agents
  """
  
  defmacro __using__(opts) do
    quote do
      @max_retries unquote(opts[:max_retries]) || 3
      @retry_delay unquote(opts[:retry_delay]) || 1000
      @circuit_breaker_threshold unquote(opts[:circuit_threshold]) || 5
      @circuit_breaker_timeout unquote(opts[:circuit_timeout]) || 60_000
      
      # DRY: Single retry logic instead of duplicating across functions
      defp with_retry(operation, retries \\ @max_retries) do
        case operation.() do
          {:ok, result} -> 
            {:ok, result}
          {:error, reason} when retries > 0 ->
            Process.sleep(@retry_delay)
            with_retry(operation, retries - 1)
          error -> 
            error
        end
      end
      
      # DRY: Circuit breaker pattern
      defp with_circuit_breaker(name, operation) do
        circuit_state = get_circuit_state(name)
        
        case circuit_state do
          :open ->
            {:error, :circuit_open}
          _ ->
            case operation.() do
              {:ok, result} ->
                reset_circuit(name)
                {:ok, result}
              {:error, reason} ->
                trip_circuit(name)
                {:error, reason}
            end
        end
      end
      
      # DRY: Bulkhead pattern for resource isolation
      defp with_bulkhead(resource_pool, operation) do
        case acquire_resource(resource_pool) do
          {:ok, resource} ->
            try do
              operation.(resource)
            after
              release_resource(resource_pool, resource)
            end
          {:error, :no_resources} ->
            {:error, :bulkhead_full}
        end
      end
      
      # DRY: Combined resilience wrapper
      defp with_resilience(name, operation, opts \\ []) do
        pipeline = [
          fn op -> with_circuit_breaker(name, op) end,
          fn op -> with_retry(op, opts[:retries] || @max_retries) end
        ]
        
        Enum.reduce(pipeline, operation, fn wrapper, op ->
          fn -> wrapper.(op) end
        end).()
      end
      
      # Helper functions (would connect to actual circuit breaker implementation)
      defp get_circuit_state(name), do: :closed
      defp reset_circuit(name), do: :ok
      defp trip_circuit(name), do: :ok
      defp acquire_resource(pool), do: {:ok, :resource}
      defp release_resource(pool, resource), do: :ok
    end
  end
end