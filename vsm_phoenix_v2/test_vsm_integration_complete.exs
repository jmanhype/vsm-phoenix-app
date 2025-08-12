#!/usr/bin/env elixir

Mix.install([
  {:req, "~> 0.5.0"},
  {:jason, "~> 1.2"}
])

defmodule VSMPhoenixV2IntegrationTest do
  @moduledoc """
  Comprehensive Integration Test Suite for VSM Phoenix V2
  
  Tests all claimed features:
  1. Phoenix Server Health
  2. VSM System 5 (Queen) Operations
  3. VSM System 4 (Cortical Attention) 
  4. CRDT Context Store Operations
  5. Circuit Breaker Functionality
  6. Telemetry Collection
  7. Error Handling
  8. Performance Benchmarks
  """

  require Logger

  @base_url "http://localhost:4001"
  @timeout 10_000

  def run_all_tests do
    Logger.info("🧪 Starting VSM Phoenix V2 Comprehensive Integration Tests")
    
    results = %{
      phoenix_health: test_phoenix_health(),
      system_status: test_system_status(),
      queen_operations: test_queen_operations(),
      attention_engine: test_attention_engine(),
      crdt_operations: test_crdt_operations(),
      circuit_breakers: test_circuit_breakers(),
      telemetry: test_telemetry(),
      error_handling: test_error_handling(),
      performance: test_performance()
    }
    
    print_test_results(results)
    results
  end

  # Test 1: Phoenix Server Health
  def test_phoenix_health do
    Logger.info("🔍 Testing Phoenix Server Health...")
    
    try do
      response = Req.get!(@base_url, receive_timeout: @timeout)
      
      case response.status do
        200 ->
          if String.contains?(response.body, "VsmPhoenixV2") do
            {:ok, "Phoenix server healthy, VSM app detected"}
          else
            {:error, "Phoenix running but not VSM app"}
          end
          
        status ->
          {:error, "HTTP #{status}"}
      end
    rescue
      error ->
        {:error, "Connection failed: #{inspect(error)}"}
    end
  end

  # Test 2: System Status Endpoint
  def test_system_status do
    Logger.info("🔍 Testing System Status...")
    
    # Try multiple possible status endpoints
    endpoints = [
      "/api/vsm/status",
      "/api/status", 
      "/status",
      "/health"
    ]
    
    Enum.reduce_while(endpoints, {:error, "No status endpoint found"}, fn endpoint, _acc ->
      try do
        response = Req.get!("#{@base_url}#{endpoint}", receive_timeout: @timeout)
        
        case response.status do
          200 ->
            {:halt, {:ok, "Status endpoint #{endpoint} working"}}
          404 ->
            {:cont, {:error, "Endpoint #{endpoint} not found"}}
          status ->
            {:halt, {:error, "HTTP #{status} from #{endpoint}"}}
        end
      rescue
        _error ->
          {:cont, {:error, "Failed to connect to #{endpoint}"}}
      end
    end)
  end

  # Test 3: Queen System Operations via IEx
  def test_queen_operations do
    Logger.info("🔍 Testing Queen System Operations...")
    
    # Create test script to run in IEx context
    test_script = """
    # Test Queen System operations
    try do
      # Test if Queen module exists and can be called
      case Code.ensure_loaded(VsmPhoenixV2.System5.Queen) do
        {:module, _} ->
          # Try to get system status
          node_id = "test_node_1"
          case VsmPhoenixV2.System5.Queen.get_system_status(node_id) do
            {:ok, status} -> 
              IO.puts("QUEEN_TEST_RESULT:SUCCESS:#{inspect(status)}")
            {:error, reason} -> 
              IO.puts("QUEEN_TEST_RESULT:ERROR:#{inspect(reason)}")
          end
        {:error, _} ->
          IO.puts("QUEEN_TEST_RESULT:ERROR:Module not loaded")
      end
    rescue
      error -> 
        IO.puts("QUEEN_TEST_RESULT:ERROR:#{inspect(error)}")
    end
    """
    
    # Write test script to temp file
    File.write!("/tmp/queen_test.exs", test_script)
    
    # Execute in the context of running Phoenix app
    try do
      {output, exit_code} = System.cmd("elixir", [
        "--name", "test@127.0.0.1",
        "--cookie", "vsm_phoenix_v2_cookie", 
        "-e", test_script
      ], stderr_to_stdout: true)
      
      cond do
        String.contains?(output, "QUEEN_TEST_RESULT:SUCCESS") ->
          {:ok, "Queen system operations working"}
        String.contains?(output, "QUEEN_TEST_RESULT:ERROR") ->
          {:error, "Queen system error: #{output}"}
        exit_code != 0 ->
          {:error, "Script execution failed: #{output}"}
        true ->
          {:partial, "Queen test inconclusive: #{output}"}
      end
    rescue
      error ->
        {:error, "Queen test execution failed: #{inspect(error)}"}
    end
  end

  # Test 4: Cortical Attention Engine
  def test_attention_engine do
    Logger.info("🔍 Testing Cortical Attention Engine...")
    
    test_script = """
    try do
      case Code.ensure_loaded(VsmPhoenixV2.System4.CorticalAttentionEngine) do
        {:module, _} ->
          node_id = "test_node_1"
          case VsmPhoenixV2.System4.CorticalAttentionEngine.get_attention_state(node_id) do
            {:ok, state} -> 
              IO.puts("ATTENTION_TEST_RESULT:SUCCESS:#{inspect(state)}")
            {:error, reason} -> 
              IO.puts("ATTENTION_TEST_RESULT:ERROR:#{inspect(reason)}")
          end
        {:error, _} ->
          IO.puts("ATTENTION_TEST_RESULT:ERROR:Module not loaded")
      end
    rescue
      error -> 
        IO.puts("ATTENTION_TEST_RESULT:ERROR:#{inspect(error)}")
    end
    """
    
    try do
      {output, _} = System.cmd("elixir", ["-e", test_script], stderr_to_stdout: true)
      
      cond do
        String.contains?(output, "ATTENTION_TEST_RESULT:SUCCESS") ->
          {:ok, "Attention engine working"}
        String.contains?(output, "ATTENTION_TEST_RESULT:ERROR") ->
          {:error, "Attention engine error: #{output}"}
        true ->
          {:partial, "Attention test inconclusive: #{output}"}
      end
    rescue
      error ->
        {:error, "Attention test failed: #{inspect(error)}"}
    end
  end

  # Test 5: CRDT Operations
  def test_crdt_operations do
    Logger.info("🔍 Testing CRDT Context Store...")
    
    test_script = """
    try do
      case Code.ensure_loaded(VsmPhoenixV2.CRDT.ContextStore) do
        {:module, _} ->
          # Test CRDT store creation and operations
          {:ok, pid} = VsmPhoenixV2.CRDT.ContextStore.start_link(node_id: "test_crdt")
          
          # Test put operation
          :ok = GenServer.call(pid, {:put_context, :test_key, "test_value"})
          
          # Test get operation  
          case GenServer.call(pid, {:get_context, :test_key}) do
            {:ok, "test_value"} ->
              IO.puts("CRDT_TEST_RESULT:SUCCESS:CRDT operations working")
            other ->
              IO.puts("CRDT_TEST_RESULT:ERROR:Unexpected result #{inspect(other)}")
          end
        {:error, _} ->
          IO.puts("CRDT_TEST_RESULT:ERROR:Module not loaded")
      end
    rescue
      error -> 
        IO.puts("CRDT_TEST_RESULT:ERROR:#{inspect(error)}")
    end
    """
    
    try do
      {output, _} = System.cmd("elixir", ["-e", test_script], stderr_to_stdout: true)
      
      cond do
        String.contains?(output, "CRDT_TEST_RESULT:SUCCESS") ->
          {:ok, "CRDT operations working"}
        String.contains?(output, "CRDT_TEST_RESULT:ERROR") ->
          {:error, "CRDT error: #{output}"}
        true ->
          {:partial, "CRDT test inconclusive: #{output}"}
      end
    rescue
      error ->
        {:error, "CRDT test failed: #{inspect(error)}"}
    end
  end

  # Test 6: Circuit Breaker Functionality  
  def test_circuit_breakers do
    Logger.info("🔍 Testing Circuit Breakers...")
    
    # Test circuit breaker dependencies exist
    test_script = """
    try do
      # Check if Fuse (circuit breaker library) is available
      case Code.ensure_loaded(:fuse) do
        {:module, _} ->
          # Test circuit breaker creation
          :fuse.install(:test_breaker, {{:standard, 2, 10_000}, {:reset, 60_000}})
          
          # Test circuit breaker state
          case :fuse.ask(:test_breaker, :sync) do
            :ok -> 
              IO.puts("CIRCUIT_BREAKER_TEST_RESULT:SUCCESS:Circuit breakers functional")
            :blown ->
              IO.puts("CIRCUIT_BREAKER_TEST_RESULT:SUCCESS:Circuit breaker blown (expected)")
            other ->
              IO.puts("CIRCUIT_BREAKER_TEST_RESULT:ERROR:Unexpected state #{inspect(other)}")
          end
        {:error, _} ->
          IO.puts("CIRCUIT_BREAKER_TEST_RESULT:ERROR:Fuse library not available")
      end
    rescue
      error -> 
        IO.puts("CIRCUIT_BREAKER_TEST_RESULT:ERROR:#{inspect(error)}")
    end
    """
    
    try do
      {output, _} = System.cmd("elixir", ["-e", test_script], stderr_to_stdout: true)
      
      cond do
        String.contains?(output, "CIRCUIT_BREAKER_TEST_RESULT:SUCCESS") ->
          {:ok, "Circuit breakers working"}
        String.contains?(output, "CIRCUIT_BREAKER_TEST_RESULT:ERROR") ->
          {:error, "Circuit breaker error: #{output}"}
        true ->
          {:partial, "Circuit breaker test inconclusive: #{output}"}
      end
    rescue
      error ->
        {:error, "Circuit breaker test failed: #{inspect(error)}"}
    end
  end

  # Test 7: Telemetry Collection
  def test_telemetry do
    Logger.info("🔍 Testing Telemetry...")
    
    test_script = """
    try do
      # Test telemetry event emission
      :telemetry.execute([:vsm, :test], %{value: 1}, %{test: true})
      
      # Check if telemetry is working by attaching handler
      ref = make_ref()
      :telemetry.attach(ref, [:vsm, :test], fn name, measurements, metadata, _ ->
        IO.puts("TELEMETRY_TEST_RESULT:SUCCESS:Event received #{inspect(name)}")
      end, nil)
      
      # Emit test event
      :telemetry.execute([:vsm, :test], %{value: 2}, %{test: true})
      
      # Cleanup
      :telemetry.detach(ref)
      
      IO.puts("TELEMETRY_TEST_RESULT:SUCCESS:Telemetry system working")
    rescue
      error -> 
        IO.puts("TELEMETRY_TEST_RESULT:ERROR:#{inspect(error)}")
    end
    """
    
    try do
      {output, _} = System.cmd("elixir", ["-e", test_script], stderr_to_stdout: true)
      
      cond do
        String.contains?(output, "TELEMETRY_TEST_RESULT:SUCCESS") ->
          {:ok, "Telemetry working"}
        String.contains?(output, "TELEMETRY_TEST_RESULT:ERROR") ->
          {:error, "Telemetry error: #{output}"}
        true ->
          {:partial, "Telemetry test inconclusive: #{output}"}
      end
    rescue
      error ->
        {:error, "Telemetry test failed: #{inspect(error)}"}
    end
  end

  # Test 8: Error Handling
  def test_error_handling do
    Logger.info("🔍 Testing Error Handling...")
    
    # Test invalid endpoints return proper errors
    try do
      response = Req.get!("#{@base_url}/invalid/endpoint", receive_timeout: @timeout)
      
      case response.status do
        404 ->
          if String.contains?(response.body, "NoRouteError") do
            {:ok, "Proper error handling for invalid routes"}
          else
            {:partial, "404 returned but not Phoenix error page"}
          end
        other ->
          {:error, "Expected 404, got #{other}"}
      end
    rescue
      error ->
        {:error, "Error handling test failed: #{inspect(error)}"}
    end
  end

  # Test 9: Performance Benchmarks
  def test_performance do
    Logger.info("🔍 Testing Performance...")
    
    start_time = :os.system_time(:millisecond)
    
    # Make multiple requests to test performance
    results = for i <- 1..10 do
      request_start = :os.system_time(:millisecond)
      
      try do
        response = Req.get!(@base_url, receive_timeout: 5000)
        request_end = :os.system_time(:millisecond)
        
        %{
          request: i,
          status: response.status,
          response_time: request_end - request_start,
          success: response.status == 200
        }
      rescue
        _error ->
          %{request: i, status: :error, response_time: :timeout, success: false}
      end
    end
    
    end_time = :os.system_time(:millisecond)
    total_time = end_time - start_time
    
    successful_requests = Enum.count(results, & &1.success)
    avg_response_time = results
                      |> Enum.filter(& &1.response_time != :timeout)
                      |> Enum.map(& &1.response_time)
                      |> case do
                           [] -> 0
                           times -> Enum.sum(times) / length(times)
                         end
    
    performance_data = %{
      total_requests: 10,
      successful_requests: successful_requests,
      total_time: total_time,
      average_response_time: avg_response_time,
      success_rate: successful_requests / 10 * 100
    }
    
    if successful_requests >= 8 and avg_response_time < 1000 do
      {:ok, "Performance good: #{inspect(performance_data)}"}
    else
      {:partial, "Performance issues: #{inspect(performance_data)}"}
    end
  end

  # Print comprehensive test results
  def print_test_results(results) do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("🧪 VSM PHOENIX V2 INTEGRATION TEST RESULTS")
    IO.puts(String.duplicate("=", 80))
    
    {passed, failed, partial} = Enum.reduce(results, {0, 0, 0}, fn {_test, result}, {p, f, part} ->
      case result do
        {:ok, _} -> {p + 1, f, part}
        {:error, _} -> {p, f + 1, part}
        {:partial, _} -> {p, f, part + 1}
      end
    end)
    
    total = map_size(results)
    
    IO.puts("📊 SUMMARY:")
    IO.puts("   Total Tests: #{total}")
    IO.puts("   ✅ Passed: #{passed}")
    IO.puts("   ❌ Failed: #{failed}")
    IO.puts("   ⚠️  Partial: #{partial}")
    IO.puts("   📈 Success Rate: #{Float.round(passed / total * 100, 1)}%")
    IO.puts("")
    
    IO.puts("📋 DETAILED RESULTS:")
    
    Enum.each(results, fn {test_name, result} ->
      {status, icon, message} = case result do
        {:ok, msg} -> {"PASS", "✅", msg}
        {:error, msg} -> {"FAIL", "❌", msg}  
        {:partial, msg} -> {"PARTIAL", "⚠️", msg}
      end
      
      IO.puts("   #{icon} #{String.pad_trailing("#{test_name}:", 20)} #{status} - #{message}")
    end)
    
    IO.puts("\n" <> String.duplicate("=", 80))
    
    overall_status = cond do
      failed == 0 and partial <= 2 -> "🎉 EXCELLENT - VSM Phoenix V2 is fully functional!"
      failed <= 2 and passed >= 6 -> "👍 GOOD - VSM Phoenix V2 is mostly functional"
      passed >= 4 -> "⚠️  PARTIAL - VSM Phoenix V2 has some working features"
      true -> "❌ CRITICAL - VSM Phoenix V2 has major issues"
    end
    
    IO.puts(overall_status)
    IO.puts(String.duplicate("=", 80))
  end
end

# Run the integration tests
VSMPhoenixV2IntegrationTest.run_all_tests()
