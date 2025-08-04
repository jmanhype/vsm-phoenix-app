# Variety Throughput Performance Benchmarks
# Tests for variety processing capacity and throughput optimization

defmodule VarietyThroughputBenchmarks do
  @moduledoc """
  Comprehensive benchmarks for variety processing throughput in VSM systems
  """
  
  use Benchee
  require Logger
  
  # Main throughput benchmarks
  def benchmark_variety_throughput() do
    Benchee.run(
      %{
        "variety_serial_100" => fn ->
          process_variety_serial(100)
        end,
        
        "variety_parallel_100" => fn ->
          process_variety_parallel(100, 10)
        end,
        
        "variety_serial_1000" => fn ->
          process_variety_serial(1000)
        end,
        
        "variety_parallel_1000" => fn ->
          process_variety_parallel(1000, 50)
        end,
        
        "variety_serial_10000" => fn ->
          process_variety_serial(10000)
        end,
        
        "variety_parallel_10000" => fn ->
          process_variety_parallel(10000, 100)
        end,
        
        "variety_stream_processing" => fn ->
          process_variety_stream(1000)
        end,
        
        "variety_batch_processing" => fn ->
          process_variety_batch(1000, 100)
        end,
        
        "variety_pipeline_3_stages" => fn ->
          process_variety_pipeline(1000, 3)
        end,
        
        "variety_pipeline_5_stages" => fn ->
          process_variety_pipeline(1000, 5)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      parallel: 1,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/variety_throughput.html"}
      ]
    )
  end
  
  # Variety complexity benchmarks
  def benchmark_variety_complexity() do
    Benchee.run(
      %{
        "simple_variety_processing" => fn ->
          data = generate_variety_data(1000, :simple)
          process_variety_by_complexity(data, :simple)
        end,
        
        "moderate_variety_processing" => fn ->
          data = generate_variety_data(1000, :moderate)
          process_variety_by_complexity(data, :moderate)
        end,
        
        "complex_variety_processing" => fn ->
          data = generate_variety_data(1000, :complex)
          process_variety_by_complexity(data, :complex)
        end,
        
        "mixed_variety_processing" => fn ->
          data = generate_mixed_variety_data(1000)
          process_mixed_variety(data)
        end,
        
        "adaptive_variety_processing" => fn ->
          data = generate_variety_data(1000, :adaptive)
          process_adaptive_variety(data)
        end,
        
        "hierarchical_variety" => fn ->
          data = generate_hierarchical_variety(5, 200)
          process_hierarchical_variety(data)
        end,
        
        "recursive_variety" => fn ->
          data = generate_recursive_variety(4, 100)
          process_recursive_variety(data)
        end,
        
        "quantum_variety" => fn ->
          data = generate_quantum_variety(500)
          process_quantum_variety(data)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/variety_complexity.html"}
      ]
    )
  end
  
  # Variety filtering and transformation benchmarks
  def benchmark_variety_transformations() do
    Benchee.run(
      %{
        "variety_filter_simple" => fn ->
          data = generate_variety_data(1000, :moderate)
          filter_variety(data, &simple_filter/1)
        end,
        
        "variety_filter_complex" => fn ->
          data = generate_variety_data(1000, :complex)
          filter_variety(data, &complex_filter/1)
        end,
        
        "variety_map_transform" => fn ->
          data = generate_variety_data(1000, :moderate)
          transform_variety(data, &map_transform/1)
        end,
        
        "variety_reduce_aggregate" => fn ->
          data = generate_variety_data(1000, :moderate)
          aggregate_variety(data)
        end,
        
        "variety_partition" => fn ->
          data = generate_variety_data(1000, :complex)
          partition_variety(data, 10)
        end,
        
        "variety_sort_by_relevance" => fn ->
          data = generate_variety_data(1000, :moderate)
          sort_variety_by_relevance(data)
        end,
        
        "variety_deduplicate" => fn ->
          data = generate_variety_with_duplicates(1000, 0.3)
          deduplicate_variety(data)
        end,
        
        "variety_normalize" => fn ->
          data = generate_variety_data(1000, :complex)
          normalize_variety(data)
        end,
        
        "variety_compress" => fn ->
          data = generate_variety_data(1000, :complex)
          compress_variety(data)
        end,
        
        "variety_encode_decode" => fn ->
          data = generate_variety_data(1000, :moderate)
          encoded = encode_variety(data)
          decode_variety(encoded)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/variety_transformations.html"}
      ]
    )
  end
  
  # Variety channel capacity benchmarks
  def benchmark_channel_capacity() do
    Benchee.run(
      %{
        "channel_capacity_small" => fn ->
          test_channel_capacity(10, 100)
        end,
        
        "channel_capacity_medium" => fn ->
          test_channel_capacity(100, 100)
        end,
        
        "channel_capacity_large" => fn ->
          test_channel_capacity(1000, 100)
        end,
        
        "channel_multiplexing_2" => fn ->
          test_channel_multiplexing(2, 500)
        end,
        
        "channel_multiplexing_5" => fn ->
          test_channel_multiplexing(5, 200)
        end,
        
        "channel_multiplexing_10" => fn ->
          test_channel_multiplexing(10, 100)
        end,
        
        "channel_buffering_none" => fn ->
          test_channel_buffering(1000, 0)
        end,
        
        "channel_buffering_small" => fn ->
          test_channel_buffering(1000, 10)
        end,
        
        "channel_buffering_large" => fn ->
          test_channel_buffering(1000, 100)
        end,
        
        "channel_backpressure" => fn ->
          test_channel_backpressure(1000, 50)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/channel_capacity.html"}
      ]
    )
  end
  
  # Variety attenuation benchmarks
  def benchmark_variety_attenuation() do
    Benchee.run(
      %{
        "attenuation_none" => fn ->
          data = generate_variety_data(1000, :moderate)
          apply_attenuation(data, 1.0)
        end,
        
        "attenuation_light" => fn ->
          data = generate_variety_data(1000, :moderate)
          apply_attenuation(data, 0.9)
        end,
        
        "attenuation_moderate" => fn ->
          data = generate_variety_data(1000, :moderate)
          apply_attenuation(data, 0.7)
        end,
        
        "attenuation_heavy" => fn ->
          data = generate_variety_data(1000, :moderate)
          apply_attenuation(data, 0.5)
        end,
        
        "attenuation_adaptive" => fn ->
          data = generate_variety_data(1000, :complex)
          apply_adaptive_attenuation(data)
        end,
        
        "attenuation_hierarchical" => fn ->
          data = generate_hierarchical_variety(5, 200)
          apply_hierarchical_attenuation(data, 0.8)
        end,
        
        "amplification_moderate" => fn ->
          data = generate_variety_data(1000, :moderate)
          apply_amplification(data, 1.5)
        end,
        
        "amplification_selective" => fn ->
          data = generate_variety_data(1000, :complex)
          apply_selective_amplification(data)
        end
      },
      time: 10,
      warmup: 3,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: "benchmarks/results/variety_attenuation.html"}
      ]
    )
  end
  
  # Helper functions for variety generation
  defp generate_variety_data(count, complexity) do
    Enum.map(1..count, fn i ->
      base = %{
        id: i,
        timestamp: System.system_time(:microsecond),
        value: :rand.uniform()
      }
      
      case complexity do
        :simple ->
          base
        
        :moderate ->
          Map.merge(base, %{
            category: Enum.random([:operational, :tactical, :strategic]),
            priority: Enum.random(1..10),
            metadata: %{
              source: "generator_#{rem(i, 10)}",
              tags: Enum.take_random(["alpha", "beta", "gamma", "delta"], 2)
            }
          })
        
        :complex ->
          Map.merge(base, %{
            category: Enum.random([:operational, :tactical, :strategic]),
            priority: Enum.random(1..10),
            metadata: %{
              source: "generator_#{rem(i, 10)}",
              tags: Enum.take_random(["alpha", "beta", "gamma", "delta", "epsilon"], 3),
              attributes: Enum.map(1..5, fn j -> {"attr_#{j}", :rand.uniform()} end) |> Map.new(),
              history: Enum.map(1..3, fn j -> 
                %{step: j, value: :rand.uniform(), time: System.system_time()}
              end)
            },
            relationships: Enum.take_random(1..count, min(3, count - 1)),
            quantum_state: %{
              superposition: :rand.uniform() > 0.5,
              entangled: if(:rand.uniform() > 0.7, do: [i - 1, i + 1], else: [])
            }
          })
        
        :adaptive ->
          Map.merge(base, %{
            complexity_level: :rand.uniform() * 10,
            processing_hint: Enum.random([:fast, :normal, :intensive]),
            adaptive_params: %{
              threshold: :rand.uniform(),
              scaling_factor: 1 + :rand.uniform()
            }
          })
      end
    end)
  end
  
  defp generate_mixed_variety_data(count) do
    complexities = [:simple, :moderate, :complex]
    
    Enum.map(1..count, fn i ->
      complexity = Enum.at(complexities, rem(i, 3))
      hd(generate_variety_data(1, complexity))
    end)
  end
  
  defp generate_hierarchical_variety(levels, items_per_level) do
    Enum.map(1..levels, fn level ->
      %{
        level: level,
        data: generate_variety_data(items_per_level, :moderate),
        children: if(level < levels, do: :placeholder, else: nil)
      }
    end)
  end
  
  defp generate_recursive_variety(depth, base_count) do
    if depth == 0 do
      generate_variety_data(base_count, :simple)
    else
      %{
        depth: depth,
        data: generate_variety_data(base_count, :moderate),
        nested: generate_recursive_variety(depth - 1, div(base_count, 2))
      }
    end
  end
  
  defp generate_quantum_variety(count) do
    Enum.map(1..count, fn i ->
      %{
        id: i,
        classical_value: :rand.uniform(),
        quantum_state: %{
          amplitude: :math.cos(:rand.uniform() * :math.pi()),
          phase: :rand.uniform() * 2 * :math.pi(),
          entanglement_strength: :rand.uniform(),
          coherence_time: :rand.uniform() * 1000
        },
        measurement_basis: Enum.random([:computational, :hadamard, :phase])
      }
    end)
  end
  
  defp generate_variety_with_duplicates(count, duplicate_ratio) do
    unique_count = round(count * (1 - duplicate_ratio))
    duplicate_count = count - unique_count
    
    unique_data = generate_variety_data(unique_count, :moderate)
    duplicates = Enum.take_random(unique_data, duplicate_count)
    
    Enum.shuffle(unique_data ++ duplicates)
  end
  
  # Processing functions
  defp process_variety_serial(count) do
    data = generate_variety_data(count, :moderate)
    
    Enum.map(data, fn item ->
      # Simulate processing
      Process.sleep(0)
      Map.put(item, :processed, true)
    end)
  end
  
  defp process_variety_parallel(count, parallelism) do
    data = generate_variety_data(count, :moderate)
    
    Task.async_stream(
      data,
      fn item ->
        # Simulate processing
        Process.sleep(0)
        Map.put(item, :processed, true)
      end,
      max_concurrency: parallelism,
      timeout: 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end
  
  defp process_variety_stream(count) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.take(count)
    |> Stream.map(fn i ->
      %{id: i, value: :rand.uniform(), timestamp: System.system_time()}
    end)
    |> Stream.map(fn item ->
      Map.put(item, :processed, true)
    end)
    |> Enum.to_list()
  end
  
  defp process_variety_batch(total_count, batch_size) do
    data = generate_variety_data(total_count, :moderate)
    
    Enum.chunk_every(data, batch_size)
    |> Enum.flat_map(fn batch ->
      # Process batch
      Enum.map(batch, fn item ->
        Map.put(item, :batch_processed, true)
      end)
    end)
  end
  
  defp process_variety_pipeline(count, stages) do
    data = generate_variety_data(count, :moderate)
    
    pipeline = Enum.map(1..stages, fn stage ->
      fn item ->
        Map.put(item, "stage_#{stage}", true)
      end
    end)
    
    Enum.reduce(pipeline, data, fn stage_fn, current_data ->
      Enum.map(current_data, stage_fn)
    end)
  end
  
  defp process_variety_by_complexity(data, complexity) do
    processing_time = case complexity do
      :simple -> 0
      :moderate -> 1
      :complex -> 2
    end
    
    Enum.map(data, fn item ->
      Process.sleep(processing_time)
      Map.put(item, :complexity_processed, complexity)
    end)
  end
  
  defp process_mixed_variety(data) do
    Enum.map(data, fn item ->
      complexity = Map.get(item, :complexity_level, 5)
      Process.sleep(round(complexity / 10))
      Map.put(item, :mixed_processed, true)
    end)
  end
  
  defp process_adaptive_variety(data) do
    Enum.map(data, fn item ->
      hint = Map.get(item, :processing_hint, :normal)
      
      case hint do
        :fast -> Map.put(item, :fast_processed, true)
        :normal -> 
          Process.sleep(1)
          Map.put(item, :normal_processed, true)
        :intensive ->
          Process.sleep(2)
          Map.put(item, :intensive_processed, true)
      end
    end)
  end
  
  defp process_hierarchical_variety(data) do
    Enum.map(data, fn level_data ->
      processed_data = Enum.map(level_data.data, fn item ->
        Map.put(item, :hierarchical_processed, level_data.level)
      end)
      
      Map.put(level_data, :data, processed_data)
    end)
  end
  
  defp process_recursive_variety(data) when is_list(data) do
    Enum.map(data, fn item ->
      Map.put(item, :recursive_processed, true)
    end)
  end
  defp process_recursive_variety(data) do
    processed = Map.update!(data, :data, fn items ->
      Enum.map(items, fn item ->
        Map.put(item, :recursive_processed, data.depth)
      end)
    end)
    
    if data.nested do
      Map.put(processed, :nested, process_recursive_variety(data.nested))
    else
      processed
    end
  end
  
  defp process_quantum_variety(data) do
    Enum.map(data, fn item ->
      # Simulate quantum processing
      measurement = :math.cos(item.quantum_state.phase) * item.quantum_state.amplitude
      Map.put(item, :measured_value, measurement)
    end)
  end
  
  # Filtering and transformation functions
  defp filter_variety(data, filter_fn) do
    Enum.filter(data, filter_fn)
  end
  
  defp simple_filter(item) do
    item.value > 0.5
  end
  
  defp complex_filter(item) do
    has_priority = Map.get(item, :priority, 5) > 7
    has_tags = case Map.get(item, :metadata) do
      %{tags: tags} -> length(tags) > 1
      _ -> false
    end
    
    has_priority and has_tags
  end
  
  defp transform_variety(data, transform_fn) do
    Enum.map(data, transform_fn)
  end
  
  defp map_transform(item) do
    Map.update(item, :value, 0, fn v -> v * 2 end)
    |> Map.put(:transformed, true)
    |> Map.put(:transform_time, System.system_time())
  end
  
  defp aggregate_variety(data) do
    Enum.reduce(data, %{sum: 0, count: 0, max: 0, min: 1}, fn item, acc ->
      value = item.value
      %{
        sum: acc.sum + value,
        count: acc.count + 1,
        max: max(acc.max, value),
        min: min(acc.min, value)
      }
    end)
  end
  
  defp partition_variety(data, partitions) do
    chunk_size = div(length(data), partitions)
    Enum.chunk_every(data, chunk_size)
  end
  
  defp sort_variety_by_relevance(data) do
    Enum.sort_by(data, fn item ->
      priority = Map.get(item, :priority, 5)
      value = item.value
      -1 * (priority * 0.7 + value * 0.3)
    end)
  end
  
  defp deduplicate_variety(data) do
    Enum.uniq_by(data, fn item ->
      {item.id, item.value}
    end)
  end
  
  defp normalize_variety(data) do
    values = Enum.map(data, & &1.value)
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    range = max_val - min_val
    
    Enum.map(data, fn item ->
      normalized_value = if range > 0 do
        (item.value - min_val) / range
      else
        0.5
      end
      
      Map.put(item, :normalized_value, normalized_value)
    end)
  end
  
  defp compress_variety(data) do
    # Simulate compression by removing redundant fields
    Enum.map(data, fn item ->
      Map.take(item, [:id, :value, :priority])
    end)
  end
  
  defp encode_variety(data) do
    # Simulate encoding
    :erlang.term_to_binary(data)
  end
  
  defp decode_variety(encoded_data) do
    # Simulate decoding
    :erlang.binary_to_term(encoded_data)
  end
  
  # Channel capacity functions
  defp test_channel_capacity(channels, items_per_channel) do
    channel_pids = Enum.map(1..channels, fn i ->
      spawn(fn -> channel_process(i) end)
    end)
    
    # Send items to channels
    Enum.each(1..items_per_channel, fn item ->
      Enum.each(channel_pids, fn pid ->
        send(pid, {:process, item})
      end)
    end)
    
    # Cleanup
    Enum.each(channel_pids, fn pid ->
      send(pid, :terminate)
    end)
    
    channels * items_per_channel
  end
  
  defp test_channel_multiplexing(channels, total_items) do
    channel_pids = Enum.map(1..channels, fn i ->
      spawn(fn -> channel_process(i) end)
    end)
    
    # Distribute items across channels
    Enum.with_index(1..total_items)
    |> Enum.each(fn {item, index} ->
      channel = Enum.at(channel_pids, rem(index, channels))
      send(channel, {:process, item})
    end)
    
    # Cleanup
    Enum.each(channel_pids, fn pid ->
      send(pid, :terminate)
    end)
    
    total_items
  end
  
  defp test_channel_buffering(items, buffer_size) do
    buffer = if buffer_size > 0 do
      :queue.new()
    else
      nil
    end
    
    process_with_buffer(1..items, buffer, buffer_size)
  end
  
  defp test_channel_backpressure(items, threshold) do
    parent = self()
    
    processor = spawn(fn ->
      backpressure_processor(parent, threshold, 0)
    end)
    
    results = Enum.map(1..items, fn i ->
      send(processor, {:process, i})
      
      receive do
        {:backpressure, :apply} -> 
          Process.sleep(1)
          {:delayed, i}
        {:processed, ^i} ->
          {:normal, i}
      after
        10 -> {:timeout, i}
      end
    end)
    
    send(processor, :terminate)
    results
  end
  
  # Attenuation functions
  defp apply_attenuation(data, factor) do
    Enum.map(data, fn item ->
      Map.update!(item, :value, fn v -> v * factor end)
    end)
  end
  
  defp apply_adaptive_attenuation(data) do
    Enum.map(data, fn item ->
      factor = case Map.get(item, :priority, 5) do
        p when p > 7 -> 1.0
        p when p > 4 -> 0.8
        _ -> 0.6
      end
      
      Map.update!(item, :value, fn v -> v * factor end)
    end)
  end
  
  defp apply_hierarchical_attenuation(data, base_factor) do
    Enum.map(data, fn level_data ->
      factor = :math.pow(base_factor, level_data.level)
      
      processed_data = Enum.map(level_data.data, fn item ->
        Map.update!(item, :value, fn v -> v * factor end)
      end)
      
      Map.put(level_data, :data, processed_data)
    end)
  end
  
  defp apply_amplification(data, factor) do
    Enum.map(data, fn item ->
      Map.update!(item, :value, fn v -> min(v * factor, 1.0) end)
    end)
  end
  
  defp apply_selective_amplification(data) do
    Enum.map(data, fn item ->
      should_amplify = Map.get(item, :priority, 5) < 3 or item.value < 0.3
      
      if should_amplify do
        Map.update!(item, :value, fn v -> min(v * 2, 1.0) end)
      else
        item
      end
    end)
  end
  
  # Helper processes
  defp channel_process(id) do
    receive do
      {:process, item} ->
        # Simulate processing
        Process.sleep(0)
        channel_process(id)
      
      :terminate ->
        :ok
    end
  end
  
  defp process_with_buffer(items, nil, _buffer_size) do
    Enum.count(items)
  end
  defp process_with_buffer(items, buffer, buffer_size) do
    Enum.reduce(items, {buffer, 0}, fn item, {buff, processed} ->
      if :queue.len(buff) >= buffer_size do
        # Process oldest item from buffer
        {{:value, _}, new_buff} = :queue.out(buff)
        {:queue.in(item, new_buff), processed + 1}
      else
        {:queue.in(item, buff), processed}
      end
    end)
    |> elem(1)
  end
  
  defp backpressure_processor(parent, threshold, count) do
    receive do
      {:process, item} ->
        new_count = count + 1
        
        if new_count > threshold do
          send(parent, {:backpressure, :apply})
          Process.sleep(5)
        end
        
        send(parent, {:processed, item})
        backpressure_processor(parent, threshold, rem(new_count, threshold))
      
      :terminate ->
        :ok
    end
  end
end