defmodule VsmPhoenix.Resilience.Config do
  @moduledoc """
  Configuration management for resilience patterns.
  
  Provides centralized configuration for circuit breakers and bulkheads
  across the VSM system.
  """
  
  @doc """
  Get circuit breaker configuration for a specific component.
  """
  def circuit_breaker_config(component) do
    base_config = %{
      failure_threshold: 5,
      success_threshold: 3,
      reset_timeout: 60_000,
      half_open_timeout: 30_000,
      window_size: 60_000
    }
    
    # Component-specific overrides
    case component do
      :llm_api ->
        Map.merge(base_config, %{
          failure_threshold: 3,      # More sensitive for expensive LLM calls
          reset_timeout: 120_000,    # Longer reset for API rate limits
          timeout: 30_000           # Longer timeout for LLM responses
        })
      
      :amqp_connection ->
        Map.merge(base_config, %{
          failure_threshold: 5,
          reset_timeout: 30_000,     # Faster recovery for messaging
          success_threshold: 2       # Quicker restoration
        })
      
      :external_api ->
        Map.merge(base_config, %{
          failure_threshold: 4,
          reset_timeout: 90_000
        })
      
      :database ->
        Map.merge(base_config, %{
          failure_threshold: 10,     # More tolerant for DB
          reset_timeout: 45_000
        })
      
      _ ->
        base_config
    end
  end
  
  @doc """
  Get bulkhead configuration for agent pools.
  """
  def bulkhead_config(pool_type) do
    base_config = %{
      size: 10,
      overflow: 5,
      timeout: 5000
    }
    
    case pool_type do
      :worker_agent ->
        Map.merge(base_config, %{
          size: 20,
          overflow: 10,
          timeout: 5000
        })
      
      :llm_worker ->
        Map.merge(base_config, %{
          size: 5,          # Limited for API rate limits
          overflow: 2,
          timeout: 30_000,  # Long timeout for LLM
          rate_limit: 10    # Requests per second
        })
      
      :sensor_agent ->
        Map.merge(base_config, %{
          size: 30,         # Many sensors
          overflow: 15,
          timeout: 3000     # Fast sensors
        })
      
      :api_agent ->
        Map.merge(base_config, %{
          size: 15,
          overflow: 5,
          timeout: 10_000,
          rate_limit: 20
        })
      
      :telegram_bot ->
        Map.merge(base_config, %{
          size: 3,          # Limited by Telegram rate limits
          overflow: 1,
          timeout: 10_000,
          rate_limit: 30    # Telegram limit
        })
      
      _ ->
        base_config
    end
  end
  
  @doc """
  Get timeout configuration for different operations.
  """
  def timeout_config(operation) do
    case operation do
      :llm_completion -> 30_000
      :amqp_publish -> 5_000
      :database_query -> 10_000
      :external_api -> 15_000
      :health_check -> 3_000
      _ -> 5_000
    end
  end
  
  @doc """
  Get backoff configuration for retries.
  """
  def backoff_config(service) do
    base_config = %{
      initial_delay: 1_000,
      max_delay: 60_000,
      multiplier: 2,
      randomization_factor: 0.1
    }
    
    case service do
      :llm_api ->
        Map.merge(base_config, %{
          initial_delay: 2_000,     # Start with longer delay
          max_delay: 120_000,       # Cap at 2 minutes
          multiplier: 3             # More aggressive backoff
        })
      
      :external_api ->
        Map.merge(base_config, %{
          initial_delay: 1_500,
          max_delay: 90_000
        })
      
      _ ->
        base_config
    end
  end
  
  @doc """
  Get health check configuration.
  """
  def health_check_config(component) do
    %{
      interval: 30_000,           # Check every 30 seconds
      timeout: 5_000,
      failure_threshold: 3,       # Mark unhealthy after 3 failures
      success_threshold: 2        # Mark healthy after 2 successes
    }
  end
end