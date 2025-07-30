defmodule VsmPhoenix.MCP.VarietyAcquisition do
  @moduledoc """
  Core module for cybernetic variety acquisition using MCP servers.
  
  This module implements the autonomous discovery and integration of external
  capabilities to maintain requisite variety according to Ashby's Law.
  
  Key responsibilities:
  - Detect variety gaps in system capabilities
  - Discover relevant MCP servers via MAGG
  - Evaluate and select optimal capability sources
  - Autonomously integrate new capabilities
  - Learn from acquisition outcomes
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MCP.{MaggIntegration, ExternalClient}
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.PolicySynthesizer
  alias VsmPhoenix.Goldrush.Plugins.PolicyLearner
  
  # Client API
  
  @doc """
  Start the variety acquisition engine.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Detect and acquire variety for a specific capability gap.
  
  ## Examples
  
      iex> VarietyAcquisition.acquire_capability(%{
      ...>   domain: "weather_data",
      ...>   requirements: ["current_weather", "forecast"],
      ...>   urgency: :high
      ...> })
      {:ok, %{
        server: "@modelcontextprotocol/server-weather",
        tools: ["get_current_weather", "get_forecast"],
        acquisition_time: 1234
      }}
  """
  def acquire_capability(capability_gap) do
    GenServer.call(__MODULE__, {:acquire_capability, capability_gap})
  end
  
  @doc """
  Trigger a comprehensive variety scan and acquisition cycle.
  """
  def scan_and_acquire(scope \\ :comprehensive) do
    GenServer.call(__MODULE__, {:scan_and_acquire, scope})
  end
  
  @doc """
  Get current variety metrics and system status.
  """
  def get_variety_status do
    GenServer.call(__MODULE__, :get_variety_status)
  end
  
  @doc """
  Register a variety gap detected by other systems.
  """
  def register_variety_gap(gap_info) do
    GenServer.cast(__MODULE__, {:register_gap, gap_info})
  end
  
  @doc """
  Get acquisition history and learning data.
  """
  def get_acquisition_history(opts \\ []) do
    GenServer.call(__MODULE__, {:get_history, opts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("🌀 Initializing Cybernetic Variety Acquisition Engine")
    
    # Initialize state
    state = %{
      # Variety metrics
      system_variety: calculate_initial_variety(),
      environmental_variety: 0,
      variety_ratio: 0,
      
      # Capability inventory
      capabilities: %{},
      active_servers: %{},
      
      # Acquisition tracking
      pending_acquisitions: %{},
      acquisition_history: [],
      
      # Learning data
      success_patterns: [],
      failure_patterns: [],
      domain_strategies: %{},
      
      # Configuration
      config: Keyword.get(opts, :config, default_config())
    }
    
    # Schedule periodic variety scan
    schedule_variety_scan(state.config.scan_interval)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:acquire_capability, gap}, _from, state) do
    Logger.info("🎯 Acquiring capability for gap: #{inspect(gap)}")
    
    case execute_acquisition_pipeline(gap, state) do
      {:ok, result, new_state} ->
        {:reply, {:ok, result}, new_state}
        
      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:scan_and_acquire, scope}, _from, state) do
    Logger.info("🔍 Executing variety scan with scope: #{scope}")
    
    # Perform comprehensive variety analysis
    case perform_variety_scan(scope, state) do
      {:ok, gaps} when length(gaps) > 0 ->
        # Acquire capabilities for detected gaps
        results = Enum.map(gaps, fn gap ->
          case execute_acquisition_pipeline(gap, state) do
            {:ok, result, _} -> {:ok, gap, result}
            {:error, reason, _} -> {:error, gap, reason}
          end
        end)
        
        new_state = update_variety_metrics(state)
        {:reply, {:ok, results}, new_state}
        
      {:ok, []} ->
        Logger.info("✅ No variety gaps detected")
        {:reply, {:ok, :no_gaps}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_variety_status, _from, state) do
    status = %{
      variety_ratio: state.variety_ratio,
      system_variety: state.system_variety,
      environmental_variety: state.environmental_variety,
      active_capabilities: map_size(state.capabilities),
      connected_servers: map_size(state.active_servers),
      pending_acquisitions: map_size(state.pending_acquisitions),
      requisite_variety_status: assess_requisite_variety(state)
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_call({:get_history, opts}, _from, state) do
    history = case Keyword.get(opts, :filter) do
      :successful -> 
        Enum.filter(state.acquisition_history, & &1.outcome == :success)
      :failed ->
        Enum.filter(state.acquisition_history, & &1.outcome == :failure)
      _ ->
        state.acquisition_history
    end
    
    {:reply, history, state}
  end
  
  @impl true
  def handle_cast({:register_gap, gap_info}, state) do
    Logger.info("📝 Registering variety gap: #{inspect(gap_info)}")
    
    # Add to pending acquisitions
    gap_id = generate_gap_id()
    pending = Map.put(state.pending_acquisitions, gap_id, %{
      gap: gap_info,
      registered_at: DateTime.utc_now(),
      status: :pending
    })
    
    # Trigger acquisition if urgent
    new_state = if gap_info[:urgency] == :critical do
      case execute_acquisition_pipeline(gap_info, state) do
        {:ok, _, updated_state} -> updated_state
        {:error, _, updated_state} -> updated_state
      end
    else
      %{state | pending_acquisitions: pending}
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:variety_scan, state) do
    Logger.debug("⏰ Periodic variety scan triggered")
    
    # Perform scan
    new_state = case perform_variety_scan(:routine, state) do
      {:ok, gaps} when length(gaps) > 0 ->
        # Process non-urgent gaps
        Enum.reduce(gaps, state, fn gap, acc_state ->
          if gap.urgency in [:normal, :low] do
            case execute_acquisition_pipeline(gap, acc_state) do
              {:ok, _, updated_state} -> updated_state
              {:error, _, updated_state} -> updated_state
            end
          else
            acc_state
          end
        end)
        
      _ ->
        state
    end
    
    # Schedule next scan
    schedule_variety_scan(state.config.scan_interval)
    
    {:noreply, update_variety_metrics(new_state)}
  end
  
  # Private Functions
  
  defp execute_acquisition_pipeline(gap, state) do
    pipeline_id = generate_pipeline_id()
    
    Logger.info("🚀 Starting acquisition pipeline #{pipeline_id} for gap: #{inspect(gap)}")
    
    with {:discover, {:ok, candidates}} <- {:discover, discover_capabilities(gap)},
         {:evaluate, {:ok, selected}} <- {:evaluate, evaluate_candidates(candidates, gap, state)},
         {:acquire, {:ok, connection}} <- {:acquire, acquire_external_capability(selected)},
         {:integrate, {:ok, integration}} <- {:integrate, integrate_capability(connection, gap, state)},
         {:validate, {:ok, validation}} <- {:validate, validate_acquisition(integration)} do
      
      # Record successful acquisition
      result = %{
        pipeline_id: pipeline_id,
        gap: gap,
        server: selected,
        connection: connection,
        integration: integration,
        acquisition_time: DateTime.utc_now()
      }
      
      new_state = record_acquisition_success(result, state)
      
      {:ok, result, new_state}
      
    else
      {phase, {:error, reason}} ->
        Logger.error("❌ Acquisition pipeline #{pipeline_id} failed at #{phase}: #{inspect(reason)}")
        
        # Record failure for learning
        failure = %{
          pipeline_id: pipeline_id,
          gap: gap,
          failed_phase: phase,
          reason: reason,
          timestamp: DateTime.utc_now()
        }
        
        new_state = record_acquisition_failure(failure, state)
        
        # Trigger alternative strategies if critical
        if gap[:urgency] == :critical do
          handle_critical_failure(gap, failure, new_state)
        else
          {:error, {phase, reason}, new_state}
        end
    end
  end
  
  defp discover_capabilities(gap) do
    # Build search query from gap description
    query = build_search_query(gap)
    
    # Search via MAGG
    case MaggIntegration.discover_servers(query) do
      {:ok, servers} when length(servers) > 0 ->
        {:ok, servers}
        
      {:ok, []} ->
        # Try alternative search strategies
        alternative_search(gap)
        
      error ->
        error
    end
  end
  
  defp evaluate_candidates(candidates, gap, state) do
    # Score each candidate
    scored = Enum.map(candidates, fn candidate ->
      score = calculate_fitness_score(candidate, gap, state)
      {score, candidate}
    end)
    
    # Sort by score and select best
    case Enum.sort_by(scored, &elem(&1, 0), :desc) do
      [{score, best} | _] when score > state.config.min_fitness_threshold ->
        {:ok, best}
        
      _ ->
        {:error, :no_suitable_candidates}
    end
  end
  
  defp acquire_external_capability(server) do
    # Add and connect to the server
    MaggIntegration.add_and_connect(server["name"])
  end
  
  defp integrate_capability(connection, gap, state) do
    # Register in capability inventory
    capability_entry = %{
      server_name: connection["server"],
      tools: connection["tools"],
      domain: gap[:domain],
      gap_id: gap[:id],
      integrated_at: DateTime.utc_now()
    }
    
    # Update state
    new_capabilities = Map.put(state.capabilities, connection["server"], capability_entry)
    new_servers = Map.put(state.active_servers, connection["server"], connection)
    
    {:ok, %{
      capability: capability_entry,
      state_updates: %{
        capabilities: new_capabilities,
        active_servers: new_servers
      }
    }}
  end
  
  defp validate_acquisition(integration) do
    # Test the acquired capability
    server_name = integration.capability.server_name
    
    # Try executing a test tool
    case test_capability(server_name, integration.capability.tools) do
      :ok ->
        {:ok, %{status: :validated, integration: integration}}
        
      error ->
        error
    end
  end
  
  defp test_capability(server_name, tools) do
    # Pick first tool for testing
    case tools do
      [tool | _] ->
        # Try to list tool details
        case ExternalClient.list_tools(server_name) do
          {:ok, _} -> :ok
          error -> error
        end
        
      [] ->
        {:error, :no_tools_available}
    end
  end
  
  defp perform_variety_scan(scope, state) do
    # Get environmental variety assessment from S4
    case Intelligence.scan_environment(scope) do
      %{variety_data: variety_data} = scan_result ->
        # Analyze for gaps
        gaps = analyze_variety_gaps(variety_data, state)
        {:ok, gaps}
        
      error ->
        {:error, {:scan_failed, error}}
    end
  end
  
  defp analyze_variety_gaps(variety_data, state) do
    # Extract patterns and anomalies
    patterns = Map.get(variety_data, :patterns, [])
    anomalies = Map.get(variety_data, :anomalies, [])
    
    # Identify capability gaps
    gaps = []
    
    # Check for pattern-based gaps
    pattern_gaps = Enum.flat_map(patterns, fn pattern ->
      if requires_new_capability?(pattern, state) do
        [pattern_to_gap(pattern)]
      else
        []
      end
    end)
    
    # Check for anomaly-based gaps
    anomaly_gaps = Enum.flat_map(anomalies, fn anomaly ->
      if anomaly["severity"] > 0.7 do
        [anomaly_to_gap(anomaly)]
      else
        []
      end
    end)
    
    gaps ++ pattern_gaps ++ anomaly_gaps
  end
  
  defp requires_new_capability?(pattern, state) do
    # Check if we have capabilities to handle this pattern
    pattern_type = Map.get(pattern, "type", "unknown")
    
    not Map.has_key?(state.capabilities, pattern_type)
  end
  
  defp pattern_to_gap(pattern) do
    %{
      type: :pattern_gap,
      domain: Map.get(pattern, "domain", "general"),
      requirements: Map.get(pattern, "required_capabilities", []),
      urgency: :normal,
      source: :pattern_analysis,
      pattern: pattern
    }
  end
  
  defp anomaly_to_gap(anomaly) do
    %{
      type: :anomaly_gap,
      domain: Map.get(anomaly, "domain", "general"),
      requirements: ["anomaly_handler", Map.get(anomaly, "type", "unknown")],
      urgency: urgency_from_severity(anomaly["severity"]),
      source: :anomaly_detection,
      anomaly: anomaly
    }
  end
  
  defp urgency_from_severity(severity) when severity > 0.9, do: :critical
  defp urgency_from_severity(severity) when severity > 0.7, do: :high
  defp urgency_from_severity(severity) when severity > 0.5, do: :normal
  defp urgency_from_severity(_), do: :low
  
  defp build_search_query(gap) do
    # Construct search query from gap information
    base_terms = [gap[:domain] | gap[:requirements] || []]
    
    # Add context if available
    context_terms = case gap[:context] do
      %{description: desc} -> String.split(desc, " ")
      _ -> []
    end
    
    (base_terms ++ context_terms)
    |> Enum.uniq()
    |> Enum.join(" ")
  end
  
  defp alternative_search(gap) do
    # Try broader search terms
    broad_query = gap[:domain] || "general capability"
    
    case MaggIntegration.discover_servers(broad_query) do
      {:ok, servers} when length(servers) > 0 ->
        {:ok, servers}
        
      _ ->
        {:error, :no_servers_found}
    end
  end
  
  defp calculate_fitness_score(candidate, gap, state) do
    # Base score components
    tool_relevance = calculate_tool_relevance(candidate["tools"], gap[:requirements])
    description_match = calculate_description_match(candidate["description"], gap)
    official_bonus = if String.starts_with?(candidate["name"], "@modelcontextprotocol/"), do: 20, else: 0
    
    # Learning-based adjustments
    historical_performance = get_historical_performance(candidate["name"], state)
    domain_affinity = get_domain_affinity(candidate, gap[:domain], state)
    
    # Calculate weighted score
    base_score = (tool_relevance * 0.4) + (description_match * 0.3) + 
                 (official_bonus * 0.1) + (historical_performance * 0.1) + 
                 (domain_affinity * 0.1)
    
    # Apply urgency multiplier
    urgency_multiplier = case gap[:urgency] do
      :critical -> 1.5
      :high -> 1.2
      :normal -> 1.0
      :low -> 0.8
    end
    
    base_score * urgency_multiplier
  end
  
  defp calculate_tool_relevance(tools, requirements) when is_list(tools) and is_list(requirements) do
    if length(requirements) == 0 do
      50  # Base score if no specific requirements
    else
      matching_tools = Enum.count(requirements, fn req ->
        Enum.any?(tools, fn tool ->
          String.contains?(String.downcase(tool), String.downcase(req))
        end)
      end)
      
      (matching_tools / length(requirements)) * 100
    end
  end
  defp calculate_tool_relevance(_, _), do: 0
  
  defp calculate_description_match(description, gap) when is_binary(description) do
    keywords = extract_keywords(gap)
    
    matching_keywords = Enum.count(keywords, fn keyword ->
      String.contains?(String.downcase(description), String.downcase(keyword))
    end)
    
    if length(keywords) > 0 do
      (matching_keywords / length(keywords)) * 100
    else
      0
    end
  end
  defp calculate_description_match(_, _), do: 0
  
  defp extract_keywords(gap) do
    domain_words = String.split(gap[:domain] || "", " ")
    requirement_words = gap[:requirements] || []
    
    (domain_words ++ requirement_words)
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end
  
  defp get_historical_performance(server_name, state) do
    # Check acquisition history for this server
    history = Enum.filter(state.acquisition_history, fn entry ->
      entry.server == server_name
    end)
    
    if length(history) > 0 do
      success_count = Enum.count(history, & &1.outcome == :success)
      (success_count / length(history)) * 100
    else
      50  # Neutral score for unknown servers
    end
  end
  
  defp get_domain_affinity(candidate, domain, state) do
    # Check if this server has been successful in this domain
    domain_strategy = Map.get(state.domain_strategies, domain, %{})
    
    case Map.get(domain_strategy, :preferred_servers) do
      nil -> 50
      preferred when is_list(preferred) ->
        if candidate["name"] in preferred, do: 100, else: 25
    end
  end
  
  defp record_acquisition_success(result, state) do
    # Update acquisition history
    history_entry = Map.merge(result, %{outcome: :success})
    new_history = [history_entry | state.acquisition_history] |> Enum.take(1000)
    
    # Update success patterns
    pattern = extract_success_pattern(result)
    new_patterns = [pattern | state.success_patterns] |> Enum.take(100)
    
    # Update domain strategies
    new_strategies = update_domain_strategy(state.domain_strategies, result, :success)
    
    # Update capabilities and servers
    new_capabilities = Map.merge(state.capabilities, result.integration.state_updates.capabilities)
    new_servers = Map.merge(state.active_servers, result.integration.state_updates.active_servers)
    
    # Notify policy learner
    Task.start(fn ->
      PolicyLearner.record_successful_acquisition(result)
    end)
    
    %{state |
      acquisition_history: new_history,
      success_patterns: new_patterns,
      domain_strategies: new_strategies,
      capabilities: new_capabilities,
      active_servers: new_servers
    }
  end
  
  defp record_acquisition_failure(failure, state) do
    # Update acquisition history
    history_entry = Map.merge(failure, %{outcome: :failure})
    new_history = [history_entry | state.acquisition_history] |> Enum.take(1000)
    
    # Update failure patterns
    pattern = extract_failure_pattern(failure)
    new_patterns = [pattern | state.failure_patterns] |> Enum.take(100)
    
    # Update domain strategies
    new_strategies = update_domain_strategy(state.domain_strategies, failure, :failure)
    
    %{state |
      acquisition_history: new_history,
      failure_patterns: new_patterns,
      domain_strategies: new_strategies
    }
  end
  
  defp extract_success_pattern(result) do
    %{
      gap_type: result.gap[:type],
      domain: result.gap[:domain],
      server_type: categorize_server(result.server["name"]),
      urgency: result.gap[:urgency],
      acquisition_time: result.acquisition_time
    }
  end
  
  defp extract_failure_pattern(failure) do
    %{
      gap_type: failure.gap[:type],
      domain: failure.gap[:domain],
      failed_phase: failure.failed_phase,
      reason_category: categorize_failure_reason(failure.reason),
      urgency: failure.gap[:urgency]
    }
  end
  
  defp categorize_server(name) do
    cond do
      String.starts_with?(name, "@modelcontextprotocol/") -> :official
      String.contains?(name, "community") -> :community
      true -> :third_party
    end
  end
  
  defp categorize_failure_reason(reason) do
    case reason do
      {:timeout, _} -> :timeout
      {:connection_failed, _} -> :connection
      :no_suitable_candidates -> :no_match
      _ -> :other
    end
  end
  
  defp update_domain_strategy(strategies, result_or_failure, outcome) do
    domain = result_or_failure.gap[:domain]
    current_strategy = Map.get(strategies, domain, %{attempts: 0, successes: 0})
    
    updated_strategy = case outcome do
      :success ->
        %{current_strategy |
          attempts: current_strategy.attempts + 1,
          successes: current_strategy.successes + 1,
          preferred_servers: update_preferred_servers(
            current_strategy[:preferred_servers],
            result_or_failure.server["name"],
            :success
          )
        }
        
      :failure ->
        %{current_strategy |
          attempts: current_strategy.attempts + 1
        }
    end
    
    Map.put(strategies, domain, updated_strategy)
  end
  
  defp update_preferred_servers(nil, server_name, :success) do
    [server_name]
  end
  defp update_preferred_servers(current, server_name, :success) when is_list(current) do
    if server_name in current do
      current
    else
      [server_name | current] |> Enum.take(5)
    end
  end
  defp update_preferred_servers(current, _, _), do: current
  
  defp handle_critical_failure(gap, failure, state) do
    Logger.error("🚨 Critical acquisition failure - triggering emergency protocols")
    
    # Try emergency acquisition strategies
    emergency_result = case failure.failed_phase do
      :discover ->
        # Try manual server configuration if available
        try_manual_configuration(gap, state)
        
      :evaluate ->
        # Lower fitness threshold and retry
        retry_with_lower_threshold(gap, state)
        
      :acquire ->
        # Try alternative connection methods
        try_alternative_connection(gap, state)
        
      _ ->
        {:error, :emergency_failed}
    end
    
    case emergency_result do
      {:ok, result, new_state} ->
        {:ok, Map.put(result, :emergency_acquisition, true), new_state}
        
      error ->
        # Notify S5 for policy intervention
        notify_policy_system(gap, failure)
        error
    end
  end
  
  defp try_manual_configuration(gap, state) do
    # Check if we have any manually configured servers for this domain
    case Application.get_env(:vsm_phoenix, :manual_mcp_servers) do
      nil ->
        {:error, :no_manual_configuration}
        
      servers ->
        case Enum.find(servers, fn s -> s.domain == gap[:domain] end) do
          nil ->
            {:error, :no_matching_manual_server}
            
          server ->
            # Try to use the manual server
            execute_acquisition_pipeline(
              Map.put(gap, :manual_server, server),
              state
            )
        end
    end
  end
  
  defp retry_with_lower_threshold(gap, state) do
    # Temporarily lower the fitness threshold
    modified_state = put_in(state.config.min_fitness_threshold, 10)
    execute_acquisition_pipeline(gap, modified_state)
  end
  
  defp try_alternative_connection(gap, state) do
    # This would implement alternative connection strategies
    # For now, just return error
    {:error, :no_alternative_connection, state}
  end
  
  defp notify_policy_system(gap, failure) do
    Task.start(fn ->
      PolicySynthesizer.handle_acquisition_failure(%{
        gap: gap,
        failure: failure,
        timestamp: DateTime.utc_now()
      })
    end)
  end
  
  defp update_variety_metrics(state) do
    # Calculate current system variety
    system_variety = calculate_system_variety(state)
    
    # Get environmental variety from latest scan
    environmental_variety = get_environmental_variety(state)
    
    # Calculate ratio
    variety_ratio = if environmental_variety > 0 do
      system_variety / environmental_variety
    else
      1.0
    end
    
    %{state |
      system_variety: system_variety,
      environmental_variety: environmental_variety,
      variety_ratio: variety_ratio
    }
  end
  
  defp calculate_system_variety(state) do
    # Count total available tools across all capabilities
    tool_count = Enum.reduce(state.capabilities, 0, fn {_, cap}, acc ->
      acc + length(cap.tools)
    end)
    
    # Add base system variety
    base_variety = 10  # VSM's inherent variety
    
    base_variety + tool_count
  end
  
  defp calculate_initial_variety do
    # Initial system variety before any acquisitions
    10
  end
  
  defp get_environmental_variety(state) do
    # Get from latest scan or use last known value
    # This would typically come from S4 intelligence
    state.environmental_variety || 15
  end
  
  defp assess_requisite_variety(state) do
    cond do
      state.variety_ratio >= 1.0 -> :adequate
      state.variety_ratio >= 0.8 -> :marginal
      state.variety_ratio >= 0.6 -> :insufficient
      true -> :critical
    end
  end
  
  defp schedule_variety_scan(interval) do
    Process.send_after(self(), :variety_scan, interval)
  end
  
  defp generate_gap_id do
    "gap_#{System.unique_integer([:positive])}_#{System.system_time(:microsecond)}"
  end
  
  defp generate_pipeline_id do
    "pipeline_#{System.unique_integer([:positive])}"
  end
  
  defp default_config do
    %{
      scan_interval: 60_000,  # 1 minute
      min_fitness_threshold: 30,
      max_concurrent_acquisitions: 3,
      acquisition_timeout: 30_000,
      retry_attempts: 3
    }
  end
end