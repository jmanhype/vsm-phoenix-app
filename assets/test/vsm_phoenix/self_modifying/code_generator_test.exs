defmodule VsmPhoenix.SelfModifying.CodeGeneratorTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.SelfModifying.CodeGenerator
  
  describe "generate_code/3" do
    test "generates simple code from template" do
      template = "def hello, do: \"Hello, World!\""
      
      assert {:ok, result} = CodeGenerator.generate_code(template)
      assert result.code == template
      assert result.metadata.validation_passed == true
    end
    
    test "processes template with bindings" do
      template = "def greet(name), do: \"Hello, {{name}}!\""
      bindings = %{name: "Alice"}
      
      assert {:ok, result} = CodeGenerator.generate_code(template, bindings)
      assert result.code == "def greet(name), do: \"Hello, Alice!\""
    end
    
    test "validates template safety" do
      dangerous_template = "File.rm(\"/etc/passwd\")"
      
      assert {:error, reason} = CodeGenerator.generate_code(dangerous_template, %{}, validate: true)
      assert reason =~ "forbidden patterns"
    end
    
    test "rejects templates that are too long" do
      long_template = String.duplicate("a", 20_000)
      
      assert {:error, reason} = CodeGenerator.generate_code(long_template, %{}, max_template_length: 1000)
      assert reason =~ "Template too long"
    end
    
    test "parses code to AST successfully" do
      template = "def test(x), do: x + 1"
      
      assert {:ok, result} = CodeGenerator.generate_code(template)
      assert is_tuple(result.ast)
    end
    
    test "rejects invalid syntax" do
      invalid_template = "def broken( do: invalid"
      
      assert {:error, reason} = CodeGenerator.generate_code(invalid_template)
      assert reason =~ "generation failed"
    end
  end
  
  describe "create_module/3" do
    test "creates a simple module" do
      code = """
      defmodule TestModule do
        def hello, do: :world
      end
      """
      
      assert {:ok, module_name} = CodeGenerator.create_module(TestModule, code)
      assert module_name == TestModule
      assert TestModule.hello() == :world
    end
    
    test "validates module name format" do
      code = "defmodule ValidModule do\nend"
      
      assert {:ok, _} = CodeGenerator.create_module(ValidModule, code, validate_name: true)
      assert {:error, _} = CodeGenerator.create_module(:invalid_name, code, validate_name: true)
    end
    
    test "handles compilation errors gracefully" do
      invalid_code = "defmodule BrokenModule do\n  invalid syntax here\nend"
      
      assert {:error, reason} = CodeGenerator.create_module(BrokenModule, invalid_code)
      assert reason =~ "Compilation error"
    end
  end
  
  describe "evolve_code/4" do
    test "evolves simple arithmetic code" do
      base_code = "1 + 1"
      fitness_fn = fn code ->
        case Code.eval_string(code) do
          {result, _} when is_number(result) -> result / 10.0
          _ -> 0
        end
      end
      
      population = CodeGenerator.evolve_code(base_code, fitness_fn, 5, population_size: 10)
      assert length(population) == 10
    end
    
    test "maintains population diversity" do
      base_code = "x = 1"
      fitness_fn = fn _code -> :rand.uniform() end
      
      population = CodeGenerator.evolve_code(base_code, fitness_fn, 3, population_size: 20)
      unique_codes = Enum.uniq(population)
      
      # Should have some diversity
      assert length(unique_codes) > 1
    end
  end
  
  describe "inject_code/4" do
    test "injects code at specified point" do
      target_module = TestTargetModule
      
      # Create a simple module first
      original_code = """
      defmodule TestTargetModule do
        def existing_function, do: :original
        # INJECTION_POINT
      end
      """
      
      CodeGenerator.create_module(target_module, original_code)
      
      new_code = "def new_function, do: :injected"
      
      assert {:ok, :injected} = CodeGenerator.inject_code(
        target_module, 
        "# INJECTION_POINT", 
        new_code,
        backup: false
      )
    end
    
    test "handles injection point not found" do
      target_module = TestTargetModule2
      
      original_code = "defmodule TestTargetModule2 do\nend"
      CodeGenerator.create_module(target_module, original_code)
      
      assert {:error, reason} = CodeGenerator.inject_code(
        target_module,
        "# NONEXISTENT_POINT",
        "def new_function, do: :test",
        backup: false
      )
      assert reason =~ "Injection point not found"
    end
  end
  
  describe "safety validations" do
    test "blocks dangerous file operations" do
      dangerous_code = "File.rm_rf(\"/\")"
      
      assert {:error, _} = CodeGenerator.generate_code(dangerous_code, %{}, validate: true)
    end
    
    test "blocks system commands" do
      dangerous_code = "System.cmd(\"rm\", [\"-rf\", \"/\"])"
      
      assert {:error, _} = CodeGenerator.generate_code(dangerous_code, %{}, validate: true)
    end
    
    test "blocks process spawning" do
      dangerous_code = "spawn(fn -> File.rm(\"/etc/passwd\") end)"
      
      assert {:error, _} = CodeGenerator.generate_code(dangerous_code, %{}, validate: true)
    end
    
    test "allows safe operations" do
      safe_code = "Enum.map([1, 2, 3], fn x -> x * 2 end)"
      
      assert {:ok, _} = CodeGenerator.generate_code(safe_code, %{}, validate: true)
    end
  end
  
  describe "AST validation" do
    test "rejects deeply nested AST" do
      # Create deeply nested code
      nested_code = (1..100)
      |> Enum.reduce("x", fn _, acc -> "f(#{acc})" end)
      
      assert {:error, reason} = CodeGenerator.generate_code(nested_code, %{}, max_ast_depth: 10)
      assert reason =~ "AST too deep"
    end
    
    test "accepts reasonably nested AST" do
      nested_code = "if true, do: if false, do: :ok, else: :error"
      
      assert {:ok, _} = CodeGenerator.generate_code(nested_code, %{}, max_ast_depth: 50)
    end
  end
  
  describe "template processing" do
    test "handles complex template bindings" do
      template = """
      def {{function_name}}({{param}}) do
        {{body}}
      end
      """
      
      bindings = %{
        function_name: "calculate",
        param: "x, y",
        body: "x + y"
      }
      
      assert {:ok, result} = CodeGenerator.generate_code(template, bindings)
      assert result.code =~ "def calculate(x, y) do"
      assert result.code =~ "x + y"
    end
    
    test "handles missing bindings gracefully" do
      template = "def {{missing_binding}}, do: :ok"
      
      assert {:ok, result} = CodeGenerator.generate_code(template, %{})
      assert result.code =~ "{{missing_binding}}"
    end
    
    test "handles special characters in bindings" do
      template = "# {{comment}}"
      bindings = %{comment: "This is a test with special chars: !@#$%"}
      
      assert {:ok, result} = CodeGenerator.generate_code(template, bindings)
      assert result.code =~ "special chars: !@#$%"
    end
  end
end