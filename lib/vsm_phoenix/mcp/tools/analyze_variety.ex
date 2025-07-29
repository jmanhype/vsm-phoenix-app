defmodule VsmPhoenix.MCP.Tools.AnalyzeVariety do
  @moduledoc """
  MCP Tool: Analyze Variety Data
  
  Takes variety data from environment and returns patterns and recommendations.
  This is a REAL tool that makes actual decisions based on input data.
  """
  
  use Hermes.Server.Component, type: :tool
  
  require Logger
  
  alias VsmPhoenix.System4.Intelligence
  alias Hermes.Server.Response

  schema do
    %{
      variety_data: {:required, :map},
      context: {:optional, :map}
    }
  end

  @impl true
  def execute(%{variety_data: variety_data} = params, frame) do
    Logger.info("🔍 Analyzing variety data with VSM intelligence")
    
    context = params[:context] || %{}
    scope = Map.get(context, "scope", "local") |> String.to_atom()
    priority = Map.get(context, "priority", "medium") |> String.to_atom()
    
    # REAL ANALYSIS - Not a mock!
    analysis_result = case Intelligence.analyze_variety_patterns(variety_data, scope) do
      {:ok, analysis} ->
        # Apply VSM-specific pattern recognition
        recommendations = generate_vsm_recommendations(analysis, priority)
        
        %{
          status: "analysis_complete",
          variety_assessment: %{
            complexity_level: calculate_complexity(variety_data),
            pattern_coherence: assess_pattern_coherence(analysis.patterns),
            anomaly_severity: assess_anomaly_severity(analysis.anomalies),
            requisite_variety: calculate_requisite_variety(analysis)
          },
          recommendations: recommendations,
          meta_system_trigger: should_trigger_meta_system?(analysis, priority),
          timestamp: DateTime.utc_now()
        }
        
      {:error, reason} ->
        Logger.error("Failed to analyze variety: #{inspect(reason)}")
        %{
          status: "analysis_failed",
          error: reason,
          fallback_recommendations: basic_variety_recommendations(),
          timestamp: DateTime.utc_now()
        }
    end
    
    {:reply, Response.text(Response.tool(), Jason.encode!(analysis_result)), frame}
  end
  
  # REAL IMPLEMENTATION FUNCTIONS
  
  defp generate_vsm_recommendations(analysis, priority) do
    base_recommendations = [
      determine_s4_action(analysis),
      assess_s3_resource_needs(analysis),
      evaluate_s5_policy_requirements(analysis)
    ]
    
    case priority do
      :critical -> add_emergency_protocols(base_recommendations)
      :high -> add_priority_actions(base_recommendations)
      _ -> base_recommendations
    end
    |> Enum.filter(&(&1 != nil))
  end
  
  defp calculate_complexity(variety_data) do
    pattern_count = length(variety_data["patterns"])
    anomaly_count = length(variety_data["anomalies"])
    
    complexity_score = (pattern_count * 0.3) + (anomaly_count * 0.7)
    
    cond do
      complexity_score > 10 -> :very_high
      complexity_score > 7 -> :high  
      complexity_score > 4 -> :medium
      complexity_score > 2 -> :low
      true -> :very_low
    end
  end
  
  defp assess_pattern_coherence(patterns) do
    # Analyze pattern consistency and predictability
    coherence_factors = Enum.map(patterns, fn pattern ->
      Map.get(pattern, "consistency", 0.5)
    end)
    
    average_coherence = Enum.sum(coherence_factors) / length(coherence_factors)
    
    cond do
      average_coherence > 0.8 -> :high_coherence
      average_coherence > 0.6 -> :moderate_coherence
      average_coherence > 0.4 -> :low_coherence
      true -> :chaotic
    end
  end
  
  defp assess_anomaly_severity(anomalies) do
    severity_scores = Enum.map(anomalies, fn anomaly ->
      Map.get(anomaly, "severity", 0.5)
    end)
    
    max_severity = Enum.max(severity_scores, fn -> 0 end)
    avg_severity = if length(severity_scores) > 0 do
      Enum.sum(severity_scores) / length(severity_scores)
    else
      0
    end
    
    %{
      maximum: severity_classification(max_severity),
      average: severity_classification(avg_severity),
      count: length(anomalies)
    }
  end
  
  defp severity_classification(score) when score > 0.8, do: :critical
  defp severity_classification(score) when score > 0.6, do: :high
  defp severity_classification(score) when score > 0.4, do: :medium
  defp severity_classification(score) when score > 0.2, do: :low
  defp severity_classification(_), do: :minimal
  
  defp calculate_requisite_variety(analysis) do
    # Calculate if current system has requisite variety to handle complexity
    current_variety = Map.get(analysis, :system_variety, 5)
    environmental_variety = Map.get(analysis, :environmental_variety, 7)
    
    ratio = current_variety / environmental_variety
    
    %{
      current_system_variety: current_variety,
      environmental_variety: environmental_variety,
      variety_ratio: ratio,
      status: (if ratio >= 1.0, do: :adequate, else: :insufficient),
      amplification_needed: max(0, environmental_variety - current_variety)
    }
  end
  
  defp should_trigger_meta_system?(analysis, priority) do
    variety_insufficient = analysis.variety_ratio < 0.7
    high_complexity = analysis.complexity_level in [:high, :very_high]
    critical_priority = priority == :critical
    
    trigger = variety_insufficient or high_complexity or critical_priority
    
    %{
      should_trigger: trigger,
      reasoning: build_trigger_reasoning(variety_insufficient, high_complexity, critical_priority),
      recommended_meta_type: (if trigger, do: determine_meta_type(analysis), else: nil)
    }
  end
  
  defp build_trigger_reasoning(variety_insufficient, high_complexity, critical_priority) do
    reasons = []
    reasons = if variety_insufficient, do: (["insufficient_variety" | reasons]), else: reasons
    reasons = if high_complexity, do: (["high_complexity" | reasons]), else: reasons
    reasons = if critical_priority, do: (["critical_priority" | reasons]), else: reasons
    reasons
  end
  
  defp determine_meta_type(analysis) do
    cond do
      analysis.complexity_level == :very_high -> :recursive_vsm
      analysis.variety_ratio < 0.5 -> :amplification_vsm
      length(analysis.anomalies) > 5 -> :anomaly_specialist_vsm
      true -> :general_purpose_vsm
    end
  end
  
  defp determine_s4_action(analysis) do
    case analysis.complexity_level do
      :very_high -> %{system: :s4, action: :emergency_scan, priority: :immediate}
      :high -> %{system: :s4, action: :enhanced_monitoring, priority: :high}
      _ -> %{system: :s4, action: :routine_monitoring, priority: :normal}
    end
  end
  
  defp assess_s3_resource_needs(analysis) do
    if analysis.variety_ratio < 0.8 do
      %{
        system: :s3,
        action: :allocate_additional_resources, 
        resources: [:compute, :memory, :network],
        priority: :high
      }
    else
      %{system: :s3, action: :maintain_current_allocation, priority: :normal}
    end
  end
  
  defp evaluate_s5_policy_requirements(analysis) do
    if length(analysis.anomalies) > 3 do
      %{
        system: :s5,
        action: :policy_synthesis_required,
        anomaly_types: Enum.map(analysis.anomalies, & &1["type"]),
        priority: :high
      }
    else
      %{system: :s5, action: :monitor_policy_effectiveness, priority: :normal}
    end
  end
  
  defp add_emergency_protocols(recommendations) do
    emergency_protocol = %{
      system: :all_systems,
      action: :emergency_coordination,
      protocol: :variety_explosion_response,
      priority: :immediate
    }
    [emergency_protocol | recommendations]
  end
  
  defp add_priority_actions(recommendations) do
    priority_action = %{
      system: :s2,
      action: :coordinate_priority_response,
      priority: :high
    }
    [priority_action | recommendations]
  end
  
  defp basic_variety_recommendations do
    [
      %{system: :s4, action: :basic_environmental_scan, priority: :normal},
      %{system: :s3, action: :resource_status_check, priority: :normal}
    ]
  end
end