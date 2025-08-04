# Recursive Spawning and Meta-VSM Benchmarks
# Tests for hierarchical VSM creation and recursive process spawning

defmodule RecursiveSpawningBenchmarks do
  @moduledoc """
  Performance benchmarks for recursive VSM spawning and meta-system operations
  """
  
  use Benchee
  require Logger
  
  # Recursive spawning benchmarks
  def benchmark_recursive_spawning() do
    Benchee.run(
      %{
        "spawn_flat_10" => fn ->
          spawn_flat_vsm(10)
        end,
        
        "spawn_flat_100" => fn ->
          spawn_flat_vsm(100)
        end,
        
        "spawn_flat_1000" => fn ->
          spawn_flat_vsm(1000)
        end,
        
        "spawn_tree_depth_3" => fn ->
          spawn_tree_vsm(3, 3)
        end,
        
        "spawn_tree_depth_5" => fn ->
          spawn_tree_vsm(5, 2)
        end,
        
        "spawn_tree_depth_7" => fn ->
          spawn_tree_vsm(7, 2)
        end,
        
        "spawn_balanced_tree" => fn ->
          spawn_balanced_tree(4, 4)
        end,
        
        "spawn_fibonacci_tree" => fn ->
          spawn_fibonacci_tree(10)
        end,
        
        "spawn_fractal_vsm" => fn ->
          spawn_fractal_vsm(3, 3)
        end,
        
        "spawn_dynamic_topology" => fn ->
          spawn_dynamic_topology(50, 0.3)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/recursive_spawning.html"}
      ]
    )
  end
  
  # Meta-VSM operation benchmarks
  def benchmark_meta_vsm() do
    Benchee.run(
      %{
        "meta_vsm_create_simple" => fn ->
          create_meta_vsm(:simple, 10)
        end,
        
        "meta_vsm_create_hierarchical" => fn ->
          create_meta_vsm(:hierarchical, 3, 5)
        end,
        
        "meta_vsm_create_recursive" => fn ->
          create_meta_vsm(:recursive, 4)
        end,
        
        "meta_vsm_transform" => fn ->
          vsm = create_meta_vsm(:simple, 10)
          transform_meta_vsm(vsm, :hierarchical)
        end,
        
        "meta_vsm_merge" => fn ->
          vsm1 = create_meta_vsm(:simple, 5)
          vsm2 = create_meta_vsm(:simple, 5)
          merge_meta_vsms(vsm1, vsm2)
        end,
        
        "meta_vsm_split" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 10)
          split_meta_vsm(vsm, 2)
        end,
        
        "meta_vsm_replicate" => fn ->
          vsm = create_meta_vsm(:simple, 5)
          replicate_meta_vsm(vsm, 10)
        end,
        
        "meta_vsm_evolve" => fn ->
          vsm = create_meta_vsm(:simple, 20)
          evolve_meta_vsm(vsm, 5)
        end,
        
        "meta_vsm_optimize" => fn ->
          vsm = create_meta_vsm(:hierarchical, 4, 8)
          optimize_meta_vsm(vsm)
        end,
        
        "meta_vsm_cascade" => fn ->
          create_cascade_meta_vsm(5, 3)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/meta_vsm.html"}
      ]
    )
  end
  
  # Algedonic signal propagation benchmarks
  def benchmark_algedonic_signals() do
    Benchee.run(
      %{
        "algedonic_single_signal" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          propagate_algedonic_signal(vsm, :pain, 8.5)
        end,
        
        "algedonic_batch_10" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          signals = generate_algedonic_signals(10)
          batch_propagate_algedonic(vsm, signals)
        end,
        
        "algedonic_batch_100" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          signals = generate_algedonic_signals(100)
          batch_propagate_algedonic(vsm, signals)
        end,
        
        "algedonic_cascade" => fn ->
          vsm = create_meta_vsm(:hierarchical, 5, 3)
          cascade_algedonic_signal(vsm, :pain, 9.0)
        end,
        
        "algedonic_feedback_loop" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          create_algedonic_feedback_loop(vsm, 10)
        end,
        
        "algedonic_attenuation" => fn ->
          vsm = create_meta_vsm(:hierarchical, 5, 3)
          test_signal_attenuation(vsm, 0.8)
        end,
        
        "algedonic_amplification" => fn ->
          vsm = create_meta_vsm(:hierarchical, 5, 3)
          test_signal_amplification(vsm, 1.5)
        end,
        
        "algedonic_interference" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          test_signal_interference(vsm)
        end,
        
        "algedonic_threshold" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          test_threshold_detection(vsm, 7.0)
        end,
        
        "algedonic_pattern_recognition" => fn ->
          vsm = create_meta_vsm(:hierarchical, 3, 5)
          recognize_algedonic_pattern(vsm, [:pain, :pleasure, :pain])
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/algedonic_signals.html"}
      ]
    )
  end
  
  # Stress test for maximum spawning capacity
  def benchmark_spawn_limits() do
    Benchee.run(
      %{
        "spawn_limit_test_10k" => fn ->
          test_spawn_limit(10_000)
        end,
        
        "spawn_limit_test_50k" => fn ->
          test_spawn_limit(50_000)
        end,
        
        "spawn_limit_test_100k" => fn ->
          test_spawn_limit(100_000)
        end,
        
        "spawn_with_memory_pressure" => fn ->
          spawn_with_memory_pressure(1000, 1024)
        end,
        
        "spawn_with_message_passing" => fn ->
          spawn_with_message_passing(1000, 100)
        end,
        
        "spawn_with_supervision" => fn ->
          spawn_with_supervision(1000)
        end,
        
        "spawn_with_linking" => fn ->
          spawn_with_linking(1000)
        end,
        
        "spawn_with_monitoring" => fn ->
          spawn_with_monitoring(1000)
        end
      },
      time: 30,
      warmup: 5,
      memory_time: 5,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/spawn_limits.html"}
      ],
      print: [
        benchmarking: true,
        configuration: true,
        fast_warning: false
      ]
    )
  end
  
  # Helper functions for spawning
  defp spawn_flat_vsm(count) do
    parent = self()
    
    pids = Enum.map(1..count, fn i ->
      spawn(fn ->
        vsm_process(parent, i, :flat)
      end)
    end)
    
    # Wait for all to initialize
    Enum.each(pids, fn pid ->
      send(pid, :initialize)
    end)
    
    # Cleanup
    Enum.each(pids, fn pid ->
      send(pid, :terminate)
    end)
    
    length(pids)
  end
  
  defp spawn_tree_vsm(depth, branching_factor) do
    spawn_tree_node(depth, branching_factor, self())
  end
  
  defp spawn_tree_node(0, _, _parent), do: nil
  defp spawn_tree_node(depth, branching, parent) do
    node_pid = spawn(fn ->
      vsm_process(parent, depth, :tree)
    end)
    
    # Spawn children
    children = Enum.map(1..branching, fn _ ->
      spawn_tree_node(depth - 1, branching, node_pid)
    end)
    
    {node_pid, children}
  end
  
  defp spawn_balanced_tree(levels, children_per_node) do
    root = spawn(fn -> vsm_coordinator(self()) end)
    spawn_balanced_subtree(root, levels - 1, children_per_node)
    root
  end
  
  defp spawn_balanced_subtree(_parent, 0, _children_per_node), do: []
  defp spawn_balanced_subtree(parent, level, children_per_node) do
    children = Enum.map(1..children_per_node, fn i ->
      spawn(fn ->
        vsm_process(parent, {level, i}, :balanced)
      end)
    end)
    
    Enum.each(children, fn child ->
      spawn_balanced_subtree(child, level - 1, children_per_node)
    end)
    
    children
  end
  
  defp spawn_fibonacci_tree(n) do
    spawn_fib_node(n, self())
  end
  
  defp spawn_fib_node(0, _parent), do: nil
  defp spawn_fib_node(1, parent) do
    spawn(fn -> vsm_process(parent, 1, :fibonacci) end)
  end
  defp spawn_fib_node(n, parent) do
    node = spawn(fn -> vsm_process(parent, n, :fibonacci) end)
    left = spawn_fib_node(n - 1, node)
    right = spawn_fib_node(n - 2, node)
    {node, left, right}
  end
  
  defp spawn_fractal_vsm(depth, scale) do
    spawn_fractal_node(depth, scale, {0.0, 0.0}, 1.0, self())
  end
  
  defp spawn_fractal_node(0, _, _, _, _), do: nil
  defp spawn_fractal_node(depth, scale, {x, y}, size, parent) do
    node = spawn(fn ->
      vsm_fractal_process(parent, {x, y, size}, depth)
    end)
    
    # Create fractal children
    new_size = size / scale
    offsets = [
      {x - new_size, y - new_size},
      {x + new_size, y - new_size},
      {x - new_size, y + new_size},
      {x + new_size, y + new_size}
    ]
    
    children = Enum.map(offsets, fn offset ->
      spawn_fractal_node(depth - 1, scale, offset, new_size, node)
    end)
    
    {node, children}
  end
  
  defp spawn_dynamic_topology(nodes, connectivity) do
    # Create nodes
    pids = Enum.map(1..nodes, fn i ->
      spawn(fn -> vsm_dynamic_process(self(), i) end)
    end)
    
    # Create random connections
    connections = for p1 <- pids, p2 <- pids, p1 != p2, :rand.uniform() < connectivity do
      send(p1, {:connect, p2})
      {p1, p2}
    end
    
    %{nodes: pids, connections: connections}
  end
  
  # Meta-VSM creation functions
  defp create_meta_vsm(:simple, size) do
    %{
      type: :simple,
      size: size,
      processes: spawn_flat_vsm(size),
      metadata: %{created_at: System.system_time()}
    }
  end
  
  defp create_meta_vsm(:hierarchical, levels, branching) do
    %{
      type: :hierarchical,
      levels: levels,
      branching: branching,
      root: spawn_tree_vsm(levels, branching),
      metadata: %{created_at: System.system_time()}
    }
  end
  
  defp create_meta_vsm(:recursive, depth) do
    %{
      type: :recursive,
      depth: depth,
      structure: spawn_recursive_meta(depth),
      metadata: %{created_at: System.system_time()}
    }
  end
  
  defp spawn_recursive_meta(0), do: nil
  defp spawn_recursive_meta(depth) do
    meta = create_meta_vsm(:simple, 5)
    children = Enum.map(1..3, fn _ ->
      spawn_recursive_meta(depth - 1)
    end)
    %{meta: meta, children: children}
  end
  
  defp transform_meta_vsm(vsm, new_type) do
    Map.put(vsm, :type, new_type)
    |> Map.put(:transformed_at, System.system_time())
  end
  
  defp merge_meta_vsms(vsm1, vsm2) do
    %{
      type: :merged,
      components: [vsm1, vsm2],
      merged_at: System.system_time()
    }
  end
  
  defp split_meta_vsm(vsm, parts) do
    Enum.map(1..parts, fn i ->
      %{
        type: :split,
        original: vsm.type,
        part: i,
        total_parts: parts
      }
    end)
  end
  
  defp replicate_meta_vsm(vsm, copies) do
    Enum.map(1..copies, fn i ->
      Map.put(vsm, :replica_id, i)
    end)
  end
  
  defp evolve_meta_vsm(vsm, generations) do
    Enum.reduce(1..generations, vsm, fn gen, current_vsm ->
      %{
        current_vsm |
        generation: gen,
        fitness: :rand.uniform(),
        mutations: Enum.random(0..3)
      }
    end)
  end
  
  defp optimize_meta_vsm(vsm) do
    # Simulate optimization
    Process.sleep(10)
    Map.put(vsm, :optimized, true)
  end
  
  defp create_cascade_meta_vsm(levels, fanout) do
    Enum.reduce(1..levels, [], fn level, acc ->
      vsms = Enum.map(1..:math.pow(fanout, level - 1), fn _ ->
        create_meta_vsm(:simple, 3)
      end)
      [vsms | acc]
    end)
  end
  
  # Algedonic signal functions
  defp propagate_algedonic_signal(vsm, type, intensity) do
    signal = %{
      type: type,
      intensity: intensity,
      timestamp: System.system_time(:microsecond),
      hops: 0
    }
    
    # Simulate propagation through VSM hierarchy
    Process.sleep(round(intensity))
    Map.put(signal, :propagated, true)
  end
  
  defp generate_algedonic_signals(count) do
    Enum.map(1..count, fn i ->
      %{
        type: if(rem(i, 2) == 0, do: :pain, else: :pleasure),
        intensity: :rand.uniform() * 10,
        source: "benchmark_#{i}"
      }
    end)
  end
  
  defp batch_propagate_algedonic(vsm, signals) do
    Enum.map(signals, fn signal ->
      propagate_algedonic_signal(vsm, signal.type, signal.intensity)
    end)
  end
  
  defp cascade_algedonic_signal(vsm, type, intensity) do
    # Simulate cascading effect
    levels = Map.get(vsm, :levels, 3)
    Enum.reduce(1..levels, intensity, fn level, current_intensity ->
      attenuated = current_intensity * 0.8
      propagate_algedonic_signal(vsm, type, attenuated)
      attenuated
    end)
  end
  
  defp create_algedonic_feedback_loop(vsm, iterations) do
    Enum.reduce(1..iterations, 5.0, fn _, intensity ->
      signal_type = if intensity > 7.0, do: :pain, else: :pleasure
      propagate_algedonic_signal(vsm, signal_type, intensity)
      # Feedback adjustment
      intensity + (:rand.uniform() - 0.5) * 2
    end)
  end
  
  defp test_signal_attenuation(vsm, factor) do
    initial = 10.0
    final = initial * :math.pow(factor, Map.get(vsm, :levels, 3))
    propagate_algedonic_signal(vsm, :pain, final)
  end
  
  defp test_signal_amplification(vsm, factor) do
    initial = 2.0
    final = initial * :math.pow(factor, Map.get(vsm, :levels, 3))
    propagate_algedonic_signal(vsm, :pleasure, min(final, 10.0))
  end
  
  defp test_signal_interference(vsm) do
    pain_signal = propagate_algedonic_signal(vsm, :pain, 8.0)
    pleasure_signal = propagate_algedonic_signal(vsm, :pleasure, 6.0)
    # Simulate interference
    {pain_signal, pleasure_signal}
  end
  
  defp test_threshold_detection(vsm, threshold) do
    signals = generate_algedonic_signals(20)
    above_threshold = Enum.filter(signals, fn s -> s.intensity > threshold end)
    batch_propagate_algedonic(vsm, above_threshold)
  end
  
  defp recognize_algedonic_pattern(vsm, pattern) do
    signals = Enum.map(pattern, fn type ->
      %{type: type, intensity: :rand.uniform() * 10}
    end)
    batch_propagate_algedonic(vsm, signals)
  end
  
  # Spawn limit testing
  defp test_spawn_limit(target) do
    try do
      pids = Enum.map(1..target, fn i ->
        spawn(fn ->
          receive do
            :terminate -> :ok
          end
        end)
      end)
      
      # Cleanup
      Enum.each(pids, &send(&1, :terminate))
      {:ok, length(pids)}
    rescue
      e -> {:error, e}
    end
  end
  
  defp spawn_with_memory_pressure(count, bytes_per_process) do
    pids = Enum.map(1..count, fn i ->
      spawn(fn ->
        # Hold memory
        _data = :crypto.strong_rand_bytes(bytes_per_process)
        receive do
          :terminate -> :ok
        end
      end)
    end)
    
    Process.sleep(100)
    Enum.each(pids, &send(&1, :terminate))
    length(pids)
  end
  
  defp spawn_with_message_passing(count, messages_per_process) do
    parent = self()
    
    pids = Enum.map(1..count, fn i ->
      spawn(fn ->
        Enum.each(1..messages_per_process, fn j ->
          send(parent, {:message, i, j})
        end)
      end)
    end)
    
    # Receive all messages
    total_messages = count * messages_per_process
    Enum.each(1..total_messages, fn _ ->
      receive do
        {:message, _, _} -> :ok
      after
        1000 -> :timeout
      end
    end)
    
    length(pids)
  end
  
  defp spawn_with_supervision(count) do
    {:ok, supervisor} = Task.Supervisor.start_link()
    
    tasks = Enum.map(1..count, fn i ->
      Task.Supervisor.async(supervisor, fn ->
        Process.sleep(10)
        i
      end)
    end)
    
    results = Enum.map(tasks, &Task.await(&1, 5000))
    Process.exit(supervisor, :normal)
    length(results)
  end
  
  defp spawn_with_linking(count) do
    pids = Enum.map(1..count, fn i ->
      spawn_link(fn ->
        Process.flag(:trap_exit, true)
        receive do
          :terminate -> :ok
          {:EXIT, _, _} -> :ok
        end
      end)
    end)
    
    Enum.each(pids, &send(&1, :terminate))
    length(pids)
  end
  
  defp spawn_with_monitoring(count) do
    pids = Enum.map(1..count, fn i ->
      pid = spawn(fn ->
        receive do
          :terminate -> :ok
        end
      end)
      _ref = Process.monitor(pid)
      pid
    end)
    
    Enum.each(pids, &send(&1, :terminate))
    
    # Wait for DOWN messages
    Enum.each(pids, fn _ ->
      receive do
        {:DOWN, _, :process, _, _} -> :ok
      after
        1000 -> :timeout
      end
    end)
    
    length(pids)
  end
  
  # VSM process implementations
  defp vsm_process(parent, id, type) do
    receive do
      :initialize ->
        send(parent, {:initialized, self(), id, type})
        vsm_process(parent, id, type)
      
      :terminate ->
        :ok
      
      {:process, data} ->
        result = process_data(data)
        send(parent, {:result, self(), result})
        vsm_process(parent, id, type)
      
      _ ->
        vsm_process(parent, id, type)
    end
  end
  
  defp vsm_coordinator(parent) do
    receive do
      {:coordinate, tasks} ->
        results = Enum.map(tasks, &execute_task/1)
        send(parent, {:coordinated, results})
        vsm_coordinator(parent)
      
      :terminate ->
        :ok
      
      _ ->
        vsm_coordinator(parent)
    end
  end
  
  defp vsm_fractal_process(parent, position, depth) do
    receive do
      {:compute, function} ->
        result = apply_fractal_function(function, position, depth)
        send(parent, {:fractal_result, self(), result})
        vsm_fractal_process(parent, position, depth)
      
      :terminate ->
        :ok
      
      _ ->
        vsm_fractal_process(parent, position, depth)
    end
  end
  
  defp vsm_dynamic_process(parent, id) do
    connections = []
    vsm_dynamic_loop(parent, id, connections)
  end
  
  defp vsm_dynamic_loop(parent, id, connections) do
    receive do
      {:connect, pid} ->
        vsm_dynamic_loop(parent, id, [pid | connections])
      
      {:broadcast, message} ->
        Enum.each(connections, fn conn ->
          send(conn, {:message, id, message})
        end)
        vsm_dynamic_loop(parent, id, connections)
      
      :terminate ->
        :ok
      
      _ ->
        vsm_dynamic_loop(parent, id, connections)
    end
  end
  
  defp process_data(data) do
    # Simulate data processing
    Process.sleep(1)
    Map.put(data, :processed, true)
  end
  
  defp execute_task(task) do
    # Simulate task execution
    Process.sleep(5)
    {:completed, task}
  end
  
  defp apply_fractal_function(function, {x, y, size}, depth) do
    # Simulate fractal computation
    result = function.(x, y) * size * depth
    Process.sleep(1)
    result
  end
end