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
      
      # Security dependencies
      {:guardian, "~> 2.3"},
      {:guardian_phoenix, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:cors_plug, "~> 3.0"},
      {:hammer, "~> 6.0"},
      {:comeonin, "~> 5.3"},
      {:argon2_elixir, "~> 3.0"},
      {:ex_json_schema, "~> 0.9"},
      {:html_sanitize_ex, "~> 1.4"},
      {:secure_random, "~> 0.5"},
      {:plug_attack, "~> 0.4"},
      {:recaptcha, "~> 3.0"},
      {:guardian_db, "~> 2.1"},
      
      # LLM API integrations - Production Ready
      {:openai, "~> 0.6.0"},
      {:anthropic, "~> 0.2.0"},
      {:req, "~> 0.5.10"},
      {:tesla, "~> 1.8"},
      {:retry, "~> 0.18.0"},
      
      # Event Processing Dependencies
      {:broadway, "~> 1.0"},
      {:gen_stage, "~> 1.2"},
      {:flow, "~> 1.2"},
      {:eventstore, "~> 1.4"},
      {:timex, "~> 3.7"},
      {:kafka_ex, "~> 0.13"},
      {:redix, "~> 1.2"},
      
      # Benchmarking dependencies
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:benchee_json, "~> 1.0", only: [:dev, :test]},
      
      # Machine Learning dependencies
      {:nx, "~> 0.9"},
      {:axon, "~> 0.7"},
      {:exla, "~> 0.9"},
      {:scidata, "~> 0.1"},
      {:scholar, "~> 0.3"},
      {:polaris, "~> 0.1"},
      {:table_rex, "~> 3.1.1"},
      {:kino, "~> 0.14", only: [:dev, :test]},
      {:kino_vega_lite, "~> 0.1", only: [:dev, :test]},
      {:vega_lite, "~> 0.1"},
      {:nx_signal, "~> 0.2"},
      {:bumblebee, "~> 0.5"},
      {:torchx, "~> 0.7", optional: true}
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