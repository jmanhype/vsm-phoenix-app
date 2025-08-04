defmodule VsmPhoenixWeb.AuditLive do
  @moduledoc """
  LiveView for System 3* Audit Channel monitoring and control.
  Provides real-time visualization of audit activities, compliance status,
  and direct audit triggering capabilities.
  """
  
  use VsmPhoenixWeb, :live_view
  
  alias VsmPhoenix.System3.{Control, AuditChannel}
  alias Phoenix.PubSub
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to audit events
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:audit")
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:governance")
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:control")
      
      # Schedule periodic updates
      Process.send_after(self(), :refresh_audit_data, 1000)
    end
    
    socket = socket
    |> assign(:audit_report, nil)
    |> assign(:recent_audits, [])
    |> assign(:compliance_status, %{})
    |> assign(:audit_metrics, %{})
    |> assign(:risk_assessment, %{})
    |> assign(:selected_agent, nil)
    |> assign(:audit_in_progress, false)
    |> load_initial_data()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="audit-dashboard">
      <h1 class="text-3xl font-bold mb-6">System 3* Audit Channel</h1>
      
      <!-- Audit Controls -->
      <div class="bg-gray-800 p-6 rounded-lg mb-6">
        <h2 class="text-xl font-semibold mb-4">Audit Controls</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button 
            phx-click="trigger_sporadic_audit"
            disabled={@audit_in_progress}
            class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white px-4 py-2 rounded">
            🎲 Trigger Sporadic Audit
          </button>
          
          <button 
            phx-click="generate_report"
            class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded">
            📊 Generate Report for S5
          </button>
          
          <button 
            phx-click="check_all_compliance"
            disabled={@audit_in_progress}
            class="bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-600 text-white px-4 py-2 rounded">
            ✅ Check All Compliance
          </button>
        </div>
        
        <!-- Direct Audit -->
        <div class="mt-4">
          <h3 class="text-lg font-medium mb-2">Direct S1 Audit (Bypass S2)</h3>
          <form phx-submit="direct_audit" class="flex gap-2">
            <select name="target" class="bg-gray-700 text-white px-3 py-2 rounded flex-1">
              <option value="operations_context">Operations Context</option>
              <option value="agent_1">Agent 1</option>
              <option value="agent_2">Agent 2</option>
            </select>
            
            <select name="operation" class="bg-gray-700 text-white px-3 py-2 rounded">
              <option value="state_dump">State Dump</option>
              <option value="compliance_check">Compliance Check</option>
              <option value="resource_audit">Resource Audit</option>
              <option value="performance_audit">Performance Audit</option>
            </select>
            
            <button 
              type="submit"
              disabled={@audit_in_progress}
              class="bg-red-600 hover:bg-red-700 disabled:bg-gray-600 text-white px-4 py-2 rounded">
              🔍 Audit Now
            </button>
          </form>
        </div>
      </div>
      
      <!-- Audit Metrics -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-gray-800 p-4 rounded-lg">
          <h3 class="text-sm text-gray-400">Total Audits</h3>
          <p class="text-2xl font-bold text-white"><%= @audit_metrics[:total_audits] || 0 %></p>
        </div>
        
        <div class="bg-gray-800 p-4 rounded-lg">
          <h3 class="text-sm text-gray-400">Compliance Rate</h3>
          <p class={["text-2xl font-bold", compliance_color(@audit_metrics[:compliance_rate])]}>
            <%= format_percentage(@audit_metrics[:compliance_rate]) %>
          </p>
        </div>
        
        <div class="bg-gray-800 p-4 rounded-lg">
          <h3 class="text-sm text-gray-400">Avg Response Time</h3>
          <p class="text-2xl font-bold text-white">
            <%= format_ms(@audit_metrics[:avg_response_time]) %>
          </p>
        </div>
        
        <div class="bg-gray-800 p-4 rounded-lg">
          <h3 class="text-sm text-gray-400">Risk Level</h3>
          <p class={["text-2xl font-bold", risk_color(@risk_assessment[:overall_risk])]}>
            <%= @risk_assessment[:overall_risk] || "Low" %>
          </p>
        </div>
      </div>
      
      <!-- Compliance Status -->
      <div class="bg-gray-800 p-6 rounded-lg mb-6">
        <h2 class="text-xl font-semibold mb-4">Compliance Status by Agent</h2>
        
        <div class="overflow-x-auto">
          <table class="min-w-full">
            <thead>
              <tr class="border-b border-gray-700">
                <th class="px-4 py-2 text-left">Agent</th>
                <th class="px-4 py-2 text-left">Status</th>
                <th class="px-4 py-2 text-left">Score</th>
                <th class="px-4 py-2 text-left">Last Check</th>
                <th class="px-4 py-2 text-left">Violations</th>
                <th class="px-4 py-2 text-left">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for {agent, status} <- @compliance_status do %>
                <tr class="border-b border-gray-700">
                  <td class="px-4 py-2"><%= agent %></td>
                  <td class="px-4 py-2">
                    <span class={["px-2 py-1 rounded text-xs", compliance_badge_class(status.compliant)]}>
                      <%= if status.compliant, do: "✅ Compliant", else: "❌ Non-Compliant" %>
                    </span>
                  </td>
                  <td class="px-4 py-2"><%= format_percentage(status.score) %></td>
                  <td class="px-4 py-2"><%= format_timestamp(status.last_check) %></td>
                  <td class="px-4 py-2">
                    <%= length(status.violations || []) %> issues
                  </td>
                  <td class="px-4 py-2">
                    <button 
                      phx-click="audit_agent"
                      phx-value-agent={agent}
                      class="text-blue-400 hover:text-blue-300 text-sm">
                      Audit
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
      
      <!-- Recent Audits -->
      <div class="bg-gray-800 p-6 rounded-lg mb-6">
        <h2 class="text-xl font-semibold mb-4">Recent Audit Activity</h2>
        
        <div class="space-y-2 max-h-96 overflow-y-auto">
          <%= for audit <- @recent_audits do %>
            <div class="bg-gray-700 p-3 rounded flex justify-between items-center">
              <div>
                <span class="font-medium"><%= audit.target %></span>
                <span class="text-sm text-gray-400 ml-2">
                  <%= audit.type %> audit
                </span>
              </div>
              
              <div class="flex items-center gap-2">
                <span class={["text-sm", if(audit.success, do: "text-green-400", else: "text-red-400")]}>
                  <%= if audit.success, do: "✓ Success", else: "✗ Failed" %>
                </span>
                <span class="text-xs text-gray-400">
                  <%= format_timestamp(audit.timestamp) %>
                </span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Risk Assessment -->
      <div class="bg-gray-800 p-6 rounded-lg">
        <h2 class="text-xl font-semibold mb-4">Risk Assessment</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for {category, risks} <- group_risks(@risk_assessment[:risks] || []) do %>
            <div class="bg-gray-700 p-4 rounded">
              <h3 class="font-medium mb-2 capitalize"><%= category %> Risks</h3>
              <ul class="space-y-1">
                <%= for risk <- risks do %>
                  <li class="text-sm">
                    <span class={["inline-block w-2 h-2 rounded-full mr-2", risk_indicator_color(risk.level)]}>
                    </span>
                    <%= risk.description %>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
        
        <!-- Recommendations -->
        <%= if @audit_report && @audit_report.recommendations do %>
          <div class="mt-4">
            <h3 class="font-medium mb-2">Recommendations</h3>
            <ul class="list-disc list-inside space-y-1">
              <%= for recommendation <- @audit_report.recommendations do %>
                <li class="text-sm text-gray-300"><%= recommendation %></li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  @impl true
  def handle_event("trigger_sporadic_audit", _params, socket) do
    Control.trigger_sporadic_audit()
    
    socket = socket
    |> assign(:audit_in_progress, true)
    |> put_flash(:info, "Sporadic audit triggered")
    
    Process.send_after(self(), :audit_complete, 2000)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("generate_report", _params, socket) do
    case Control.get_audit_report() do
      {:ok, report} ->
        socket = socket
        |> assign(:audit_report, report)
        |> put_flash(:info, "Report generated and sent to System 5")
        
        {:noreply, socket}
        
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate report: #{inspect(reason)}")}
    end
  end
  
  @impl true
  def handle_event("check_all_compliance", _params, socket) do
    # Check compliance for all known agents
    agents = [:operations_context, :agent_1, :agent_2]
    
    Task.start(fn ->
      for agent <- agents do
        Control.check_compliance(agent)
        Process.sleep(100)
      end
    end)
    
    socket = socket
    |> assign(:audit_in_progress, true)
    |> put_flash(:info, "Checking compliance for all agents...")
    
    Process.send_after(self(), :audit_complete, 3000)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("direct_audit", %{"target" => target, "operation" => operation}, socket) do
    target_atom = String.to_existing_atom(target)
    operation_atom = String.to_existing_atom(operation)
    
    Task.start(fn ->
      Control.audit(target_atom, operation: operation_atom)
    end)
    
    socket = socket
    |> assign(:audit_in_progress, true)
    |> put_flash(:info, "Direct audit initiated for #{target}")
    
    Process.send_after(self(), :audit_complete, 2000)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("audit_agent", %{"agent" => agent}, socket) do
    agent_atom = String.to_existing_atom(agent)
    
    Task.start(fn ->
      Control.audit(agent_atom, operation: :compliance_check)
    end)
    
    {:noreply, put_flash(socket, :info, "Auditing #{agent}...")}
  end
  
  @impl true
  def handle_info(:refresh_audit_data, socket) do
    socket = load_audit_data(socket)
    
    # Schedule next refresh
    Process.send_after(self(), :refresh_audit_data, 5000)
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(:audit_complete, socket) do
    {:noreply, assign(socket, :audit_in_progress, false)}
  end
  
  @impl true
  def handle_info({:audit_report, report}, socket) do
    socket = socket
    |> assign(:audit_report, report)
    |> assign(:risk_assessment, report.risk_assessment || %{})
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:compliance_violation, agent, violations}, socket) do
    socket = put_flash(socket, :error, "Compliance violation detected in #{agent}: #{length(violations)} issues")
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:critical_anomaly, agent, anomalies}, socket) do
    socket = put_flash(socket, :error, "CRITICAL: Anomaly detected in #{agent}")
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:audit_metrics, metrics_report}, socket) do
    socket = assign(socket, :audit_metrics, metrics_report.metrics || %{})
    {:noreply, socket}
  end
  
  # Private functions
  
  defp load_initial_data(socket) do
    socket
    |> load_audit_data()
    |> load_compliance_status()
  end
  
  defp load_audit_data(socket) do
    case Control.get_audit_report() do
      {:ok, report} ->
        socket
        |> assign(:audit_report, report)
        |> assign(:recent_audits, Enum.take(report.recent_audits || [], 10))
        |> assign(:risk_assessment, report.risk_assessment || %{})
        |> assign(:audit_metrics, %{
          total_audits: report.audit_statistics.total_audits || 0,
          compliance_rate: calculate_compliance_rate(report),
          avg_response_time: 0
        })
        
      _ ->
        socket
    end
  end
  
  defp load_compliance_status(socket) do
    # In a real implementation, this would fetch actual compliance data
    # For now, we'll use sample data
    compliance_status = %{
      operations_context: %{
        compliant: true,
        score: 0.92,
        last_check: DateTime.utc_now(),
        violations: []
      },
      agent_1: %{
        compliant: true,
        score: 0.88,
        last_check: DateTime.add(DateTime.utc_now(), -3600, :second),
        violations: []
      },
      agent_2: %{
        compliant: false,
        score: 0.72,
        last_check: DateTime.add(DateTime.utc_now(), -7200, :second),
        violations: [
          %{type: :resource, violation: :cpu_exceeded}
        ]
      }
    }
    
    assign(socket, :compliance_status, compliance_status)
  end
  
  defp calculate_compliance_rate(report) do
    if report.compliance_summary do
      report.compliance_summary.compliance_rate || 1.0
    else
      1.0
    end
  end
  
  defp group_risks(risks) do
    Enum.group_by(risks, & &1.category)
  end
  
  defp format_percentage(nil), do: "N/A"
  defp format_percentage(value) when is_float(value), do: "#{Float.round(value * 100, 1)}%"
  defp format_percentage(value), do: "#{value}%"
  
  defp format_ms(nil), do: "N/A"
  defp format_ms(value) when is_number(value), do: "#{Float.round(value, 1)}ms"
  defp format_ms(_), do: "N/A"
  
  defp format_timestamp(nil), do: "Never"
  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S")
  end
  defp format_timestamp(_), do: "Unknown"
  
  defp compliance_color(nil), do: "text-gray-400"
  defp compliance_color(rate) when rate >= 0.9, do: "text-green-400"
  defp compliance_color(rate) when rate >= 0.7, do: "text-yellow-400"
  defp compliance_color(_), do: "text-red-400"
  
  defp compliance_badge_class(true), do: "bg-green-600 text-white"
  defp compliance_badge_class(false), do: "bg-red-600 text-white"
  
  defp risk_color("Critical"), do: "text-red-500"
  defp risk_color("High"), do: "text-orange-500"
  defp risk_color("Medium"), do: "text-yellow-500"
  defp risk_color("Low"), do: "text-green-500"
  defp risk_color(_), do: "text-gray-400"
  
  defp risk_indicator_color(:critical), do: "bg-red-500"
  defp risk_indicator_color(:high), do: "bg-orange-500"
  defp risk_indicator_color(:medium), do: "bg-yellow-500"
  defp risk_indicator_color(:low), do: "bg-green-500"
  defp risk_indicator_color(_), do: "bg-gray-500"
end