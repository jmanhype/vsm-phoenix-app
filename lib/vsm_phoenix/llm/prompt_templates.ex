defmodule VsmPhoenix.LLM.PromptTemplates do
  @moduledoc """
  Structured prompt templates for consistent LLM outputs.
  Provides templates for different VSM use cases with variable substitution.
  """
  
  @doc """
  Environmental scanning analysis template.
  Analyzes market signals, trends, and external factors.
  """
  def environmental_scan_template do
    %{
      name: "environmental_scan",
      system_prompt: """
      You are an expert business analyst specializing in environmental scanning and market intelligence.
      Your role is to analyze data for threats, opportunities, and emerging patterns.
      Provide structured, actionable insights focusing on viability and adaptation needs.
      """,
      user_prompt: """
      Analyze the following environmental scan data for a Viable System Model:

      Market Signals:
      <%= for signal <- market_signals do %>
      - Signal: <%= signal.signal %>, Strength: <%= signal.strength %>, Source: <%= signal.source %>
      <% end %>

      Technology Trends:
      <%= for trend <- technology_trends do %>
      - Trend: <%= trend.trend %>, Impact: <%= trend.impact %>, Timeline: <%= trend.timeline %>
      <% end %>

      Regulatory Updates:
      <%= for reg <- regulatory_updates do %>
      - Regulation: <%= reg.regulation %>, Status: <%= reg.status %>, Impact: <%= reg.impact %>
      <% end %>

      Competitive Moves:
      <%= for comp <- competitive_moves do %>
      - Competitor: <%= comp.competitor %>, Action: <%= comp.action %>, Threat Level: <%= comp.threat_level %>
      <% end %>

      Please provide:
      1. Key insights and patterns
      2. Potential threats to system viability
      3. Emerging opportunities
      4. Recommended adaptations
      5. Novel patterns or unexpected connections

      Format your response as structured JSON.
      """,
      output_schema: %{
        insights: "array of key insights",
        threats: "array of identified threats with severity",
        opportunities: "array of opportunities with potential impact",
        adaptations: "array of recommended adaptations",
        novel_patterns: "any unexpected patterns or connections",
        meta_analysis: "higher-level analysis of the system state"
      }
    }
  end
  
  @doc """
  Anomaly explanation template.
  Provides natural language explanations for detected anomalies.
  """
  def anomaly_explanation_template do
    %{
      name: "anomaly_explanation",
      system_prompt: """
      You are a systems analyst expert in explaining complex anomalies in simple terms.
      Your role is to help stakeholders understand what anomalies mean and their implications.
      Focus on clarity, actionability, and business impact.
      """,
      user_prompt: """
      Explain the following anomaly detected in our Viable System Model:

      Anomaly Type: <%= anomaly.type %>
      Severity: <%= anomaly.severity %>
      Description: <%= anomaly.description %>
      
      Data:
      <%= Jason.encode!(anomaly.data, pretty: true) %>
      
      Timestamp: <%= anomaly.timestamp %>
      Recommended Action: <%= anomaly.recommended_action %>

      Please provide:
      1. A clear explanation of what this anomaly means
      2. Why it matters for system viability
      3. Potential root causes
      4. Immediate actions to take
      5. Long-term implications if not addressed

      Write in clear, non-technical language suitable for management.
      """,
      output_schema: %{
        explanation: "clear explanation of the anomaly",
        significance: "why this matters",
        root_causes: "array of potential causes",
        immediate_actions: "array of actions to take now",
        long_term_implications: "what happens if not addressed"
      }
    }
  end
  
  @doc """
  Future scenario planning template.
  Generates multiple future scenarios based on current trends.
  """
  def scenario_planning_template do
    %{
      name: "scenario_planning",
      system_prompt: """
      You are a strategic foresight expert specializing in scenario planning.
      Your role is to generate plausible future scenarios based on current data and trends.
      Focus on both challenges and opportunities, providing actionable strategic options.
      """,
      user_prompt: """
      Based on the following current state and trends, generate future scenarios:

      Current System Health: <%= system_health %>
      
      Environmental Factors:
      <%= Jason.encode!(environmental_data, pretty: true) %>
      
      Current Adaptations:
      <%= for adaptation <- current_adaptations do %>
      - <%= adaptation.model_type %>: <%= Enum.join(adaptation.actions, ", ") %>
      <% end %>
      
      Key Metrics:
      - Scan Coverage: <%= metrics.scan_coverage %>
      - Prediction Accuracy: <%= metrics.prediction_accuracy %>
      - Innovation Index: <%= metrics.innovation_index %>

      Generate 3 scenarios:
      1. Optimistic scenario (things go well)
      2. Realistic scenario (mixed outcomes)
      3. Pessimistic scenario (challenges materialize)

      For each scenario, provide:
      - Description of the future state
      - Key events that lead to this outcome
      - Impact on system viability
      - Strategic recommendations
      """,
      output_schema: %{
        scenarios: [
          %{
            type: "optimistic|realistic|pessimistic",
            description: "narrative of the scenario",
            key_events: "array of events",
            viability_impact: "numerical 0-1",
            recommendations: "array of strategic actions"
          }
        ],
        common_threads: "patterns across all scenarios",
        critical_decisions: "key decision points"
      }
    }
  end
  
  @doc """
  Policy synthesis template.
  Generates new policies based on anomalies and system state.
  """
  def policy_synthesis_template do
    %{
      name: "policy_synthesis",
      system_prompt: """
      You are a policy architect for complex adaptive systems.
      Your role is to synthesize effective policies that maintain system viability.
      Focus on balance, adaptability, and emergent properties.
      """,
      user_prompt: """
      Synthesize a policy response for the following situation:

      Detected Anomalies:
      <%= for anomaly <- anomalies do %>
      - Type: <%= anomaly.type %>, Severity: <%= anomaly.severity %>
        Description: <%= anomaly.description %>
      <% end %>

      Current System State:
      - Viability Score: <%= viability_score %>
      - Resource Utilization: <%= Jason.encode!(resource_state) %>
      - Active Policies: <%= length(active_policies) %>

      System Context:
      <%= Jason.encode!(system_context, pretty: true) %>

      Design a policy that:
      1. Addresses the detected anomalies
      2. Maintains system viability
      3. Balances competing demands
      4. Allows for emergence and adaptation
      5. Can be implemented incrementally

      Structure the policy with clear triggers, actions, and success metrics.
      """,
      output_schema: %{
        policy_name: "descriptive name",
        objectives: "array of policy objectives",
        triggers: "conditions that activate the policy",
        actions: "specific actions to take",
        constraints: "boundaries and limitations",
        success_metrics: "how to measure effectiveness",
        adaptation_rules: "how the policy can evolve"
      }
    }
  end
  
  @doc """
  Variety amplification template.
  Analyzes data to discover novel patterns and hidden variety.
  """
  def variety_amplification_template do
    %{
      name: "variety_amplification",
      system_prompt: """
      You are a complexity scientist specializing in variety engineering.
      Your role is to discover hidden patterns, novel connections, and emergent properties.
      Think creatively and look for non-obvious relationships and recursive patterns.
      """,
      user_prompt: """
      Analyze the following system data for hidden variety and emergent patterns:

      System Snapshot:
      <%= Jason.encode!(system_data, pretty: true) %>

      Known Patterns:
      <%= for pattern <- known_patterns do %>
      - <%= pattern.name %>: <%= pattern.description %>
      <% end %>

      Recent Changes:
      <%= Jason.encode!(recent_changes, pretty: true) %>

      Please identify:
      1. Novel patterns not previously recognized
      2. Emergent properties from component interactions
      3. Recursive structures that could spawn meta-systems
      4. Hidden connections between seemingly unrelated elements
      5. Potential for self-organization or autopoiesis

      Be creative and speculative. Look for the unexpected.
      """,
      output_schema: %{
        novel_patterns: "map of pattern_id to description",
        emergent_properties: "map of property to explanation",
        recursive_potential: "array of recursive structures",
        hidden_connections: "array of connection descriptions",
        meta_system_seeds: "potential for meta-system spawning",
        variety_explosion_risk: "0-1 score of variety overwhelming the system"
      }
    }
  end
  
  @doc """
  Applies a template with the given variables.
  Returns the formatted prompt ready for LLM consumption.
  """
  def apply_template(template_name, variables \\ %{}) do
    template = get_template(template_name)
    
    user_prompt = EEx.eval_string(template.user_prompt, 
      assigns: Map.to_list(variables),
      engine: EEx.SmartEngine
    )
    
    %{
      system_prompt: template.system_prompt,
      user_prompt: user_prompt,
      output_schema: template.output_schema
    }
  end
  
  @doc """
  Validates that all required variables are present for a template.
  """
  def validate_variables(template_name, variables) do
    template = get_template(template_name)
    required = extract_required_variables(template.user_prompt)
    provided = Map.keys(variables) |> Enum.map(&to_string/1) |> MapSet.new()
    
    missing = MapSet.difference(required, provided) |> MapSet.to_list()
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_variables, missing}}
    end
  end
  
  @doc """
  Lists all available templates.
  """
  def list_templates do
    [
      environmental_scan_template(),
      anomaly_explanation_template(),
      scenario_planning_template(),
      policy_synthesis_template(),
      variety_amplification_template()
    ]
    |> Enum.map(fn template -> {template.name, template} end)
    |> Map.new()
  end
  
  # Private functions
  
  defp get_template(name) when is_atom(name), do: get_template(Atom.to_string(name))
  
  defp get_template("environmental_scan"), do: environmental_scan_template()
  defp get_template("anomaly_explanation"), do: anomaly_explanation_template()
  defp get_template("scenario_planning"), do: scenario_planning_template()
  defp get_template("policy_synthesis"), do: policy_synthesis_template()
  defp get_template("variety_amplification"), do: variety_amplification_template()
  
  defp get_template(name) do
    raise ArgumentError, "Unknown template: #{name}. Available templates: #{Map.keys(list_templates()) |> Enum.join(", ")}"
  end
  
  defp extract_required_variables(template_string) do
    # Extract <%= variable %> patterns
    Regex.scan(~r/<%= ([\w\.]+)/, template_string)
    |> Enum.map(fn [_, var] -> String.split(var, ".") |> List.first() end)
    |> Enum.uniq()
    |> MapSet.new()
  end
end