defmodule VsmPhoenix.Resilience.CircuitBreakerBehavior do
  @moduledoc """
  Circuit breaker behavior for god objects to prevent cascade failures.
  
  This addresses architectural violations by providing consistent
  circuit breaker patterns across all god objects:
  
  - control.ex: Protects resource allocation and system control operations
  - intelligence.ex: Protects LLM API calls and analysis operations  
  - queen.ex: Protects policy synthesis and strategic operations
  - telegram_agent.ex: Protects Telegram API and user interactions
  
  Usage:
      defmodule MyGodObject do
        use VsmPhoenix.Resilience.CircuitBreakerBehavior,
          circuits: [:external_api, :database, :llm_processing],
          failure_threshold: 5,
          timeout: 30_000
        
        def risky_operation(params) do
          with_circuit_breaker :external_api do
            ExternalAPI.call(params)
          end
        end
      end
  """
  
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      require Logger
      
      alias VsmPhoenix.Resilience.{CircuitBreaker, Integration, SharedBehaviors}
      alias VsmPhoenix.System5.Components.AlgedonicProcessor
      
      @circuits Keyword.get(opts, :circuits, [:default])
      @failure_threshold Keyword.get(opts, :failure_threshold, 5)  
      @timeout Keyword.get(opts, :timeout, 30_000)
      @recovery_timeout Keyword.get(opts, :recovery_timeout, 60_000)
      
      @doc """
      Initialize circuit breakers for this module.
      Call this in your module's init or start_link function.
      """
      def init_circuit_breakers do
        Enum.each(@circuits, fn circuit_name ->
          full_name = :"#{__MODULE__}_#{circuit_name}"
          
          CircuitBreaker.start_link([
            name: full_name,
            failure_threshold: @failure_threshold,
            timeout: @recovery_timeout
          ])
          
          Logger.info("🔌 Circuit breaker initialized: #{full_name}")
        end)
      end
      
      @doc """
      Execute operation with circuit breaker protection.
      """
      defmacro with_circuit_breaker(circuit_name, opts \\ [], do: block) do
        quote do
          circuit_full_name = :"#{__MODULE__}_#{unquote(circuit_name)}"
          operation_timeout = Keyword.get(unquote(opts), :timeout, @timeout)
          fallback = Keyword.get(unquote(opts), :fallback)
          
          case Integration.with_llm_circuit_breaker(
            fn -> unquote(block) end,
            [circuit_breaker: circuit_full_name, timeout: operation_timeout]
          ) do
            {:ok, result} ->
              # Emit pleasure signal for successful circuit breaker operation
              AlgedonicProcessor.send_pleasure_signal(0.5, %{
                source: "circuit_breaker",
                context: :circuit_breaker_success,
                module: __MODULE__,
                circuit: unquote(circuit_name)
              })
              {:ok, result}
              
            {:error, :circuit_open} ->
              Logger.warning("⚡ Circuit breaker #{circuit_full_name} is OPEN")
              
              # Emit pain signal for circuit breaker activation
              AlgedonicProcessor.send_pain_signal(0.7, %{
                source: "circuit_breaker",
                context: :circuit_breaker_open,
                module: __MODULE__,
                circuit: unquote(circuit_name)
              })
              
              if fallback do
                Logger.info("🔄 Using fallback for #{circuit_full_name}")
                fallback.()
              else
                {:error, {:circuit_open, circuit_full_name}}
              end
              
            {:error, reason} = error ->
              Logger.error("💥 Circuit breaker operation failed: #{inspect(reason)}")
              error
          end
        end
      end
      
      @doc """
      Check circuit breaker status for a specific circuit.
      """
      def circuit_status(circuit_name) do
        full_name = :"#{__MODULE__}_#{circuit_name}"
        CircuitBreaker.get_status(full_name)
      end
      
      @doc """
      Get status of all circuit breakers for this module.
      """
      def all_circuit_status do
        @circuits
        |> Enum.map(fn circuit_name ->
          full_name = :"#{__MODULE__}_#{circuit_name}"
          {circuit_name, CircuitBreaker.get_status(full_name)}
        end)
        |> Map.new()
      end
      
      @doc """
      Reset a specific circuit breaker (force close).
      Use with caution - only for maintenance or testing.
      """
      def reset_circuit(circuit_name) do
        full_name = :"#{__MODULE__}_#{circuit_name}"
        
        case CircuitBreaker.reset(full_name) do
          :ok ->
            Logger.info("🔄 Circuit breaker #{full_name} reset")
            # Neutral signals are low-intensity pleasure in refactored API
            AlgedonicProcessor.send_pleasure_signal(0.03, %{
              source: "circuit_breaker",
              context: :circuit_breaker_reset,
              module: __MODULE__,
              circuit: circuit_name
            })
            :ok
            
          {:error, reason} ->
            Logger.error("Failed to reset circuit breaker #{full_name}: #{inspect(reason)}")
            {:error, reason}
        end
      end
      
      @doc """
      Execute batch operations with individual circuit breaker protection.
      Prevents one failing operation from affecting others.
      """
      def batch_with_circuit_breakers(operations, circuit_name, opts \\ []) do
        max_concurrent = Keyword.get(opts, :max_concurrent, 5)
        timeout = Keyword.get(opts, :timeout, @timeout)
        
        operations
        |> Enum.with_index()
        |> Enum.chunk_every(max_concurrent)
        |> Enum.reduce({[], []}, fn batch, {successes, failures} ->
          batch_results = batch
          |> Task.async_stream(fn {operation_fn, index} ->
            individual_circuit = :"#{circuit_name}_#{index}"
            
            with_circuit_breaker individual_circuit, timeout: timeout do
              operation_fn.()
            end
          end, timeout: timeout + 1000, max_concurrency: max_concurrent)
          |> Enum.to_list()
          
          Enum.reduce(batch_results, {successes, failures}, fn
            {:ok, {:ok, result}}, {s_acc, f_acc} -> 
              {[result | s_acc], f_acc}
            {:ok, {:error, reason}}, {s_acc, f_acc} -> 
              {s_acc, [reason | f_acc]}
            {:exit, reason}, {s_acc, f_acc} ->
              {s_acc, [{:exit, reason} | f_acc]}
          end)
        end)
      end
      
      @doc """
      Monitor circuit breaker health and emit algedonic signals.
      Call this periodically to track circuit breaker patterns.
      """
      def monitor_circuit_health do
        circuit_states = all_circuit_status()
        
        open_circuits = circuit_states
        |> Enum.filter(fn {_name, status} -> 
          match?({:ok, %{state: :open}}, status) 
        end)
        |> Enum.map(fn {name, _} -> name end)
        
        half_open_circuits = circuit_states
        |> Enum.filter(fn {_name, status} -> 
          match?({:ok, %{state: :half_open}}, status) 
        end)
        |> Enum.map(fn {name, _} -> name end)
        
        cond do
          length(open_circuits) > length(@circuits) / 2 ->
            # More than half circuits are open - critical situation
            Logger.error("🚨 Critical: #{length(open_circuits)} circuit breakers open in #{__MODULE__}")
            AlgedonicProcessor.send_pain_signal(0.9, %{
              source: "circuit_breaker",
              context: :critical_circuit_failure,
              module: __MODULE__,
              open_circuits: open_circuits
            })
            
          length(open_circuits) > 0 ->
            # Some circuits open - warning situation
            Logger.warning("⚠️ Warning: #{length(open_circuits)} circuit breakers open in #{__MODULE__}")
            AlgedonicProcessor.send_pain_signal(0.6, %{
              source: "circuit_breaker",
              context: :circuit_degradation,
              module: __MODULE__,
              open_circuits: open_circuits
            })
            
          length(half_open_circuits) > 0 ->
            # Circuits recovering - neutral signal
            Logger.info("🔄 #{length(half_open_circuits)} circuit breakers recovering in #{__MODULE__}")
            # Neutral signals are low-intensity pleasure in refactored API
            AlgedonicProcessor.send_pleasure_signal(0.04, %{
              source: "circuit_breaker",
              context: :circuit_recovery,
              module: __MODULE__,
              half_open_circuits: half_open_circuits
            })
            
          true ->
            # All circuits healthy - pleasure signal
            Logger.debug("✅ All circuit breakers healthy in #{__MODULE__}")
            AlgedonicProcessor.send_pleasure_signal(0.3, %{
              source: "circuit_breaker",
              context: :circuit_health_good,
              module: __MODULE__
            })
        end
        
        %{
          total_circuits: length(@circuits),
          open_circuits: open_circuits,
          half_open_circuits: half_open_circuits,
          health_status: (if length(open_circuits) == 0, do: :healthy, else: :degraded)
        }
      end
      
      @doc """
      Get circuit breaker metrics for monitoring and alerting.
      """
      def get_circuit_metrics do
        @circuits
        |> Enum.map(fn circuit_name ->
          full_name = :"#{__MODULE__}_#{circuit_name}"
          
          case CircuitBreaker.get_metrics(full_name) do
            {:ok, metrics} ->
              {circuit_name, metrics}
            {:error, _} ->
              {circuit_name, %{error: :not_available}}
          end
        end)
        |> Map.new()
      end
      
      # Provide callback hooks for modules to customize behavior
      @doc """
      Called when a circuit breaker opens. Override to add custom logic.
      """
      def on_circuit_open(circuit_name, reason) do
        Logger.warning("🔴 Circuit #{circuit_name} opened: #{inspect(reason)}")
      end
      
      @doc """
      Called when a circuit breaker closes (recovers). Override to add custom logic.
      """
      def on_circuit_close(circuit_name) do
        Logger.info("🟢 Circuit #{circuit_name} closed (recovered)")
      end
      
      defoverridable [on_circuit_open: 2, on_circuit_close: 1]
    end
  end
end