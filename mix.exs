defmodule VsmPhoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsm_phoenix,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {VsmPhoenix.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:phoenix_pubsub, "~> 2.1"},
      {:quantum, "~> 3.5"},
      {:tidewave, github: "tidewave-ai/tidewave_phoenix", branch: "main"},
      # VSMCP: Using AMQP with OTP 27 compatible version
      {:amqp, "~> 3.2"},  # Try older version that works with OTP 27
      {:hackney, "~> 1.9"},
      {:hermes_mcp, github: "cloudwalk/hermes-mcp", branch: "main"},
      {:goldrush, github: "DeadZen/goldrush", branch: "develop-elixir", override: true},
      {:meck, "~> 0.9", only: :test},
      {:httpoison, "~> 2.0"},
      
      # Benchmarking dependencies
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:benchee_json, "~> 1.0", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      
      # Benchmarking aliases
      benchmark: ["run benchmarks/run_benchmarks.exs"],
      "benchmark.quick": ["run benchmarks/run_benchmarks.exs --profile quick"],
      "benchmark.stress": ["run benchmarks/run_benchmarks.exs --profile stress"],
      "benchmark.quantum": ["run benchmarks/run_benchmarks.exs --suite quantum"],
      "benchmark.variety": ["run benchmarks/run_benchmarks.exs --suite variety"]
    ]
  end
end