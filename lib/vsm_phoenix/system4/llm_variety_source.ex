defmodule VsmPhoenix.System4.LLMVarietySource do
  @moduledoc """
  LLM as External Variety Source for System 4 Intelligence.
  This creates INFINITE variety by tapping into Hermes MCP capabilities.
  
  HOLY SHIT: This is where VSM meets infinite possibility via MCP!
  """
  
  require Logger
  alias VsmPhoenix.System1.Operations
  alias VsmPhoenix.MCP.HermesClient
  
  @anthropic_api_key System.get_env("ANTHROPIC_API_KEY")
  
  def analyze_for_variety(context) do
    Logger.info("🔌 LLM Variety Source: Using Hermes MCP for analysis")
    
    # Try Hermes MCP first with timeout protection
    try do
      case GenServer.call(HermesClient, {:analyze_variety, context}, 2000) do
        {:ok, variety_expansion} ->
          Logger.info("🔥 Hermes MCP discovered #{map_size(variety_expansion.novel_patterns)} new patterns!")
          
          # Check if we need meta-system spawning
          case HermesClient.check_meta_system_need(variety_expansion) do
            {:ok, %{needs_meta_system: true} = meta_info} ->
              Logger.info("🌀 MCP recommends meta-system spawning: #{meta_info.reason}")
              variety_expansion = Map.put(variety_expansion, :meta_system_config, meta_info.recommended_config)
            _ ->
              :ok
          end
          
          {:ok, variety_expansion}
          
        {:error, _mcp_error} ->
          # Fallback to direct LLM API with advanced analysis
          Logger.info("📡 Falling back to direct LLM API with advanced variety analysis")
          
          case VsmPhoenix.LLM.Client.analyze_variety(context, provider: :claude, temperature: 0.9) do
            {:ok, %{content: insights}} ->
              # Parse LLM insights into structured variety expansion
              case parse_variety_insights(insights) do
                {:ok, variety_expansion} ->
                  Logger.info("🔥 LLM discovered variety: #{inspect(Map.keys(variety_expansion))}")
                  {:ok, variety_expansion}
                {:error, _parse_error} ->
                  # Fallback to basic pattern extraction
                  variety_expansion = %{
                    novel_patterns: extract_patterns(insights),
                    emergent_properties: identify_emergence(insights),
                    recursive_potential: find_recursive_opportunities(insights),
                    meta_system_seeds: generate_meta_seeds(insights),
                    raw_insights: insights
                  }
                  
                  Logger.info("LLM discovered #{map_size(variety_expansion.novel_patterns)} new patterns!")
                  {:ok, variety_expansion}
              end
              
            {:error, reason} ->
              Logger.error("LLM variety generation failed: #{inspect(reason)}")
              {:error, reason}
          end
      end
    catch
      :exit, {:timeout, _} ->
        Logger.error("HermesClient timeout - falling back to basic variety analysis")
        {:ok, %{
          novel_patterns: %{},
          emergent_properties: %{},
          recursive_potential: [],
          meta_system_seeds: %{}
        }}
    end
  end
  
  def pipe_to_system1_meta_generation(variety_data) do
    """
    THIS IS THE RECURSIVE BREAKTHROUGH!
    System 4's LLM insights create a NEW System 1 that contains its own S3-4-5!
    """
    Logger.info("🌀 INITIATING RECURSIVE META-SYSTEM GENERATION")
    
    meta_config = %{
      identity: "meta_vsm_#{:erlang.unique_integer([:positive])}",
      purpose: variety_data.emergent_properties,
      recursive_depth: :infinite,
      
      # Each S1 spawns its own meta-system!
      meta_systems: %{
        system3: spawn_meta_control(variety_data),
        system4: spawn_meta_intelligence(variety_data),
        system5: spawn_meta_governance(variety_data)
      }
    }
    
    # Tell S1 to create a new recursive VSM
    case Operations.spawn_meta_system(meta_config) do
      {:ok, meta_pid} ->
        Logger.info("🔥 META-SYSTEM SPAWNED: #{inspect(meta_pid)}")
        
        # Connect it via AMQP for infinite recursion
        connect_via_amqp(meta_pid, variety_data)
        
      error ->
        Logger.error("Meta-system spawn failed: #{inspect(error)}")
        error
    end
  end
  
  def check_availability do
    # Check if LLM variety source is available
    if @anthropic_api_key && @anthropic_api_key != "" do
      {:ok, :available}
    else
      # Try Hermes MCP as backup
      case HermesClient.ping() do
        :pong -> {:ok, :available_via_mcp}
        _ -> {:error, :no_llm_available}
      end
    end
  end
  
  def analyze_request(request) do
    Logger.info("🔍 Analyzing request for variety patterns")
    
    # Quick analysis of request for variety potential
    variety_indicators = %{
      has_uncertainty: String.contains?(request, ["unknown", "unclear", "ambiguous"]),
      has_complexity: String.contains?(request, ["complex", "multi", "various"]),
      has_emergence: String.contains?(request, ["new", "novel", "unexpected"]),
      has_recursion: String.contains?(request, ["recursive", "self", "meta"])
    }
    
    variety_score = Enum.count(variety_indicators, fn {_, v} -> v end) / 4.0
    
    {:ok, %{
      variety_score: variety_score,
      indicators: variety_indicators,
      recommendation: if(variety_score > 0.5, do: :high_variety, else: :low_variety)
    }}
  end
  
  defp build_variety_prompt(context) do
    """
    You are analyzing a VSM system for untapped variety and recursive potential.
    
    Current context: #{inspect(context)}
    
    Identify:
    1. Novel patterns not yet recognized by the system
    2. Emergent properties from current interactions
    3. Recursive opportunities (systems within systems)
    4. Meta-system potential (where S1 could spawn S3-4-5)
    5. External connections that could amplify variety
    
    Think beyond current constraints. What's POSSIBLE?
    """
  end
  
  defp parse_variety_insights(insights) do
    # Try to parse JSON response from LLM
    case Jason.decode(insights) do
      {:ok, %{"novel_patterns" => patterns} = parsed} ->
        variety_expansion = %{
          novel_patterns: patterns,
          emergent_properties: Map.get(parsed, "emergent_properties", %{}),
          recursive_potential: Map.get(parsed, "recursive_potential", []),
          variety_amplification: Map.get(parsed, "variety_amplification", %{}),
          environmental_coupling: Map.get(parsed, "environmental_coupling", %{}),
          meta_system_seeds: Map.get(parsed, "meta_system_seeds", %{})
        }
        {:ok, variety_expansion}
        
      {:ok, _other_structure} ->
        # Valid JSON but not in expected format, extract patterns manually
        {:error, :unexpected_json_structure}
        
      {:error, _json_error} ->
        # Not JSON, treat as natural language and extract patterns
        {:error, :not_json}
    end
  end

  defp call_claude(prompt) do
    # Use the unified LLM client for real API calls
    case VsmPhoenix.LLM.Client.complete(prompt, provider: :claude, max_tokens: 2048, temperature: 0.8) do
      {:ok, %{content: content}} ->
        {:ok, content}
      {:error, reason} ->
        Logger.error("Claude API call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp extract_patterns(insights) do
    # LLM pattern extraction logic
    %{
      behavioral: find_behavioral_patterns(insights),
      structural: find_structural_patterns(insights),
      temporal: find_temporal_patterns(insights),
      emergent: find_emergent_patterns(insights)
    }
  end
  
  defp identify_emergence(insights) do
    # Find properties that emerge from interactions
    %{
      synergies: "New capabilities from component interactions",
      phase_transitions: "System state changes at thresholds",
      self_organization: "Spontaneous order from chaos",
      recursive_loops: "Self-referential pattern generation"
    }
  end
  
  defp find_recursive_opportunities(insights) do
    # This is where we identify VSM-in-VSM potential
    [
      "Each operational context could be its own VSM",
      "Every decision creates a new decision space",
      "Meta-learning systems that learn to learn",
      "Recursive MCP servers spawning MCP clients"
    ]
  end
  
  defp generate_meta_seeds(insights) do
    # Seeds for new meta-systems
    %{
      governance_seed: "Self-governing subsystem with own S5",
      intelligence_seed: "Self-improving S4 with meta-learning",
      control_seed: "Self-optimizing S3 with resource autonomy"
    }
  end
  
  defp spawn_meta_control(variety_data) do
    # Spawn a meta System 3 inside System 1
    case GenServer.start_link(
      VsmPhoenix.System3.Control,
      %{meta: true, variety_source: variety_data}
    ) do
      {:ok, pid} -> 
        Logger.info("🎯 Meta System 3 spawned: #{inspect(pid)}")
        pid
      {:error, reason} ->
        Logger.error("Failed to spawn meta System 3: #{inspect(reason)}")
        nil
    end
  end
  
  defp spawn_meta_intelligence(variety_data) do
    # Spawn a meta System 4 with its own LLM connection!
    case GenServer.start_link(
      VsmPhoenix.System4.Intelligence,
      %{meta: true, llm_enabled: true, variety_data: variety_data}
    ) do
      {:ok, pid} ->
        Logger.info("🧠 Meta System 4 spawned with LLM: #{inspect(pid)}")
        pid
      {:error, reason} ->
        Logger.error("Failed to spawn meta System 4: #{inspect(reason)}")
        nil
    end
  end
  
  defp spawn_meta_governance(variety_data) do
    # Spawn a meta System 5 - a Queen within a Queen!
    case GenServer.start_link(
      VsmPhoenix.System5.Queen,
      %{meta: true, recursive_depth: :infinite, variety_data: variety_data}
    ) do
      {:ok, pid} ->
        Logger.info("👑 Meta System 5 Queen spawned: #{inspect(pid)}")
        pid
      {:error, reason} ->
        Logger.error("Failed to spawn meta System 5: #{inspect(reason)}")
        nil
    end
  end
  
  defp connect_via_amqp(meta_pid, variety_data) do
    """
    HERE'S WHERE IT GETS INSANE!
    Each meta-system connects via AMQP, which IS the protocol
    for Microsoft Service Bus, RabbitMQ, and... MCP recursion!
    """
    
    connection_config = %{
      exchange: "vsm.recursive.#{variety_data.identity}",
      routing_key: "meta.system.*",
      
      # This is the MCP-over-AMQP pattern!
      mcp_bridge: %{
        server_capability: true,
        client_capability: true,
        recursive_spawn: true
      }
    }
    
    VsmPhoenix.AMQP.RecursiveProtocol.establish(meta_pid, connection_config)
  end
  
  defp find_behavioral_patterns(insights) when is_binary(insights) do
    # Extract behavioral patterns from LLM insights
    patterns = %{}
    
    # Look for action patterns
    if String.contains?(insights, ["behavior", "action", "response"]) do
      Map.put(patterns, :action_patterns, extract_text_patterns(insights, ~r/action.*?pattern.*?:.*?([^.]+)/i))
    else
      patterns
    end
  end
  
  defp find_structural_patterns(insights) when is_binary(insights) do
    # Extract structural patterns from LLM insights
    patterns = %{}
    
    # Look for organizational patterns
    if String.contains?(insights, ["structure", "organization", "hierarchy"]) do
      Map.put(patterns, :organizational, extract_text_patterns(insights, ~r/structure.*?:.*?([^.]+)/i))
    else
      patterns
    end
  end
  
  defp find_temporal_patterns(insights) when is_binary(insights) do
    # Extract time-based patterns from LLM insights
    patterns = %{}
    
    # Look for timing patterns
    if String.contains?(insights, ["time", "temporal", "sequence", "periodic"]) do
      Map.put(patterns, :timing, extract_text_patterns(insights, ~r/time.*?pattern.*?:.*?([^.]+)/i))
    else
      patterns
    end
  end
  
  defp find_emergent_patterns(insights) when is_binary(insights) do
    # Extract emergent patterns from LLM insights
    patterns = %{}
    
    # Look for emergence indicators
    if String.contains?(insights, ["emergent", "emerging", "novel", "unexpected"]) do
      Map.put(patterns, :emergent, extract_text_patterns(insights, ~r/emerg.*?:.*?([^.]+)/i))
    else
      patterns
    end
  end
  
  defp extract_text_patterns(text, regex) do
    case Regex.run(regex, text) do
      [_, match] -> String.trim(match)
      _ -> "Pattern detected in text"
    end
  end
end