defmodule VsmPhoenixWeb.ResilienceDashboardLive do
  @moduledoc """
  Live dashboard for monitoring resilience patterns in VSM Phoenix.

  Displays real-time metrics for:
  - Circuit breakers
  - Bulkhead pools
  - AMQP connections
  - HTTP clients
  - Overall system health
  """

  use VsmPhoenixWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to metrics updates
      VsmPhoenix.Resilience.MetricsReporter.subscribe()

      # Request immediate metrics
      VsmPhoenix.Resilience.MetricsReporter.broadcast_now()
    end

    {:ok,
     assign(socket,
       circuit_breakers: %{},
       bulkheads: %{},
       amqp_connection: %{},
       http_clients: %{},
       health_status: %{},
       last_update: nil
     )}
  end

  @impl true
  def handle_info({:resilience_metrics, metrics}, socket) do
    {:noreply,
     assign(socket,
       circuit_breakers: metrics.circuit_breakers,
       bulkheads: metrics.bulkheads,
       amqp_connection: metrics.amqp_connection,
       http_clients: metrics.http_clients,
       health_status: metrics.health_status,
       last_update: metrics.timestamp
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resilience-dashboard">
      <h1 class="text-3xl font-bold mb-6">VSM Resilience Dashboard</h1>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Health Status -->
        <div class="card">
          <h2 class="card-title">System Health</h2>
          <div class="health-status">
            <%= render_health_status(@health_status) %>
          </div>
        </div>
        
        <!-- AMQP Connection -->
        <div class="card">
          <h2 class="card-title">AMQP Connection</h2>
          <div class="amqp-status">
            <%= render_amqp_status(@amqp_connection) %>
          </div>
        </div>
        
        <!-- Circuit Breakers -->
        <div class="card">
          <h2 class="card-title">Circuit Breakers</h2>
          <div class="circuit-breakers">
            <%= for {name, breaker} <- @circuit_breakers do %>
              <%= render_circuit_breaker(name, breaker) %>
            <% end %>
          </div>
        </div>
        
        <!-- Bulkheads -->
        <div class="card">
          <h2 class="card-title">Bulkhead Pools</h2>
          <div class="bulkheads">
            <%= for {name, bulkhead} <- @bulkheads do %>
              <%= render_bulkhead(name, bulkhead) %>
            <% end %>
          </div>
        </div>
        
        <!-- HTTP Clients -->
        <div class="card col-span-full">
          <h2 class="card-title">HTTP Clients</h2>
          <div class="http-clients grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for {name, client} <- @http_clients do %>
              <%= render_http_client(name, client) %>
            <% end %>
          </div>
        </div>
      </div>
      
      <div class="mt-4 text-sm text-gray-500">
        Last updated: <%= format_timestamp(@last_update) %>
      </div>
    </div>

    <style>
      .resilience-dashboard {
        padding: 2rem;
      }
      
      .card {
        background: white;
        border-radius: 0.5rem;
        padding: 1.5rem;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
      }
      
      .card-title {
        font-size: 1.25rem;
        font-weight: 600;
        margin-bottom: 1rem;
      }
      
      .status-indicator {
        display: inline-block;
        width: 0.75rem;
        height: 0.75rem;
        border-radius: 50%;
        margin-right: 0.5rem;
      }
      
      .status-healthy { background-color: #10b981; }
      .status-degraded { background-color: #f59e0b; }
      .status-unhealthy { background-color: #ef4444; }
      .status-closed { background-color: #10b981; }
      .status-open { background-color: #ef4444; }
      .status-half_open { background-color: #f59e0b; }
      
      .metric-row {
        display: flex;
        justify-content: space-between;
        padding: 0.25rem 0;
      }
      
      .progress-bar {
        width: 100%;
        height: 0.5rem;
        background-color: #e5e7eb;
        border-radius: 0.25rem;
        overflow: hidden;
        margin-top: 0.5rem;
      }
      
      .progress-fill {
        height: 100%;
        background-color: #3b82f6;
        transition: width 0.3s ease;
      }
      
      .progress-fill.high {
        background-color: #ef4444;
      }
      
      .progress-fill.medium {
        background-color: #f59e0b;
      }
    </style>
    """
  end

  defp render_health_status(%{status: status} = health) do
    assigns = %{health: health, status: status}

    ~H"""
    <div class="health-overview">
      <div class="metric-row">
        <span>Overall Status</span>
        <span>
          <span class={"status-indicator status-#{@status}"}></span>
          <%= String.capitalize(to_string(@status)) %>
        </span>
      </div>
      <%= if @health[:components] do %>
        <div class="mt-4">
          <h3 class="font-semibold mb-2">Components</h3>
          <%= for {name, component} <- @health.components do %>
            <div class="metric-row text-sm">
              <span><%= name %></span>
              <span>
                <span class={"status-indicator status-#{component.status}"}></span>
                <%= String.capitalize(to_string(component.status)) %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_health_status(_), do: "No health data available"

  defp render_amqp_status(%{status: status} = amqp) do
    assigns = %{amqp: amqp, status: status}

    ~H"""
    <div class="amqp-metrics">
      <div class="metric-row">
        <span>Connection Status</span>
        <span>
          <span class={"status-indicator status-#{status_to_health(@status)}"}></span>
          <%= String.capitalize(to_string(@status)) %>
        </span>
      </div>
      <%= if @amqp[:connection_attempts] do %>
        <div class="metric-row">
          <span>Connection Attempts</span>
          <span><%= @amqp.connection_attempts %></span>
        </div>
        <div class="metric-row">
          <span>Successful Connections</span>
          <span><%= @amqp.successful_connections %></span>
        </div>
        <div class="metric-row">
          <span>Failed Connections</span>
          <span><%= @amqp.failed_connections %></span>
        </div>
        <div class="metric-row">
          <span>Circuit Breaker Trips</span>
          <span><%= @amqp.circuit_breaker_trips %></span>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_amqp_status(_), do: "No AMQP data available"

  defp render_circuit_breaker(name, %{available: true} = breaker) do
    assigns = %{name: name, breaker: breaker}

    ~H"""
    <div class="mb-4">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="metric-row">
        <span>State</span>
        <span>
          <span class={"status-indicator status-#{@breaker.state}"}></span>
          <%= String.capitalize(to_string(@breaker.state)) %>
        </span>
      </div>
      <div class="metric-row text-sm">
        <span>Failures</span>
        <span><%= @breaker.failure_count %></span>
      </div>
    </div>
    """
  end

  defp render_circuit_breaker(name, _) do
    assigns = %{name: name}

    ~H"""
    <div class="mb-4">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="text-sm text-gray-500">Unavailable</div>
    </div>
    """
  end

  defp render_bulkhead(name, %{status: :available} = bulkhead) do
    assigns = %{name: name, bulkhead: bulkhead}
    utilization = bulkhead.utilization_percent

    utilization_class =
      cond do
        utilization > 90 -> "high"
        utilization > 70 -> "medium"
        true -> ""
      end

    ~H"""
    <div class="mb-4">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="metric-row">
        <span>Active/Total</span>
        <span><%= @bulkhead.busy %>/<%= @bulkhead.max_concurrent %></span>
      </div>
      <div class="metric-row">
        <span>Waiting</span>
        <span><%= @bulkhead.waiting %></span>
      </div>
      <div class="metric-row text-sm">
        <span>Rejected</span>
        <span><%= @bulkhead.rejected_checkouts %></span>
      </div>
      <div class="progress-bar">
        <div class={"progress-fill #{utilization_class}"} 
             style={"width: #{@bulkhead.utilization_percent}%"}></div>
      </div>
      <div class="text-xs text-gray-500 mt-1">
        <%= @bulkhead.utilization_percent %>% utilization
      </div>
    </div>
    """
  end

  defp render_bulkhead(name, _) do
    assigns = %{name: name}

    ~H"""
    <div class="mb-4">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="text-sm text-gray-500">Unavailable</div>
    </div>
    """
  end

  defp render_http_client(name, %{status: :available} = client) do
    assigns = %{name: name, client: client}

    ~H"""
    <div class="http-client-card">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="grid grid-cols-2 gap-2 mt-2">
        <div class="metric-row">
          <span>Total Requests</span>
          <span><%= @client.total_requests %></span>
        </div>
        <div class="metric-row">
          <span>Successful</span>
          <span><%= @client.successful_requests %></span>
        </div>
        <div class="metric-row">
          <span>Failed</span>
          <span><%= @client.failed_requests %></span>
        </div>
        <div class="metric-row">
          <span>Timeouts</span>
          <span><%= @client.timeouts %></span>
        </div>
      </div>
      <%= if @client[:circuit_breaker] do %>
        <div class="mt-2 text-sm">
          Circuit Breaker: 
          <span class={"status-indicator status-#{@client.circuit_breaker.state}"}></span>
          <%= String.capitalize(to_string(@client.circuit_breaker.state)) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_http_client(name, _) do
    assigns = %{name: name}

    ~H"""
    <div class="http-client-card">
      <h3 class="font-semibold"><%= @name %></h3>
      <div class="text-sm text-gray-500">Unavailable</div>
    </div>
    """
  end

  defp status_to_health(:connected), do: :healthy
  defp status_to_health(:circuit_open), do: :unhealthy
  defp status_to_health(:disconnected), do: :unhealthy
  defp status_to_health(_), do: :degraded

  defp format_timestamp(nil), do: "Never"

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S UTC")
  end
end
