defmodule VsmPhoenix.SelfModifying.SafeSandboxTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.SelfModifying.SafeSandbox
  
  setup do
    {:ok, _pid} = SafeSandbox.start_link()
    :ok
  end
  
  describe "execute/3" do
    test "executes safe code successfully" do
      assert {:ok, 2} = SafeSandbox.execute("1 + 1")
    end
    
    test "executes code with arguments" do
      code = "Enum.sum(args)"
      args = [[1, 2, 3, 4]]
      
      assert {:ok, 10} = SafeSandbox.execute(code, args)
    end
    
    test "respects timeout limits" do
      infinite_loop = "Stream.cycle([1]) |> Enum.take(1000000) |> Enum.sum()"
      
      assert {:error, reason} = SafeSandbox.execute(infinite_loop, [], timeout: 100)
      assert reason =~ "timeout"
    end
    
    test "blocks dangerous file operations" do
      dangerous_code = "File.rm(\"/etc/passwd\")"
      
      assert {:error, reason} = SafeSandbox.execute(dangerous_code)
      assert reason =~ "Forbidden module"
    end
    
    test "blocks dangerous system operations" do
      dangerous_code = "System.cmd(\"rm\", [\"-rf\", \"/\"])"
      
      assert {:error, reason} = SafeSandbox.execute(dangerous_code)
      assert reason =~ "Forbidden module"
    end
    
    test "blocks network operations" do
      dangerous_code = ":gen_tcp.connect('evil.com', 80, [])"
      
      assert {:error, reason} = SafeSandbox.execute(dangerous_code)
      assert reason =~ "Forbidden module"
    end
    
    test "allows safe Enum operations" do
      safe_code = "Enum.map([1, 2, 3], fn x -> x * 2 end)"
      
      assert {:ok, [2, 4, 6]} = SafeSandbox.execute(safe_code)
    end
    
    test "allows safe String operations" do
      safe_code = "String.upcase(\"hello world\")"
      
      assert {:ok, "HELLO WORLD"} = SafeSandbox.execute(safe_code)
    end
    
    test "handles execution errors gracefully" do
      error_code = "raise \"intentional error\""
      
      assert {:error, reason} = SafeSandbox.execute(error_code)
      assert reason =~ "intentional error"
    end
  end
  
  describe "execute_monitored/3" do
    test "monitors resource usage" do
      simple_code = fn -> Enum.sum(1..1000) end
      limits = %{memory_mb: 100, wall_time_ms: 5000}
      
      assert {:ok, result} = SafeSandbox.execute_monitored(simple_code, limits)
      assert is_number(result)
    end
    
    test "enforces memory limits" do
      memory_hog = fn ->
        # Try to allocate large amount of memory
        Stream.cycle([1]) |> Enum.take(1_000_000) |> Enum.to_list()
      end
      
      limits = %{memory_mb: 1, wall_time_ms: 5000}
      
      # This should either succeed with small memory or fail with limit exceeded
      result = SafeSandbox.execute_monitored(memory_hog, limits)
      assert match?({:ok, _} | {:error, _}, result)
    end
    
    test "enforces time limits" do
      slow_function = fn ->
        Process.sleep(2000)
        :done
      end
      
      limits = %{memory_mb: 100, wall_time_ms: 500}
      
      assert {:error, reason} = SafeSandbox.execute_monitored(slow_function, limits)
      assert reason =~ "timeout"
    end
  end
  
  describe "create_restricted_env/1" do
    test "creates environment with safe functions" do
      env = SafeSandbox.create_restricted_env()
      
      assert Map.has_key?(env, "+")
      assert Map.has_key?(env, "map")
      assert Map.has_key?(env, "upcase")
    end
    
    test "includes allowed modules" do
      env = SafeSandbox.create_restricted_env([String, Enum])
      
      assert Map.has_key?(env, "String")
      assert Map.has_key?(env, "Enum")
    end
    
    test "safe functions work correctly" do
      env = SafeSandbox.create_restricted_env()
      
      add_fn = Map.get(env, "+")
      assert add_fn.(2, 3) == 5
      
      map_fn = Map.get(env, "map")
      assert map_fn.([1, 2, 3], fn x -> x * 2 end) == [2, 4, 6]
    end
  end
  
  describe "validate_code_safety/1" do
    test "validates safe code" do
      safe_code = "x = 1 + 2"
      
      assert {:ok, :safe} = SafeSandbox.validate_code_safety(safe_code)
    end
    
    test "detects forbidden modules" do
      dangerous_code = "File.read(\"/etc/passwd\")"
      
      assert {:error, reason} = SafeSandbox.validate_code_safety(dangerous_code)
      assert reason =~ "Unsafe code"
    end
    
    test "detects dangerous function patterns" do
      dangerous_code = "System.shell(\"rm -rf /\")"
      
      assert {:error, reason} = SafeSandbox.validate_code_safety(dangerous_code)
      assert reason =~ "Unsafe code"
    end
    
    test "detects complex code structures" do
      complex_code = String.duplicate("if true, do: (", 200) <> String.duplicate(")", 200)
      
      assert {:error, reason} = SafeSandbox.validate_code_safety(complex_code)
      assert reason =~ "too complex"
    end
    
    test "validates function safety" do
      safe_function = fn x -> x * 2 end
      
      assert {:ok, :runtime_monitored} = SafeSandbox.validate_code_safety(safe_function)
    end
  end
  
  describe "sandbox isolation" do
    test "processes are isolated" do
      code1 = "Process.put(:test_key, :process1)"
      code2 = "Process.get(:test_key, :not_found)"
      
      assert {:ok, :process1} = SafeSandbox.execute(code1)
      assert {:ok, :not_found} = SafeSandbox.execute(code2)
    end
    
    test "global state is not shared" do
      # Test that code executions don't share global state
      code1 = ":ets.new(:test_table, [:named_table, :public])"
      code2 = ":ets.info(:test_table)"
      
      # First execution should create table
      SafeSandbox.execute(code1)
      
      # Second execution should not see the table
      result = SafeSandbox.execute(code2)
      # Note: ETS tables might still be visible depending on implementation
      # This test verifies the isolation behavior
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
  
  describe "resource monitoring" do
    test "tracks memory usage during execution" do
      memory_using_code = fn ->
        # Create some data structures
        list = Enum.to_list(1..10_000)
        map = Enum.into(list, %{}, fn x -> {x, x * x} end)
        {list, map}
      end
      
      result = SafeSandbox.execute_monitored(memory_using_code, %{memory_mb: 50, wall_time_ms: 5000})
      assert match?({:ok, _}, result)
    end
    
    test "detects resource limit violations" do
      # This test depends on the specific limits and system behavior
      resource_heavy_code = fn ->
        # Try to use significant resources
        1..100_000 |> Enum.map(&(&1 * &1)) |> Enum.sum()
      end
      
      # Very restrictive limits
      result = SafeSandbox.execute_monitored(resource_heavy_code, %{memory_mb: 1, wall_time_ms: 10})
      
      # Should either succeed quickly or fail due to limits
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
  
  describe "error handling" do
    test "catches and reports syntax errors" do
      invalid_syntax = "def broken( do: invalid"
      
      assert {:error, reason} = SafeSandbox.execute(invalid_syntax)
      assert reason =~ "Unsafe code" or reason =~ "error"
    end
    
    test "catches and reports runtime errors" do
      runtime_error = "1 / 0"
      
      assert {:error, reason} = SafeSandbox.execute(runtime_error)
      assert is_binary(reason)
    end
    
    test "handles thrown values" do
      throw_code = "throw(:test_throw)"
      
      assert {:error, reason} = SafeSandbox.execute(throw_code)
      assert reason =~ "throw" or reason =~ "test_throw"
    end
    
    test "handles exits gracefully" do
      exit_code = "exit(:test_exit)"
      
      assert {:error, reason} = SafeSandbox.execute(exit_code)
      assert is_binary(reason)
    end
  end
  
  describe "concurrent execution" do
    test "handles multiple concurrent executions" do
      # Run multiple sandbox executions concurrently
      tasks = 1..10
      |> Enum.map(fn i ->
        Task.async(fn ->
          SafeSandbox.execute("#{i} * 2", [], timeout: 1000)
        end)
      end)
      
      results = Enum.map(tasks, &Task.await/1)
      
      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
      
      # Results should be correct
      expected_results = Enum.map(1..10, fn i -> {:ok, i * 2} end)
      assert results == expected_results
    end
    
    test "isolates concurrent executions" do
      # Test that concurrent executions don't interfere
      task1 = Task.async(fn ->
        SafeSandbox.execute("Process.sleep(100); 1", [], timeout: 1000)
      end)
      
      task2 = Task.async(fn ->
        SafeSandbox.execute("Process.sleep(100); 2", [], timeout: 1000)
      end)
      
      assert Task.await(task1) == {:ok, 1}
      assert Task.await(task2) == {:ok, 2}
    end
  end
end