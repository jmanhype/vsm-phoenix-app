defmodule VsmPhoenix.Resilience.ErrorHandlingBehavior do
  @moduledoc """
  Behavior module for consistent error handling across god objects.
  
  This eliminates the 142 duplicate try/rescue blocks by providing
  standardized error handling patterns that can be used by:
  - control.ex (3,442 lines, 257 functions)
  - intelligence.ex (1,755 lines) 
  - queen.ex (1,471 lines)
  - And other god objects
  
  Usage:
      defmodule MyModule do
        use VsmPhoenix.Resilience.ErrorHandlingBehavior
        
        def my_function(params) do
          with_error_handling(:my_operation, params) do
            # Your business logic here
            risky_operation(params)
          end
        end
      end
  """
  
  defmacro __using__(opts \\ []) do
    quote do
      require Logger
      
      alias VsmPhoenix.Resilience.SharedBehaviors
      alias VsmPhoenix.System5.Components.AlgedonicProcessor
      
      @error_context Keyword.get(unquote(opts), :context, __MODULE__)
      @default_timeout Keyword.get(unquote(opts), :timeout, 30_000)
      
      @doc """
      Execute operation with standardized error handling.
      Eliminates repetitive try/rescue blocks across god objects.
      """
      defmacro with_error_handling(operation_name, context \\ %{}, opts \\ [], do: block) do
        quote do
          operation_opts = [
            module: __MODULE__,
            operation: unquote(operation_name),
            context: unquote(context),
            timeout: Keyword.get(unquote(opts), :timeout, @default_timeout)
          ] ++ unquote(opts)
          
          SharedBehaviors.monitor_operation(
            unquote(operation_name),
            fn -> unquote(block) end,
            operation_opts
          )
        end
      end
      
      @doc """
      Execute operation with full resilience patterns.
      Combines circuit breaker, retry, and error handling.
      """
      def with_resilience(operation_fn, opts \\ []) do
        default_opts = [
          circuit_breaker: Module.concat(__MODULE__, :circuit_breaker),
          algedonic_context: @error_context,
          timeout: @default_timeout
        ]
        
        SharedBehaviors.with_resilience(operation_fn, Keyword.merge(default_opts, opts))
      end
      
      @doc """
      Log error with module context.
      Standardizes error logging across god objects.
      """
      def log_error(error, context \\ %{}, opts \\ []) do
        default_opts = [
          module: __MODULE__,
          severity: :error
        ]
        
        SharedBehaviors.log_error(error, context, Keyword.merge(default_opts, opts))
      end
      
      @doc """
      Log success with module context.
      Standardizes success logging and metrics.
      """
      def log_success(result, context \\ %{}, opts \\ []) do
        default_opts = [
          module: __MODULE__
        ]
        
        SharedBehaviors.log_success(result, context, Keyword.merge(default_opts, opts))
      end
      
      @doc """
      Handle external API calls with resilience.
      Common pattern across god objects for external integrations.
      """
      def call_external_api(api_name, request_fn, opts \\ []) do
        circuit_breaker = Keyword.get(opts, :circuit_breaker, :"#{__MODULE__}_#{api_name}")
        
        with_resilience(request_fn, [
          circuit_breaker: circuit_breaker,
          algedonic_context: :external_api_call,
          error_handler: &handle_api_error/2
        ] ++ opts)
      end
      
      @doc """
      Handle database operations with resilience.
      Common pattern for database interactions in god objects.
      """
      def call_database(operation_name, db_fn, opts \\ []) do
        with_resilience(db_fn, [
          circuit_breaker: :"#{__MODULE__}_database",
          bulkhead_pool: :database_pool,
          algedonic_context: :database_operation,
          error_handler: &handle_db_error/2,
          retry_config: [max_attempts: 3, base_backoff: 200]
        ] ++ opts)
      end
      
      @doc """
      Handle AMQP operations with resilience.
      Common pattern for message queue operations.
      """
      def call_amqp(operation_name, amqp_fn, opts \\ []) do
        with_resilience(amqp_fn, [
          circuit_breaker: :"#{__MODULE__}_amqp",
          algedonic_context: :amqp_operation,
          error_handler: &handle_amqp_error/2,
          retry_config: [max_attempts: 5, base_backoff: 1000]
        ] ++ opts)
      end
      
      @doc """
      Handle CPU-intensive operations with bulkhead isolation.
      Prevents resource exhaustion in god objects.
      """
      def call_cpu_intensive(operation_name, compute_fn, opts \\ []) do
        bulkhead_pool = Keyword.get(opts, :bulkhead_pool, :cpu_intensive)
        
        with_resilience(compute_fn, [
          circuit_breaker: :"#{__MODULE__}_compute",
          bulkhead_pool: bulkhead_pool,
          algedonic_context: :cpu_intensive_operation,
          timeout: Keyword.get(opts, :timeout, 60_000)
        ] ++ opts)
      end
      
      # Default error handlers (can be overridden)
      
      defp handle_api_error(reason, _opts) do
        case reason do
          {:timeout, _} ->
            log_error("API timeout", %{reason: reason}, severity: :warning)
            {:error, :api_timeout}
            
          {:http_error, status} when status >= 500 ->
            log_error("API server error", %{status: status}, severity: :error)
            {:error, :api_server_error}
            
          {:http_error, status} when status >= 400 ->
            log_error("API client error", %{status: status}, severity: :warning)
            {:error, :api_client_error}
            
          _ ->
            log_error("API error", %{reason: reason}, severity: :error)
            {:error, :api_error}
        end
      end
      
      defp handle_db_error(reason, _opts) do
        case reason do
          {:timeout, _} ->
            log_error("Database timeout", %{reason: reason}, severity: :warning)
            {:error, :db_timeout}
            
          %Postgrex.Error{postgres: %{code: code}} when code in ["40001", "40P01"] ->
            log_error("Database deadlock", %{code: code}, severity: :info)
            {:error, :db_deadlock}
            
          %Postgrex.Error{} = error ->
            log_error("Database error", %{error: error}, severity: :error)
            {:error, :db_error}
            
          _ ->
            log_error("Database operation failed", %{reason: reason}, severity: :error)
            {:error, :db_failure}
        end
      end
      
      defp handle_amqp_error(reason, _opts) do
        case reason do
          {:timeout, _} ->
            log_error("AMQP timeout", %{reason: reason}, severity: :warning)
            {:error, :amqp_timeout}
            
          {:connection_error, _} ->
            log_error("AMQP connection error", %{reason: reason}, severity: :error)
            {:error, :amqp_connection_error}
            
          _ ->
            log_error("AMQP operation failed", %{reason: reason}, severity: :error)
            {:error, :amqp_failure}
        end
      end
      
      # Allow modules to override error handlers
      defoverridable [
        handle_api_error: 2,
        handle_db_error: 2, 
        handle_amqp_error: 2
      ]
    end
  end
end