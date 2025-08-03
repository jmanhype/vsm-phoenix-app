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