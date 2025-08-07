defmodule VsmPhoenix.MCP.CapabilityMatcher do
  @moduledoc """
  Matches variety gaps to available MCP server capabilities.
  
  Uses a multi-dimensional matching algorithm that considers:
  - Tool name similarity
  - Description semantic matching  
  - Input/output type compatibility
  - Domain alignment
  - Historical success rates
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.VarietyAnalyzer
  alias VsmPhoenix.System4.LLMVarietySource
  
  @match_threshold 0.6
  @semantic_weight 0.4
  @structural_weight 0.3
  @historical_weight 0.3
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Find the best matching MCP servers for a given variety gap.
  Returns a list of matches sorted by relevance score.
  """
  def find_matches(variety_gap, available_servers) do
    GenServer.call(__MODULE__, {:find_matches, variety_gap, available_servers}, 30_000)
  end
  
  @doc """
  Match a specific tool to a capability requirement.
  Returns a detailed match analysis.
  """
  def match_tool_to_capability(tool, capability_requirement) do
    GenServer.call(__MODULE__, {:match_tool, tool, capability_requirement})
  end
  
  @doc """
  Learn from acquisition outcomes to improve future matching.
  """
  def record_acquisition_outcome(server_name, gap, success) do
    GenServer.cast(__MODULE__, {:record_outcome, server_name, gap, success})
  end
  
  @doc """
  Get matching statistics and performance metrics.
  """
  def get_match_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      match_history: [],
      success_rates: %{},
      domain_mappings: build_domain_mappings(),
      tool_embeddings: %{},
      llm_client: nil
    }
    
    # Initialize LLM client for semantic matching
    {:ok, state, {:continue, :init_llm}}
  end
  
  @impl true
  def handle_continue(:init_llm, state) do
    # Initialize LLM for semantic matching if available
    new_state = case LLMVarietySource.check_availability() do
      {:ok, _} ->
        Logger.info("LLM available for semantic capability matching")
        %{state | llm_client: :available}
      _ ->
        Logger.warning("LLM not available, using structural matching only")
        state
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:find_matches, variety_gap, available_servers}, _from, state) do
    matches = available_servers
    |> Enum.map(fn server ->
      score = calculate_match_score(server, variety_gap, state)
      %{
        server: server,
        score: score,
        match_details: analyze_match_details(server, variety_gap, state),
        confidence: calculate_confidence(score, state)
      }
    end)
    |> Enum.filter(& &1.score >= @match_threshold)
    |> Enum.sort_by(& &1.score, :desc)
    
    {:reply, matches, state}
  end
  
  @impl true
  def handle_call({:match_tool, tool, capability_requirement}, _from, state) do
    match_analysis = %{
      name_similarity: calculate_name_similarity(tool["name"], capability_requirement),
      description_match: calculate_description_match(tool["description"], capability_requirement, state),
      input_compatibility: check_input_compatibility(tool["inputSchema"], capability_requirement),
      output_compatibility: check_output_compatibility(tool["outputSchema"], capability_requirement),
      domain_alignment: check_domain_alignment(tool, capability_requirement, state)
    }
    
    overall_score = calculate_overall_tool_score(match_analysis)
    
    {:reply, %{analysis: match_analysis, score: overall_score}, state}
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    stats = %{
      total_matches: length(state.match_history),
      success_rates: state.success_rates,
      average_confidence: calculate_average_confidence(state),
      domain_coverage: calculate_domain_coverage(state)
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_cast({:record_outcome, server_name, gap, success}, state) do
    # Update success rates
    key = {server_name, gap.missing_capabilities.domain_gaps}
    current_rate = Map.get(state.success_rates, key, {0, 0})
    {successes, attempts} = current_rate
    
    new_rate = if success do
      {successes + 1, attempts + 1}
    else
      {successes, attempts + 1}
    end
    
    # Update match history
    match_record = %{
      server: server_name,
      gap: gap,
      success: success,
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{
      state |
      success_rates: Map.put(state.success_rates, key, new_rate),
      match_history: [match_record | Enum.take(state.match_history, 999)]
    }
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp build_domain_mappings do
    %{
      # VSM domain to common tool patterns
      data_processing: ["database", "sql", "query", "transform", "etl", "analytics"],
      external_integration: ["api", "http", "webhook", "rest", "graphql", "grpc"],
      specialized_computation: ["ml", "ai", "neural", "compute", "algorithm", "math"],
      monitoring: ["metrics", "logs", "trace", "observability", "alert"],
      automation: ["workflow", "pipeline", "orchestration", "schedule", "trigger"],
      security: ["auth", "encrypt", "secure", "certificate", "vault"],
      communication: ["email", "sms", "notification", "message", "chat"],
      file_processing: ["file", "document", "pdf", "image", "convert"],
      version_control: ["git", "github", "gitlab", "version", "repository"]
    }
  end
  
  defp calculate_match_score(server, variety_gap, state) do
    # Multi-dimensional scoring
    tool_score = calculate_tool_coverage_score(server["tools"] || [], variety_gap)
    domain_score = calculate_domain_alignment_score(server, variety_gap, state)
    historical_score = calculate_historical_success_score(server["name"], variety_gap, state)
    
    # Weighted combination
    tool_score * 0.5 + domain_score * 0.3 + historical_score * 0.2
  end
  
  defp calculate_tool_coverage_score(tools, variety_gap) do
    required_capabilities = extract_required_capabilities(variety_gap)
    
    if Enum.empty?(required_capabilities) do
      0.0
    else
      matched = Enum.count(required_capabilities, fn cap ->
        Enum.any?(tools, fn tool ->
          matches_capability?(tool, cap)
        end)
      end)
      
      matched / length(required_capabilities)
    end
  end
  
  defp extract_required_capabilities(variety_gap) do
    Enum.concat([
      variety_gap.missing_capabilities.tool_gaps,
      map_domain_to_capabilities(variety_gap.missing_capabilities.domain_gaps),
      map_integration_to_capabilities(variety_gap.missing_capabilities.integration_gaps),
      map_data_type_to_capabilities(variety_gap.missing_capabilities.data_type_gaps)
    ])
  end
  
  defp map_domain_to_capabilities(domain_gaps) do
    Enum.flat_map(domain_gaps, fn domain ->
      case domain do
        :data_processing -> ["query", "transform", "analyze"]
        :external_integration -> ["http_request", "api_call", "webhook"]
        :specialized_computation -> ["compute", "ml_inference", "algorithm"]
        _ -> []
      end
    end)
  end
  
  defp map_integration_to_capabilities(integration_gaps) do
    Enum.map(integration_gaps, fn integration ->
      case integration do
        :version_control -> "git_operations"
        :messaging -> "send_message"
        :cloud_provider -> "cloud_api"
        :containerization -> "container_management"
        _ -> to_string(integration)
      end
    end)
  end
  
  defp map_data_type_to_capabilities(data_type_gaps) do
    Enum.map(data_type_gaps, fn data_type ->
      case data_type do
        :media -> "media_processing"
        :document -> "document_parsing"
        :streaming -> "stream_processing"
        _ -> "#{data_type}_handler"
      end
    end)
  end
  
  defp matches_capability?(tool, capability) do
    tool_name = String.downcase(tool["name"] || "")
    tool_desc = String.downcase(tool["description"] || "")
    cap_lower = String.downcase(capability)
    
    String.contains?(tool_name, cap_lower) ||
    String.contains?(tool_desc, cap_lower) ||
    semantic_match?(tool, capability)
  end
  
  defp semantic_match?(tool, capability) do
    # Simple keyword-based semantic matching
    # In production, this could use embeddings or LLM
    tool_keywords = extract_keywords(tool)
    cap_keywords = String.split(capability, ["_", "-", " "])
    
    Enum.any?(cap_keywords, fn keyword ->
      Enum.any?(tool_keywords, fn tool_kw ->
        String.jaro_distance(keyword, tool_kw) > 0.8
      end)
    end)
  end
  
  defp extract_keywords(tool) do
    name_parts = String.split(tool["name"] || "", ["_", "-", " ", "."])
    desc_words = String.split(tool["description"] || "", " ")
    
    (name_parts ++ desc_words)
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.uniq()
  end
  
  defp calculate_domain_alignment_score(server, variety_gap, state) do
    server_domains = infer_server_domains(server, state)
    required_domains = variety_gap.missing_capabilities.domain_gaps
    
    if Enum.empty?(required_domains) do
      0.5  # Neutral score if no specific domain requirements
    else
      matched = Enum.count(required_domains, fn domain ->
        Enum.member?(server_domains, domain)
      end)
      
      matched / length(required_domains)
    end
  end
  
  defp infer_server_domains(server, state) do
    # Infer domains from server name and tools
    domains = []
    
    server_name = String.downcase(server["name"] || "")
    tool_names = Enum.map(server["tools"] || [], &String.downcase(&1["name"] || ""))
    
    Enum.reduce(state.domain_mappings, [], fn {domain, keywords}, acc ->
      if Enum.any?(keywords, fn keyword ->
        String.contains?(server_name, keyword) ||
        Enum.any?(tool_names, &String.contains?(&1, keyword))
      end) do
        [domain | acc]
      else
        acc
      end
    end)
  end
  
  defp calculate_historical_success_score(server_name, variety_gap, state) do
    key = {server_name, variety_gap.missing_capabilities.domain_gaps}
    
    case Map.get(state.success_rates, key) do
      nil -> 0.5  # No history, neutral score
      {0, _} -> 0.1  # Failed attempts
      {successes, attempts} -> successes / attempts
    end
  end
  
  defp analyze_match_details(server, variety_gap, state) do
    %{
      matched_tools: find_matched_tools(server["tools"] || [], variety_gap),
      coverage_percentage: calculate_coverage_percentage(server, variety_gap),
      domain_alignment: infer_server_domains(server, state),
      compatibility_notes: generate_compatibility_notes(server, variety_gap)
    }
  end
  
  defp find_matched_tools(tools, variety_gap) do
    required = extract_required_capabilities(variety_gap)
    
    Enum.flat_map(tools, fn tool ->
      matched_caps = Enum.filter(required, fn cap ->
        matches_capability?(tool, cap)
      end)
      
      if Enum.empty?(matched_caps) do
        []
      else
        [%{tool: tool["name"], matches: matched_caps}]
      end
    end)
  end
  
  defp calculate_coverage_percentage(server, variety_gap) do
    required = extract_required_capabilities(variety_gap)
    
    if Enum.empty?(required) do
      0.0
    else
      matched = Enum.count(required, fn cap ->
        Enum.any?(server["tools"] || [], fn tool ->
          matches_capability?(tool, cap)
        end)
      end)
      
      (matched / length(required)) * 100
    end
  end
  
  defp generate_compatibility_notes(server, variety_gap) do
    notes = []
    
    notes = if server["transport"] == "stdio",
      do: ["Direct stdio communication supported" | notes],
      else: notes
      
    notes = if server["requiredEnv"],
      do: ["Requires environment configuration" | notes],
      else: notes
      
    notes = if variety_gap.variety.complexity == :high && length(server["tools"] || []) < 5,
      do: ["May have limited capacity for high complexity requests" | notes],
      else: notes
      
    notes
  end
  
  defp calculate_confidence(score, state) do
    # Confidence based on score and historical data
    base_confidence = score
    history_factor = min(length(state.match_history) / 100, 1.0)
    
    base_confidence * (0.7 + history_factor * 0.3)
  end
  
  defp calculate_name_similarity(tool_name, requirement) do
    tool_lower = String.downcase(tool_name || "")
    req_lower = String.downcase(requirement)
    
    String.jaro_distance(tool_lower, req_lower)
  end
  
  defp calculate_description_match(description, requirement, state) do
    if state.llm_client == :available do
      # Use LLM for semantic matching
      case LLMVarietySource.analyze_request("Match description: '#{description}' to requirement: '#{requirement}'") do
        {:ok, %{"match_score" => score}} -> score
        _ -> simple_description_match(description, requirement)
      end
    else
      simple_description_match(description, requirement)
    end
  end
  
  defp simple_description_match(description, requirement) do
    desc_words = String.split(String.downcase(description || ""), " ")
    req_words = String.split(String.downcase(requirement), ["_", "-", " "])
    
    matched = Enum.count(req_words, fn word ->
      Enum.any?(desc_words, &String.contains?(&1, word))
    end)
    
    if length(req_words) > 0 do
      matched / length(req_words)
    else
      0.0
    end
  end
  
  defp check_input_compatibility(input_schema, requirement) do
    # Basic compatibility check
    # In production, this would analyze JSON schemas
    case input_schema do
      nil -> 0.5
      %{} -> 0.8
      _ -> 0.6
    end
  end
  
  defp check_output_compatibility(output_schema, requirement) do
    # Basic compatibility check
    case output_schema do
      nil -> 0.5
      %{} -> 0.8
      _ -> 0.6
    end
  end
  
  defp check_domain_alignment(tool, requirement, state) do
    tool_domain = infer_tool_domain(tool, state)
    req_domain = infer_requirement_domain(requirement)
    
    if tool_domain == req_domain do
      1.0
    else
      0.3  # Different domains can still be partially compatible
    end
  end
  
  defp infer_tool_domain(tool, state) do
    tool_lower = String.downcase(tool["name"] || "")
    
    Enum.find_value(state.domain_mappings, :general, fn {domain, keywords} ->
      if Enum.any?(keywords, &String.contains?(tool_lower, &1)) do
        domain
      end
    end)
  end
  
  defp infer_requirement_domain(requirement) do
    # Simple domain inference from requirement
    cond do
      String.contains?(requirement, ["data", "query", "sql"]) -> :data_processing
      String.contains?(requirement, ["api", "http", "webhook"]) -> :external_integration
      String.contains?(requirement, ["file", "document"]) -> :file_processing
      true -> :general
    end
  end
  
  defp calculate_overall_tool_score(match_analysis) do
    # Weighted scoring of different match dimensions
    scores = [
      match_analysis.name_similarity * 0.2,
      match_analysis.description_match * 0.3,
      match_analysis.input_compatibility * 0.15,
      match_analysis.output_compatibility * 0.15,
      match_analysis.domain_alignment * 0.2
    ]
    
    Enum.sum(scores)
  end
  
  defp calculate_average_confidence(state) do
    recent_matches = Enum.take(state.match_history, 100)
    
    if Enum.empty?(recent_matches) do
      0.5
    else
      successful = Enum.count(recent_matches, & &1.success)
      successful / length(recent_matches)
    end
  end
  
  defp calculate_domain_coverage(state) do
    covered_domains = state.match_history
    |> Enum.flat_map(fn match ->
      match.gap.missing_capabilities.domain_gaps
    end)
    |> Enum.uniq()
    |> length()
    
    total_domains = Map.keys(state.domain_mappings) |> length()
    
    if total_domains > 0 do
      covered_domains / total_domains
    else
      0.0
    end
  end
end