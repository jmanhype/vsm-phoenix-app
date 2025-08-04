defmodule VsmPhoenixWeb.Router do
  use VsmPhoenixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VsmPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
  end

  # Enhanced API pipeline with authentication and error handling
  pipeline :api_v2 do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug VsmPhoenixWeb.Plugs.APIAuthentication
    plug VsmPhoenixWeb.Plugs.RateLimiter
    plug VsmPhoenixWeb.Plugs.RequestValidation
  end

  # Authentication pipeline for protected routes
  pipeline :auth do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug VsmPhoenixWeb.Plugs.APIAuthentication
    plug VsmPhoenixWeb.Plugs.RateLimiter
  end

  # Public API pipeline (no authentication required)
  pipeline :public_api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug VsmPhoenixWeb.Plugs.RateLimiter, limits: %{limit: 100, window: 3600}
  end

  # MCP pipeline - skips CSRF protection for MCP endpoints
  pipeline :mcp do
    plug :accepts, ["json", "application/msgpack"]
    plug :fetch_session
    plug :put_secure_browser_headers
  end

  scope "/", VsmPhoenixWeb do
    pipe_through :browser

    live "/", VSMDashboardLive, :index
    live "/dashboard", VSMDashboardLive, :index
    live "/audit", AuditLive, :index
    
    # Event Processing Web Interface
    get "/events", EventsController, :index
    get "/events/dashboard", EventsController, :dashboard
  end

  # VSM API routes
  scope "/api/vsm", VsmPhoenixWeb do
    pipe_through :api

    # Existing VSM system routes
    get "/status", VSMController, :status
    get "/system/:level", VSMController, :system_status
    post "/system5/decision", VSMController, :queen_decision
    post "/algedonic/:signal", VSMController, :algedonic_signal
    
    # NEW: S1 Agent Management Routes (The Missing HTTP Bridge!)
    post "/agents", AgentController, :create           # Spawn agent
    get "/agents", AgentController, :index             # List all agents  
    get "/agents/:id", AgentController, :show          # Get agent details
    post "/agents/:id/command", AgentController, :execute_command  # Execute command
    delete "/agents/:id", AgentController, :delete     # Terminate agent
    
    # NEW: S3 Audit Bypass Route
    post "/audit/bypass", AgentController, :audit_bypass  # Direct S1 inspection
    
    # NEW: Telegram Integration Routes
    post "/telegram/webhook/:agent_id", TelegramController, :webhook  # Telegram webhook
    get "/telegram/health", TelegramController, :health  # Telegram health check
    post "/telegram/set_webhook", TelegramController, :set_webhook  # Set webhook (for testing)
    
    # Event Processing API Routes
    post "/events/inject", EventsController, :inject_event
    get "/events/streams/:stream_id/stats", EventsController, :stream_stats
    get "/events/analytics", EventsController, :analytics_data
    get "/events/insights", EventsController, :pattern_insights
  end

  # Phase 2 API routes - Advanced VSM capabilities with enhanced security
  scope "/api/v2", VsmPhoenixWeb do
    pipe_through :api_v2

    # Chaos Engineering Routes - Enhanced API
    post "/chaos/experiments", ChaosController, :create_experiment
    get "/chaos/experiments/:id", ChaosController, :get_experiment
    delete "/chaos/experiments/:id", ChaosController, :stop_experiment
    post "/chaos/faults/:type", ChaosController, :inject_fault_by_type
    post "/chaos/scenarios", ChaosController, :run_scenario
    
    # Legacy chaos routes
    post "/chaos/inject", ChaosController, :inject_fault
    get "/chaos/faults", ChaosController, :list_faults
    delete "/chaos/faults/:id", ChaosController, :remove_fault
    get "/chaos/metrics", ChaosController, :metrics
    post "/chaos/cascade", ChaosController, :simulate_cascade
    get "/chaos/resilience", ChaosController, :resilience_analysis

    # Quantum Logic Routes - Enhanced API
    post "/quantum/superposition", QuantumController, :create_superposition
    post "/quantum/entangle", QuantumController, :entangle_states
    post "/quantum/measure", QuantumController, :measure_state
    post "/quantum/tunnel", QuantumController, :quantum_tunnel
    get "/quantum/states", QuantumController, :list_states
    get "/quantum/states/:id", QuantumController, :get_state
    delete "/quantum/states/:id", QuantumController, :destroy_state
    get "/quantum/metrics", QuantumController, :metrics

    # Emergent Intelligence Routes - Enhanced API
    post "/emergent/swarm", EmergentController, :init_swarm
    get "/emergent/patterns", EmergentController, :detect_patterns
    post "/emergent/learn", EmergentController, :collective_learn
    get "/emergent/consciousness", EmergentController, :get_consciousness_level
    post "/emergent/evolve", EmergentController, :evolve_step
    get "/emergent/metrics", EmergentController, :get_swarm_metrics
    
    # Legacy emergent routes
    post "/emergent/swarm/init", EmergentController, :init_swarm
    post "/emergent/pattern/detect", EmergentController, :detect_patterns
    get "/emergent/behaviors", EmergentController, :list_behaviors
    get "/emergent/intelligence", EmergentController, :intelligence_metrics

    # Meta-VSM Routes - Enhanced API
    post "/meta-vsm/spawn", MetaVsmController, :spawn_meta_vsm
    get "/meta-vsm/hierarchy", MetaVsmController, :get_hierarchy
    get "/meta-vsm/lineage", MetaVsmController, :get_lineage
    post "/meta-vsm/mutate", MetaVsmController, :evolve_genetics
    post "/meta-vsm/merge", MetaVsmController, :merge_vsms
    get "/meta-vsm/fractals", MetaVsmController, :fractal_analysis
    delete "/meta-vsm/:id", MetaVsmController, :destroy_meta_vsm
    
    # Legacy meta-vsm routes
    post "/meta-vsm/evolve", MetaVsmController, :evolve_genetics

    # Algedonic System Routes - Enhanced API
    post "/algedonic/pain", AlgedonicController, :send_pain_signal
    post "/algedonic/pleasure", AlgedonicController, :send_pleasure_signal
    get "/algedonic/autonomic", AlgedonicController, :get_autonomic_responses
    post "/algedonic/bypass", AlgedonicController, :algedonic_bypass
    get "/algedonic/metrics", AlgedonicController, :list_signals
    
    # Legacy algedonic routes
    get "/algedonic/signals", AlgedonicController, :list_signals
    get "/algedonic/responses", AlgedonicController, :list_autonomic_responses
    
    # Machine Learning Engine Routes - Neural Networks & AI
    scope "/ml", VsmPhoenixWeb do
      # Anomaly Detection
      post "/anomaly/detect", MLController, :detect_anomaly
      post "/anomaly/batch-detect", MLController, :batch_detect_anomalies
      post "/anomaly/train", MLController, :train_anomaly_detector
      
      # Pattern Recognition
      post "/pattern/recognize", MLController, :recognize_pattern
      post "/pattern/train/:model_type", MLController, :train_pattern_recognizer
      get "/pattern/library", MLController, :get_pattern_library
      
      # Predictive Analytics
      post "/predict/time-series", MLController, :predict_time_series
      post "/predict/regression", MLController, :predict_regression
      post "/predict/classification", MLController, :predict_classification
      post "/predict/ensemble", MLController, :ensemble_predict
      post "/predict/train", MLController, :train_predictor
      
      # Neural Network Training
      post "/neural/train", MLController, :train_neural_network
      post "/neural/hyperparameter-tuning", MLController, :hyperparameter_tuning
      get "/neural/training-history", MLController, :get_training_history
      
      # Model Storage
      post "/models", MLController, :save_model
      get "/models/:model_name", MLController, :load_model
      get "/models", MLController, :list_models
      delete "/models/:model_name", MLController, :delete_model
      
      # Performance Monitoring
      get "/metrics/system", MLController, :get_system_metrics
      get "/metrics/models/:model_name", MLController, :get_model_metrics
      get "/metrics/report", MLController, :get_performance_report
      
      # GPU Management
      get "/gpu/status", MLController, :get_gpu_status
      post "/gpu/cleanup", MLController, :cleanup_gpu_memory
      
      # VSM Integration
      post "/vsm/analyze/:system_id", MLController, :analyze_vsm_system
      get "/vsm/recommendations/:system_id", MLController, :get_ml_recommendations
      get "/vsm/health-assessment", MLController, :get_system_health_assessment
    end
  end

  # Fallback API routes for backward compatibility (using original api pipeline)
  scope "/api", VsmPhoenixWeb do
    pipe_through :api

    # Chaos Engineering Routes (legacy endpoints)
    post "/chaos/inject", ChaosController, :inject_fault
    get "/chaos/faults", ChaosController, :list_faults
    delete "/chaos/faults/:id", ChaosController, :remove_fault
    get "/chaos/metrics", ChaosController, :metrics
    post "/chaos/cascade", ChaosController, :simulate_cascade
    get "/chaos/resilience", ChaosController, :resilience_analysis

    # Quantum Logic Routes (legacy endpoints)
    post "/quantum/superposition", QuantumController, :create_superposition
    post "/quantum/entangle", QuantumController, :entangle_states  
    post "/quantum/measure", QuantumController, :measure_state
    post "/quantum/tunnel", QuantumController, :quantum_tunnel
    get "/quantum/states", QuantumController, :list_states
    get "/quantum/metrics", QuantumController, :metrics

    # Emergent Intelligence Routes (legacy endpoints)
    post "/emergent/swarm/init", EmergentController, :init_swarm
    post "/emergent/pattern/detect", EmergentController, :detect_patterns
    get "/emergent/behaviors", EmergentController, :list_behaviors
    post "/emergent/learn", EmergentController, :collective_learn
    get "/emergent/intelligence", EmergentController, :intelligence_metrics

    # Meta-VSM Routes (legacy endpoints)
    post "/meta-vsm/spawn", MetaVsmController, :spawn_meta_vsm
    get "/meta-vsm/hierarchy", MetaVsmController, :get_hierarchy
    post "/meta-vsm/evolve", MetaVsmController, :evolve_genetics
    get "/meta-vsm/fractals", MetaVsmController, :fractal_analysis
    delete "/meta-vsm/:id", MetaVsmController, :destroy_meta_vsm

    # Algedonic System Routes (legacy endpoints)
    post "/algedonic/pain", AlgedonicController, :send_pain_signal
    post "/algedonic/pleasure", AlgedonicController, :send_pleasure_signal
    get "/algedonic/signals", AlgedonicController, :list_signals
    get "/algedonic/responses", AlgedonicController, :list_autonomic_responses
  end

  # MCP routes - Handled by MCPController
  # JSON-RPC requests are processed and forwarded to appropriate VSM systems
  scope "/mcp", VsmPhoenixWeb do
    pipe_through :mcp

    # Forward all MCP requests to the Hermes Plug which handles:
    # - JSON-RPC protocol
    # - Tool discovery and execution  
    # - Streaming responses
    # - Error handling
    # Use MCPController instead of direct Hermes forwarding
    # Hermes.Server.Transport.StreamableHTTP.Plug requires specific setup
    get "/", MCPController, :health
    post "/", MCPController, :handle
    get "/health", MCPController, :health
    post "/rpc", MCPController, :handle
    options "/*path", MCPController, :options
  end

  # Other scopes may use custom stacks.
  # scope "/api", VsmPhoenixWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vsm_phoenix, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VsmPhoenixWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end