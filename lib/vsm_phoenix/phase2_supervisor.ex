defmodule VsmPhoenix.Phase2Supervisor do
  @moduledoc """
  Supervisor for Phase 2 Advanced VSM Cybernetics components.
  Manages GoldRush pattern engine, enhanced LLM integration,
  Telegram NLU, and AMQP security protocol components.
  """
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Load Phase 2 configuration
    phase2_config = Application.get_env(:vsm_phoenix, :phase2, [])
    
    children = build_children(phase2_config)
    
    # Log startup
    Logger.info("""
    🚀 Starting Phase 2 Advanced VSM Cybernetics
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Components:
    #{Enum.map_join(children, "\n", fn {module, _, _, _, _} -> "  ✓ #{inspect(module)}" end)}
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp build_children(config) do
    children = []

    # GoldRush Pattern Engine
    children = if get_in(config, [:goldrush, :enabled]) do
      children ++ [
        # Pattern Engine Core
        {VsmPhoenix.Goldrush.PatternEngine, 
         [
           max_patterns: get_in(config, [:goldrush, :max_patterns]) || 1000,
           persistence_path: get_in(config, [:goldrush, :persistence_path]) || "priv/goldrush"
         ]},
        
        # Pattern Storage (ETS-based with persistence)
        {VsmPhoenix.Goldrush.PatternStorage, []},
        
        # Event Processor
        {VsmPhoenix.Goldrush.EventProcessor,
         [
           retention_hours: get_in(config, [:goldrush, :event_retention_hours]) || 168
         ]},
        
        # Aggregation Engine
        {VsmPhoenix.Goldrush.AggregationEngine,
         [
           windows: get_in(config, [:goldrush, :aggregation_windows]) || ["1m", "5m", "15m", "1h"]
         ]},
        
        # Alert Manager
        {VsmPhoenix.Goldrush.AlertManager,
         [
           cooldown_seconds: get_in(config, [:goldrush, :alert_cooldown_seconds]) || 300
         ]}
      ]
    else
      children
    end

    # Telegram NLU Integration
    children = if get_in(config, [:telegram_nlu, :enabled]) do
      children ++ [
        # NLU Core Engine
        {VsmPhoenix.Telegram.NLUIntegration,
         [
           provider: get_in(config, [:telegram_nlu, :provider]) || :openai,
           model: get_in(config, [:telegram_nlu, :model]) || "gpt-4-turbo",
           confidence_threshold: get_in(config, [:telegram_nlu, :confidence_threshold]) || 0.75
         ]},
        
        # Intent Classifier
        {VsmPhoenix.Telegram.IntentClassifier,
         [
           categories: get_in(config, [:telegram_nlu, :intent_categories]) || []
         ]},
        
        # Entity Extractor
        {VsmPhoenix.Telegram.EntityExtractor,
         [
           extractors: get_in(config, [:telegram_nlu, :entity_extractors]) || []
         ]},
        
        # Context Manager
        {VsmPhoenix.Telegram.ContextManager,
         [
           max_context_messages: get_in(config, [:telegram_nlu, :max_context_messages]) || 10
         ]}
      ]
    else
      children
    end

    # AMQP Security Protocol
    children = if get_in(config, [:amqp_security, :enabled]) do
      children ++ [
        # Security Protocol Handler
        {VsmPhoenix.AMQP.SecurityProtocol,
         [
           encryption_algorithm: get_in(config, [:amqp_security, :encryption_algorithm]) || "aes-256-gcm",
           signature_algorithm: get_in(config, [:amqp_security, :signature_algorithm]) || "ed25519"
         ]},
        
        # Key Manager (handles rotation)
        {VsmPhoenix.AMQP.KeyManager,
         [
           rotation_hours: get_in(config, [:amqp_security, :key_rotation_hours]) || 24
         ]},
        
        # Access Control
        {VsmPhoenix.AMQP.AccessControl,
         [
           enabled: get_in(config, [:amqp_security, :access_control_enabled]) || true
         ]},
        
        # Message Auditor
        {VsmPhoenix.AMQP.MessageAuditor,
         [
           audit_all: get_in(config, [:amqp_security, :audit_all_messages]) || true
         ]},
        
        # Rate Limiter
        {VsmPhoenix.AMQP.RateLimiter,
         [
           limits: get_in(config, [:amqp_security, :rate_limiting]) || %{}
         ]}
      ]
    else
      children
    end

    # Enhanced LLM Integration
    children = if get_in(config, [:llm_enhanced, :variety_amplification]) do
      children ++ [
        # LLM Variety Amplifier
        {VsmPhoenix.LLM.VarietyAmplifier,
         [
           mode: get_in(config, [:llm_enhanced, :cost_optimization_mode]) || "balanced"
         ]},
        
        # Intelligent Analyzer
        {VsmPhoenix.LLM.IntelligentAnalyzer,
         [
           predictive: get_in(config, [:llm_enhanced, :predictive_adaptation]) || true
         ]},
        
        # Context Optimizer
        {VsmPhoenix.LLM.ContextOptimizer,
         [
           enabled: get_in(config, [:llm_enhanced, :context_window_optimization]) || true
         ]},
        
        # Fallback Handler
        {VsmPhoenix.LLM.FallbackHandler,
         [
           strategies: get_in(config, [:llm_enhanced, :fallback_strategies]) || []
         ]}
      ]
    else
      children
    end

    # Integration Components
    children = if get_in(config, [:integration, :event_correlation_enabled]) do
      children ++ [
        # Event Correlator
        {VsmPhoenix.Integration.EventCorrelator, []},
        
        # Cross-System Pattern Detector
        {VsmPhoenix.Integration.CrossSystemPatterns,
         [
           enabled: get_in(config, [:integration, :cross_system_patterns]) || true
         ]},
        
        # Distributed Decision Coordinator
        {VsmPhoenix.Integration.DistributedDecisionMaker,
         [
           consensus: get_in(config, [:integration, :consensus_protocol]) || "simple_majority"
         ]},
        
        # System Boundary Enforcer
        {VsmPhoenix.Integration.BoundaryEnforcer,
         [
           enabled: get_in(config, [:integration, :system_boundary_enforcement]) || true
         ]},
        
        # Telemetry Aggregator
        {VsmPhoenix.Integration.TelemetryAggregator,
         [
           enabled: get_in(config, [:integration, :telemetry_aggregation]) || true
         ]}
      ]
    else
      children
    end

    children
  end

  @doc """
  Starts a specific Phase 2 component dynamically.
  """
  def start_component(component, args \\ []) do
    Supervisor.start_child(__MODULE__, {component, args})
  end

  @doc """
  Stops a specific Phase 2 component.
  """
  def stop_component(component_id) do
    Supervisor.terminate_child(__MODULE__, component_id)
  end

  @doc """
  Gets the status of all Phase 2 components.
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, pid, type, modules} ->
      %{
        id: id,
        pid: pid,
        type: type,
        modules: modules,
        status: if(is_pid(pid) and Process.alive?(pid), do: :running, else: :stopped)
      }
    end)
  end

  @doc """
  Performs health check on all Phase 2 components.
  """
  def health_check do
    components = status()
    
    health_status = Enum.map(components, fn component ->
      health = if component.status == :running do
        # Try to call health check on the component if it implements it
        try do
          case component.id do
            VsmPhoenix.Goldrush.PatternEngine ->
              VsmPhoenix.Goldrush.PatternEngine.health_check()
            VsmPhoenix.Telegram.NLUIntegration ->
              VsmPhoenix.Telegram.NLUIntegration.health_check()
            VsmPhoenix.AMQP.SecurityProtocol ->
              VsmPhoenix.AMQP.SecurityProtocol.health_check()
            _ ->
              {:ok, :no_health_check}
          end
        rescue
          _ -> {:error, :health_check_failed}
        end
      else
        {:error, :not_running}
      end
      
      Map.put(component, :health, health)
    end)
    
    %{
      timestamp: DateTime.utc_now(),
      components: health_status,
      overall_health: calculate_overall_health(health_status)
    }
  end

  defp calculate_overall_health(health_status) do
    total = length(health_status)
    healthy = Enum.count(health_status, fn c -> 
      match?({:ok, _}, c.health) and c.status == :running 
    end)
    
    health_percentage = if total > 0, do: healthy / total * 100, else: 0
    
    cond do
      health_percentage == 100 -> :healthy
      health_percentage >= 80 -> :degraded
      health_percentage >= 50 -> :unhealthy
      true -> :critical
    end
  end
end