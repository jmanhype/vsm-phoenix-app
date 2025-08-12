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
      
      # Schedule periodic updates
      :timer.send_interval(5000, self(), :update_dashboard)
      :timer.send_interval(1000, self(), :update_latency_metrics)
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
      |> assign(:algedonic_signals, [])
      |> assign(:system_topology, generate_system_topology())
      |> assign(:s1_agents, [])
      |> assign(:audit_results, %{})
      |> assign(:algedonic_pulse_rates, %{})
      |> assign(:latency_metrics, %{avg: 0, p95: 0, p99: 0})
      |> assign(:test_message, "")
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
  def handle_event("send_test_message", %{"message" => message, "target_system" => target_system}, socket) do
    # Send the message to the variety calculator to generate real metrics
    system_atom = String.to_existing_atom(target_system)
    
    # Determine message type based on content to create variety
    msg_lower = String.downcase(message)
    message_type = cond do
      String.contains?(msg_lower, "order") or String.contains?(msg_lower, "buy") or String.contains?(msg_lower, "purchase") -> :order
      String.contains?(msg_lower, "alert") or String.contains?(msg_lower, "warning") or String.contains?(msg_lower, "error") -> :alert  
      String.contains?(msg_lower, "report") or String.contains?(msg_lower, "status") or String.contains?(msg_lower, "update") -> :report
      String.contains?(msg_lower, "policy") or String.contains?(msg_lower, "rule") or String.contains?(msg_lower, "govern") -> :policy
      String.contains?(msg_lower, "data") or String.contains?(msg_lower, "info") or String.contains?(msg_lower, "metric") -> :data
      true -> :general
    end
    
    # Record the message in the variety calculator
    VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(
      system_atom, 
      :inbound, 
      message_type
    )
    
    # Also generate an outbound response to create variety
    response_type = case message_type do
      :order -> :confirmation
      :alert -> :acknowledgment  
      :report -> :analysis
      :policy -> :compliance
      :data -> :processed
      _ -> :response
    end
    
    VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(
      system_atom,
      :outbound, 
      response_type
    )
    
    # Clear the input and refresh metrics
    socket = socket
    |> assign(:test_message, "")
    |> update_system_metrics()
    
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
                  <%= format_percentage(Map.get(@queen_metrics, :coherence, Map.get(@queen_metrics, :policy_coherence, 0.95))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Identity Preservation</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@queen_metrics, :identity_preservation, Map.get(@queen_metrics, :identity_coherence, 0.92))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Strategic Alignment</span>
                <span class="font-mono text-blue-400">
                  <%= format_percentage(Map.get(@queen_metrics, :strategic_alignment, Map.get(@queen_metrics, :strategic_coherence, 0.89))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Decision Consistency</span>
                <span class="font-mono text-blue-400">
                  <%= format_percentage(Map.get(@queen_metrics, :decision_consistency, Map.get(@queen_metrics, :decision_confidence, 0.90))) %>
                </span>
              </div>
              
              <div class="mt-4 p-3 bg-gray-700 rounded">
                <div class="text-sm text-gray-400 mb-1">Active Policies</div>
                <div class="text-sm">
                  <%= for policy <- Map.get(@queen_metrics, :active_policies, Map.get(@queen_metrics, :policies, ["governance", "adaptation", "resource"])) do %>
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
                  <%= format_percentage(Map.get(@intelligence_status, :scan_coverage, Map.get(@intelligence_status, :environmental_scanning, 0.87))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Adaptation Readiness</span>
                <span class="font-mono text-yellow-400">
                  <%= format_percentage(Map.get(@intelligence_status, :adaptation_readiness, Map.get(@intelligence_status, :variety_amplification, 0.91))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Innovation Index</span>
                <span class="font-mono text-blue-400">
                  <%= format_percentage(Map.get(@intelligence_status, :innovation_capacity, Map.get(@intelligence_status, :anomaly_detection, 0.74))) %>
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
                  <%= format_percentage(Map.get(@control_metrics, :efficiency, Map.get(@control_metrics, :resource_efficiency, 0.83))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Flow Utilization</span>
                <span class="font-mono text-yellow-400">
                  <%= format_percentage(Map.get(@control_metrics, :flow_utilization, Map.get(@control_metrics, :utilization, 0.76))) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Active Allocations</span>
                <span class="font-mono text-blue-400">
                  <%= map_size(Map.get(@control_metrics, :allocations, %{})) %>
                </span>
              </div>
              
              <!-- Resource bars -->
              <div class="mt-4 space-y-2">
                <% pools = Map.get(@control_metrics, :flow_pools, %{}) %>
              <%= for {resource, usage} <- [
                {"CPU", get_in(pools, [:compute, :allocated_capacity]) || 0.0}, 
                {"Memory", get_in(pools, [:memory, :allocated_capacity]) || 0.0}, 
                {"Network", get_in(pools, [:network, :allocated_capacity]) || 0.0}, 
                {"Storage", get_in(pools, [:storage, :allocated_capacity]) || 0.0}
              ] do %>
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
                <span class="text-gray-400">Message Volume</span>
                <span class="font-mono text-blue-400">
                  <%= Float.round(Map.get(@coordination_status, :message_rate, 0.0), 2) %>/s
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Routing Efficiency</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@coordination_status, :routing_efficiency, 1.0)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Sync Events</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@coordination_status, :sync_events_per_minute, 0) %>/min
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Conflict Resolution Rate</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@coordination_status, :conflict_resolution_rate, 1.0)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Flow Balance</span>
                <span class={[
                  "font-mono",
                  if(abs(Map.get(@coordination_status, :flow_balance_ratio, 1.0) - 1.0) > 0.2, do: "text-yellow-400", else: "text-green-400")
                ]}>
                  <%= Float.round(Map.get(@coordination_status, :flow_balance_ratio, 1.0), 2) %>
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
                <span class="text-gray-400">Activity Rate</span>
                <span class="font-mono text-green-400">
                  <%= Float.round(Map.get(@operations_metrics, :activity_rate, 0.0), 2) %>/s
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Success Ratio</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@operations_metrics, :success_ratio, 1.0)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Processing Latency</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@operations_metrics, :avg_latency, 0) %>ms
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Throughput</span>
                <span class="font-mono text-blue-400">
                  <%= Map.get(@operations_metrics, :throughput, 0) %> ops/min
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Error Rate</span>
                <span class="font-mono text-yellow-400">
                  <%= format_percentage(Map.get(@operations_metrics, :error_rate, 0.0)) %>
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
                <span class="text-gray-400">Resource Allocation Efficiency</span>
                <span class="font-mono text-green-400">
                  <%= format_percentage(Map.get(@audit_results, :efficiency, 0.85)) %>
                </span>
              </div>
              
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Resource Waste Ratio</span>
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
          
          <!-- Message Input for Testing Variety -->
          <div class="bg-gray-800 rounded-lg p-6 lg:col-span-2">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-cyan-400">Test Variety Metrics</h2>
              <div class="text-2xl">💬</div>
            </div>
            
            <form phx-submit="send_test_message" class="space-y-4">
              <div class="flex space-x-2">
                <input 
                  type="text" 
                  name="message" 
                  placeholder="Type a message to test variety calculation..." 
                  value={@test_message || ""}
                  class="flex-1 px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
                />
                <select name="target_system" class="px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-white focus:ring-2 focus:ring-cyan-500">
                  <option value="s1">S1 Operations</option>
                  <option value="s2">S2 Coordination</option>
                  <option value="s3">S3 Control</option>
                  <option value="s4">S4 Intelligence</option>
                  <option value="s5">S5 Policy</option>
                </select>
                <button 
                  type="submit" 
                  class="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 text-white rounded-md transition-colors"
                >
                  Send
                </button>
              </div>
              <div class="text-xs text-gray-400">
                Try different types of messages (orders, alerts, reports, etc.) to see variety metrics change in real-time!
              </div>
            </form>
          </div>
          
          <!-- Dynamic Metrics Section -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-green-400">Variety Engineering</h2>
              <div class="text-2xl">🔄</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Overall Diversity</span>
                <span class="font-mono text-green-400">
                  <%= Float.round(Map.get(@variety_metrics, :overall_diversity, 0.0), 3) %>
                </span>
              </div>
              
              <%= if Map.get(@variety_metrics, :variety_metrics) do %>
                <%= for {level, metrics} <- @variety_metrics.variety_metrics do %>
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400 text-sm">
                      <%= String.upcase(to_string(level)) %> Entropy
                    </span>
                    <span class="font-mono text-blue-400">
                      <%= 
                        entropy_value = case Map.get(metrics, :entropy, 0.0) do
                          %{input: input} when is_number(input) -> input
                          %{output: output} when is_number(output) -> output  
                          %{ratio: ratio} when is_number(ratio) -> ratio
                          value when is_number(value) -> value
                          _ -> 0.0
                        end
                        Float.round(entropy_value, 2)
                      %>
                    </span>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
          
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-yellow-400">Balance Monitor</h2>
              <div class="text-2xl">⚖️</div>
            </div>
            
            <div class="space-y-4">
              <%= if Map.get(@balance_status, :balance_status) do %>
                <%= for {level, status} <- @balance_status.balance_status do %>
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400 text-sm">
                      <%= String.upcase(to_string(level)) %>
                    </span>
                    <span class={[
                      "font-mono text-sm px-2 py-1 rounded",
                      case status do
                        :balanced -> "bg-green-600 text-green-100"
                        :overloaded -> "bg-red-600 text-red-100"  
                        :underloaded -> "bg-yellow-600 text-yellow-100"
                        _ -> "bg-gray-600 text-gray-100"
                      end
                    ]}>
                      <%= status %>
                    </span>
                  </div>
                <% end %>
              <% else %>
                <div class="text-gray-400 text-sm">No balance data available</div>
              <% end %>
            </div>
          </div>
          
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-purple-400">Performance Monitor</h2>
              <div class="text-2xl">📊</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Performance Score</span>
                <span class="font-mono text-purple-400">
                  <%= Float.round(Map.get(@performance_metrics, :performance_score, 1.0), 2) %>
                </span>
              </div>
              
              <%= if Map.get(@performance_metrics, :trends) do %>
                <%= for {metric, trend} <- @performance_metrics.trends do %>
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400 text-sm capitalize">
                      <%= String.replace(to_string(metric), "_", " ") %>
                    </span>
                    <span class={[
                      "font-mono text-sm",
                      case Map.get(trend, :direction, :stable) do
                        :increasing -> "text-red-400"
                        :decreasing -> "text-green-400"
                        :stable -> "text-blue-400"
                        _ -> "text-gray-400"
                      end
                    ]}>
                      <%= Map.get(trend, :direction, :stable) %>
                      (<%= Float.round(Map.get(trend, :rate, 0.0), 3) %>)
                    </span>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
          
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-xl font-semibold text-red-400">Health Monitor</h2>
              <div class="text-2xl">🏥</div>
            </div>
            
            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span class="text-gray-400">Overall Health</span>
                <span class="font-mono text-red-400">
                  <%= Float.round(Map.get(@health_status, :overall_health, 1.0), 2) %>
                </span>
              </div>
              
              <%= if Map.get(@health_status, :system_health) do %>
                <%= for {system, health} <- @health_status.system_health do %>
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400 text-sm">
                      <%= String.capitalize(String.replace(to_string(system), "_", " ")) %>
                    </span>
                    <span class={[
                      "font-mono text-sm px-2 py-1 rounded",
                      case Map.get(health, :status, :unknown) do
                        :excellent -> "bg-green-600 text-green-100"
                        :healthy -> "bg-blue-600 text-blue-100"
                        :degraded -> "bg-yellow-600 text-yellow-100"
                        :unhealthy -> "bg-red-600 text-red-100"
                        :critical -> "bg-red-800 text-red-100"
                        _ -> "bg-gray-600 text-gray-100"
                      end
                    ]}>
                      <%= Map.get(health, :status, :unknown) %>
                    </span>
                  </div>
                <% end %>
              <% end %>
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
    # Get static system metrics with error handling
    queen_metrics = try do
      Queen.get_identity_metrics()
    rescue
      e ->
        Logger.error("Failed to get Queen metrics: #{inspect(e)}")
        %{}
    end
    
    intelligence_status = try do
      Intelligence.get_system_health()
    rescue
      e ->
        Logger.error("Failed to get Intelligence status: #{inspect(e)}")
        %{}
    end
    
    control_metrics = try do
      case Control.get_resource_metrics() do
        {:ok, metrics} -> metrics
        _ -> %{}
      end
    rescue
      e ->
        Logger.error("Failed to get Control metrics: #{inspect(e)}")
        %{}
    end
    
    coordination_status = try do
      VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.get_metrics()
    rescue
      e ->
        Logger.error("Failed to get Coordinator status: #{inspect(e)}")
        %{}
    end
    
    operations_metrics = try do
      VsmPhoenix.Infrastructure.SystemicOperationsMetrics.get_metrics()
    rescue
      e ->
        Logger.error("Failed to get Operations metrics: #{inspect(e)}")
        %{error_rate: 0.0, success_rate: 1.0, average_processing_time: 0.0}
    end
    
    # Get dynamic metrics from our new components
    variety_metrics = try do
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.get_all_metrics()
    rescue
      e ->
        Logger.error("Failed to get Variety metrics: #{inspect(e)}")
        %{variety_metrics: %{}, overall_diversity: 0.0}
    end
    
    balance_status = try do
      VsmPhoenix.VarietyEngineering.Metrics.BalanceMonitor.get_balance_status()
    rescue
      e ->
        Logger.error("Failed to get Balance status: #{inspect(e)}")
        %{balance_status: %{}, overall_balance: :unknown}
    end
    
    performance_metrics = try do
      GenServer.call(VsmPhoenix.PerformanceMonitor, :get_current_metrics)
    rescue
      e ->
        Logger.error("Failed to get Performance metrics: #{inspect(e)}")
        %{performance_score: 1.0, trends: %{}}
    end
    
    health_status = try do
      VsmPhoenix.HealthChecker.get_health_status()
    rescue
      e ->
        Logger.error("Failed to get Health status: #{inspect(e)}")
        %{overall_health: 1.0, system_health: %{}}
    end
    
    socket
    |> assign(:queen_metrics, queen_metrics)
    |> assign(:intelligence_status, intelligence_status)
    |> assign(:control_metrics, control_metrics)
    |> assign(:coordination_status, coordination_status)
    |> assign(:operations_metrics, operations_metrics)
    |> assign(:variety_metrics, variety_metrics)
    |> assign(:balance_status, balance_status)
    |> assign(:performance_metrics, performance_metrics)
    |> assign(:health_status, health_status)
  end
  
  defp update_viability_score(socket) do
    viability_score = try do
      viability = Queen.evaluate_viability()
      # Check if we got a viability_index or system_health
      cond do
        is_map(viability) and Map.has_key?(viability, :viability_index) ->
          viability.viability_index
        is_map(viability) and Map.has_key?(viability, :system_health) ->
          viability.system_health  
        true ->
          Logger.warning("Unexpected viability format: #{inspect(viability)}")
          0.0
      end
    rescue
      e ->
        Logger.error("Failed to evaluate viability: #{inspect(e)}")
        0.0
    end
    
    assign(socket, :viability_score, viability_score)
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
    audit_summary = try do
      # Get latest audit results from S3
      audit = Control.audit_resource_usage()
      
      # Get the actual pattern metrics which includes last_calculated
      pattern_metrics = Control.get_pattern_metrics()
      
      %{
        timestamp: Map.get(pattern_metrics, :last_calculated, DateTime.utc_now()),
        efficiency: Map.get(audit, :efficiency, 0.85),
        waste: Map.get(audit, :waste_ratio, Map.get(audit, :waste, 0.05)),
        recommendations: Map.get(audit, :recommendations, [])
      }
    rescue
      e ->
        Logger.error("Failed to get audit results: #{inspect(e)}")
        %{
          timestamp: DateTime.utc_now(),
          efficiency: 0.85,
          waste: 0.05,
          recommendations: []
        }
    end
    
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