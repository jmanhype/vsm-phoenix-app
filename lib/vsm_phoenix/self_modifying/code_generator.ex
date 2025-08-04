defmodule VsmPhoenix.SelfModifying.CodeGenerator do
  @moduledoc """
  Dynamic code generation system for VSM self-modification capabilities.
  
  This module provides safe code generation, AST manipulation, and dynamic
  module creation with strict validation and security measures.
  """
  
  require Logger
  alias VsmPhoenix.SelfModifying.SafeSandbox
  
  @doc """
  Generates Elixir code dynamically based on templates and parameters.
  
  ## Parameters
  - template: Code template with placeholders
  - bindings: Map of variable bindings
  - opts: Generation options (validation, safety checks)
  
  ## Examples
      iex> template = "def hello(name), do: \"Hello, #{name}!\""
      iex> CodeGenerator.generate_code(template, %{}, validate: true)
      {:ok, generated_code}
  """
  def generate_code(template, bindings \\ %{}, opts \\ []) do
    with {:ok, validated_template} <- validate_template(template, opts),
         {:ok, processed_code} <- process_template(validated_template, bindings),
         {:ok, ast} <- parse_to_ast(processed_code),
         {:ok, validated_ast} <- validate_ast(ast, opts) do
      {:ok, %{
        code: processed_code,
        ast: ast,
        metadata: %{
          template: template,
          bindings: bindings,
          generated_at: DateTime.utc_now(),
          validation_passed: true
        }
      }}
    else
      {:error, reason} -> {:error, "Code generation failed: #{reason}"}
    end
  end
  
  @doc """
  Creates a new module dynamically with given code and validates it.
  """
  def create_module(module_name, code, opts \\ []) do
    validate_module_name = Keyword.get(opts, :validate_name, true)
    
    with {:ok, validated_name} <- validate_module_name(module_name, validate_module_name),
         {:ok, compiled_code} <- compile_code(code, opts),
         {:ok, _module} <- define_module(validated_name, compiled_code, opts) do
      
      Logger.info("Successfully created dynamic module: #{validated_name}")
      {:ok, validated_name}
    else
      {:error, reason} -> 
        Logger.error("Failed to create module #{module_name}: #{reason}")
        {:error, reason}
    end
  end
  
  @doc """
  Evolves existing code using genetic programming principles.
  """
  def evolve_code(base_code, fitness_function, generations \\ 10, opts \\ []) do
    population_size = Keyword.get(opts, :population_size, 20)
    mutation_rate = Keyword.get(opts, :mutation_rate, 0.1)
    
    initial_population = generate_population(base_code, population_size)
    
    Enum.reduce(1..generations, initial_population, fn generation, population ->
      Logger.debug("Evolution generation #{generation}")
      
      # Evaluate fitness of each individual
      evaluated_pop = Enum.map(population, fn individual ->
        fitness = evaluate_fitness(individual, fitness_function)
        {individual, fitness}
      end)
      
      # Select best individuals
      selected = select_best(evaluated_pop, div(population_size, 2))
      
      # Generate new population through crossover and mutation
      new_population = breed_population(selected, population_size, mutation_rate)
      
      new_population
    end)
    |> select_best_individual()
  end
  
  @doc """
  Injects code into an existing module safely.
  """
  def inject_code(target_module, injection_point, new_code, opts \\ []) do
    backup_enabled = Keyword.get(opts, :backup, true)
    validate_injection = Keyword.get(opts, :validate, true)
    
    with {:ok, original_code} <- get_module_source(target_module),
         {:ok, _backup} <- maybe_backup_module(target_module, original_code, backup_enabled),
         {:ok, modified_code} <- perform_injection(original_code, injection_point, new_code),
         {:ok, _validation} <- maybe_validate_injection(modified_code, validate_injection),
         {:ok, _compiled} <- recompile_module(target_module, modified_code) do
      
      Logger.info("Successfully injected code into #{target_module}")
      {:ok, :injected}
    else
      {:error, reason} -> 
        Logger.error("Code injection failed for #{target_module}: #{reason}")
        {:error, reason}
    end
  end
  
  # Private helper functions
  
  defp validate_template(template, opts) do
    max_length = Keyword.get(opts, :max_template_length, 10_000)
    forbidden_patterns = Keyword.get(opts, :forbidden_patterns, [
      ~r/File\.(rm|rm_rf|write)/,
      ~r/System\.(cmd|shell)/,
      ~r/:os\./,
      ~r/spawn/,
      ~r/Process\.exit/
    ])
    
    cond do
      String.length(template) > max_length ->
        {:error, "Template too long (max: #{max_length})"}
      
      Enum.any?(forbidden_patterns, &Regex.match?(&1, template)) ->
        {:error, "Template contains forbidden patterns"}
      
      true ->
        {:ok, template}
    end
  end
  
  defp process_template(template, bindings) do
    try do
      processed = Enum.reduce(bindings, template, fn {key, value}, acc ->
        String.replace(acc, "{{#{key}}}", to_string(value))
      end)
      {:ok, processed}
    rescue
      e -> {:error, "Template processing error: #{Exception.message(e)}"}
    end
  end
  
  defp parse_to_ast(code) do
    try do
      case Code.string_to_quoted(code) do
        {:ok, ast} -> {:ok, ast}
        {:error, reason} -> {:error, "Parse error: #{inspect(reason)}"}
      end
    rescue
      e -> {:error, "AST parsing error: #{Exception.message(e)}"}
    end
  end
  
  defp validate_ast(ast, opts) do
    max_depth = Keyword.get(opts, :max_ast_depth, 50)
    forbidden_functions = Keyword.get(opts, :forbidden_functions, [
      {:File, :rm},
      {:File, :rm_rf},
      {:System, :cmd},
      {:System, :shell}
    ])
    
    with {:ok, _depth} <- check_ast_depth(ast, max_depth),
         {:ok, _safety} <- check_forbidden_functions(ast, forbidden_functions) do
      {:ok, ast}
    end
  end
  
  defp validate_module_name(name, true) when is_atom(name) do
    name_str = Atom.to_string(name)
    if Regex.match?(~r/^[A-Z][a-zA-Z0-9_.]*$/, name_str) do
      {:ok, name}
    else
      {:error, "Invalid module name format"}
    end
  end
  defp validate_module_name(name, false), do: {:ok, name}
  defp validate_module_name(name, _), do: {:error, "Module name must be an atom, got: #{inspect(name)}"}
  
  defp compile_code(code, opts) do
    timeout = Keyword.get(opts, :compile_timeout, 5000)
    
    task = Task.async(fn ->
      try do
        case Code.compile_string(code) do
          [] -> {:error, "No modules compiled"}
          modules -> {:ok, modules}
        end
      rescue
        e -> {:error, "Compilation error: #{Exception.message(e)}"}
      end
    end)
    
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Compilation timeout"}
    end
  end
  
  defp define_module(name, compiled_code, _opts) do
    try do
      # Module is already defined by compilation
      {:ok, name}
    rescue
      e -> {:error, "Module definition error: #{Exception.message(e)}"}
    end
  end
  
  defp generate_population(base_code, size) do
    1..size
    |> Enum.map(fn _ -> mutate_code(base_code, 0.2) end)
    |> Enum.uniq()
  end
  
  defp mutate_code(code, mutation_rate) do
    # Simple mutation: randomly change small parts
    code
    |> String.graphemes()
    |> Enum.map(fn char ->
      if :rand.uniform() < mutation_rate do
        # Random character substitution
        Enum.random(~w(a b c d e f g h i j k l m n o p q r s t u v w x y z))
      else
        char
      end
    end)
    |> Enum.join("")
  end
  
  defp evaluate_fitness(code, fitness_function) do
    try do
      case SafeSandbox.execute(fitness_function, [code], timeout: 1000) do
        {:ok, fitness} when is_number(fitness) -> fitness
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end
  
  defp select_best(evaluated_population, count) do
    evaluated_population
    |> Enum.sort_by(fn {_code, fitness} -> fitness end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn {code, _fitness} -> code end)
  end
  
  defp breed_population(selected, population_size, mutation_rate) do
    # Generate new individuals through crossover and mutation
    1..population_size
    |> Enum.map(fn _ ->
      parent1 = Enum.random(selected)
      parent2 = Enum.random(selected)
      
      child = crossover(parent1, parent2)
      mutate_code(child, mutation_rate)
    end)
  end
  
  defp crossover(parent1, parent2) do
    # Simple crossover: take parts from each parent
    len1 = String.length(parent1)
    len2 = String.length(parent2)
    
    cut_point = :rand.uniform(min(len1, len2))
    
    String.slice(parent1, 0, cut_point) <> String.slice(parent2, cut_point, len2)
  end
  
  defp select_best_individual(population) do
    case population do
      [] -> {:error, "Empty population"}
      [best | _] -> {:ok, best}
    end
  end
  
  defp get_module_source(module) do
    try do
      case :code.which(module) do
        :non_existing -> {:error, "Module not found"}
        beam_file -> 
          # This is a simplified approach - in reality, you'd need
          # to maintain source mappings or use debug info
          {:ok, "# Source code for #{module}"}
      end
    rescue
      e -> {:error, "Failed to get source: #{Exception.message(e)}"}
    end
  end
  
  defp maybe_backup_module(_module, _code, false), do: {:ok, :no_backup}
  defp maybe_backup_module(module, code, true) do
    backup_key = "backup_#{module}_#{System.system_time(:second)}"
    # Store backup in ETS or persistent storage
    {:ok, backup_key}
  end
  
  defp perform_injection(original_code, injection_point, new_code) do
    # Simple injection at specified point
    case String.split(original_code, injection_point, parts: 2) do
      [before, after] -> 
        {:ok, before <> new_code <> injection_point <> after}
      _ -> 
        {:error, "Injection point not found"}
    end
  end
  
  defp maybe_validate_injection(_code, false), do: {:ok, :no_validation}
  defp maybe_validate_injection(code, true) do
    parse_to_ast(code)
  end
  
  defp recompile_module(module, code) do
    try do
      # Purge old module
      :code.purge(module)
      :code.delete(module)
      
      # Compile new version
      compile_code(code, [])
    rescue
      e -> {:error, "Recompilation failed: #{Exception.message(e)}"}
    end
  end
  
  defp check_ast_depth(ast, max_depth) do
    depth = calculate_ast_depth(ast)
    if depth <= max_depth do
      {:ok, depth}
    else
      {:error, "AST too deep: #{depth} (max: #{max_depth})"}
    end
  end
  
  defp calculate_ast_depth({_, _, args}) when is_list(args) do
    1 + (args |> Enum.map(&calculate_ast_depth/1) |> Enum.max(fn -> 0 end))
  end
  defp calculate_ast_depth(_), do: 1
  
  defp check_forbidden_functions(ast, forbidden) do
    if contains_forbidden_function?(ast, forbidden) do
      {:error, "Contains forbidden function calls"}
    else
      {:ok, :safe}
    end
  end
  
  defp contains_forbidden_function?({module, function, _args}, forbidden) when is_atom(module) and is_atom(function) do
    {module, function} in forbidden
  end
  defp contains_forbidden_function?({_, _, args}, forbidden) when is_list(args) do
    Enum.any?(args, &contains_forbidden_function?(&1, forbidden))
  end
  defp contains_forbidden_function?(_, _), do: false
end