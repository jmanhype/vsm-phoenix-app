defmodule VsmPhoenix.Infrastructure.AMQPRoutes do
  @moduledoc """
  Route mapping and queue naming conventions for the VSM system.
  Provides consistent queue naming across all VSM subsystems.
  """

  @queue_mappings %{
    # System queues
    system5_policy: "vsm.system5.policy",
    system5_commands: "vsm.system5.commands",
    system4_intelligence: "vsm.system4.intelligence",
    system4_commands: "vsm.system4.commands",
    system3_control: "vsm.system3.control",
    system3_commands: "vsm.system3.commands",
    system2_coordination: "vsm.system2.coordination",
    system2_commands: "vsm.system2.commands",
    system1_operations: "vsm.system1.operations",
    system1_commands: "vsm.system1.commands",

    # Audit queues
    audit_responses: "vsm.audit.responses"
  }

  @doc """
  Get the actual queue name for a logical key.
  """
  def get_queue_name(key, opts \\ []) when is_atom(key) do
    case Map.get(@queue_mappings, key) do
      nil ->
        # Check if it's a dynamic queue pattern
        build_dynamic_queue_name(key, opts)

      queue_name ->
        # Apply environment prefix if configured
        apply_env_prefix(queue_name)
    end
  end

  @doc """
  Build routing key patterns for topic exchanges.
  """
  def build_routing_key(pattern, vars \\ %{}) do
    Enum.reduce(vars, pattern, fn {key, value}, acc ->
      String.replace(acc, "{#{key}}", to_string(value))
    end)
  end

  @doc """
  Generate agent-specific queue names.
  """
  def agent_queue(agent_id, queue_type) do
    prefix = System.get_env("VSM_ENV_PREFIX", "vsm")
    "#{prefix}.s1.#{agent_id}.#{queue_type}"
  end

  @doc """
  Generate swarm-specific queue names.
  """
  def swarm_queue(specialist) do
    prefix = System.get_env("VSM_ENV_PREFIX", "vsm")
    "#{prefix}.swarm.#{specialist}"
  end

  # Private Functions

  defp build_dynamic_queue_name(key, opts) do
    cond do
      opts[:agent_id] && opts[:type] ->
        agent_queue(opts[:agent_id], opts[:type])

      opts[:specialist] ->
        swarm_queue(opts[:specialist])

      true ->
        # Default to the key as string with prefix
        apply_env_prefix("vsm.#{key}")
    end
  end

  defp apply_env_prefix(queue_name) do
    env_prefix = System.get_env("VSM_ENV_PREFIX", "vsm")
    String.replace(queue_name, "vsm", env_prefix)
  end
end
