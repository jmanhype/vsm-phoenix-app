defmodule VsmPhoenix.Agents.AgentFactory do
  @moduledoc """
  Factory Pattern: Centralizes agent creation logic
  DRY: Eliminates duplicate agent initialization code
  Open/Closed: Easy to add new agent types without modifying existing code
  """
  
  use VsmPhoenix.Behaviors.Loggable, prefix: "🏭 AgentFactory:"
  
  # Agent type registry - easily extensible
  @agent_types %{
    telegram: VsmPhoenix.Agents.TelegramAgent,
    llm_worker: VsmPhoenix.Agents.LLMWorkerAgent,
    sensor: VsmPhoenix.Agents.SensorAgent,
    api: VsmPhoenix.Agents.ApiAgent
  }
  
  # DRY: Single agent creation interface
  def create_agent(type, config) do
    with {:ok, module} <- get_agent_module(type),
         {:ok, validated_config} <- validate_config(type, config),
         {:ok, enhanced_config} <- enhance_config(type, validated_config),
         {:ok, agent} <- spawn_agent(module, enhanced_config) do
      log_info("Created #{type} agent: #{agent.id}")
      {:ok, agent}
    else
      error ->
        log_error("Failed to create #{type} agent: #{inspect(error)}")
        error
    end
  end
  
  # DRY: Batch agent creation
  def create_agents(specs) when is_list(specs) do
    specs
    |> Enum.map(fn {type, config} -> 
      Task.async(fn -> create_agent(type, config) end)
    end)
    |> Enum.map(&Task.await/1)
  end
  
  # Agent module resolution
  defp get_agent_module(type) do
    case Map.get(@agent_types, type) do
      nil -> {:error, :unknown_agent_type}
      module -> {:ok, module}
    end
  end
  
  # DRY: Common configuration validation
  defp validate_config(:telegram, config) do
    required = [:bot_token, :id]
    validate_required_fields(config, required)
  end
  
  defp validate_config(:llm_worker, config) do
    required = [:id]
    validate_required_fields(config, required)
  end
  
  defp validate_config(_type, config) do
    {:ok, config}
  end
  
  defp validate_required_fields(config, required) do
    missing = Enum.filter(required, &(not Map.has_key?(config, &1)))
    
    case missing do
      [] -> {:ok, config}
      fields -> {:error, {:missing_fields, fields}}
    end
  end
  
  # DRY: Common configuration enhancements
  defp enhance_config(type, config) do
    config
    |> add_default_values(type)
    |> add_infrastructure_config()
    |> add_resilience_config()
    |> add_logging_config()
    |> (fn cfg -> {:ok, cfg} end).()
  end
  
  defp add_default_values(config, :telegram) do
    Map.merge(%{
      webhook_mode: false,
      authorized_chats: [],
      admin_chats: [],
      polling_timeout: 30
    }, config)
  end
  
  defp add_default_values(config, :llm_worker) do
    Map.merge(%{
      max_concurrent: 5,
      timeout: 30_000,
      api_provider: :anthropic
    }, config)
  end
  
  defp add_default_values(config, _type) do
    config
  end
  
  # DRY: Common infrastructure components
  defp add_infrastructure_config(config) do
    Map.merge(config, %{
      amqp_channel: get_amqp_channel(),
      ets_tables: setup_ets_tables(config.id),
      context_manager: setup_context_manager(config.id)
    })
  end
  
  defp add_resilience_config(config) do
    Map.merge(config, %{
      circuit_breaker: %{
        threshold: 5,
        timeout: 60_000
      },
      bulkhead: %{
        max_concurrent: 10
      },
      retry: %{
        max_attempts: 3,
        backoff: :exponential
      }
    })
  end
  
  defp add_logging_config(config) do
    Map.put(config, :log_prefix, "[#{config.id}]")
  end
  
  # Agent spawning
  defp spawn_agent(module, config) do
    case DynamicSupervisor.start_child(
      VsmPhoenix.System1.DynamicSupervisor,
      {module, config}
    ) do
      {:ok, pid} ->
        {:ok, %{
          id: config.id,
          pid: pid,
          type: config.type,
          config: config
        }}
      error ->
        error
    end
  end
  
  # Helper functions (would connect to actual infrastructure)
  defp get_amqp_channel do
    # VsmPhoenix.AMQP.ChannelPool.get_channel()
    :mock_channel
  end
  
  defp setup_ets_tables(agent_id) do
    # Create agent-specific ETS tables
    %{
      state: :"#{agent_id}_state",
      cache: :"#{agent_id}_cache",
      metrics: :"#{agent_id}_metrics"
    }
  end
  
  defp setup_context_manager(agent_id) do
    # VsmPhoenix.AMQP.ContextWindowManager.start_link(...)
    :"#{agent_id}_context"
  end
end