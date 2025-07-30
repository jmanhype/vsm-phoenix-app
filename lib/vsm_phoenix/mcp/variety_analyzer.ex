defmodule VsmPhoenix.MCP.VarietyAnalyzer do
  @moduledoc """
  Detects variety gaps in VSM capabilities using cybernetic principles.
  
  Core concept: When the variety of incoming requests exceeds the variety
  of available responses, the system needs to acquire new capabilities.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System1
  alias VsmPhoenix.System4
  alias VsmPhoenix.MCP.ExternalClient
  
  @variety_threshold 0.7  # Confidence threshold for handling requests
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Analyze the current state of VSM capabilities.
  Returns a map of capability domains and their variety handling capacity.
  """
  def analyze_current_state do
    GenServer.call(__MODULE__, :analyze_current_state)
  end
  
  @doc """
  Detect if a request creates a variety gap that VSM cannot handle.
  Returns {:ok, :handled} or {:error, variety_gap_details}
  """
  def detect_variety_gap(request) do
    GenServer.call(__MODULE__, {:detect_variety_gap, request})
  end
  
  @doc """
  Score how well a set of server tools matches a detected variety gap.
  Returns a score between 0.0 and 1.0
  """
  def score_capability_match(gap, server_tools) do
    GenServer.call(__MODULE__, {:score_capability_match, gap, server_tools})
  end
  
  @doc """
  Recommend which MCP servers to acquire based on detected gaps.
  Returns a prioritized list of server recommendations.
  """
  def recommend_acquisition(gaps, available_servers) do
    GenServer.call(__MODULE__, {:recommend_acquisition, gaps, available_servers})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      capability_map: build_capability_map(),
      gap_history: [],
      acquisition_history: [],
      variety_metrics: %{}
    }
    
    # Schedule periodic capability analysis
    Process.send_after(self(), :analyze_capabilities, 5_000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:analyze_current_state, _from, state) do
    analysis = %{
      total_capabilities: map_size(state.capability_map),
      domains: extract_domains(state.capability_map),
      variety_capacity: calculate_variety_capacity(state),
      recent_gaps: Enum.take(state.gap_history, 10),
      acquisition_success_rate: calculate_acquisition_success(state)
    }
    
    {:reply, analysis, state}
  end
  
  @impl true
  def handle_call({:detect_variety_gap, request}, _from, state) do
    # Extract request characteristics
    request_variety = analyze_request_variety(request)
    
    # Check if current capabilities can handle it
    case can_handle_variety?(request_variety, state.capability_map) do
      {:ok, confidence} when confidence >= @variety_threshold ->
        {:reply, {:ok, :handled}, state}
        
      {:ok, confidence} ->
        gap = %{
          request: request,
          variety: request_variety,
          confidence: confidence,
          missing_capabilities: identify_missing_capabilities(request_variety, state.capability_map),
          timestamp: DateTime.utc_now()
        }
        
        new_state = %{state | gap_history: [gap | state.gap_history]}
        {:reply, {:error, gap}, new_state}
        
      {:error, reason} ->
        gap = %{
          request: request,
          variety: request_variety,
          confidence: 0.0,
          missing_capabilities: reason,
          timestamp: DateTime.utc_now()
        }
        
        new_state = %{state | gap_history: [gap | state.gap_history]}
        {:reply, {:error, gap}, new_state}
    end
  end
  
  @impl true
  def handle_call({:score_capability_match, gap, server_tools}, _from, state) do
    score = calculate_match_score(gap.missing_capabilities, server_tools)
    {:reply, score, state}
  end
  
  @impl true
  def handle_call({:recommend_acquisition, gaps, available_servers}, _from, state) do
    recommendations = 
      available_servers
      |> Enum.map(fn server ->
        score = calculate_server_score(server, gaps)
        %{
          server: server,
          score: score,
          matched_gaps: find_matched_gaps(server, gaps),
          priority: determine_priority(score, gaps)
        }
      end)
      |> Enum.sort_by(& &1.priority, :desc)
      |> Enum.take(5)
    
    {:reply, recommendations, state}
  end
  
  @impl true
  def handle_info(:analyze_capabilities, state) do
    # Periodic capability analysis
    new_state = update_variety_metrics(state)
    
    # Schedule next analysis
    Process.send_after(self(), :analyze_capabilities, 60_000)
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp build_capability_map do
    %{
      # Core VSM capabilities
      operational: %{
        tools: ["system1_monitor", "system1_act", "system1_optimize"],
        variety_handling: 0.9
      },
      coordination: %{
        tools: ["system2_coordinate", "system2_balance", "system2_distribute"],
        variety_handling: 0.85
      },
      control: %{
        tools: ["system3_control", "system3_audit", "system3_intervene"],
        variety_handling: 0.8
      },
      intelligence: %{
        tools: ["system4_scan", "system4_analyze", "system4_predict"],
        variety_handling: 0.75
      },
      policy: %{
        tools: ["system5_synthesize", "system5_decide", "system5_govern"],
        variety_handling: 0.7
      },
      
      # Domain-specific capabilities (initially limited)
      data_processing: %{
        tools: ["basic_transform", "simple_aggregate"],
        variety_handling: 0.5
      },
      external_integration: %{
        tools: ["http_request", "basic_api_call"],
        variety_handling: 0.4
      },
      specialized_computation: %{
        tools: [],  # No specialized tools initially
        variety_handling: 0.1
      }
    }
  end
  
  defp analyze_request_variety(request) do
    %{
      domain: classify_domain(request),
      complexity: estimate_complexity(request),
      required_tools: extract_required_tools(request),
      data_types: identify_data_types(request),
      integration_needs: detect_integration_needs(request)
    }
  end
  
  defp classify_domain(request) do
    cond do
      String.contains?(request, ["database", "sql", "query"]) -> :data_processing
      String.contains?(request, ["api", "webhook", "integration"]) -> :external_integration
      String.contains?(request, ["predict", "forecast", "analyze"]) -> :intelligence
      String.contains?(request, ["coordinate", "balance", "distribute"]) -> :coordination
      String.contains?(request, ["policy", "decide", "govern"]) -> :policy
      String.contains?(request, ["monitor", "operate", "optimize"]) -> :operational
      String.contains?(request, ["machine learning", "neural", "ai"]) -> :specialized_computation
      true -> :general
    end
  end
  
  defp estimate_complexity(request) do
    # Simple heuristic based on request characteristics
    factors = [
      String.length(request) > 200,
      Regex.match?(~r/multiple|several|complex|advanced/i, request),
      Regex.match?(~r/integrate|combine|orchestrate/i, request),
      Regex.match?(~r/real-time|streaming|continuous/i, request)
    ]
    
    complexity_score = Enum.count(factors, & &1) / length(factors)
    
    cond do
      complexity_score >= 0.75 -> :high
      complexity_score >= 0.5 -> :medium
      true -> :low
    end
  end
  
  defp extract_required_tools(request) do
    # Pattern matching for tool requirements
    tools = []
    
    tools = if String.contains?(request, ["monitor", "watch", "observe"]),
      do: ["monitoring" | tools], else: tools
      
    tools = if String.contains?(request, ["analyze", "examine", "investigate"]),
      do: ["analysis" | tools], else: tools
      
    tools = if String.contains?(request, ["predict", "forecast", "estimate"]),
      do: ["prediction" | tools], else: tools
      
    tools = if String.contains?(request, ["database", "sql", "query"]),
      do: ["data_access" | tools], else: tools
      
    tools = if String.contains?(request, ["api", "http", "webhook"]),
      do: ["external_api" | tools], else: tools
      
    tools = if String.contains?(request, ["file", "read", "write"]),
      do: ["file_system" | tools], else: tools
      
    tools
  end
  
  defp identify_data_types(request) do
    types = []
    
    types = if String.contains?(request, ["json", "xml", "yaml"]),
      do: [:structured | types], else: types
      
    types = if String.contains?(request, ["image", "video", "audio"]),
      do: [:media | types], else: types
      
    types = if String.contains?(request, ["text", "document", "pdf"]),
      do: [:document | types], else: types
      
    types = if String.contains?(request, ["stream", "real-time", "live"]),
      do: [:streaming | types], else: types
      
    types
  end
  
  defp detect_integration_needs(request) do
    needs = []
    
    needs = if String.contains?(request, ["github", "gitlab", "git"]),
      do: [:version_control | needs], else: needs
      
    needs = if String.contains?(request, ["slack", "discord", "teams"]),
      do: [:messaging | needs], else: needs
      
    needs = if String.contains?(request, ["aws", "azure", "gcp"]),
      do: [:cloud_provider | needs], else: needs
      
    needs = if String.contains?(request, ["docker", "kubernetes", "container"]),
      do: [:containerization | needs], else: needs
      
    needs
  end
  
  defp can_handle_variety?(request_variety, capability_map) do
    domain_capability = Map.get(capability_map, request_variety.domain, %{variety_handling: 0.0})
    base_confidence = domain_capability.variety_handling
    
    # Adjust confidence based on complexity
    confidence = case request_variety.complexity do
      :low -> base_confidence
      :medium -> base_confidence * 0.8
      :high -> base_confidence * 0.6
    end
    
    # Check if we have required tools
    available_tools = extract_all_tools(capability_map)
    missing_tools = request_variety.required_tools -- available_tools
    
    if Enum.empty?(missing_tools) do
      {:ok, confidence}
    else
      {:ok, confidence * 0.5}  # Heavily penalize missing tools
    end
  end
  
  defp identify_missing_capabilities(request_variety, capability_map) do
    %{
      domain_gaps: identify_domain_gaps(request_variety.domain, capability_map),
      tool_gaps: identify_tool_gaps(request_variety.required_tools, capability_map),
      integration_gaps: request_variety.integration_needs,
      data_type_gaps: identify_data_type_gaps(request_variety.data_types)
    }
  end
  
  defp identify_domain_gaps(domain, capability_map) do
    case Map.get(capability_map, domain) do
      nil -> [domain]
      %{variety_handling: handling} when handling < @variety_threshold -> [domain]
      _ -> []
    end
  end
  
  defp identify_tool_gaps(required_tools, capability_map) do
    available_tools = extract_all_tools(capability_map)
    required_tools -- available_tools
  end
  
  defp identify_data_type_gaps(data_types) do
    # For now, assume we have basic text handling but lack specialized types
    supported_types = [:text, :structured]
    data_types -- supported_types
  end
  
  defp extract_all_tools(capability_map) do
    capability_map
    |> Map.values()
    |> Enum.flat_map(& &1.tools)
  end
  
  defp calculate_match_score(missing_capabilities, server_tools) do
    total_gaps = count_total_gaps(missing_capabilities)
    
    if total_gaps == 0 do
      1.0
    else
      matched_gaps = count_matched_gaps(missing_capabilities, server_tools)
      matched_gaps / total_gaps
    end
  end
  
  defp count_total_gaps(missing_capabilities) do
    Enum.sum([
      length(missing_capabilities.domain_gaps),
      length(missing_capabilities.tool_gaps),
      length(missing_capabilities.integration_gaps),
      length(missing_capabilities.data_type_gaps)
    ])
  end
  
  defp count_matched_gaps(missing_capabilities, server_tools) do
    tool_names = Enum.map(server_tools, & &1["name"])
    
    matched_tools = Enum.count(missing_capabilities.tool_gaps, fn gap ->
      Enum.any?(tool_names, &String.contains?(&1, gap))
    end)
    
    # Add more sophisticated matching logic here
    matched_tools
  end
  
  defp calculate_server_score(server, gaps) do
    # Score based on how many gaps this server can fill
    gap_scores = Enum.map(gaps, fn gap ->
      calculate_match_score(gap.missing_capabilities, server["tools"] || [])
    end)
    
    if Enum.empty?(gap_scores) do
      0.0
    else
      Enum.sum(gap_scores) / length(gap_scores)
    end
  end
  
  defp find_matched_gaps(server, gaps) do
    Enum.filter(gaps, fn gap ->
      score = calculate_match_score(gap.missing_capabilities, server["tools"] || [])
      score > 0.5
    end)
  end
  
  defp determine_priority(score, gaps) do
    recent_gap_count = Enum.count(gaps, fn gap ->
      DateTime.diff(DateTime.utc_now(), gap.timestamp) < 3600  # Last hour
    end)
    
    score * (1 + recent_gap_count * 0.1)
  end
  
  defp extract_domains(capability_map) do
    capability_map
    |> Enum.map(fn {domain, info} ->
      %{
        name: domain,
        tools: info.tools,
        variety_handling: info.variety_handling
      }
    end)
  end
  
  defp calculate_variety_capacity(state) do
    total_handling = state.capability_map
    |> Map.values()
    |> Enum.map(& &1.variety_handling)
    |> Enum.sum()
    
    total_handling / map_size(state.capability_map)
  end
  
  defp calculate_acquisition_success(state) do
    successful = Enum.count(state.acquisition_history, & &1.success)
    total = length(state.acquisition_history)
    
    if total == 0, do: 0.0, else: successful / total
  end
  
  defp update_variety_metrics(state) do
    # Collect current metrics
    metrics = %{
      timestamp: DateTime.utc_now(),
      total_capabilities: map_size(state.capability_map),
      average_variety_handling: calculate_variety_capacity(state),
      recent_gaps: length(Enum.take(state.gap_history, 100)),
      acquisition_rate: calculate_acquisition_rate(state)
    }
    
    %{state | variety_metrics: metrics}
  end
  
  defp calculate_acquisition_rate(state) do
    recent_acquisitions = Enum.filter(state.acquisition_history, fn acq ->
      DateTime.diff(DateTime.utc_now(), acq.timestamp) < 86400  # Last 24 hours
    end)
    
    length(recent_acquisitions)
  end
end