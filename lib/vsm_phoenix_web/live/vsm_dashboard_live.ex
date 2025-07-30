defmodule VsmPhoenixWeb.VSMDashboardLive do
  @moduledoc """
  LiveView Dashboard for VSM System Monitoring
  
  Provides real-time visualization of:
  - System 5 policy and viability metrics
  - System 4 intelligence and adaptation status
  - System 3 resource allocation and control
  - System 2 coordination effectiveness
  - System 1 operational contexts
  """
  
  use VsmPhoenixWeb, :live_view
  require Logger
  
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System1.Operations
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to VSM system updates
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:health")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:metrics")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:coordination")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:policy")
      
      # Schedule periodic updates
      :timer.send_interval(5000, self(), :update_dashboard)
    end
    
    socket = 
      socket
      |> assign(:page_title, "VSM System Dashboard")
      |> assign(:system_status, :loading)
      |> assign(:queen_metrics, %{})
      |> assign(:intelligence_status, %{})
      |> assign(:control_metrics, %{})
      |> assign(:coordination_status, %{})
      |> assign(:operations_metrics, %{})
      |> assign(:viability_score, 0.0)
      |> assign(:alerts, [])
      |> assign(:system_topology, generate_system_topology())
      |> load_initial_data()
    
    # Send immediate update
    if connected?(socket), do: send(self(), :update_dashboard)
    
    {:ok, socket}
  end
  
  @impl true
  def handle_info(:update_dashboard, socket) do
    socket = 
      socket
      |> update_system_metrics()
      |> update_viability_score()
      |> check_system_alerts()
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:health_report, context, health}, socket) do
    Logger.debug("Dashboard: Received health report from #{context}")
    # Update context health and trigger metrics refresh
    socket = 
      socket
      |> update_context_health(context, health)
      |> update_system_metrics()
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:operation_complete, context, operation, result}, socket) do
    Logger.debug("Dashboard: Operation complete in #{context}: #{operation}")
    # Update operation metrics
    socket = 
      socket
      |> update_operation_metrics(context, operation, result)
      |> update_system_metrics()
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:policy_update, policy_type, policy_data}, socket) do
    Logger.info("Dashboard: Policy update received - #{policy_type}")
    # Show policy update alert
    alert = %{
      id: :rand.uniform(10000),
      type: :info,
      message: "Policy updated: #{policy_type}",
      timestamp: DateTime.utc_now()
    }
    
    socket = 
      socket
      |> update(:alerts, fn alerts -> [alert | Enum.take(alerts, 9)] end)
      |> update_system_metrics()
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:viability_update, viability_metrics}, socket) do
    Logger.info("Dashboard: Received viability update - #{inspect(viability_metrics)}")
    
    # Update the viability score
    socket = assign(socket, :viability_score, viability_metrics.system_health)
    
    # Trigger a full metrics refresh to get the latest values from all systems
    socket = update_system_metrics(socket)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:vsm_update, system, data}, socket) do
    Logger.debug("Dashboard: VSM update from #{system}")
    # Handle generic VSM updates
    socket = update_system_metrics(socket)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("refresh_system", _params, socket) do
    socket = load_initial_data(socket)
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("clear_alerts", _params, socket) do
    socket = assign(socket, :alerts, [])
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("trigger_adaptation", _params, socket) do
    Logger.info("Dashboard: Triggering adaptation through System 4")
    
    # Trigger adaptation in System 4
    challenge = %{
      type: :manual_trigger,
      urgency: :medium,
      scope: :system_wide
    }
    
    # Generate proposal and log it
    proposal = Intelligence.generate_adaptation_proposal(challenge)
    Logger.info("Dashboard: Generated adaptation proposal: #{inspect(proposal.id)}")
    
    # Send proposal to Queen for approval
    Queen.approve_adaptation(proposal)
    
    alert = %{
      id: :rand.uniform(10000),
      type: :success,
      message: "Adaptation triggered - Proposal ID: #{proposal.id}",
      timestamp: DateTime.utc_now()
    }
    
    socket = update(socket, :alerts, fn alerts -> [alert | Enum.take(alerts, 9)] end)
    
    # Trigger immediate dashboard update
    send(self(), :update_dashboard)
    
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <!-- Header -->
      <div class="bg-gray-800 shadow-lg">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="h-8 w-8 bg-blue-600 rounded-lg flex items-center justify-center">
                  <span class="text-sm font-bold">VSM</span>
                </div>
              </div>
              <div class="ml-4">
                <h1 class="text-2xl font-bold">Viable Systems Model Dashboard</h1>
                <p class="text-gray-400">Real-time system monitoring and control</p>
              </div>
            </div>
            
            <!-- System Status -->
            <div class="flex items-center space-x-4">
              <div class="flex items-center">
                <div class={[
                  "h-3 w-3 rounded-full mr-2",
                  system_status_color(@system_status)
                ]}></div>
                <span class="text-sm font-medium">
                  <%= system_status_text(@system_status) %>
                </span>
              </div>
              
              <!-- Viability Score -->
              <div class="bg-gray-700 rounded-lg px-4 py-2">
                <div class="text-xs text-gray-400">Viability Score</div>
                <div class={[
                  "text-lg font-bold",
                  viability_color(@viability_score)
                ]}>
                  <%= :erlang.float_to_binary(@viability_score * 100, [decimals: 1]) %>%
                </div>
              </div>
              
              <button 
                phx-click="refresh_system"
                class="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
              >
                Refresh
              </button>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Alerts -->
      <%= if length(@alerts) > 0 do %>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="bg-gray-800 rounded-lg p-4">
            <div class="flex justify-between items-center mb-3">
              <h3 class="text-lg font-semibold">System Alerts</h3>
              <button 
                phx-click="clear_alerts"
                class="text-sm text-gray-400 hover:text-white"
              >
                Clear All
              </button>
            </div>
            <div class="space-y-2">
              <%= for alert <- @alerts do %>
                <div class={[
                  "flex items-center p-3 rounded border-l-4",
                  alert_classes(alert.type)
                ]}>
                  <div class="flex-1">
                    <p class="text-sm"><%= alert.message %></p>
                    <p class="text-xs text-gray-400">
                      <%= relative_time(alert.timestamp) %>
                    </p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Main Dashboard -->
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          
          <!-- System 5 - Queen -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-purple-400">System 5 - Queen</h2>
              <div class="text-2xl">👑</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Policy Coherence</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@queen_metrics, :policy_coherence, 0.95)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Identity Preservation</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@queen_metrics, :coherence, 0.92)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Strategic Alignment</span>
                <span class="font-mono text-blue-400">
                  <%= format_percentage(Map.get(@queen_metrics, :strategic_alignment, 0.89)) %>
                </span>
              </div>
              
              <div class="mt-4 p-3 bg-gray-700 rounded">
                <div class="text-sm text-gray-400 mb-1">Active Policies</div>
                <div class="text-sm">
                  <%= for policy <- Map.get(@queen_metrics, :active_policies, ["governance", "adaptation", "resource"]) do %>
                    <span class="inline-block bg-purple-600 rounded px-2 py-1 text-xs mr-1 mb-1">
                      <%= policy %>
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          
          <!-- System 4 - Intelligence -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-blue-400">System 4 - Intelligence</h2>
              <div class="text-2xl">🧠</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Environmental Scan</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@intelligence_status, :scan_coverage, 0.87)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Adaptation Readiness</span>
                <span class="font-mono text-yellow-400">
                  <%= format_percentage(Map.get(@intelligence_status, :adaptation_readiness, 0.91)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Innovation Index</span>
                <span class="font-mono text-blue-400">
                  <%= format_percentage(Map.get(@intelligence_status, :innovation_capacity, 0.74)) %>
                </span>
              </div>
              
              <div class="mt-4">
                <button 
                  phx-click="trigger_adaptation"
                  class="w-full bg-blue-600 hover:bg-blue-700 py-2 rounded text-sm font-medium transition-colors"
                >
                  Trigger Adaptation
                </button>
              </div>
            </div>
          </div>
          
          <!-- System 3 - Control -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-green-400">System 3 - Control</h2>
              <div class="text-2xl">⚙️</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Resource Efficiency</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@control_metrics, :efficiency, 0.83)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Utilization</span>
                <span class="font-mono text-yellow-400">
                  <%= format_percentage(Map.get(@control_metrics, :utilization, 0.76)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Active Allocations</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@control_metrics, :active_allocations, 12) %>
                </span>
              </div>
              
              <!-- Resource bars -->
              <div class="mt-4 space-y-2">
                <% resources = Map.get(@control_metrics, :resources, %{compute: 0.72, memory: 0.68, network: 0.45, storage: 0.91}) %>
              <%= for {resource, usage} <- [{"CPU", Map.get(resources, :compute, 0.72)}, {"Memory", Map.get(resources, :memory, 0.68)}, {"Network", Map.get(resources, :network, 0.45)}, {"Storage", Map.get(resources, :storage, 0.91)}] do %>
                  <div>
                    <div class="flex justify-between text-sm mb-1">
                      <span class="text-gray-400"><%= resource %></span>
                      <span class="text-gray-300"><%= format_percentage(usage) %></span>
                    </div>
                    <div class="w-full bg-gray-700 rounded-full h-2">
                      <div class={[
                        "h-2 rounded-full transition-all duration-300",
                        resource_bar_color(usage)
                      ]} style={"width: #{usage * 100}%"}></div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
          
          <!-- System 2 - Coordinator -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-yellow-400">System 2 - Coordinator</h2>
              <div class="text-2xl">🔄</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Coordination Effectiveness</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@coordination_status, :effectiveness, 0.94)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Message Flows</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@coordination_status, :active_flows, 8) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Synchronization Level</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@coordination_status, :synchronization_level, 0.96)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Oscillation Risks</span>
                <span class={[
                  "font-mono",
                  if(length(Map.get(@coordination_status, :oscillation_risks, [])) > 0, do: "text-red-400", else: "text-green-400")
                ]}>
                  <%= length(Map.get(@coordination_status, :oscillation_risks, [])) %>
                </span>
              </div>
            </div>
          </div>
          
          <!-- System 1 - Operations -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-orange-400">System 1 - Operations</h2>
              <div class="text-2xl">🔧</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Success Rate</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@operations_metrics, :success_rate, 0.97)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Orders Processed</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@operations_metrics, :orders_processed, 1247) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Customer Satisfaction</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@operations_metrics, :customer_satisfaction, 0.93)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Inventory Accuracy</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@operations_metrics, :inventory_accuracy, 0.98)) %>
                </span>
              </div>
            </div>
          </div>
          
          <!-- System Topology Visualization -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-gray-300">System Topology</h2>
              <div class="text-2xl">🏗️</div>
            </div>
            
            <div class="space-y-4">
              <!-- SVG visualization would go here -->
              <div class="bg-gray-700 rounded-lg p-4 h-64 flex items-center justify-center">
                <div class="text-center">
                  <div class="text-4xl mb-2">🌐</div>
                  <p class="text-gray-400 text-sm">
                    VSM Recursive<br/>
                    Network Topology
                  </p>
                  <div class="mt-4 grid grid-cols-2 gap-2 text-xs">
                    <%= for {system, status} <- @system_topology do %>
                      <div class="flex items-center">
                        <div class={[
                          "w-2 h-2 rounded-full mr-2",
                          if(status == :active, do: "bg-green-500", else: "bg-red-500")
                        ]}></div>
                        <span class="text-gray-400"><%= system %></span>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Private Functions
  
  defp load_initial_data(socket) do
    socket
    |> assign(:system_status, :active)
    |> update_system_metrics()
    |> update_viability_score()
  end
  
  defp update_system_metrics(socket) do
    # Direct calls - no fallbacks, fail fast
    queen_metrics = Queen.get_identity_metrics()
    intelligence_status = Intelligence.get_system_health()
    control_metrics = Control.get_resource_metrics()
    coordination_status = Coordinator.get_coordination_status()
    operations_metrics = GenServer.call(:operations_context, :get_metrics)
    
    socket
    |> assign(:queen_metrics, queen_metrics)
    |> assign(:intelligence_status, intelligence_status)
    |> assign(:control_metrics, control_metrics)
    |> assign(:coordination_status, coordination_status)
    |> assign(:operations_metrics, operations_metrics)
  end
  
  defp update_viability_score(socket) do
    # Direct call - fail fast
    viability = Queen.evaluate_viability()
    assign(socket, :viability_score, viability.system_health)
  end
  
  defp check_system_alerts(socket) do
    # Check for system issues and generate alerts
    alerts = []
    
    # Check viability
    alerts = if socket.assigns.viability_score < 0.7 do
      alert = %{
        id: :rand.uniform(10000),
        type: :warning,
        message: "System viability below threshold",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
    
    # Update alerts if there are new ones
    if length(alerts) > 0 do
      current_alerts = socket.assigns.alerts
      new_alerts = alerts ++ current_alerts
      assign(socket, :alerts, Enum.take(new_alerts, 10))
    else
      socket
    end
  end
  
  defp update_context_health(socket, context, health) do
    # Update context-specific health metrics
    Logger.debug("Updating health for context: #{context}")
    
    # Update operations metrics if it's from System 1
    if context in [:operations_context, :supply_chain, :customer_service, :production] do
      # Handle both number and map formats for health
      health_score = case health do
        %{score: score} -> score
        score when is_number(score) -> score
        _ -> 0.95
      end
      
      operations_metrics = Map.merge(socket.assigns.operations_metrics, %{
        health: health_score,
        last_update: DateTime.utc_now()
      })
      
      assign(socket, :operations_metrics, operations_metrics)
    else
      socket
    end
  end
  
  defp update_operation_metrics(socket, context, operation, result) do
    # Update operation metrics based on context
    Logger.debug("Updating metrics for operation: #{operation} in #{context}")
    
    if context == :operations_context do
      operations_metrics = socket.assigns.operations_metrics
      
      # Update relevant metrics based on operation type
      updated_metrics = case operation do
        :process_order ->
          %{operations_metrics | 
            orders_processed: (operations_metrics[:orders_processed] || 0) + 1,
            success_rate: calculate_new_success_rate(operations_metrics, result)
          }
        
        :inventory_update ->
          %{operations_metrics | 
            inventory_accuracy: result[:accuracy] || operations_metrics[:inventory_accuracy]
          }
        
        :customer_feedback ->
          %{operations_metrics | 
            customer_satisfaction: result[:satisfaction] || operations_metrics[:customer_satisfaction]
          }
        
        _ -> operations_metrics
      end
      
      assign(socket, :operations_metrics, updated_metrics)
    else
      socket
    end
  end
  
  defp calculate_new_success_rate(metrics, result) do
    if result[:success] do
      current_rate = metrics[:success_rate] || 0.95
      # Weighted average favoring recent results
      current_rate * 0.95 + 1.0 * 0.05
    else
      current_rate = metrics[:success_rate] || 0.95
      current_rate * 0.95
    end
  end
  
  defp generate_system_topology do
    [
      {"System 5", :active},
      {"System 4", :active},
      {"System 3", :active},
      {"System 2", :active},
      {"System 1", :active}
    ]
  end
  
  
  defp system_status_color(:active), do: "bg-green-500"
  defp system_status_color(:warning), do: "bg-yellow-500"
  defp system_status_color(:error), do: "bg-red-500"
  defp system_status_color(_), do: "bg-gray-500"
  
  defp system_status_text(:active), do: "System Active"
  defp system_status_text(:warning), do: "System Warning"
  defp system_status_text(:error), do: "System Error"
  defp system_status_text(_), do: "System Unknown"
  
  defp viability_color(score) when score >= 0.8, do: "text-green-400"
  defp viability_color(score) when score >= 0.6, do: "text-yellow-400"
  defp viability_color(_), do: "text-red-400"
  
  defp alert_classes(:info), do: "bg-blue-900 border-blue-500"
  defp alert_classes(:success), do: "bg-green-900 border-green-500"
  defp alert_classes(:warning), do: "bg-yellow-900 border-yellow-500"
  defp alert_classes(:error), do: "bg-red-900 border-red-500"
  
  defp resource_bar_color(usage) when usage < 0.6, do: "bg-green-500"
  defp resource_bar_color(usage) when usage < 0.8, do: "bg-yellow-500"
  defp resource_bar_color(_), do: "bg-red-500"
  
  defp format_percentage(value) when is_float(value) do
    "#{:erlang.float_to_binary(value * 100, [decimals: 1])}%"
  end
  
  defp format_percentage(value) when is_integer(value) do
    "#{value * 100}%"
  end
  
  defp format_percentage(_), do: "N/A"
  
  defp relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
end