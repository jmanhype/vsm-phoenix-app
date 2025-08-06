defmodule VsmPhoenix.Infrastructure.ExchangeConfig do
  @moduledoc """
  Configuration module for AMQP exchange mappings.
  Maps logical exchange names to environment-specific exchange names.
  """

  @default_exchanges %{
    # Core VSM exchanges
    recursive: "vsm.recursive",
    algedonic: "vsm.algedonic",
    coordination: "vsm.coordination",
    control: "vsm.control",
    intelligence: "vsm.intelligence",
    policy: "vsm.policy",
    audit: "vsm.audit",
    meta: "vsm.meta",
    commands: "vsm.commands",

    # Swarm exchanges
    swarm: "vsm.swarm",

    # System-specific command exchanges
    s1_commands: "vsm.s1.commands",

    # Agent-specific exchanges
    results: "vsm.results",
    telemetry: "vsm.telemetry",
    api_responses: "vsm.api.responses",
    api_events: "vsm.api.events",
    telegram_events: "vsm.telegram.events",
    telegram_commands: "vsm.telegram.commands",
    vsm_commands: "vsm.commands"
  }

  @exchange_types %{
    recursive: :topic,
    algedonic: :fanout,
    coordination: :fanout,
    control: :fanout,
    intelligence: :fanout,
    policy: :fanout,
    audit: :fanout,
    meta: :topic,
    commands: :topic,
    swarm: :topic,
    s1_commands: :topic,
    # Agent-specific exchange types
    results: :topic,
    telemetry: :topic,
    api_responses: :topic,
    api_events: :topic,
    telegram_events: :topic,
    telegram_commands: :topic,
    vsm_commands: :topic
  }

  @doc """
  Load exchange configuration from environment or use defaults.
  """
  def load_config do
    env_prefix = System.get_env("VSM_ENV_PREFIX", "vsm")

    @default_exchanges
    |> Enum.map(fn {key, default_name} ->
      env_key = "VSM_EXCHANGE_#{String.upcase(to_string(key))}"
      configured_name = System.get_env(env_key, String.replace(default_name, "vsm", env_prefix))
      {key, configured_name}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get the actual exchange name for a logical key.
  """
  def get_exchange_name(key) when is_atom(key) do
    config = load_config()
    Map.get(config, key, Map.get(@default_exchanges, key, "vsm.unknown"))
  end

  def get_exchange_name(key) when is_binary(key) do
    key
    |> String.to_existing_atom()
    |> get_exchange_name()
  rescue
    # Return as-is if not a known atom
    ArgumentError -> key
  end

  @doc """
  Get the exchange type for a logical key.
  """
  def get_exchange_type(key) when is_atom(key) do
    Map.get(@exchange_types, key, :topic)
  end

  @doc """
  Get all configured exchanges with their types.
  """
  def all_exchanges do
    config = load_config()

    @exchange_types
    |> Enum.map(fn {key, type} ->
      {Map.get(config, key), type}
    end)
  end

  @doc """
  Generate agent-specific exchange names.
  """
  def agent_exchange(agent_id, type) do
    prefix = System.get_env("VSM_ENV_PREFIX", "vsm")
    "#{prefix}.s1.#{agent_id}.#{type}"
  end

  @doc """
  Generate swarm-specific exchange names.
  """
  def swarm_exchange(specialist) do
    prefix = System.get_env("VSM_ENV_PREFIX", "vsm")
    "#{prefix}.swarm.#{specialist}"
  end
end
