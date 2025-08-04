# VSM Phoenix Performance Benchmarking Suite
# Comprehensive benchmarks for variety processing, quantum operations, and recursive spawning

Application.put_env(:vsm_phoenix, VsmPhoenixWeb.Endpoint,
  http: [port: 4002],
  server: false
)

Application.ensure_all_started(:vsm_phoenix)
ExUnit.start()

# Helper modules for benchmarking
defmodule BenchmarkHelpers do
  @moduledoc """
  Common utilities for VSM benchmarks
  """
  
  def generate_variety_data(count, complexity \\ :medium) do
    Enum.map(1..count, fn i ->
      case complexity do
        :simple ->
          %{id: i, value: :rand.uniform()}
        
        :medium ->
          %{
            id: i,
            value: :rand.uniform(),
            metadata: %{
              timestamp: System.system_time(:microsecond),
              source: "benchmark_#{i}",
              tags: Enum.take_random(["urgent", "normal", "low", "critical"], 2)
            }
          }
        
        :complex ->
          %{
            id: i,
            value: :rand.uniform(),
            quantum_state: %{
              superposition: Enum.map(1..8, fn _ -> :rand.uniform() end),
              entanglement: :rand.uniform() > 0.5,
              coherence: :rand.uniform()
            },
            metadata: %{
              timestamp: System.system_time(:microsecond),
              source: "benchmark_#{i}",
              tags: Enum.take_random(["urgent", "normal", "low", "critical"], 3),
              history: Enum.map(1..5, fn j -> 
                %{step: j, value: :rand.uniform(), time: System.system_time()}
              end)
            },
            algedonic: %{
              pain: :rand.uniform() * 10,
              pleasure: :rand.uniform() * 10
            }
          }
      end
    end)
  end
  
  def spawn_vsm_system(size) do
    parent = self()
    
    Enum.map(1..size, fn i ->
      spawn_link(fn ->
        Process.register(self(), String.to_atom("vsm_#{i}"))
        vsm_loop(parent, i)
      end)
    end)
  end
  
  defp vsm_loop(parent, id) do
    receive do
      {:process, data} ->
        # Simulate variety processing
        result = process_variety(data)
        send(parent, {:result, id, result})
        vsm_loop(parent, id)
      
      :terminate ->
        :ok
    end
  end
  
  defp process_variety(data) do
    # Simulate complex processing
    :timer.sleep(:rand.uniform(5))
    Map.put(data, :processed, true)
  end
end

# Main benchmark suite
Benchee.run(
  %{
    # Variety throughput benchmarks
    "variety_simple_100" => fn ->
      data = BenchmarkHelpers.generate_variety_data(100, :simple)
      VsmPhoenix.Core.VarietyProcessor.process_batch(data)
    end,
    
    "variety_medium_100" => fn ->
      data = BenchmarkHelpers.generate_variety_data(100, :medium)
      VsmPhoenix.Core.VarietyProcessor.process_batch(data)
    end,
    
    "variety_complex_100" => fn ->
      data = BenchmarkHelpers.generate_variety_data(100, :complex)
      VsmPhoenix.Core.VarietyProcessor.process_batch(data)
    end,
    
    "variety_simple_1000" => fn ->
      data = BenchmarkHelpers.generate_variety_data(1000, :simple)
      VsmPhoenix.Core.VarietyProcessor.process_batch(data)
    end,
    
    "variety_complex_1000" => fn ->
      data = BenchmarkHelpers.generate_variety_data(1000, :complex)
      VsmPhoenix.Core.VarietyProcessor.process_batch(data)
    end,
    
    # Quantum operation benchmarks
    "quantum_superposition_small" => fn ->
      VsmPhoenix.Quantum.Superposition.create_state(8)
    end,
    
    "quantum_superposition_large" => fn ->
      VsmPhoenix.Quantum.Superposition.create_state(256)
    end,
    
    "quantum_entanglement_pair" => fn ->
      VsmPhoenix.Quantum.Entanglement.create_pair()
    end,
    
    "quantum_entanglement_network" => fn ->
      VsmPhoenix.Quantum.Entanglement.create_network(10)
    end,
    
    "quantum_measurement_single" => fn ->
      state = VsmPhoenix.Quantum.Superposition.create_state(8)
      VsmPhoenix.Quantum.Measurement.observe(state)
    end,
    
    "quantum_measurement_batch" => fn ->
      states = Enum.map(1..100, fn _ -> 
        VsmPhoenix.Quantum.Superposition.create_state(8)
      end)
      Enum.map(states, &VsmPhoenix.Quantum.Measurement.observe/1)
    end,
    
    # Recursive spawning benchmarks
    "vsm_spawn_10" => fn ->
      pids = BenchmarkHelpers.spawn_vsm_system(10)
      Enum.each(pids, &Process.exit(&1, :normal))
    end,
    
    "vsm_spawn_100" => fn ->
      pids = BenchmarkHelpers.spawn_vsm_system(100)
      Enum.each(pids, &Process.exit(&1, :normal))
    end,
    
    "vsm_spawn_1000" => fn ->
      pids = BenchmarkHelpers.spawn_vsm_system(1000)
      Enum.each(pids, &Process.exit(&1, :normal))
    end,
    
    # Meta-VSM operations
    "meta_vsm_single_level" => fn ->
      VsmPhoenix.Meta.VSM.create_hierarchy(1, 10)
    end,
    
    "meta_vsm_three_levels" => fn ->
      VsmPhoenix.Meta.VSM.create_hierarchy(3, 5)
    end,
    
    "meta_vsm_five_levels" => fn ->
      VsmPhoenix.Meta.VSM.create_hierarchy(5, 3)
    end,
    
    # Algedonic signal benchmarks
    "algedonic_signal_single" => fn ->
      VsmPhoenix.Algedonic.Signal.process(%{
        type: :pain,
        intensity: 8.5,
        source: "benchmark"
      })
    end,
    
    "algedonic_signal_batch_100" => fn ->
      signals = Enum.map(1..100, fn i ->
        %{
          type: if(rem(i, 2) == 0, do: :pain, else: :pleasure),
          intensity: :rand.uniform() * 10,
          source: "benchmark_#{i}"
        }
      end)
      VsmPhoenix.Algedonic.Signal.process_batch(signals)
    end,
    
    "algedonic_propagation" => fn ->
      hierarchy = VsmPhoenix.Meta.VSM.create_hierarchy(3, 5)
      signal = %{type: :pain, intensity: 9.0, source: "critical"}
      VsmPhoenix.Algedonic.Signal.propagate(signal, hierarchy)
    end
  },
  time: 10,
  memory_time: 2,
  warmup: 2,
  parallel: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/results/vsm_benchmark.html"},
    {Benchee.Formatters.JSON, file: "benchmarks/results/vsm_benchmark.json"}
  ],
  save: [path: "benchmarks/results/vsm_benchmark.benchee"],
  load: "benchmarks/results/vsm_benchmark.benchee",
  print: [
    benchmarking: true,
    configuration: true,
    fast_warning: true
  ],
  inputs: nil,
  pre_check: true,
  unit_scaling: :best
)