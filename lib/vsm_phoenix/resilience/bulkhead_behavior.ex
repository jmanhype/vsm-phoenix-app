defmodule VsmPhoenix.Resilience.BulkheadBehavior do
  @moduledoc """
  Bulkhead behavior for god objects to prevent resource exhaustion.
  
  Provides resource isolation patterns to prevent any single operation
  from consuming all available resources in god objects:
  
  - control.ex: Isolates resource allocation, system monitoring, audit operations
  - intelligence.ex: Isolates LLM processing, analysis, knowledge operations  
  - queen.ex: Isolates policy synthesis, strategic planning, decision operations
  - telegram_agent.ex: Isolates message processing, user interactions, API calls
  
  Usage:
      defmodule MyGodObject do
        use VsmPhoenix.Resilience.BulkheadBehavior,
          pools: [
            cpu_intensive: [max_concurrent: 3, max_waiting: 10],
            io_operations: [max_concurrent: 10, max_waiting: 50],
            external_apis: [max_concurrent: 5, max_waiting: 20]
          ]
        
        def heavy_computation(data) do
          with_bulkhead :cpu_intensive do
            complex_analysis(data)
          end
        end
      end
  """
  
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      require Logger
      
      alias VsmPhoenix.Resilience.{Bulkhead, SharedBehaviors}
      alias VsmPhoenix.System5.Components.AlgedonicProcessor
      
      @pools Keyword.get(opts, :pools, [
        default: [max_concurrent: 5, max_waiting: 20]
      ])
      @default_timeout Keyword.get(opts, :timeout, 30_000)
      
      @doc """
      Initialize bulkhead pools for this module.
      Call this in your module's init or start_link function.
      """
      def init_bulkhead_pools do
        Enum.each(@pools, fn {pool_name, pool_config} ->
          full_name = :"#{__MODULE__}_#{pool_name}"
          
          config = [
            name: full_name,
            max_concurrent: Keyword.get(pool_config, :max_concurrent, 5),
            max_waiting: Keyword.get(pool_config, :max_waiting, 20)
          ]
          
          case Bulkhead.start_link(config) do
            {:ok, _pid} ->
              Logger.info("🏗️ Bulkhead pool initialized: #{full_name} (#{config[:max_concurrent]} concurrent, #{config[:max_waiting]} waiting)")
              
            {:error, {:already_started, _}} ->
              Logger.debug("🏗️ Bulkhead pool already exists: #{full_name}")
              
            {:error, reason} ->
              Logger.error("💥 Failed to initialize bulkhead pool #{full_name}: #{inspect(reason)}")
          end
        end)
      end
      
      @doc """
      Execute operation with bulkhead resource isolation.
      """
      defmacro with_bulkhead(pool_name, opts \\ [], do: block) do
        quote do
          pool_full_name = :"#{__MODULE__}_#{unquote(pool_name)}"
          operation_timeout = Keyword.get(unquote(opts), :timeout, @default_timeout)
          fallback = Keyword.get(unquote(opts), :fallback)
          priority = Keyword.get(unquote(opts), :priority, :normal)
          
          start_time = System.monotonic_time(:millisecond)
          
          case Bulkhead.with_pool(pool_full_name, fn _resource ->
            unquote(block)
          end, operation_timeout) do
            {:ok, result} ->
              duration = System.monotonic_time(:millisecond) - start_time
              
              Logger.debug("✅ Bulkhead operation completed in #{duration}ms (pool: #{pool_full_name})")
              
              # Emit pleasure signal for successful resource utilization
              AlgedonicProcessor.send_pleasure_signal(0.4, %{
                source: "bulkhead",
                context: :bulkhead_success,
                module: __MODULE__,
                pool: unquote(pool_name)
              })
              
              {:ok, result}
              
            {:error, :bulkhead_full} ->
              duration = System.monotonic_time(:millisecond) - start_time
              
              Logger.warning("🚧 Bulkhead pool #{pool_full_name} is full (waited #{duration}ms)")
              
              # Emit pain signal for resource exhaustion
              AlgedonicProcessor.send_pain_signal(0.8, %{
                source: "bulkhead",
                context: :resource_exhaustion,
                module: __MODULE__,
                pool: unquote(pool_name)
              })
              
              if fallback do
                Logger.info("🔄 Using fallback for full bulkhead #{pool_full_name}")
                fallback.()
              else
                {:error, {:resource_exhausted, pool_full_name}}
              end
              
            {:error, :timeout} ->
              Logger.error("⏰ Bulkhead operation timeout (pool: #{pool_full_name})")
              
              AlgedonicProcessor.send_pain_signal(0.6, %{
                source: "bulkhead",
                context: :bulkhead_timeout,
                module: __MODULE__,
                pool: pool_full_name,
                timeout: timeout
              })
              
              {:error, {:bulkhead_timeout, pool_full_name}}
              
            {:error, reason} = error ->
              Logger.error("💥 Bulkhead operation failed: #{inspect(reason)}")
              error
          end
        end
      end
      
      @doc """
      Get status of a specific bulkhead pool.
      """
      def bulkhead_status(pool_name) do
        full_name = :"#{__MODULE__}_#{pool_name}"
        
        case Bulkhead.get_metrics(full_name) do
          {:ok, metrics} ->
            pool_config = Keyword.get(@pools, pool_name, [])
            max_concurrent = Keyword.get(pool_config, :max_concurrent, 5)
            max_waiting = Keyword.get(pool_config, :max_waiting, 20)
            
            utilization = if max_concurrent > 0 do
              metrics.active_resources / max_concurrent * 100
            else
              0
            end
            
            queue_utilization = if max_waiting > 0 do
              metrics.waiting_count / max_waiting * 100  
            else
              0
            end
            
            status = cond do
              utilization >= 90 -> :critical
              utilization >= 70 -> :warning
              utilization >= 50 -> :moderate
              true -> :healthy
            end
            
            {:ok, %{
              pool_name: pool_name,
              status: status,
              utilization_percent: Float.round(utilization, 1),
              queue_utilization_percent: Float.round(queue_utilization, 1),
              active_resources: metrics.active_resources,
              waiting_count: metrics.waiting_count,
              max_concurrent: max_concurrent,
              max_waiting: max_waiting,
              metrics: metrics
            }}
            
        {:error, reason} ->
          {:error, reason}
        end
      end
      
      @doc """
      Get status of all bulkhead pools for this module.
      """
      def all_bulkhead_status do
        @pools
        |> Enum.map(fn {pool_name, _config} ->
          {pool_name, bulkhead_status(pool_name)}
        end)
        |> Map.new()
      end
      
      @doc """
      Monitor bulkhead pool health and emit algedonic signals.
      """
      def monitor_bulkhead_health do
        pool_statuses = all_bulkhead_status()
        
        critical_pools = pool_statuses
        |> Enum.filter(fn {_name, status} -> 
          match?({:ok, %{status: :critical}}, status)
        end)
        |> Enum.map(fn {name, _} -> name end)
        
        warning_pools = pool_statuses
        |> Enum.filter(fn {_name, status} -> 
          match?({:ok, %{status: :warning}}, status)
        end)
        |> Enum.map(fn {name, _} -> name end)
        
        cond do
          length(critical_pools) > 0 ->
            Logger.error("🚨 Critical: #{length(critical_pools)} bulkhead pools at capacity in #{__MODULE__}")
            AlgedonicProcessor.send_pain_signal(0.9, %{
              source: "bulkhead",
              context: :critical_resource_exhaustion,
              module: __MODULE__,
              critical_pools: critical_pools
            })
            
          length(warning_pools) > 0 ->
            Logger.warning("⚠️ Warning: #{length(warning_pools)} bulkhead pools under high load in #{__MODULE__}")
            AlgedonicProcessor.send_pain_signal(0.5, %{
              source: "bulkhead",
              context: :resource_pressure,
              module: __MODULE__,
              warning_pools: warning_pools
            })
            
          true ->
            Logger.debug("✅ All bulkhead pools healthy in #{__MODULE__}")
            AlgedonicProcessor.send_pleasure_signal(0.2, %{
              source: "bulkhead",
              context: :resource_health_good,
              module: __MODULE__
            })
        end
        
        %{
          total_pools: length(@pools),
          critical_pools: critical_pools,
          warning_pools: warning_pools,
          health_status: (if length(critical_pools) == 0, do: :healthy, else: :degraded)
        }
      end
      
      @doc """
      Execute prioritized operation with bulkhead isolation.
      Higher priority operations can preempt lower priority ones.
      """
      def with_priority_bulkhead(pool_name, priority, operation_fn, opts \\ []) do
        # Implementation would require priority queue support in Bulkhead
        # For now, fall back to regular bulkhead with priority hint
        with_bulkhead pool_name, [priority: priority] ++ opts do
          operation_fn.()
        end
      end
      
      @doc """
      Execute batch operations with bulkhead resource management.
      Automatically manages concurrency based on pool capacity.
      """
      def batch_with_bulkheads(operations, pool_name, opts \\ []) do
        pool_full_name = :"#{__MODULE__}_#{pool_name}"
        
        case bulkhead_status(pool_name) do
          {:ok, %{max_concurrent: max_concurrent}} ->
            # Use pool capacity to determine batch size
            batch_size = max(1, div(max_concurrent, 2)) # Use half capacity for batching
            timeout = Keyword.get(opts, :timeout, @default_timeout)
            
            results = operations
            |> Enum.chunk_every(batch_size)
            |> Enum.reduce([], fn batch, acc ->
              batch_results = batch
              |> Task.async_stream(fn operation_fn ->
                with_bulkhead pool_name, timeout: timeout do
                  operation_fn.()
                end
              end, timeout: timeout + 1000, max_concurrency: batch_size)
              |> Enum.to_list()
              
              acc ++ batch_results
            end)
            
            {successes, failures} = results
            |> Enum.reduce({[], []}, fn
              {:ok, {:ok, result}}, {s, f} -> {[result | s], f}
              {:ok, {:error, reason}}, {s, f} -> {s, [reason | f]}
              {:exit, reason}, {s, f} -> {s, [{:exit, reason} | f]}
            end)
            
            Logger.info("📊 Batch bulkhead operation: #{length(successes)} successes, #{length(failures)} failures")
            
            {:ok, %{
              successes: Enum.reverse(successes),
              failures: Enum.reverse(failures),
              total: length(operations)
            }}
            
          {:error, reason} ->
            {:error, {:pool_unavailable, reason}}
        end
      end
      
      @doc """
      Adaptive bulkhead scaling based on load patterns.
      Temporarily adjusts pool size based on demand.
      """
      def scale_bulkhead(pool_name, scale_factor, duration_ms) do
        full_name = :"#{__MODULE__}_#{pool_name}"
        
        Logger.info("📈 Scaling bulkhead #{full_name} by #{scale_factor}x for #{duration_ms}ms")
        
        # Send scaling message to bulkhead (would need implementation in Bulkhead module)
        send(full_name, {:scale_temporarily, scale_factor, duration_ms})
        
        # Emit signal for scaling event
        # Neutral signals are low-intensity pleasure in refactored API
        AlgedonicProcessor.send_pleasure_signal(0.03, %{
          source: "bulkhead",
          context: :bulkhead_scaling,
          module: __MODULE__,
          pool: pool_name,
          direction: (if scale_up, do: :up, else: :down)
        })
        
        :ok
      end
      
      @doc """
      Get bulkhead pool metrics for monitoring and alerting.
      """
      def get_bulkhead_metrics do
        @pools
        |> Enum.map(fn {pool_name, _config} ->
          case bulkhead_status(pool_name) do
            {:ok, status} -> {pool_name, status}
            {:error, reason} -> {pool_name, %{error: reason}}
          end
        end)
        |> Map.new()
      end
      
      # Provide callback hooks for modules to customize behavior
      @doc """
      Called when a bulkhead pool reaches capacity. Override for custom logic.
      """
      def on_bulkhead_full(pool_name, metrics) do
        Logger.warning("🚧 Bulkhead pool #{pool_name} is full: #{inspect(metrics)}")
      end
      
      @doc """
      Called when a bulkhead pool recovers from full capacity. Override for custom logic.
      """
      def on_bulkhead_recovery(pool_name, metrics) do
        Logger.info("🟢 Bulkhead pool #{pool_name} recovered: #{inspect(metrics)}")
      end
      
      defoverridable [on_bulkhead_full: 2, on_bulkhead_recovery: 2]
    end
  end
end