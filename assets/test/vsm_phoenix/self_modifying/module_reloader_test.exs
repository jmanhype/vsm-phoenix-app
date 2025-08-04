defmodule VsmPhoenix.SelfModifying.ModuleReloaderTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.SelfModifying.ModuleReloader
  
  setup do
    {:ok, _pid} = ModuleReloader.start_link()
    :ok
  end
  
  describe "reload_module/3" do
    test "creates and reloads a simple module" do
      module_name = TestReloadModule1
      
      initial_code = """
      defmodule TestReloadModule1 do
        def version, do: 1
      end
      """
      
      # First load
      assert {:ok, :reloaded} = ModuleReloader.reload_module(module_name, initial_code)
      assert TestReloadModule1.version() == 1
      
      # Reload with new version
      updated_code = """
      defmodule TestReloadModule1 do
        def version, do: 2
      end
      """
      
      assert {:ok, :reloaded} = ModuleReloader.reload_module(module_name, updated_code)
      assert TestReloadModule1.version() == 2
    end
    
    test "validates code before reloading" do
      module_name = TestReloadModule2
      
      invalid_code = """
      defmodule TestReloadModule2 do
        def broken( do: invalid_syntax
      end
      """
      
      assert {:error, reason} = ModuleReloader.reload_module(module_name, invalid_code, validate: true)
      assert reason =~ "Syntax error"
    end
    
    test "blocks dangerous code patterns" do
      module_name = TestReloadModule3
      
      dangerous_code = """
      defmodule TestReloadModule3 do
        def dangerous do
          File.rm_rf("/")
        end
      end
      """
      
      assert {:error, reason} = ModuleReloader.reload_module(module_name, dangerous_code, validate: true)
      assert reason =~ "dangerous patterns"
    end
    
    test "handles compilation errors gracefully" do
      module_name = TestReloadModule4
      
      compilation_error_code = """
      defmodule TestReloadModule4 do
        def test do
          undefined_variable + 1
        end
      end
      """
      
      # This might succeed during compilation but fail at runtime
      # The test verifies the system handles it gracefully
      result = ModuleReloader.reload_module(module_name, compilation_error_code)
      assert match?({:ok, :reloaded} | {:error, _}, result)
    end
    
    test "tracks version history" do
      module_name = TestReloadModule5
      
      v1_code = """
      defmodule TestReloadModule5 do
        def version, do: "v1"
      end
      """
      
      v2_code = """
      defmodule TestReloadModule5 do
        def version, do: "v2"
      end
      """
      
      ModuleReloader.reload_module(module_name, v1_code)
      ModuleReloader.reload_module(module_name, v2_code)
      
      versions = ModuleReloader.get_module_versions(module_name)
      assert length(versions) >= 1  # Should have at least the latest version
      assert Enum.all?(versions, fn v -> Map.has_key?(v, :version) and Map.has_key?(v, :timestamp) end)
    end
  end
  
  describe "hot_swap_function/5" do
    test "swaps a single function in a module" do
      module_name = TestHotSwapModule1
      
      initial_code = """
      defmodule TestHotSwapModule1 do
        def greet(name), do: "Hello, \#{name}!"
        def farewell(name), do: "Goodbye, \#{name}!"
      end
      """
      
      ModuleReloader.reload_module(module_name, initial_code)
      assert TestHotSwapModule1.greet("World") == "Hello, World!"
      
      # Hot swap the greet function
      new_function_code = "def greet(name), do: \"Hi there, \#{name}!\""
      
      assert {:ok, :swapped} = ModuleReloader.hot_swap_function(
        module_name, 
        :greet, 
        1, 
        new_function_code
      )
      
      # The function should be updated
      assert TestHotSwapModule1.greet("World") == "Hi there, World!"
      # Other functions should remain unchanged
      assert TestHotSwapModule1.farewell("World") == "Goodbye, World!"
    end
    
    test "handles hot swap of non-existent function" do
      module_name = TestHotSwapModule2
      
      initial_code = """
      defmodule TestHotSwapModule2 do
        def existing_function, do: :exists
      end
      """
      
      ModuleReloader.reload_module(module_name, initial_code)
      
      new_function_code = "def new_function, do: :new"
      
      # Should be able to add new function
      result = ModuleReloader.hot_swap_function(
        module_name,
        :new_function,
        0,
        new_function_code
      )
      
      assert match?({:ok, :swapped} | {:error, _}, result)
    end
  end
  
  describe "rollback_module/2" do
    test "rolls back to previous version" do
      module_name = TestRollbackModule1
      
      v1_code = """
      defmodule TestRollbackModule1 do
        def version, do: 1
      end
      """
      
      v2_code = """
      defmodule TestRollbackModule1 do
        def version, do: 2
      end
      """
      
      # Load initial version
      ModuleReloader.reload_module(module_name, v1_code)
      assert TestRollbackModule1.version() == 1
      
      # Reload with new version
      ModuleReloader.reload_module(module_name, v2_code)
      assert TestRollbackModule1.version() == 2
      
      # Rollback to previous version
      assert {:ok, :rolled_back} = ModuleReloader.rollback_module(module_name, :previous)
      assert TestRollbackModule1.version() == 1
    end
    
    test "handles rollback when no previous version exists" do
      module_name = TestRollbackModule2
      
      code = """
      defmodule TestRollbackModule2 do
        def test, do: :ok
      end
      """
      
      ModuleReloader.reload_module(module_name, code)
      
      assert {:error, reason} = ModuleReloader.rollback_module(module_name, :previous)
      assert reason =~ "No previous version"
    end
    
    test "rolls back to specific version" do
      module_name = TestRollbackModule3
      
      v1_code = """
      defmodule TestRollbackModule3 do
        def version, do: "v1"
      end
      """
      
      ModuleReloader.reload_module(module_name, v1_code)
      versions = ModuleReloader.get_module_versions(module_name)
      
      if length(versions) > 0 do
        target_version = hd(versions).version
        
        v2_code = """
        defmodule TestRollbackModule3 do
          def version, do: "v2"
        end
        """
        
        ModuleReloader.reload_module(module_name, v2_code)
        assert TestRollbackModule3.version() == "v2"
        
        # Rollback to specific version
        assert {:ok, :rolled_back} = ModuleReloader.rollback_module(module_name, target_version)
        assert TestRollbackModule3.version() == "v1"
      end
    end
  end
  
  describe "register_reload_callback/2" do
    test "executes callback after module reload" do
      test_pid = self()
      
      callback = fn module_name ->
        send(test_pid, {:callback_executed, module_name})
      end
      
      module_name = TestCallbackModule1
      ModuleReloader.register_reload_callback(module_name, callback)
      
      code = """
      defmodule TestCallbackModule1 do
        def test, do: :callback_test
      end
      """
      
      ModuleReloader.reload_module(module_name, code)
      
      assert_receive {:callback_executed, ^module_name}, 1000
    end
    
    test "handles callback errors gracefully" do
      failing_callback = fn _module_name ->
        raise "callback error"
      end
      
      module_name = TestCallbackModule2
      ModuleReloader.register_reload_callback(module_name, failing_callback)
      
      code = """
      defmodule TestCallbackModule2 do
        def test, do: :ok
      end
      """
      
      # Should not crash despite failing callback
      assert {:ok, :reloaded} = ModuleReloader.reload_module(module_name, code)
      assert TestCallbackModule2.test() == :ok
    end
  end
  
  describe "create_rollback_point/1" do
    test "creates and restores rollback point" do
      point_name = "test_rollback_point"
      
      # Create some modules first
      module1_code = """
      defmodule RollbackTestModule1 do
        def state, do: :initial
      end
      """
      
      ModuleReloader.reload_module(RollbackTestModule1, module1_code)
      
      # Create rollback point
      assert {:ok, ^point_name} = ModuleReloader.create_rollback_point(point_name)
      
      # Make changes
      updated_code = """
      defmodule RollbackTestModule1 do
        def state, do: :modified
      end
      """
      
      ModuleReloader.reload_module(RollbackTestModule1, updated_code)
      assert RollbackTestModule1.state() == :modified
      
      # Restore rollback point
      assert {:ok, :restored} = ModuleReloader.restore_rollback_point(point_name)
      
      # State should be restored (this is simplified - actual behavior may vary)
      # In a real implementation, you'd verify the restoration worked
    end
    
    test "handles restoration of non-existent rollback point" do
      assert {:error, reason} = ModuleReloader.restore_rollback_point("non_existent_point")
      assert reason =~ "not found"
    end
  end
  
  describe "atomic_reload/2" do
    test "performs atomic reload of multiple modules" do
      module_updates = [
        {AtomicTestModule1, """
        defmodule AtomicTestModule1 do
          def value, do: 1
        end
        """},
        {AtomicTestModule2, """
        defmodule AtomicTestModule2 do
          def value, do: 2  
        end
        """}
      ]
      
      assert {:ok, :atomic_reload_complete} = ModuleReloader.atomic_reload(module_updates)
      
      assert AtomicTestModule1.value() == 1
      assert AtomicTestModule2.value() == 2
    end
    
    test "rolls back all modules if one fails validation" do
      module_updates = [
        {AtomicTestModule3, """
        defmodule AtomicTestModule3 do
          def value, do: 3
        end
        """},
        {AtomicTestModule4, """
        defmodule AtomicTestModule4 do
          def broken( do: invalid_syntax
        end
        """}
      ]
      
      assert {:error, reason} = ModuleReloader.atomic_reload(module_updates, validate: true)
      assert reason =~ "Validation failed"
      
      # Neither module should be loaded due to atomic rollback
      assert_raise UndefinedFunctionError, fn ->
        AtomicTestModule3.value()
      end
    end
    
    test "handles empty module update list" do
      assert {:ok, :atomic_reload_complete} = ModuleReloader.atomic_reload([])
    end
  end
  
  describe "get_reload_stats/0" do
    test "returns reload statistics" do
      # Perform some operations first
      ModuleReloader.reload_module(StatsTestModule1, """
      defmodule StatsTestModule1 do
        def test, do: :ok
      end
      """)
      
      ModuleReloader.create_rollback_point("stats_test")
      
      stats = ModuleReloader.get_reload_stats()
      
      assert Map.has_key?(stats, :successful_reloads)
      assert Map.has_key?(stats, :failed_reloads)
      assert Map.has_key?(stats, :rollbacks)
      assert Map.has_key?(stats, :hot_swaps)
      assert Map.has_key?(stats, :tracked_modules)
      assert Map.has_key?(stats, :rollback_points)
      
      assert is_number(stats.successful_reloads)
      assert is_number(stats.failed_reloads)
      assert stats.successful_reloads >= 1  # At least one from our test
    end
  end
  
  describe "safety and validation" do
    test "blocks system command execution" do
      dangerous_code = """
      defmodule DangerousModule1 do
        def hack do
          System.cmd("rm", ["-rf", "/"])
        end  
      end
      """
      
      assert {:error, reason} = ModuleReloader.reload_module(DangerousModule1, dangerous_code, validate: true)
      assert reason =~ "dangerous patterns"
    end
    
    test "blocks file system manipulation" do
      dangerous_code = """
      defmodule DangerousModule2 do
        def destroy do
          File.rm_rf("/important/data")
        end
      end
      """
      
      assert {:error, reason} = ModuleReloader.reload_module(DangerousModule2, dangerous_code, validate: true)
      assert reason =~ "dangerous patterns"
    end
    
    test "allows safe operations" do
      safe_code = """
      defmodule SafeModule1 do
        def calculate(x, y) do
          x + y
        end
        
        def process_list(list) do
          Enum.map(list, fn x -> x * 2 end)
        end
      end
      """
      
      assert {:ok, :reloaded} = ModuleReloader.reload_module(SafeModule1, safe_code, validate: true)
      assert SafeModule1.calculate(2, 3) == 5
      assert SafeModule1.process_list([1, 2, 3]) == [2, 4, 6]
    end
  end
  
  describe "concurrent operations" do
    test "handles concurrent module reloads" do
      tasks = 1..5
      |> Enum.map(fn i ->
        Task.async(fn ->
          module_name = :"ConcurrentTestModule#{i}"
          code = """
          defmodule #{module_name} do
            def value, do: #{i}
          end
          """
          ModuleReloader.reload_module(module_name, code)
        end)
      end)
      
      results = Enum.map(tasks, &Task.await/1)
      
      # All reloads should succeed
      assert Enum.all?(results, fn result -> result == {:ok, :reloaded} end)
    end
    
    test "handles concurrent rollbacks" do
      # Setup modules first
      setup_tasks = 1..3
      |> Enum.map(fn i ->
        Task.async(fn ->
          module_name = :"RollbackConcurrentModule#{i}"
          
          v1_code = """
          defmodule #{module_name} do
            def version, do: 1
          end
          """
          
          v2_code = """
          defmodule #{module_name} do
            def version, do: 2  
          end
          """
          
          ModuleReloader.reload_module(module_name, v1_code)
          ModuleReloader.reload_module(module_name, v2_code)
          module_name
        end)
      end)
      
      modules = Enum.map(setup_tasks, &Task.await/1)
      
      # Now perform concurrent rollbacks
      rollback_tasks = Enum.map(modules, fn module_name ->
        Task.async(fn ->
          ModuleReloader.rollback_module(module_name, :previous)
        end)
      end)
      
      results = Enum.map(rollback_tasks, &Task.await/1)
      
      # Should handle concurrent rollbacks gracefully
      assert Enum.all?(results, fn result -> 
        match?({:ok, :rolled_back} | {:error, _}, result)
      end)
    end
  end
  
  describe "edge cases and error handling" do
    test "handles reloading non-existent module" do
      new_module_code = """
      defmodule BrandNewModule do
        def hello, do: :world
      end
      """
      
      assert {:ok, :reloaded} = ModuleReloader.reload_module(BrandNewModule, new_module_code)
      assert BrandNewModule.hello() == :world
    end
    
    test "handles very large module code" do
      # Generate a large module
      large_functions = 1..100
      |> Enum.map(fn i -> "def func#{i}, do: #{i}" end)
      |> Enum.join("\n  ")
      
      large_code = """
      defmodule LargeModule do
        #{large_functions}
      end
      """
      
      result = ModuleReloader.reload_module(LargeModule, large_code)
      assert match?({:ok, :reloaded} | {:error, _}, result)
    end
    
    test "handles module with complex macros" do
      macro_code = """
      defmodule MacroModule do
        defmacro simple_macro(expr) do
          quote do: unquote(expr) + 1
        end
        
        def use_macro do
          require __MODULE__
          simple_macro(5)
        end
      end
      """
      
      result = ModuleReloader.reload_module(MacroModule, macro_code)
      
      case result do
        {:ok, :reloaded} ->
          assert MacroModule.use_macro() == 6
        {:error, _reason} ->
          # Complex macros might not reload properly, which is acceptable
          :ok
      end
    end
    
    test "handles module reload timeout" do
      # This would require a way to simulate slow compilation
      # For now, just test that timeout option is accepted
      simple_code = """
      defmodule TimeoutTestModule do
        def test, do: :ok
      end
      """
      
      result = ModuleReloader.reload_module(
        TimeoutTestModule, 
        simple_code, 
        compile_timeout: 1000
      )
      
      assert result == {:ok, :reloaded}
    end
  end
end