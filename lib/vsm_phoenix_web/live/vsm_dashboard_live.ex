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
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:algedonic")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm.registry.events")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:amqp")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety")
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:quantum")
      
      # Schedule periodic updates with different intervals
      :timer.send_interval(5000, self(), :update_dashboard)
      :timer.send_interval(1000, self(), :update_latency_metrics)
      :timer.send_interval(100, self(), :update_realtime_flows)  # Very fast for animations
      :timer.send_interval(2000, self(), :update_quantum_states)
      :timer.send_interval(500, self(), :update_variety_flow)
    
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
      |> assign(:algedonic_signals, [])
      |> assign(:system_topology, generate_system_topology())
      |> assign(:s1_agents, [])
      |> assign(:audit_results, %{})
      |> assign(:algedonic_pulse_rates, %{})
      |> assign(:latency_metrics, %{avg: 0, p95: 0, p99: 0})
      |> assign(:variety_flow, generate_initial_variety_flow())
      |> assign(:quantum_states, %{})
      |> assign(:flow_animations, %{})
      |> assign(:topology_data, generate_topology_data())
      |> assign(:heatmap_data, generate_initial_heatmap())
      |> assign(:quantum_superpositions, [])
      |> assign(:entanglement_pairs, [])
      |> assign(:coherence_levels, %{})
      |> assign(:wave_functions, %{})
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
      |> update_s1_agents()
      |> update_audit_results()
      |> check_system_alerts()
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(:update_latency_metrics, socket) do
    socket = update_latency_metrics(socket)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(:update_realtime_flows, socket) do
    socket = update_realtime_flow_animations(socket)
    {:noreply, push_event(socket, "update_flow_viz", %{flows: socket.assigns.flow_animations})}
  end
  
  @impl true
  def handle_info(:update_quantum_states, socket) do
    socket = update_quantum_visualization(socket)
    {:noreply, push_event(socket, "update_quantum_viz", %{states: socket.assigns.quantum_states})}
  end
  
  @impl true
  def handle_info(:update_variety_flow, socket) do
    socket = update_variety_flow_data(socket)
    {:noreply, push_event(socket, "update_variety_heatmap", %{data: socket.assigns.heatmap_data})}
  end
  
  @impl true
  def handle_info({:variety_absorption, level, amount}, socket) do
    Logger.debug("Variety absorption at level #{level}: #{amount}")
    socket = update_variety_metrics(socket, level, amount)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:quantum_collapse, state_id, result}, socket) do
    Logger.info("Quantum state collapsed: #{state_id} -> #{result}")
    socket = handle_quantum_collapse(socket, state_id, result)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:agent_registered, agent_id, pid, metadata}, socket) do
    Logger.debug("Dashboard: S1 agent registered - #{agent_id}")
    socket = update_s1_agents(socket)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:agent_unregistered, agent_id}, socket) do
    Logger.debug("Dashboard: S1 agent unregistered - #{agent_id}")
    socket = update_s1_agents(socket)
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:agent_crashed, agent_id, reason}, socket) do
    Logger.warning("Dashboard: S1 agent crashed - #{agent_id}: #{inspect(reason)}")
    
    alert = %{
      id: System.unique_integer([:positive]),
      type: :error,
      message: "S1 Agent crashed: #{agent_id}",
      severity: :warning,
      timestamp: DateTime.utc_now()
    }
    
    socket = 
      socket
      |> assign(:alerts, [alert | socket.assigns.alerts] |> Enum.take(10))
      |> update_s1_agents()
    
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
  def handle_info({:algedonic_signal, signal}, socket) do
    Logger.info("Dashboard: Received algedonic signal - #{signal.signal_type} (delta: #{signal.delta})")
    IO.inspect(signal, label: "🎯 DASHBOARD RECEIVED SIGNAL")
    
    # Add signal to recent list (keep last 20)
    new_signals = [signal | socket.assigns.algedonic_signals] |> Enum.take(20)
    
    # Add alert for significant signals
    socket = if abs(signal.delta) > 0.2 do
      alert = %{
        id: System.unique_integer([:positive]),
        type: signal.signal_type,
        message: "#{String.capitalize(to_string(signal.signal_type))} signal from #{signal.context}: viability delta #{Float.round(signal.delta, 2)}",
        severity: if(signal.signal_type == :pain, do: :warning, else: :info),
        timestamp: DateTime.utc_now()
      }
      assign(socket, :alerts, [alert | socket.assigns.alerts] |> Enum.take(10))
    else
      socket
    end
    
    socket = assign(socket, :algedonic_signals, new_signals)
    
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
  def handle_event("toggle_visualization", %{"viz_type" => viz_type}, socket) do
    Logger.info("Toggling visualization: #{viz_type}")
    {:noreply, push_event(socket, "toggle_viz", %{type: viz_type})}
  end
  
  @impl true
  def handle_event("observe_quantum_state", %{"state_id" => state_id}, socket) do
    # Quantum observation causes wavefunction collapse
    collapsed_state = collapse_quantum_state(state_id)
    socket = update_quantum_after_observation(socket, state_id, collapsed_state)
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
        <div class="px-4 sm:px-6 lg:px-8">
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
        <div class="px-4 sm:px-6 lg:px-8 py-4">
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
      <div class="px-4 sm:px-6 lg:px-8 py-8">
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
          
          <!-- S1 Agent Registry -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-cyan-400">S1 Agent Registry</h2>
              <div class="text-2xl">🤖</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Active Agents</span>
                <span class="font-mono text-green-400">
                  <%= length(@s1_agents) %>
                </span>
              </div>
              
              <div class="max-h-48 overflow-y-auto">
                <%= if length(@s1_agents) > 0 do %>
                  <div class="space-y-1">
                    <%= for agent <- Enum.take(@s1_agents, 10) do %>
                      <div class="flex items-center justify-between text-sm p-2 bg-gray-700 rounded">
                        <div class="flex items-center">
                          <div class={[
                            "w-2 h-2 rounded-full mr-2",
                            if(agent.alive, do: "bg-green-500", else: "bg-red-500")
                          ]}></div>
                          <span class="text-gray-300"><%= agent.agent_id %></span>
                        </div>
                        <div class="text-xs text-gray-400">
                          <%= Map.get(agent.metadata, :zone, "N/A") %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                  <%= if length(@s1_agents) > 10 do %>
                    <p class="text-xs text-gray-400 mt-2">... and <%= length(@s1_agents) - 10 %> more</p>
                  <% end %>
                <% else %>
                  <p class="text-center text-gray-400">No S1 agents registered</p>
                <% end %>
              </div>
            </div>
          </div>
          
          <!-- Audit Results Panel -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-emerald-400">S3 Audit Results</h2>
              <div class="text-2xl">📊</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Last Audit</span>
                <span class="font-mono text-blue-400">
                  <%= format_time_ago(Map.get(@audit_results, :timestamp, DateTime.utc_now())) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Efficiency</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@audit_results, :efficiency, 0.85)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Waste Detected</span>
                <span class={[
                  "font-mono",
                  if(Map.get(@audit_results, :waste, 0.05) > 0.1, do: "text-red-400", else: "text-green-400")
                ]}>
                  <%= format_percentage(Map.get(@audit_results, :waste, 0.05)) %>
                </span>
              </div>
              
              <div class="mt-2">
                <p class="text-xs text-gray-400 mb-1">Recommendations:</p>
                <div class="space-y-1">
                  <%= for rec <- Enum.take(Map.get(@audit_results, :recommendations, []), 3) do %>
                    <p class="text-xs text-gray-300 pl-2">• <%= rec %></p>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Algedonic Pulse Rates -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-purple-400">Algedonic Pulse Rates</h2>
              <div class="text-2xl">💓</div>
            </div>
            
            <div class="space-y-4">
              <%= for {agent_id, pulse_rate} <- Enum.take(@algedonic_pulse_rates, 5) do %>
                <div class="flex justify-between items-center">
                  <span class="text-gray-400 text-sm"><%= agent_id %></span>
                  <div class="flex items-center">
                    <div class={[
                      "w-16 h-2 bg-gray-700 rounded-full mr-2",
                      "relative overflow-hidden"
                    ]}>
                      <div class={[
                        "h-full rounded-full",
                        pulse_color(pulse_rate)
                      ]} style={"width: #{Enum.min([pulse_rate * 10, 100])}%"}></div>
                    </div>
                    <span class="font-mono text-xs"><%= Float.round(pulse_rate, 1) %>Hz</span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Command/Response Latency -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-amber-400">Command Latency</h2>
              <div class="text-2xl">⚡</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Average (T-90ms)</span>
                <span class={[
                  "font-mono",
                  latency_color(@latency_metrics.avg)
                ]}>
                  <%= @latency_metrics.avg %>ms
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">P95</span>
                <span class="font-mono text-blue-400">
                  <%= @latency_metrics.p95 %>ms
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">P99</span>
                <span class="font-mono text-gray-400">
                  <%= @latency_metrics.p99 %>ms
                </span>
              </div>
              
              <div class="mt-2">
                <div class="w-full bg-gray-700 rounded-full h-2">
                  <div class={[
                    "h-2 rounded-full transition-all duration-300",
                    if(@latency_metrics.avg <= 90, do: "bg-green-500", else: "bg-red-500")
                  ]} style={"width: #{Enum.min([@latency_metrics.avg / 150 * 100, 100])}%"}></div>
                </div>
                <p class="text-xs text-gray-400 mt-1">Target: &lt; 90ms</p>
              </div>
            </div>
          </div>
          
          <!-- Algedonic Signals -->
          <div class="bg-gray-800 rounded-lg p-6 lg:col-span-2">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-indigo-400">Algedonic Signals</h2>
              <div class="text-2xl">📡</div>
            </div>
            
            <div class="space-y-4">
              <%= if length(@algedonic_signals) > 0 do %>
                <div class="space-y-2 max-h-64 overflow-y-auto">
                  <%= for signal <- @algedonic_signals do %>
                    <div class={[
                      "flex items-center p-3 rounded border-l-4",
                      algedonic_signal_classes(signal.signal_type)
                    ]}>
                      <div class="flex-1">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center space-x-2">
                            <span class="text-2xl">
                              <%= if signal.signal_type == :pain, do: "😣", else: "😊" %>
                            </span>
                            <div>
                              <p class="text-sm font-medium">
                                <%= String.capitalize(to_string(signal.signal_type)) %> Signal from <%= signal.context %>
                              </p>
                              <p class="text-xs text-gray-400">
                                Delta: <%= Float.round(signal.delta, 3) %> | Health: <%= Float.round(signal.health, 2) %>
                              </p>
                            </div>
                          </div>
                          <span class="text-xs text-gray-400">
                            <%= signal.timestamp %>
                          </span>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-8 text-gray-400">
                  <div class="text-3xl mb-2">🔇</div>
                  <p>No algedonic signals received yet</p>
                  <p class="text-sm mt-1">Signals will appear here when system viability changes</p>
                </div>
              <% end %>
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
  
  defp generate_topology_data do
    %{
      nodes: [
        %{id: "s5", label: "System 5 - Queen", level: 5, x: 400, y: 50, color: "#9333ea"},
        %{id: "s4", label: "System 4 - Intelligence", level: 4, x: 400, y: 150, color: "#3b82f6"},
        %{id: "s3", label: "System 3 - Control", level: 3, x: 400, y: 250, color: "#10b981"},
        %{id: "s3*", label: "System 3* - Audit", level: 3, x: 550, y: 250, color: "#14b8a6"},
        %{id: "s2", label: "System 2 - Coordination", level: 2, x: 400, y: 350, color: "#eab308"},
        %{id: "s1a", label: "S1 - Operations", level: 1, x: 200, y: 450, color: "#f97316"},
        %{id: "s1b", label: "S1 - Supply Chain", level: 1, x: 400, y: 450, color: "#f97316"},
        %{id: "s1c", label: "S1 - Customer Service", level: 1, x: 600, y: 450, color: "#f97316"}
      ],
      edges: [
        %{source: "s5", target: "s4", type: "command", strength: 0.8},
        %{source: "s4", target: "s5", type: "feedback", strength: 0.6},
        %{source: "s4", target: "s3", type: "intelligence", strength: 0.7},
        %{source: "s3", target: "s2", type: "control", strength: 0.9},
        %{source: "s3", target: "s3*", type: "audit_request", strength: 0.5},
        %{source: "s3*", target: "s1a", type: "audit", strength: 0.4},
        %{source: "s3*", target: "s1b", type: "audit", strength: 0.4},
        %{source: "s2", target: "s1a", type: "coordination", strength: 0.8},
        %{source: "s2", target: "s1b", type: "coordination", strength: 0.8},
        %{source: "s2", target: "s1c", type: "coordination", strength: 0.8},
        %{source: "s1a", target: "s3", type: "algedonic", strength: 0.3},
        %{source: "s1b", target: "s3", type: "algedonic", strength: 0.3},
        %{source: "s1c", target: "s3", type: "algedonic", strength: 0.3}
      ]
    }
  end
  
  defp generate_initial_variety_flow do
    %{
      s5_to_s4: :rand.uniform() * 100,
      s4_to_s3: :rand.uniform() * 150,
      s3_to_s2: :rand.uniform() * 200,
      s2_to_s1: :rand.uniform() * 300,
      environmental: :rand.uniform() * 500,
      absorbed: %{
        s5: :rand.uniform() * 20,
        s4: :rand.uniform() * 30,
        s3: :rand.uniform() * 40,
        s2: :rand.uniform() * 50,
        s1: :rand.uniform() * 100
      }
    }
  end
  
  defp generate_initial_heatmap do
    # Generate variety absorption heatmap data
    for level <- 1..5, hour <- 0..23 do
      %{
        level: level,
        hour: hour,
        variety: :rand.uniform() * 100,
        absorbed: :rand.uniform() * 80,
        efficiency: 0.7 + :rand.uniform() * 0.3
      }
    end
  end
  
  defp update_realtime_flow_animations(socket) do
    # Update flow animations for real-time visualization
    flows = %{
      timestamp: System.system_time(:millisecond),
      particles: generate_flow_particles(),
      intensities: calculate_flow_intensities(socket.assigns),
      pulses: generate_algedonic_pulses(socket.assigns.algedonic_signals)
    }
    
    assign(socket, :flow_animations, flows)
  end
  
  defp update_quantum_visualization(socket) do
    # Update quantum state visualizations
    quantum_states = %{
      superpositions: generate_quantum_superpositions(),
      entanglements: detect_entanglements(socket.assigns.s1_agents),
      coherence: calculate_system_coherence(socket.assigns),
      wave_functions: generate_wave_functions()
    }
    
    socket
    |> assign(:quantum_states, quantum_states)
    |> assign(:quantum_superpositions, quantum_states.superpositions)
    |> assign(:entanglement_pairs, quantum_states.entanglements)
    |> assign(:coherence_levels, %{system: quantum_states.coherence})
  end
  
  defp update_variety_flow_data(socket) do
    # Update variety flow heatmap
    new_heatmap = update_heatmap_with_current_data(socket.assigns.heatmap_data)
    assign(socket, :heatmap_data, new_heatmap)
  end
  
  defp update_variety_metrics(socket, level, amount) do
    variety_flow = socket.assigns.variety_flow
    absorbed = Map.update!(variety_flow.absorbed, String.to_atom("s#{level}"), &(&1 + amount))
    
    assign(socket, :variety_flow, %{variety_flow | absorbed: absorbed})
  end
  
  defp handle_quantum_collapse(socket, state_id, result) do
    # Update quantum states after collapse
    quantum_states = socket.assigns.quantum_states
    superpositions = Enum.reject(quantum_states.superpositions, &(&1.id == state_id))
    
    alert = %{
      id: System.unique_integer([:positive]),
      type: :info,
      message: "Quantum state #{state_id} collapsed to: #{result}",
      severity: :info,
      timestamp: DateTime.utc_now()
    }
    
    socket
    |> assign(:quantum_superpositions, superpositions)
    |> update(:alerts, fn alerts -> [alert | Enum.take(alerts, 9)] end)
  end
  
  defp generate_flow_particles do
    # Generate particles for flow animation
    for _ <- 1..20 do
      %{
        id: System.unique_integer([:positive]),
        x: :rand.uniform() * 800,
        y: :rand.uniform() * 500,
        vx: (:rand.uniform() - 0.5) * 2,
        vy: (:rand.uniform() - 0.5) * 2,
        level: Enum.random(1..5),
        type: Enum.random([:information, :command, :feedback, :algedonic])
      }
    end
  end
  
  defp calculate_flow_intensities(assigns) do
    %{
      s5_s4: assigns.queen_metrics[:policy_coherence] || 0.8,
      s4_s3: assigns.intelligence_status[:scan_coverage] || 0.7,
      s3_s2: assigns.control_metrics[:efficiency] || 0.6,
      s2_s1: assigns.coordination_status[:effectiveness] || 0.9
    }
  end
  
  defp generate_algedonic_pulses(signals) do
    # Generate pulse animations for recent algedonic signals
    Enum.take(signals, 3)
    |> Enum.map(fn signal ->
      %{
        origin: signal.context,
        intensity: abs(signal.delta),
        type: signal.signal_type,
        timestamp: signal.timestamp,
        propagation: :rand.uniform() * 100
      }
    end)
  end
  
  defp generate_quantum_superpositions do
    # Generate quantum superposition states for visualization
    for i <- 1..5 do
      %{
        id: "quantum_#{i}",
        states: ["state_a", "state_b"],
        amplitudes: [:rand.uniform(), :rand.uniform()],
        phase: :rand.uniform() * 2 * :math.pi(),
        coherence: 0.7 + :rand.uniform() * 0.3,
        entangled_with: if(:rand.uniform() > 0.5, do: "quantum_#{Enum.random(1..5)}", else: nil)
      }
    end
  end
  
  defp detect_entanglements(agents) do
    # Detect quantum entanglements between S1 agents
    agents
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [a1, a2] -> 
        if :rand.uniform() > 0.6 do
          %{agent1: a1.agent_id, agent2: a2.agent_id, strength: :rand.uniform()}
        else
          nil
        end
      _ -> nil
    end)
    |> Enum.filter(& &1)
  end
  
  defp calculate_system_coherence(assigns) do
    # Calculate overall quantum coherence
    viability = assigns.viability_score
    coordination = assigns.coordination_status[:effectiveness] || 0.9
    
    (viability + coordination) / 2 * (0.8 + :rand.uniform() * 0.2)
  end
  
  defp generate_wave_functions do
    # Generate wave function visualizations
    for level <- 1..5 do
      %{
        level: level,
        amplitude: :math.sin(:rand.uniform() * 2 * :math.pi()),
        frequency: 0.5 + :rand.uniform() * 2,
        phase: :rand.uniform() * 2 * :math.pi(),
        decay: 0.95 + :rand.uniform() * 0.05
      }
    end
  end
  
  defp update_heatmap_with_current_data(current_heatmap) do
    # Update heatmap with new variety flow data
    current_hour = DateTime.utc_now().hour
    
    Enum.map(current_heatmap, fn cell ->
      if cell.hour == current_hour do
        %{cell | 
          variety: cell.variety * 0.9 + :rand.uniform() * 10,
          absorbed: cell.absorbed * 0.9 + :rand.uniform() * 8
        }
      else
        cell
      end
    end)
  end
  
  defp collapse_quantum_state(state_id) do
    # Simulate quantum state collapse
    Enum.random(["collapsed_a", "collapsed_b", "collapsed_mixed"])
  end
  
  defp update_quantum_after_observation(socket, state_id, collapsed_state) do
    quantum_states = socket.assigns.quantum_states
    
    # Remove from superpositions
    new_superpositions = Enum.reject(quantum_states.superpositions, &(&1.id == state_id))
    
    # Break any entanglements
    new_entanglements = Enum.reject(quantum_states.entanglements, fn e ->
      e.agent1 == state_id || e.agent2 == state_id
    end)
    
    socket
    |> assign(:quantum_superpositions, new_superpositions)
    |> assign(:entanglement_pairs, new_entanglements)
    |> put_flash(:info, "Quantum state #{state_id} observed and collapsed to #{collapsed_state}")
  end
  
  defp update_s1_agents(socket) do
    agents = VsmPhoenix.System1.Registry.list_agents()
    
    # Calculate algedonic pulse rates per agent
    pulse_rates = Enum.map(agents, fn agent ->
      # Simulated pulse rate based on agent activity
      base_rate = :rand.uniform() * 5.0 + 2.0
      adjusted_rate = if agent.alive, do: base_rate, else: 0.0
      {agent.agent_id, adjusted_rate}
    end)
    |> Enum.into(%{})
    
    socket
    |> assign(:s1_agents, agents)
    |> assign(:algedonic_pulse_rates, pulse_rates)
  end
  
  defp update_audit_results(socket) do
    # Get latest audit results from S3
    audit = Control.audit_resource_usage()
    
    audit_summary = %{
      timestamp: DateTime.utc_now(),
      efficiency: Map.get(audit.efficiency_analysis || %{}, :current, 0.85),
      waste: Map.get(audit.waste_analysis || %{}, :resource_waste, 0.05),
      recommendations: audit.recommendations || []
    }
    
    assign(socket, :audit_results, audit_summary)
  end
  
  defp update_latency_metrics(socket) do
    # In production, this would track real command/response latencies
    # For now, simulate with reasonable values
    metrics = %{
      avg: 45 + :rand.uniform(30),  # 45-75ms average
      p95: 80 + :rand.uniform(40),  # 80-120ms p95
      p99: 100 + :rand.uniform(50)  # 100-150ms p99
    }
    
    assign(socket, :latency_metrics, metrics)
  end
  
  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
  
  defp pulse_color(rate) when rate < 3.0, do: "bg-green-500"
  defp pulse_color(rate) when rate < 6.0, do: "bg-yellow-500"
  defp pulse_color(_), do: "bg-red-500"
  
  defp pulse_color_hex(rate) when rate < 3.0, do: "#10b981"
  defp pulse_color_hex(rate) when rate < 6.0, do: "#eab308"
  defp pulse_color_hex(_), do: "#ef4444"
  
  defp latency_color(latency) when latency <= 90, do: "text-green-400"
  defp latency_color(latency) when latency <= 120, do: "text-yellow-400"
  defp latency_color(_), do: "text-red-400"
  
  
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
  defp alert_classes(:pain), do: "bg-red-900 border-red-500"
  defp alert_classes(:pleasure), do: "bg-green-900 border-green-500"
  defp alert_classes(_), do: "bg-gray-900 border-gray-500"
  
  defp algedonic_signal_classes(:pain), do: "bg-red-900 border-red-500"
  defp algedonic_signal_classes(:pleasure), do: "bg-green-900 border-green-500"
  defp algedonic_signal_classes(_), do: "bg-gray-900 border-gray-500"
  
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