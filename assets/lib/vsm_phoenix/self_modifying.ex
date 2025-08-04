defmodule VsmPhoenix.SelfModifying do
  @moduledoc """
  Self-modifying code capabilities for the Viable System Model (VSM) implementation.
  
  This module provides a comprehensive framework for runtime code generation,
  evolution, and adaptation. It enables the VSM to modify its own behavior
  based on environmental changes, performance metrics, and learned patterns.
  
  ## Core Components
  
  - `CodeGenerator` - Dynamic code generation and compilation
  - `SafeSandbox` - Isolated execution environment for code safety
  - `GeneticProgramming` - Evolutionary optimization of code
  - `AdaptiveBehavior` - Runtime adaptation and learning
  - `ModuleReloader` - Hot-swapping and version management
  
  ## Key Features
  
  - **Safe Code Generation**: Template-based code generation with security validation
  - **Evolutionary Optimization**: Genetic algorithms for code improvement
  - **Runtime Adaptation**: Automatic behavior modification based on metrics
  - **Hot Code Reloading**: Zero-downtime module updates with rollback
  - **Sandboxed Execution**: Secure isolated environment for code testing
  
  ## Usage Examples
  
  ### Basic Code Generation
  
      template = "def greet(name), do: \"Hello, {{name}}!\""
      bindings = %{name: "World"}
      
      {:ok, result} = VsmPhoenix.SelfModifying.generate_code(template, bindings)
      # result.code => "def greet(name), do: \"Hello, World!\""
  
  ### Safe Code Execution
  
      code = "Enum.sum([1, 2, 3, 4])"
      {:ok, 10} = VsmPhoenix.SelfModifying.execute_safely(code)
      
      dangerous_code = "File.rm(\"/etc/passwd\")"
      {:error, "Forbidden module access"} = VsmPhoenix.SelfModifying.execute_safely(dangerous_code)
  
  ### Code Evolution
  
      initial_code = "def calculate(x), do: x + 1"
      fitness_fn = fn code -> evaluate_performance(code) end
      
      {:ok, evolved} = VsmPhoenix.SelfModifying.evolve_code(initial_code, fitness_fn)
      # evolved.best_code contains optimized implementation
  
  ### Adaptive Behavior
  
      # Register adaptation pattern
      VsmPhoenix.SelfModifying.register_adaptation(
        :high_cpu_usage,
        %{cpu_usage: %{operator: :gt, threshold: 80}},
        &optimize_cpu_intensive_code/1
      )
      
      # Monitor metrics - triggers adaptation when threshold exceeded
      VsmPhoenix.SelfModifying.monitor_metric(:cpu_usage, 85)
  
  ### Hot Module Reloading
  
      new_code = "defmodule MyModule do\\n  def version, do: 2\\nend"
      {:ok, :reloaded} = VsmPhoenix.SelfModifying.reload_module(MyModule, new_code)
      
      # Create rollback point before risky changes
      {:ok, point_id} = VsmPhoenix.SelfModifying.create_rollback_point("before_update")
      # ... perform updates ...
      {:ok, :restored} = VsmPhoenix.SelfModifying.restore_rollback_point(point_id)
  
  ## Safety and Security
  
  All self-modification operations include comprehensive safety measures:
  
  - **Code Validation**: Syntax and semantic analysis before execution
  - **Sandboxed Execution**: Isolated environment with resource limits
  - **Pattern Blocking**: Detection and prevention of dangerous operations
  - **Resource Monitoring**: CPU, memory, and time constraints
  - **Rollback Capability**: Version management and recovery mechanisms
  
  ## Architecture Integration
  
  The self-modifying capabilities integrate with the VSM architecture through:
  
  - **System 1 (Operations)**: Runtime performance optimization
  - **System 2 (Coordination)**: Adaptive resource management  
  - **System 3 (Control)**: Policy-based behavior modification
  - **System 4 (Intelligence)**: Learning from environmental changes
  - **System 5 (Policy)**: Governance of self-modification rules
  
  ## Performance Considerations
  
  - Code generation is optimized for frequent small changes
  - Evolution uses configurable population sizes and generations
  - Sandboxed execution includes timeout and resource limits
  - Module reloading supports atomic operations for consistency
  - Adaptive behavior uses efficient pattern matching and caching
  """
  
  alias VsmPhoenix.SelfModifying.{
    CodeGenerator,
    SafeSandbox,
    GeneticProgramming,
    AdaptiveBehavior,
    ModuleReloader
  }
  
  @doc """
  Generates code from a template with variable bindings.
  
  ## Parameters
  - template: String template with {{variable}} placeholders
  - bindings: Map of variable names to values
  - opts: Generation options (validation, safety checks)
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.generate_code("def add(a, b), do: a + b", %{})
      {:ok, %{code: "def add(a, b), do: a + b", ast: {...}, metadata: %{...}}}
  """
  def generate_code(template, bindings \\ %{}, opts \\ []) do
    CodeGenerator.generate_code(template, bindings, opts)
  end
  
  @doc """
  Creates a new module dynamically with validation.
  
  ## Parameters
  - module_name: Atom name for the new module
  - code: Module source code as string
  - opts: Creation options
  
  ## Examples
      iex> code = "defmodule TestMod do\\n  def test, do: :ok\\nend"
      iex> VsmPhoenix.SelfModifying.create_module(TestMod, code)
      {:ok, TestMod}
  """
  def create_module(module_name, code, opts \\ []) do
    CodeGenerator.create_module(module_name, code, opts)
  end
  
  @doc """
  Executes code in a safe sandboxed environment.
  
  ## Parameters
  - code: Code string or function to execute
  - args: Arguments to pass to the code
  - opts: Execution options (timeout, limits)
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.execute_safely("1 + 1")
      {:ok, 2}
      
      iex> VsmPhoenix.SelfModifying.execute_safely("File.rm(\"/etc/passwd\")")
      {:error, "Forbidden module access: File"}
  """
  def execute_safely(code, args \\ [], opts \\ []) do
    SafeSandbox.execute(code, args, opts)
  end
  
  @doc """
  Validates code for safety before execution.
  
  ## Parameters
  - code: Code string or function to validate
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.validate_code_safety("x = 1 + 2")
      {:ok, :safe}
      
      iex> VsmPhoenix.SelfModifying.validate_code_safety("System.cmd(\\"rm\\", [])")
      {:error, "Unsafe code: Contains dangerous function calls"}
  """
  def validate_code_safety(code) do
    SafeSandbox.validate_code_safety(code)
  end
  
  @doc """
  Evolves code using genetic programming algorithms.
  
  ## Parameters
  - initial_code: Starting code template
  - fitness_function: Function to evaluate code quality
  - config: Evolution configuration (population_size, generations, etc.)
  
  ## Examples
      iex> fitness_fn = fn code -> evaluate_performance(code) end
      iex> VsmPhoenix.SelfModifying.evolve_code("1 + 1", fitness_fn, %{generations: 10})
      {:ok, %{best_code: "...", best_fitness: 0.95, generation: 10}}
  """
  def evolve_code(initial_code, fitness_function, config \\ %{}) do
    GeneticProgramming.evolve(initial_code, fitness_function, config)
  end
  
  @doc """
  Evolves functions for a specific task with test cases.
  
  ## Parameters
  - task_description: Natural language description of the task
  - test_cases: List of {input, expected_output} tuples
  - config: Evolution configuration
  
  ## Examples
      iex> test_cases = [{2, 4}, {3, 9}, {4, 16}]  # Square function
      iex> VsmPhoenix.SelfModifying.evolve_functions("square a number", test_cases)
      {:ok, %{best_code: "def solve(n), do: n * n", best_fitness: 1.0}}
  """
  def evolve_functions(task_description, test_cases, config \\ %{}) do
    GeneticProgramming.evolve_functions(task_description, test_cases, config)
  end
  
  @doc """
  Registers an adaptive behavior pattern.
  
  ## Parameters
  - pattern_id: Unique identifier for the pattern
  - trigger_conditions: Map of conditions that activate the pattern
  - adaptation_logic: Function to execute when pattern triggers
  - opts: Pattern options
  
  ## Examples
      iex> conditions = %{cpu_usage: %{operator: :gt, threshold: 80}}
      iex> logic = fn ctx -> optimize_cpu_code(ctx) end
      iex> VsmPhoenix.SelfModifying.register_adaptation(:cpu_opt, conditions, logic)
      :ok
  """
  def register_adaptation(pattern_id, trigger_conditions, adaptation_logic, opts \\ []) do
    AdaptiveBehavior.register_pattern(pattern_id, trigger_conditions, adaptation_logic, opts)
  end
  
  @doc """
  Monitors a system metric and triggers adaptations when thresholds are met.
  
  ## Parameters
  - metric_name: Name of the metric being monitored
  - current_value: Current value of the metric
  - opts: Monitoring options
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.monitor_metric(:cpu_usage, 85)
      :ok  # May trigger registered adaptations
  """
  def monitor_metric(metric_name, current_value, opts \\ []) do
    AdaptiveBehavior.monitor_metric(metric_name, current_value, opts)
  end
  
  @doc """
  Manually triggers an adaptation for a specific scenario.
  
  ## Parameters
  - adaptation_type: Type of adaptation to trigger
  - context: Context map with relevant information
  
  ## Examples
      iex> ctx = %{error_rate: 0.15, component: :database}
      iex> VsmPhoenix.SelfModifying.trigger_adaptation(:error_handling, ctx)
      {:ok, %{id: "adapt_123", type: :error_handling, result: %{...}}}
  """
  def trigger_adaptation(adaptation_type, context \\ %{}) do
    AdaptiveBehavior.trigger_adaptation(adaptation_type, context)
  end
  
  @doc """
  Creates a self-adapting function that improves based on usage.
  
  ## Parameters
  - base_function: Initial function implementation
  - fitness_criteria: Function to evaluate performance quality
  - opts: Adaptation options
  
  ## Examples
      iex> base_fn = fn x -> x * 2 end
      iex> fitness_fn = fn result -> if is_number(result), do: 1.0, else: 0.0 end
      iex> {:ok, adaptive_fn, id} = VsmPhoenix.SelfModifying.create_adaptive_function(base_fn, fitness_fn)
      iex> adaptive_fn.(5)  # Returns 10, but may adapt over time
      10
  """
  def create_adaptive_function(base_function, fitness_criteria, opts \\ []) do
    AdaptiveBehavior.create_adaptive_function(base_function, fitness_criteria, opts)
  end
  
  @doc """
  Records feedback about an adaptation's effectiveness.
  
  ## Parameters
  - adaptation_id: ID of the adaptation to provide feedback on
  - feedback: Feedback value (:success, :failure, or custom)
  - metrics: Optional performance metrics map
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.record_feedback("adapt_123", :success, %{improvement: 25})
      :ok
  """
  def record_feedback(adaptation_id, feedback, metrics \\ %{}) do
    AdaptiveBehavior.record_feedback(adaptation_id, feedback, metrics)
  end
  
  @doc """
  Reloads a module with new code at runtime.
  
  ## Parameters
  - module_name: Name of the module to reload
  - new_code: New source code for the module
  - opts: Reload options (validation, callbacks, etc.)
  
  ## Examples
      iex> new_code = "defmodule MyMod do\\n  def version, do: 2\\nend"
      iex> VsmPhoenix.SelfModifying.reload_module(MyMod, new_code)
      {:ok, :reloaded}
  """
  def reload_module(module_name, new_code, opts \\ []) do
    ModuleReloader.reload_module(module_name, new_code, opts)
  end
  
  @doc """
  Hot-swaps a single function within a module.
  
  ## Parameters
  - module_name: Module containing the function
  - function_name: Name of the function to replace
  - arity: Number of arguments the function takes
  - new_function_code: New implementation code
  - opts: Hot-swap options
  
  ## Examples
      iex> new_fn = "def greet(name), do: \\"Hi, \#{name}!\\""
      iex> VsmPhoenix.SelfModifying.hot_swap_function(MyMod, :greet, 1, new_fn)
      {:ok, :swapped}
  """
  def hot_swap_function(module_name, function_name, arity, new_function_code, opts \\ []) do
    ModuleReloader.hot_swap_function(module_name, function_name, arity, new_function_code, opts)
  end
  
  @doc """
  Creates a rollback point for the current system state.
  
  ## Parameters
  - point_name: Name to identify this rollback point
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.create_rollback_point("before_risky_update")
      {:ok, "before_risky_update"}
  """
  def create_rollback_point(point_name) do
    ModuleReloader.create_rollback_point(point_name)
  end
  
  @doc """
  Restores the system to a previous rollback point.
  
  ## Parameters
  - point_name: Name of the rollback point to restore
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.restore_rollback_point("before_risky_update")
      {:ok, :restored}
  """
  def restore_rollback_point(point_name) do
    ModuleReloader.restore_rollback_point(point_name)
  end
  
  @doc """
  Rolls back a module to a previous version.
  
  ## Parameters
  - module_name: Module to roll back
  - version: Version identifier or :previous for the last version
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.rollback_module(MyMod, :previous)
      {:ok, :rolled_back}
  """
  def rollback_module(module_name, version \\ :previous) do
    ModuleReloader.rollback_module(module_name, version)
  end
  
  @doc """
  Performs atomic reload of multiple modules.
  
  ## Parameters
  - module_updates: List of {module_name, new_code} tuples
  - opts: Atomic reload options
  
  ## Examples
      iex> updates = [{Mod1, "defmodule Mod1...end"}, {Mod2, "defmodule Mod2...end"}]
      iex> VsmPhoenix.SelfModifying.atomic_reload(updates)
      {:ok, :atomic_reload_complete}
  """
  def atomic_reload(module_updates, opts \\ []) do
    ModuleReloader.atomic_reload(module_updates, opts)
  end
  
  @doc """
  Gets comprehensive system statistics and status.
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.get_system_stats()
      %{
        adaptation_stats: %{active_adaptations: 3, success_rate: 0.85},
        reload_stats: %{successful_reloads: 15, failed_reloads: 2},
        evolution_stats: %{active_evolutions: 1, best_fitness: 0.92}
      }
  """
  def get_system_stats do
    %{
      adaptation_stats: AdaptiveBehavior.get_adaptation_stats(),
      reload_stats: ModuleReloader.get_reload_stats(),
      system_health: %{
        sandbox_active: Process.alive?(Process.whereis(SafeSandbox)),
        adaptive_behavior_active: Process.alive?(Process.whereis(AdaptiveBehavior)),
        module_reloader_active: Process.alive?(Process.whereis(ModuleReloader))
      }
    }
  end
  
  @doc """
  Learns from historical patterns and updates adaptation strategies.
  
  ## Parameters
  - time_window: Time window for pattern analysis (:hour, :day, :week, or seconds)
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.learn_from_patterns(:day)
      {:ok, [%{type: :performance_optimization, success_rate: 0.8, confidence: 0.9}]}
  """
  def learn_from_patterns(time_window \\ :hour) do
    AdaptiveBehavior.learn_from_patterns(time_window)
  end
  
  @doc """
  Starts all self-modification services.
  
  ## Parameters
  - opts: Service startup options
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.start_services()
      {:ok, [:safe_sandbox, :adaptive_behavior, :module_reloader]}
  """
  def start_services(opts \\ []) do
    services = []
    
    services = case SafeSandbox.start_link(opts) do
      {:ok, _pid} -> [:safe_sandbox | services]
      {:error, {:already_started, _}} -> [:safe_sandbox | services]
      _ -> services
    end
    
    services = case AdaptiveBehavior.start_link(opts) do
      {:ok, _pid} -> [:adaptive_behavior | services]
      {:error, {:already_started, _}} -> [:adaptive_behavior | services]
      _ -> services
    end
    
    services = case ModuleReloader.start_link(opts) do
      {:ok, _pid} -> [:module_reloader | services]
      {:error, {:already_started, _}} -> [:module_reloader | services]
      _ -> services
    end
    
    {:ok, Enum.reverse(services)}
  end
  
  @doc """
  Stops all self-modification services gracefully.
  
  ## Examples
      iex> VsmPhoenix.SelfModifying.stop_services()
      :ok
  """
  def stop_services do
    services = [SafeSandbox, AdaptiveBehavior, ModuleReloader]
    
    Enum.each(services, fn service ->
      case Process.whereis(service) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end
    end)
    
    :ok
  end
end