defmodule FixMLDeps do
  @moduledoc """
  Script to fix ML dependencies for Mac M2 (Apple Silicon)
  Run with: mix run fix_ml_deps.exs
  """

  def run do
    IO.puts("🔧 Fixing ML Dependencies for Mac M2...")
    
    # 1. Check system architecture
    {arch, 0} = System.cmd("uname", ["-m"])
    arch = String.trim(arch)
    
    if arch == "arm64" do
      IO.puts("✅ Detected Apple Silicon (M2)")
    else
      IO.puts("⚠️  Warning: Not running on Apple Silicon, but continuing...")
    end
    
    # 2. Set environment variables for M2 compilation
    env_vars = %{
      "EXLA_TARGET" => "METAL",
      "XLA_TARGET" => "arm64-apple-darwin",
      "EXLA_MODE" => "opt",
      "EXLA_CACHE" => Path.expand("~/.cache/exla"),
      "CC" => "/opt/homebrew/opt/llvm/bin/clang",
      "CXX" => "/opt/homebrew/opt/llvm/bin/clang++",
      "LDFLAGS" => "-L/opt/homebrew/opt/llvm/lib",
      "CPPFLAGS" => "-I/opt/homebrew/opt/llvm/include"
    }
    
    Enum.each(env_vars, fn {key, value} ->
      System.put_env(key, value)
      IO.puts("  Set #{key}=#{value}")
    end)
    
    # 3. Create XLA cache directory
    cache_dir = Path.expand("~/.cache/exla")
    File.mkdir_p!(cache_dir)
    IO.puts("✅ Created XLA cache directory: #{cache_dir}")
    
    # 4. Update mix.exs to use M2-compatible versions
    mix_content = File.read!("mix.exs")
    
    # Replace ML dependency versions with M2-compatible ones
    updated_mix = mix_content
    |> String.replace(
      "{:nx, \"~> 0.9\"}",
      "{:nx, \"~> 0.9.2\"}"
    )
    |> String.replace(
      "{:axon, \"~> 0.7\"}",
      "{:axon, \"~> 0.7.0\"}"
    )
    |> String.replace(
      "{:exla, \"~> 0.9\"}",
      "{:exla, \"~> 0.9.2\"}"
    )
    |> String.replace(
      "{:torchx, \"~> 0.7\", optional: true}",
      "# {:torchx, \"~> 0.7\", optional: true}  # Not compatible with M2 yet"
    )
    
    File.write!("mix.exs", updated_mix)
    IO.puts("✅ Updated mix.exs with M2-compatible ML dependency versions")
    
    # 5. Create a minimal ML config for testing
    ml_config = """
    config :nx, 
      default_backend: EXLA.Backend,
      default_defn_options: [compiler: EXLA]
    
    config :exla,
      clients: [
        metal: [platform: :metal]
      ]
    """
    
    File.write!("config/ml.exs", ml_config)
    IO.puts("✅ Created ML configuration for Metal acceleration")
    
    # 6. Add import to config.exs
    config_content = File.read!("config/config.exs")
    if not String.contains?(config_content, "import_config \"ml.exs\"") do
      updated_config = String.replace(
        config_content,
        "import_config \"#{config_env()}.exs\"",
        "import_config \"ml.exs\"\nimport_config \"\#{config_env()}.exs\""
      )
      File.write!("config/config.exs", updated_config)
      IO.puts("✅ Added ML config import to config.exs")
    end
    
    IO.puts("\n🎯 Next steps:")
    IO.puts("1. Run: mix deps.clean --all")
    IO.puts("2. Run: mix deps.get")
    IO.puts("3. Run: mix deps.compile")
    IO.puts("\nNote: EXLA compilation will take 10-15 minutes on first run!")
  end
end

FixMLDeps.run()