defmodule VsmPhoenix.MCP.CapabilityAnalyzer do
  @moduledoc """
  Analyzes system capabilities and identifies variety gaps.
  Works with VSM systems to understand what capabilities are missing.
  """

  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      known_capabilities: %{},
      gap_history: [],
      analysis_cache: %{}
    }
    
    {:ok, state}
  end

  @doc """
  Analyze current system capabilities and return a map of what exists.
  """
  def analyze_current_capabilities do
    GenServer.call(__MODULE__, :analyze_current)
  end

  @doc """
  Identify gaps between required and current capabilities.
  """
  def identify_gaps(required_capabilities) do
    GenServer.call(__MODULE__, {:identify_gaps, required_capabilities})
  end

  @doc """
  Check if a specific capability exists in the system.
  """
  def has_capability?(capability_type) do
    GenServer.call(__MODULE__, {:has_capability, capability_type})
  end

  @impl true
  def handle_call(:analyze_current, _from, state) do
    capabilities = %{
      # System1 capabilities
      operational: analyze_operational_capabilities(),
      
      # System2 capabilities  
      coordination: analyze_coordination_capabilities(),
      
      # System3 capabilities
      optimization: analyze_optimization_capabilities(),
      
      # System4 capabilities
      strategic: analyze_strategic_capabilities(),
      
      # System5 capabilities
      identity: analyze_identity_capabilities(),
      
      # MCP-specific capabilities
      mcp_servers: analyze_mcp_capabilities()
    }
    
    new_state = %{state | known_capabilities: capabilities}
    {:reply, capabilities, new_state}
  end

  @impl true
  def handle_call({:identify_gaps, required}, _from, state) do
    current = state.known_capabilities
    
    gaps = Enum.flat_map(required, fn {category, requirements} ->
      current_in_category = Map.get(current, category, %{})
      
      Enum.filter_map(requirements,
        fn req -> !Map.has_key?(current_in_category, req.type) end,
        fn req -> 
          %{
            id: "gap_#{:erlang.phash2({category, req.type})}",
            type: req.type,
            category: category,
            required_capability: req.type,
            severity: req.severity || 0.5,
            priority: req.priority || :medium,
            description: req.description || "Missing #{req.type} capability"
          }
        end
      )
    end)
    
    # Cache the analysis
    new_state = %{state | 
      gap_history: [{DateTime.utc_now(), gaps} | state.gap_history]
    }
    
    {:reply, gaps, new_state}
  end

  @impl true
  def handle_call({:has_capability, capability_type}, _from, state) do
    has_it = Enum.any?(state.known_capabilities, fn {_category, caps} ->
      Map.has_key?(caps, capability_type)
    end)
    
    {:reply, has_it, state}
  end

  # Private analysis functions

  defp analyze_operational_capabilities do
    # Check what System1 can do
    %{
      pattern_matching: true,
      real_time_response: true,
      sensor_integration: check_sensor_integration(),
      actuator_control: check_actuator_control(),
      data_processing: check_data_processing()
    }
  end

  defp analyze_coordination_capabilities do
    # Check what System2 can coordinate
    %{
      multi_agent_coordination: true,
      resource_allocation: true,
      conflict_resolution: check_conflict_resolution(),
      communication_protocols: check_communication_protocols()
    }
  end

  defp analyze_optimization_capabilities do
    # Check System3 optimization abilities
    %{
      performance_monitoring: true,
      resource_optimization: true,
      predictive_analytics: check_predictive_analytics(),
      anomaly_detection: check_anomaly_detection()
    }
  end

  defp analyze_strategic_capabilities do
    # Check System4 strategic planning
    %{
      environmental_scanning: true,
      strategic_planning: true,
      market_analysis: check_market_analysis(),
      competitive_intelligence: check_competitive_intelligence()
    }
  end

  defp analyze_identity_capabilities do
    # Check System5 governance
    %{
      policy_management: true,
      identity_preservation: true,
      ethical_constraints: true,
      value_alignment: true
    }
  end

  defp analyze_mcp_capabilities do
    # Check what MCP servers are currently integrated
    case GenServer.call(VsmPhoenix.MCP.MCPRegistry, :list_active_servers, 5000) do
      servers when is_list(servers) ->
        Map.new(servers, fn server ->
          {server.id, %{
            capabilities: server.capabilities,
            status: :active,
            integrated_at: server.integrated_at
          }}
        end)
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  # Helper functions that check for specific capabilities
  defp check_sensor_integration do
    # Check if we have sensor integration capabilities
    Code.ensure_loaded?(VsmPhoenix.Sensors) 
  end

  defp check_actuator_control do
    Code.ensure_loaded?(VsmPhoenix.Actuators)
  end

  defp check_data_processing do
    Code.ensure_loaded?(VsmPhoenix.DataPipeline)
  end

  defp check_conflict_resolution do
    Code.ensure_loaded?(VsmPhoenix.ConflictResolver)
  end

  defp check_communication_protocols do
    # Check available protocols
    protocols = Application.get_env(:vsm_phoenix, :communication_protocols, [])
    length(protocols) > 0
  end

  defp check_predictive_analytics do
    Code.ensure_loaded?(VsmPhoenix.Analytics.Predictive)
  end

  defp check_anomaly_detection do
    Code.ensure_loaded?(VsmPhoenix.Analytics.AnomalyDetector)
  end

  defp check_market_analysis do
    Code.ensure_loaded?(VsmPhoenix.Strategic.MarketAnalyzer)
  end

  defp check_competitive_intelligence do
    Code.ensure_loaded?(VsmPhoenix.Strategic.CompetitiveIntel)
  end
end