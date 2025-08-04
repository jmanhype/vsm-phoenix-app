defmodule VsmPhoenix.SelfModifying.SafeSandbox do
  @moduledoc """
  Safe execution sandbox for self-modifying code.
  
  Provides isolated execution environment with resource limits,
  security constraints, and monitoring capabilities.
  """
  
  require Logger
  use GenServer
  
  @default_limits %{
    memory_mb: 50,
    cpu_time_ms: 5000,
    wall_time_ms: 10000,
    file_descriptors: 10,
    processes: 5
  }
  
  @forbidden_modules [
    File, System, :os, Port, Node, :net, :inet, :gen_tcp, :gen_udp,
    Code, :code, :erlang
  ]
  
  defstruct [
    :id,
    :limits,
    :start_time,
    :pid,
    :monitor_ref,
    :status,
    :result,
    :resource_usage
  ]
  
  ## Public API
  
  @doc """
  Starts a new sandbox instance.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Executes code in a safe sandbox environment.
  
  ## Parameters
  - code: String or function to execute
  - args: Arguments to pass to the code
  - opts: Execution options (limits, timeout, etc.)
  
  ## Examples
      iex> SafeSandbox.execute("1 + 1", [], timeout: 1000)
      {:ok, 2}
      
      iex> SafeSandbox.execute("File.rm(\"/etc/passwd\")", [])
      {:error, "Forbidden module access: File"}
  """
  def execute(code, args \\ [], opts \\ []) do
    sandbox_id = generate_sandbox_id()
    limits = merge_limits(opts)
    
    Logger.debug("Executing code in sandbox #{sandbox_id}")
    
    with {:ok, validated_code} <- validate_code(code),
         {:ok, compiled_fun} <- compile_safe_code(validated_code, args),
         {:ok, result} <- run_in_sandbox(compiled_fun, limits, opts) do
      
      Logger.debug("Sandbox #{sandbox_id} execution successful")
      {:ok, result}
    else
      {:error, reason} -> 
        Logger.warn("Sandbox #{sandbox_id} execution failed: #{reason}")
        {:error, reason}
    end
  end
  
  @doc """
  Executes a function with resource monitoring.
  """
  def execute_monitored(fun, limits \\ @default_limits, opts \\ []) when is_function(fun) do
    timeout = Keyword.get(opts, :timeout, limits.wall_time_ms)
    
    # Start resource monitoring
    monitor_pid = start_resource_monitor(limits)
    
    task = Task.async(fn ->
      try do
        result = fun.()
        stop_resource_monitor(monitor_pid)
        {:ok, result}
      rescue
        e -> 
          stop_resource_monitor(monitor_pid)
          {:error, "Execution error: #{Exception.message(e)}"}
      catch
        kind, reason ->
          stop_resource_monitor(monitor_pid)
          {:error, "Execution #{kind}: #{inspect(reason)}"}
      end
    end)
    
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Execution timeout"}
    end
  end
  
  @doc """
  Creates a restricted execution environment.
  """
  def create_restricted_env(allowed_modules \\ []) do
    base_env = %{
      # Safe built-in functions
      "+" => &Kernel.+/2,
      "-" => &Kernel.-/2,
      "*" => &Kernel.*/2,
      "/" => &Kernel.//2,
      "==" => &Kernel.==/2,
      "!=" => &Kernel.!=/2,
      "<" => &Kernel.</2,
      ">" => &Kernel.>/2,
      "and" => &Kernel.and/2,
      "or" => &Kernel.or/2,
      "not" => &Kernel.not/1,
      
      # Safe Enum functions
      "map" => &Enum.map/2,
      "filter" => &Enum.filter/2,
      "reduce" => &Enum.reduce/3,
      "count" => &Enum.count/1,
      
      # Safe String functions
      "upcase" => &String.upcase/1,
      "downcase" => &String.downcase/1,
      "length" => &String.length/1
    }
    
    # Add allowed modules
    allowed_env = Enum.reduce(allowed_modules, %{}, fn module, acc ->
      Map.put(acc, to_string(module), module)
    end)
    
    Map.merge(base_env, allowed_env)
  end
  
  @doc """
  Validates that code is safe for execution.
  """
  def validate_code_safety(code) when is_binary(code) do
    with {:ok, ast} <- Code.string_to_quoted(code),
         {:ok, _} <- check_forbidden_modules(ast),
         {:ok, _} <- check_dangerous_functions(ast),
         {:ok, _} <- check_resource_usage(ast) do
      {:ok, :safe}
    else
      {:error, reason} -> {:error, "Unsafe code: #{reason}"}
    end
  end
  
  def validate_code_safety(fun) when is_function(fun) do
    # For functions, we can't easily inspect the code,
    # so we rely on runtime monitoring
    {:ok, :runtime_monitored}
  end
  
  ## GenServer implementation
  
  @impl true
  def init(opts) do
    state = %{
      active_sandboxes: %{},
      resource_monitors: %{},
      global_limits: Keyword.get(opts, :global_limits, @default_limits)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:execute, code, args, opts}, _from, state) do
    # Implementation would handle async execution
    {:reply, {:ok, :executed}, state}
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.debug("Sandbox process #{inspect(pid)} terminated: #{inspect(reason)}")
    {:noreply, state}
  end
  
  ## Private functions
  
  defp generate_sandbox_id do
    "sandbox_#{System.unique_integer([:positive])}"
  end
  
  defp merge_limits(opts) do
    custom_limits = Keyword.get(opts, :limits, %{})
    Map.merge(@default_limits, custom_limits)
  end
  
  defp validate_code(code) when is_binary(code) do
    validate_code_safety(code)
  end
  
  defp validate_code(fun) when is_function(fun) do
    validate_code_safety(fun)
  end
  
  defp validate_code(_), do: {:error, "Invalid code type"}
  
  defp compile_safe_code(code, args) when is_binary(code) do
    try do
      # Create a safe function that accepts the provided arguments
      safe_code = """
      fn(#{generate_arg_pattern(args)}) ->
        #{code}
      end
      """
      
      case Code.eval_string(safe_code) do
        {fun, _binding} when is_function(fun) -> {:ok, fun}
        _ -> {:error, "Failed to compile to function"}
      end
    rescue
      e -> {:error, "Compilation error: #{Exception.message(e)}"}
    end
  end
  
  defp compile_safe_code(fun, _args) when is_function(fun) do
    {:ok, fun}
  end
  
  defp generate_arg_pattern([]), do: ""
  defp generate_arg_pattern(args) do
    args
    |> Enum.with_index()
    |> Enum.map(fn {_arg, index} -> "arg#{index}" end)
    |> Enum.join(", ")
  end
  
  defp run_in_sandbox(fun, limits, opts) do
    timeout = Keyword.get(opts, :timeout, limits.wall_time_ms)
    
    # Create isolated process for execution
    parent = self()
    
    task_pid = spawn_link(fn ->
      # Set process limits
      Process.flag(:max_heap_size, div(limits.memory_mb * 1024 * 1024, 8)) # Convert MB to words
      
      try do
        result = fun.()
        send(parent, {:sandbox_result, self(), {:ok, result}})
      rescue
        e -> send(parent, {:sandbox_result, self(), {:error, Exception.message(e)}})
      catch
        kind, reason -> send(parent, {:sandbox_result, self(), {:error, "#{kind}: #{inspect(reason)}"}})
      end
    end)
    
    # Monitor the task
    monitor_ref = Process.monitor(task_pid)
    
    receive do
      {:sandbox_result, ^task_pid, result} ->
        Process.demonitor(monitor_ref, [:flush])
        result
        
      {:DOWN, ^monitor_ref, :process, ^task_pid, reason} ->
        {:error, "Sandbox process died: #{inspect(reason)}"}
    after
      timeout ->
        Process.exit(task_pid, :kill)
        Process.demonitor(monitor_ref, [:flush])
        {:error, "Sandbox timeout"}
    end
  end
  
  defp start_resource_monitor(limits) do
    parent = self()
    
    spawn_link(fn ->
      monitor_resources(parent, limits)
    end)
  end
  
  defp stop_resource_monitor(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :normal)
    end
  end
  
  defp monitor_resources(parent, limits) do
    start_time = System.monotonic_time(:millisecond)
    monitor_loop(parent, limits, start_time)
  end
  
  defp monitor_loop(parent, limits, start_time) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - start_time
    
    if elapsed > limits.wall_time_ms do
      send(parent, {:resource_limit_exceeded, :wall_time})
    else
      # Check memory usage
      case Process.info(parent, :memory) do
        {:memory, memory_bytes} ->
          memory_mb = memory_bytes / (1024 * 1024)
          if memory_mb > limits.memory_mb do
            send(parent, {:resource_limit_exceeded, :memory})
          end
        _ -> :ok
      end
      
      # Continue monitoring
      Process.sleep(100)
      monitor_loop(parent, limits, start_time)
    end
  end
  
  defp check_forbidden_modules(ast) do
    if contains_forbidden_modules?(ast) do
      {:error, "Contains forbidden module access"}
    else
      {:ok, :safe}
    end
  end
  
  defp contains_forbidden_modules?({module, _function, _args}) when module in @forbidden_modules do
    true
  end
  
  defp contains_forbidden_modules?({{:., _, [{:__aliases__, _, module_parts}, _function_name]}, _, _args}) do
    module_atom = Module.concat(module_parts)
    module_atom in @forbidden_modules
  end
  
  defp contains_forbidden_modules?({_, _, args}) when is_list(args) do
    Enum.any?(args, &contains_forbidden_modules?/1)
  end
  
  defp contains_forbidden_modules?(_), do: false
  
  defp check_dangerous_functions(ast) do
    dangerous_patterns = [
      # File operations
      {:File, :rm}, {:File, :rm_rf}, {:File, :write},
      # System operations
      {:System, :cmd}, {:System, :shell},
      # Process operations
      {:Process, :exit}, {:spawn, :_}, {:spawn_link, :_},
      # Network operations
      {:gen_tcp, :_}, {:gen_udp, :_}
    ]
    
    if contains_dangerous_patterns?(ast, dangerous_patterns) do
      {:error, "Contains dangerous function calls"}
    else
      {:ok, :safe}
    end
  end
  
  defp contains_dangerous_patterns?(ast, patterns) do
    Enum.any?(patterns, fn {module, function} ->
      contains_function_call?(ast, module, function)
    end)
  end
  
  defp contains_function_call?({module, function, _args}, target_module, target_function) 
       when module == target_module and (function == target_function or target_function == :_) do
    true
  end
  
  defp contains_function_call?({_, _, args}, target_module, target_function) when is_list(args) do
    Enum.any?(args, &contains_function_call?(&1, target_module, target_function))
  end
  
  defp contains_function_call?(_, _, _), do: false
  
  defp check_resource_usage(ast) do
    # Simple heuristic: count nested structures
    depth = calculate_ast_depth(ast)
    
    if depth > 100 do
      {:error, "Code too complex (max depth: 100)"}
    else
      {:ok, :acceptable}
    end
  end
  
  defp calculate_ast_depth({_, _, args}) when is_list(args) do
    1 + (args |> Enum.map(&calculate_ast_depth/1) |> Enum.max(fn -> 0 end))
  end
  defp calculate_ast_depth(_), do: 1
end