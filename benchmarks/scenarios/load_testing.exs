# Load Testing Scenarios for VSM Phoenix
# Simulates various load patterns and stress conditions

defmodule LoadTesting do
  @moduledoc """
  Comprehensive load testing scenarios for VSM systems
  """
  
  alias VsmPhoenix.Core.{VarietyProcessor, System}
  alias VsmPhoenix.Quantum.{Superposition, Entanglement}
  alias VsmPhoenix.Meta.VSM
  
  # Load patterns
  def constant_load(rate, duration) do
    IO.puts("Starting constant load test: #{rate} req/s for #{duration}s")
    
    start_time = System.monotonic_time(:millisecond)
    interval = div(1000, rate) # milliseconds between requests
    
    Task.async_stream(
      1..rate * duration,
      fn i ->
        Process.sleep(interval)
        execute_request(i)
      end,
      max_concurrency: rate,
      timeout: duration * 1000 + 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> analyze_results(start_time)
  end
  
  def ramp_up_load(initial_rate, max_rate, ramp_duration, hold_duration) do
    IO.puts("Starting ramp-up load test: #{initial_rate} -> #{max_rate} req/s")
    
    start_time = System.monotonic_time(:millisecond)
    rate_increment = (max_rate - initial_rate) / ramp_duration
    
    # Ramp-up phase
    ramp_results = Enum.flat_map(1..ramp_duration, fn second ->
      current_rate = round(initial_rate + rate_increment * second)
      execute_concurrent_requests(current_rate)
    end)
    
    # Hold phase
    hold_results = Enum.flat_map(1..hold_duration, fn _second ->
      execute_concurrent_requests(max_rate)
    end)
    
    (ramp_results ++ hold_results)
    |> analyze_results(start_time)
  end
  
  def spike_load(baseline_rate, spike_rate, spike_duration, total_duration) do
    IO.puts("Starting spike load test: baseline=#{baseline_rate}, spike=#{spike_rate} req/s")
    
    start_time = System.monotonic_time(:millisecond)
    spike_start = div(total_duration - spike_duration, 2)
    spike_end = spike_start + spike_duration
    
    results = Enum.flat_map(1..total_duration, fn second ->
      rate = if second >= spike_start and second < spike_end do
        spike_rate
      else
        baseline_rate
      end
      
      execute_concurrent_requests(rate)
    end)
    
    analyze_results(results, start_time)
  end
  
  def wave_load(min_rate, max_rate, wave_period, duration) do
    IO.puts("Starting wave load test: #{min_rate}-#{max_rate} req/s, period=#{wave_period}s")
    
    start_time = System.monotonic_time(:millisecond)
    amplitude = (max_rate - min_rate) / 2
    mean_rate = (max_rate + min_rate) / 2
    
    results = Enum.flat_map(1..duration, fn second ->
      # Sinusoidal wave pattern
      angle = 2 * :math.pi() * second / wave_period
      rate = round(mean_rate + amplitude * :math.sin(angle))
      
      execute_concurrent_requests(rate)
    end)
    
    analyze_results(results, start_time)
  end
  
  # Stress testing scenarios
  def memory_stress_test(allocation_mb, duration) do
    IO.puts("Starting memory stress test: #{allocation_mb}MB for #{duration}s")
    
    # Allocate large binaries to stress memory
    binaries = Enum.map(1..allocation_mb, fn _ ->
      :crypto.strong_rand_bytes(1024 * 1024) # 1MB each
    end)
    
    start_time = System.monotonic_time(:millisecond)
    
    # Run operations while holding memory
    results = Enum.flat_map(1..duration, fn _second ->
      execute_concurrent_requests(100)
    end)
    
    # Force GC to measure impact
    :erlang.garbage_collect()
    
    # Clear references
    _binaries = nil
    
    analyze_results(results, start_time)
  end
  
  def cpu_stress_test(complexity, duration) do
    IO.puts("Starting CPU stress test: complexity=#{complexity} for #{duration}s")
    
    start_time = System.monotonic_time(:millisecond)
    
    # Spawn CPU-intensive tasks
    tasks = Enum.map(1..System.schedulers_online(), fn i ->
      Task.async(fn ->
        cpu_intensive_work(complexity, duration * 1000, i)
      end)
    end)
    
    # Run normal operations concurrently
    results = Enum.flat_map(1..duration, fn _second ->
      execute_concurrent_requests(50)
    end)
    
    # Wait for CPU tasks to complete
    Enum.each(tasks, &Task.await(&1, duration * 1000 + 5000))
    
    analyze_results(results, start_time)
  end
  
  def network_stress_test(packet_size_kb, packets_per_second, duration) do
    IO.puts("Starting network stress test: #{packet_size_kb}KB packets at #{packets_per_second}/s")
    
    start_time = System.monotonic_time(:millisecond)
    packet_data = :crypto.strong_rand_bytes(packet_size_kb * 1024)
    
    results = Enum.flat_map(1..duration, fn _second ->
      tasks = Enum.map(1..packets_per_second, fn i ->
        Task.async(fn ->
          simulate_network_operation(packet_data, i)
        end)
      end)
      
      Enum.map(tasks, fn task ->
        Task.await(task, 5000)
      end)
    end)
    
    analyze_results(results, start_time)
  end
  
  # Chaos testing
  def chaos_test(duration, chaos_probability \\ 0.1) do
    IO.puts("Starting chaos test: duration=#{duration}s, chaos_probability=#{chaos_probability}")
    
    start_time = System.monotonic_time(:millisecond)
    
    results = Enum.flat_map(1..duration, fn second ->
      # Randomly inject chaos
      if :rand.uniform() < chaos_probability do
        inject_chaos()
      end
      
      # Try to execute normal operations
      try do
        execute_concurrent_requests(100)
      rescue
        _ -> [{:error, :chaos_failure, System.monotonic_time(:millisecond) - start_time}]
      end
    end)
    
    analyze_results(results, start_time)
  end
  
  # Helper functions
  defp execute_request(id) do
    start = System.monotonic_time(:microsecond)
    
    try do
      # Simulate variety processing
      data = generate_test_data(id)
      _result = VarietyProcessor.process(data)
      
      latency = System.monotonic_time(:microsecond) - start
      {:ok, id, latency}
    rescue
      error ->
        latency = System.monotonic_time(:microsecond) - start
        {:error, error, latency}
    end
  end
  
  defp execute_concurrent_requests(count) do
    Task.async_stream(
      1..count,
      &execute_request/1,
      max_concurrency: count,
      timeout: 5000
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, _} -> {:error, :timeout, 5000}
    end)
  end
  
  defp generate_test_data(id) do
    %{
      id: id,
      timestamp: System.system_time(:microsecond),
      value: :rand.uniform(),
      metadata: %{
        source: "load_test",
        complexity: Enum.random([:simple, :medium, :complex])
      }
    }
  end
  
  defp cpu_intensive_work(complexity, duration_ms, worker_id) do
    end_time = System.monotonic_time(:millisecond) + duration_ms
    
    Stream.iterate(0, &(&1 + 1))
    |> Enum.reduce_while(0, fn i, acc ->
      if System.monotonic_time(:millisecond) >= end_time do
        {:halt, acc}
      else
        # Perform CPU-intensive calculation
        result = case complexity do
          :low -> :math.sqrt(i)
          :medium -> :math.pow(i, 0.5) * :math.log(i + 1)
          :high -> Enum.reduce(1..100, 0, fn j, sum ->
            sum + :math.sin(i * j) * :math.cos(i / (j + 1))
          end)
        end
        
        {:cont, acc + result}
      end
    end)
  end
  
  defp simulate_network_operation(data, id) do
    start = System.monotonic_time(:microsecond)
    
    # Simulate network latency
    Process.sleep(Enum.random(1..10))
    
    # Simulate data processing
    _checksum = :erlang.phash2(data)
    
    latency = System.monotonic_time(:microsecond) - start
    {:ok, id, latency, byte_size(data)}
  end
  
  defp inject_chaos() do
    chaos_action = Enum.random([
      :kill_random_process,
      :exhaust_ets,
      :trigger_gc,
      :spawn_bomb,
      :memory_spike
    ])
    
    case chaos_action do
      :kill_random_process ->
        processes = Process.list()
        if length(processes) > 10 do
          Process.exit(Enum.random(processes), :chaos_kill)
        end
      
      :exhaust_ets ->
        # Create temporary ETS tables
        Enum.each(1..100, fn i ->
          :ets.new(String.to_atom("chaos_#{i}"), [:set, :public])
        end)
      
      :trigger_gc ->
        Enum.each(Process.list(), &:erlang.garbage_collect/1)
      
      :spawn_bomb ->
        # Spawn many short-lived processes
        Enum.each(1..1000, fn _ ->
          spawn(fn -> Process.sleep(10) end)
        end)
      
      :memory_spike ->
        # Allocate and immediately release memory
        _data = :crypto.strong_rand_bytes(10 * 1024 * 1024)
        :erlang.garbage_collect()
    end
  end
  
  defp analyze_results(results, start_time) do
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    {successes, failures} = Enum.split_with(results, fn
      {:ok, _, _} -> true
      _ -> false
    end)
    
    latencies = Enum.map(successes, fn {:ok, _, latency} -> latency end)
    
    stats = if length(latencies) > 0 do
      %{
        total_requests: length(results),
        successful: length(successes),
        failed: length(failures),
        duration_ms: duration,
        throughput: length(results) * 1000 / duration,
        latency: %{
          min: Enum.min(latencies),
          max: Enum.max(latencies),
          mean: Enum.sum(latencies) / length(latencies),
          median: median(latencies),
          p95: percentile(latencies, 0.95),
          p99: percentile(latencies, 0.99)
        }
      }
    else
      %{
        total_requests: 0,
        successful: 0,
        failed: length(failures),
        duration_ms: duration,
        throughput: 0,
        latency: %{}
      }
    end
    
    IO.puts("\nLoad Test Results:")
    IO.inspect(stats, pretty: true)
    
    stats
  end
  
  defp median(list) do
    sorted = Enum.sort(list)
    mid = div(length(sorted), 2)
    
    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
  
  defp percentile(list, p) do
    sorted = Enum.sort(list)
    index = round(p * length(sorted)) - 1
    Enum.at(sorted, max(0, index))
  end
end