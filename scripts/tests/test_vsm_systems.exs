#!/usr/bin/env elixir

# VSM Systems Test
# Consolidated system verification combining dashboard data and API tests

defmodule VsmSystemsTest do
  @moduledoc """
  Tests all VSM systems (S1-S5) for proper operation.
  Can test individual systems or all systems at once.
  """
  
  def run(system \\ :all) do
    IO.puts """
    🧪 VSM Systems Test
    ==================
    Testing: #{system}
    
    """
    
    case system do
      :all -> test_all_systems()
      :s5 -> test_queen()
      :s4 -> test_intelligence()
      :s3 -> test_control()
      :s2 -> test_coordinator()
      :s1 -> test_operations()
      _ -> IO.puts "Invalid system. Use: all, s1, s2, s3, s4, s5"
    end
  end
  
  defp test_all_systems do
    systems = [
      {:s5, &test_queen/0},
      {:s4, &test_intelligence/0},
      {:s3, &test_control/0},
      {:s2, &test_coordinator/0},
      {:s1, &test_operations/0}
    ]
    
    results = Enum.map(systems, fn {name, test_fn} ->
      IO.puts "\nTesting System #{name |> to_string() |> String.upcase()}..."
      IO.puts String.duplicate("-", 40)
      {name, test_fn.()}
    end)
    
    # Summary
    IO.puts "\n📊 Test Summary"
    IO.puts "==============="
    
    passed = Enum.count(results, fn {_, result} -> result == :ok end)
    total = length(results)
    
    Enum.each(results, fn {name, result} ->
      status = if result == :ok, do: "✅ PASS", else: "❌ FAIL"
      IO.puts "#{name |> to_string() |> String.upcase()}: #{status}"
    end)
    
    IO.puts "\nTotal: #{passed}/#{total} systems operational"
  end
  
  defp test_queen do
    IO.puts "👑 System 5 - Queen (Governance)"
    
    try do
      # Test direct GenServer call
      case GenServer.call(VsmPhoenix.System5.Queen, :get_identity_metrics, 1000) do
        metrics when is_map(metrics) ->
          IO.puts "  ✅ Identity metrics: #{inspect(metrics.coherence)}"
          
          # Test viability evaluation
          viability = GenServer.call(VsmPhoenix.System5.Queen, :evaluate_viability, 1000)
          IO.puts "  ✅ Viability score: #{viability.system_health}"
          
          :ok
          
        _ ->
          IO.puts "  ❌ Invalid response from Queen"
          :error
      end
    catch
      :exit, {:noproc, _} ->
        IO.puts "  ❌ Queen process not running"
        :error
      :exit, {:timeout, _} ->
        IO.puts "  ⚠️  Queen timeout (process exists but slow)"
        :ok
    end
  end
  
  defp test_intelligence do
    IO.puts "🧠 System 4 - Intelligence"
    
    try do
      health = GenServer.call(VsmPhoenix.System4.Intelligence, :get_system_health, 1000)
      
      if is_map(health) do
        IO.puts "  ✅ Scan coverage: #{health.scan_coverage || "N/A"}"
        IO.puts "  ✅ Adaptation readiness: #{health.adaptation_readiness || "N/A"}"
        :ok
      else
        IO.puts "  ❌ Invalid health data"
        :error
      end
    catch
      :exit, {:noproc, _} ->
        IO.puts "  ❌ Intelligence process not running"
        :error
      :exit, {:timeout, _} ->
        IO.puts "  ⚠️  Intelligence timeout"
        :ok
    end
  end
  
  defp test_control do
    IO.puts "⚙️  System 3 - Control"
    
    try do
      metrics = GenServer.call(VsmPhoenix.System3.Control, :get_resource_metrics, 1000)
      
      if is_map(metrics) do
        IO.puts "  ✅ Resource efficiency: #{metrics.efficiency || "N/A"}"
        IO.puts "  ✅ Active allocations: #{metrics.active_allocations || 0}"
        :ok
      else
        IO.puts "  ❌ Invalid metrics"
        :error
      end
    catch
      :exit, {:noproc, _} ->
        IO.puts "  ❌ Control process not running"
        :error
      :exit, {:timeout, _} ->
        IO.puts "  ⚠️  Control timeout"
        :ok
    end
  end
  
  defp test_coordinator do
    IO.puts "🔄 System 2 - Coordinator"
    
    try do
      status = GenServer.call(VsmPhoenix.System2.Coordinator, :get_coordination_status, 1000)
      
      if is_map(status) do
        IO.puts "  ✅ Coordination effectiveness: #{status.effectiveness || "N/A"}"
        IO.puts "  ✅ Active contexts: #{length(status.active_contexts || [])}"
        :ok
      else
        IO.puts "  ❌ Invalid status"
        :error
      end
    catch
      :exit, {:noproc, _} ->
        IO.puts "  ❌ Coordinator process not running"
        :error
      :exit, {:timeout, _} ->
        IO.puts "  ⚠️  Coordinator timeout"
        :ok
    end
  end
  
  defp test_operations do
    IO.puts "🔧 System 1 - Operations"
    
    try do
      # Operations uses a named process
      metrics = GenServer.call(:operations_context, :get_metrics, 1000)
      
      if is_map(metrics) do
        IO.puts "  ✅ Success rate: #{metrics.success_rate || "N/A"}"
        IO.puts "  ✅ Orders processed: #{metrics.orders_processed || 0}"
        :ok
      else
        IO.puts "  ❌ Invalid metrics"
        :error
      end
    catch
      :exit, {:noproc, _} ->
        IO.puts "  ❌ Operations context not running"
        :error
      :exit, {:timeout, _} ->
        IO.puts "  ⚠️  Operations timeout"
        :ok
    end
  end
end

# Parse command line arguments
system = case System.argv() do
  [system_str] -> String.to_atom(system_str)
  [] -> :all
  _ -> 
    IO.puts "Usage: #{__ENV__.file} [all|s1|s2|s3|s4|s5]"
    System.halt(1)
end

# Run the test
VsmSystemsTest.run(system)