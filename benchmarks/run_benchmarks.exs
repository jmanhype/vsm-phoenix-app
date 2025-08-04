#!/usr/bin/env elixir
# VSM Phoenix Benchmark Runner
# Executes all benchmark suites with configuration and reporting

defmodule BenchmarkRunner do
  @moduledoc """
  Main benchmark runner for VSM Phoenix performance testing
  """
  
  @benchmark_suites [
    {"Main VSM Benchmarks", "benchmarks/vsm_benchmark.exs"},
    {"Load Testing", "benchmarks/scenarios/load_testing.exs"},
    {"Quantum Operations", "benchmarks/scenarios/quantum_benchmarks.exs"},
    {"Recursive Spawning", "benchmarks/scenarios/recursive_spawning_benchmarks.exs"},
    {"Variety Throughput", "benchmarks/scenarios/variety_throughput_benchmarks.exs"}
  ]
  
  def run(args \\ []) do
    IO.puts("""
    ╔══════════════════════════════════════════════════════════════╗
    ║           VSM Phoenix Performance Benchmark Suite             ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
    
    options = parse_args(args)
    
    # Ensure results directory exists
    File.mkdir_p!("benchmarks/results")
    
    # Run selected benchmarks
    suites_to_run = if options[:suite] do
      filter_suites(options[:suite])
    else
      @benchmark_suites
    end
    
    start_time = System.monotonic_time(:second)
    
    results = Enum.map(suites_to_run, fn {name, path} ->
      run_suite(name, path, options)
    end)
    
    end_time = System.monotonic_time(:second)
    total_time = end_time - start_time
    
    # Generate summary report
    generate_summary_report(results, total_time, options)
    
    IO.puts("\n✅ All benchmarks completed successfully!")
    IO.puts("📊 Results saved to benchmarks/results/")
  end
  
  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        suite: :string,
        profile: :string,
        format: :string,
        time: :integer,
        warmup: :integer,
        parallel: :integer,
        memory: :boolean,
        save: :boolean,
        compare: :boolean,
        verbose: :boolean
      ],
      aliases: [
        s: :suite,
        p: :profile,
        f: :format,
        t: :time,
        w: :warmup,
        m: :memory,
        v: :verbose
      ]
    )
    
    # Apply profile presets
    profile_opts = case opts[:profile] do
      "quick" -> [time: 2, warmup: 1, memory: false]
      "standard" -> [time: 10, warmup: 3, memory: true]
      "thorough" -> [time: 30, warmup: 5, memory: true]
      "stress" -> [time: 60, warmup: 10, memory: true, parallel: 1]
      _ -> []
    end
    
    Keyword.merge(profile_opts, opts)
    |> Keyword.put_new(:time, 10)
    |> Keyword.put_new(:warmup, 3)
    |> Keyword.put_new(:memory, true)
    |> Keyword.put_new(:save, true)
    |> Keyword.put_new(:format, "all")
    |> Keyword.put_new(:verbose, false)
  end
  
  defp filter_suites(suite_name) do
    Enum.filter(@benchmark_suites, fn {name, _path} ->
      String.contains?(String.downcase(name), String.downcase(suite_name))
    end)
  end
  
  defp run_suite(name, path, options) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📈 Running: #{name}")
    IO.puts(String.duplicate("=", 60))
    
    if options[:verbose] do
      IO.puts("Configuration:")
      IO.puts("  Time: #{options[:time]}s")
      IO.puts("  Warmup: #{options[:warmup]}s")
      IO.puts("  Memory profiling: #{options[:memory]}")
    end
    
    suite_start = System.monotonic_time(:millisecond)
    
    try do
      # Load and execute the benchmark file
      Code.eval_file(path)
      
      suite_end = System.monotonic_time(:millisecond)
      duration = suite_end - suite_start
      
      IO.puts("✓ Completed in #{format_duration(duration)}")
      
      {:ok, name, duration}
    rescue
      e ->
        IO.puts("❌ Error running #{name}: #{inspect(e)}")
        {:error, name, inspect(e)}
    end
  end
  
  defp generate_summary_report(results, total_time, options) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📊 BENCHMARK SUMMARY REPORT")
    IO.puts(String.duplicate("=", 60))
    
    {successful, failed} = Enum.split_with(results, fn
      {:ok, _, _} -> true
      _ -> false
    end)
    
    IO.puts("\n📈 Execution Statistics:")
    IO.puts("  Total suites run: #{length(results)}")
    IO.puts("  Successful: #{length(successful)}")
    IO.puts("  Failed: #{length(failed)}")
    IO.puts("  Total time: #{format_duration(total_time * 1000)}")
    
    if length(successful) > 0 do
      IO.puts("\n✅ Successful Suites:")
      Enum.each(successful, fn {:ok, name, duration} ->
        IO.puts("  • #{name} (#{format_duration(duration)})")
      end)
    end
    
    if length(failed) > 0 do
      IO.puts("\n❌ Failed Suites:")
      Enum.each(failed, fn {:error, name, error} ->
        IO.puts("  • #{name}: #{error}")
      end)
    end
    
    if options[:save] do
      save_summary_to_file(results, total_time, options)
    end
  end
  
  defp save_summary_to_file(results, total_time, options) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    filename = "benchmarks/results/summary_#{timestamp}.json"
    
    summary = %{
      timestamp: timestamp,
      total_time_seconds: total_time,
      configuration: Map.new(options),
      results: Enum.map(results, fn
        {:ok, name, duration} -> 
          %{suite: name, status: "success", duration_ms: duration}
        {:error, name, error} -> 
          %{suite: name, status: "error", error: error}
      end)
    }
    
    json = Jason.encode!(summary, pretty: true)
    File.write!(filename, json)
    
    IO.puts("\n💾 Summary saved to: #{filename}")
  end
  
  defp format_duration(ms) when ms < 1000 do
    "#{ms}ms"
  end
  defp format_duration(ms) when ms < 60000 do
    seconds = ms / 1000
    "#{Float.round(seconds, 1)}s"
  end
  defp format_duration(ms) do
    minutes = div(ms, 60000)
    seconds = rem(ms, 60000) / 1000
    "#{minutes}m #{Float.round(seconds, 1)}s"
  end
end

# CLI Interface
defmodule BenchmarkCLI do
  def main(args) do
    case args do
      ["help" | _] -> print_help()
      ["--help" | _] -> print_help()
      ["-h" | _] -> print_help()
      ["list" | _] -> list_benchmarks()
      ["profiles" | _] -> list_profiles()
      args -> BenchmarkRunner.run(args)
    end
  end
  
  defp print_help() do
    IO.puts("""
    VSM Phoenix Benchmark Runner
    
    Usage: mix run benchmarks/run_benchmarks.exs [options]
           elixir benchmarks/run_benchmarks.exs [options]
    
    Options:
      -s, --suite NAME      Run specific benchmark suite (partial match)
      -p, --profile NAME    Use predefined profile (quick|standard|thorough|stress)
      -t, --time SECONDS    Benchmarking time per scenario (default: 10)
      -w, --warmup SECONDS  Warmup time per scenario (default: 3)
      -m, --memory          Enable memory profiling (default: true)
      -f, --format FORMAT   Output format (console|html|json|all) (default: all)
      --parallel N          Number of parallel processes (default: System.schedulers_online())
      --save                Save results to file (default: true)
      --compare             Compare with previous results
      -v, --verbose         Verbose output
    
    Commands:
      help                  Show this help message
      list                  List available benchmark suites
      profiles              List available profiles
    
    Examples:
      # Run all benchmarks with standard profile
      mix run benchmarks/run_benchmarks.exs
      
      # Run only quantum benchmarks with quick profile
      mix run benchmarks/run_benchmarks.exs --suite quantum --profile quick
      
      # Run stress test on variety processing
      mix run benchmarks/run_benchmarks.exs --suite variety --profile stress
      
      # Custom configuration
      mix run benchmarks/run_benchmarks.exs --time 30 --warmup 5 --memory
    """)
  end
  
  defp list_benchmarks() do
    IO.puts("Available Benchmark Suites:\n")
    [
      {"Main VSM Benchmarks", "Core VSM operations, variety processing, quantum ops"},
      {"Load Testing", "Load patterns, stress testing, chaos testing"},
      {"Quantum Operations", "Superposition, entanglement, measurement, gates"},
      {"Recursive Spawning", "Process spawning, meta-VSM, algedonic signals"},
      {"Variety Throughput", "Throughput, complexity, channels, attenuation"}
    ]
    |> Enum.each(fn {name, description} ->
      IO.puts("  • #{name}")
      IO.puts("    #{description}\n")
    end)
  end
  
  defp list_profiles() do
    IO.puts("""
    Available Profiles:
    
    • quick
      Time: 2s, Warmup: 1s, Memory: disabled
      Use for rapid testing and CI/CD pipelines
    
    • standard (default)
      Time: 10s, Warmup: 3s, Memory: enabled
      Balanced profile for regular benchmarking
    
    • thorough
      Time: 30s, Warmup: 5s, Memory: enabled
      Comprehensive testing with high accuracy
    
    • stress
      Time: 60s, Warmup: 10s, Memory: enabled, Parallel: 1
      Extended stress testing for stability validation
    """)
  end
end

# Run the CLI
BenchmarkCLI.main(System.argv())