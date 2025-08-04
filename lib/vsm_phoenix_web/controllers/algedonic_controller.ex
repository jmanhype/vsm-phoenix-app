defmodule VsmPhoenixWeb.AlgedonicController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.VSM.AlgedonicSystem
  alias VsmPhoenix.VSM.AutonomicResponse
  alias VsmPhoenix.VSM.System5
  
  require Logger

  @doc """
  POST /api/algedonic/pain - Send pain signal through algedonic channels
  """
  def send_pain_signal(conn, params) do
    with {:ok, validated_params} <- validate_pain_signal_params(params),
         {:ok, signal_id} <- AlgedonicSystem.send_pain_signal(validated_params) do
      
      Logger.warning("Algedonic pain signal sent: #{signal_id} - Severity: #{validated_params.severity}")
      
      # Trigger immediate autonomic response for high severity pain
      autonomic_response = if validated_params.severity in ["high", "critical"] do
        AutonomicResponse.trigger_emergency_response(signal_id, validated_params)
      else
        nil
      end
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        signal_id: signal_id,
        message: "Pain signal sent successfully",
        details: %{
          source_system: validated_params.source_system,
          severity: validated_params.severity,
          signal_type: "pain",
          propagation_path: validated_params.propagation_path,
          autonomic_response: autonomic_response
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid pain signal parameters",
          details: errors
        })
      
      {:error, :signal_blocked} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Pain signal blocked",
          message: "System protection mechanisms have blocked the pain signal"
        })
      
      {:error, :system_overload} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "System overload",
          message: "Algedonic system is overloaded and cannot process additional pain signals"
        })
      
      {:error, reason} ->
        Logger.error("Pain signal transmission failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Pain signal transmission failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/algedonic/pleasure - Send pleasure signal through algedonic channels
  """
  def send_pleasure_signal(conn, params) do
    with {:ok, validated_params} <- validate_pleasure_signal_params(params),
         {:ok, signal_id} <- AlgedonicSystem.send_pleasure_signal(validated_params) do
      
      Logger.info("Algedonic pleasure signal sent: #{signal_id} - Intensity: #{validated_params.intensity}")
      
      # Reinforce successful behaviors for high intensity pleasure
      reinforcement_result = if validated_params.intensity in ["high", "very_high"] do
        AutonomicResponse.reinforce_positive_behavior(signal_id, validated_params)
      else
        nil
      end
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        signal_id: signal_id,
        message: "Pleasure signal sent successfully",
        details: %{
          source_system: validated_params.source_system,
          intensity: validated_params.intensity,
          signal_type: "pleasure",
          reward_context: validated_params.reward_context,
          reinforcement_applied: reinforcement_result
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid pleasure signal parameters",
          details: errors
        })
      
      {:error, :signal_suppressed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Pleasure signal suppressed",
          message: "Current system state suppresses pleasure signals to maintain focus on critical issues"
        })
      
      {:error, reason} ->
        Logger.error("Pleasure signal transmission failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Pleasure signal transmission failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/algedonic/signals - List algedonic signals
  """
  def list_signals(conn, params) do
    try do
      filter_params = %{
        signal_type: Map.get(params, "type"),  # "pain", "pleasure", or nil for both
        severity: Map.get(params, "severity"),
        time_range: parse_time_range(Map.get(params, "time_range", "1h")),
        source_system: Map.get(params, "source_system"),
        active_only: Map.get(params, "active_only", "false") == "true",
        limit: parse_integer(Map.get(params, "limit", "100"))
      }
      
      signals = AlgedonicSystem.list_signals(filter_params)
      
      enriched_signals = Enum.map(signals, fn signal ->
        Map.merge(signal, %{
          autonomic_responses: AutonomicResponse.get_responses_for_signal(signal.id),
          propagation_history: AlgedonicSystem.get_propagation_history(signal.id),
          impact_metrics: AlgedonicSystem.calculate_signal_impact(signal.id)
        })
      end)
      
      conn
      |> json(%{
        success: true,
        signals: enriched_signals,
        count: length(signals),
        summary: %{
          pain_signals: Enum.count(signals, & &1.type == "pain"),
          pleasure_signals: Enum.count(signals, & &1.type == "pleasure"),
          high_severity: Enum.count(signals, & &1.severity in ["high", "critical"]),
          active_signals: Enum.count(signals, & &1.status == "active")
        },
        filters_applied: filter_params
      })
    rescue
      error ->
        Logger.error("Failed to list algedonic signals: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve algedonic signals"
        })
    end
  end

  @doc """
  POST /api/algedonic/bypass - S1→S5 bypass
  """
  def algedonic_bypass(conn, params) do
    with {:ok, validated_params} <- validate_bypass_params(params),
         {:ok, bypass_id} <- AlgedonicSystem.create_s1_s5_bypass(validated_params) do
      
      Logger.warning("Algedonic S1→S5 bypass created: #{bypass_id} - Priority: #{validated_params.priority}")
      
      # Notify System 5 of direct bypass
      system5_notification = System5.notify_algedonic_bypass(bypass_id, validated_params)
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        bypass_id: bypass_id,
        message: "S1→S5 algedonic bypass established successfully",
        details: %{
          source_system: "s1",
          target_system: "s5",
          bypass_type: validated_params.bypass_type,
          priority: validated_params.priority,
          urgency_level: validated_params.urgency_level,
          expected_duration: validated_params.duration,
          system5_acknowledgment: system5_notification
        },
        warnings: [
          "This bypass circumvents normal VSM hierarchy",
          "Use only for critical system conditions",
          "Monitor for system stability impacts"
        ]
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid bypass parameters",
          details: errors
        })
      
      {:error, :bypass_blocked} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Bypass blocked by System 5",
          message: "System 5 has blocked the bypass due to current system state or policy restrictions"
        })
      
      {:error, :system_overload} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "System overload",
          message: "Too many active bypasses. Wait for existing bypasses to complete."
        })
      
      {:error, reason} ->
        Logger.error("Algedonic bypass failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Bypass creation failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/algedonic/autonomic - Get autonomic responses
  """
  def get_autonomic_responses(conn, params) do
    try do
      filter_params = %{
        signal_id: Map.get(params, "signal_id"),
        response_type: Map.get(params, "type"),
        system_level: Map.get(params, "system_level"),
        time_range: parse_time_range(Map.get(params, "time_range", "1h")),
        effectiveness_threshold: parse_float(Map.get(params, "min_effectiveness", "0.0")),
        active_only: Map.get(params, "active_only", "false") == "true",
        limit: parse_integer(Map.get(params, "limit", "100"))
      }
      
      responses = AutonomicResponse.get_autonomic_responses(filter_params)
      
      enriched_responses = Enum.map(responses, fn response ->
        Map.merge(response, %{
          trigger_signal: AlgedonicSystem.get_signal(response.signal_id),
          effectiveness_metrics: AutonomicResponse.calculate_detailed_effectiveness(response.id),
          system_impact_analysis: AutonomicResponse.analyze_system_impact(response.id),
          physiological_changes: AutonomicResponse.get_physiological_changes(response.id),
          behavioral_adaptations: AutonomicResponse.get_behavioral_adaptations(response.id)
        })
      end)
      
      conn
      |> json(%{
        success: true,
        autonomic_responses: enriched_responses,
        count: length(responses),
        system_health: %{
          autonomic_balance: AutonomicResponse.measure_autonomic_balance(responses),
          response_latency_avg: AutonomicResponse.calculate_avg_response_latency(responses),
          adaptation_effectiveness: AutonomicResponse.measure_adaptation_effectiveness(responses),
          homeostasis_stability: AutonomicResponse.assess_homeostasis_stability(responses)
        },
        filters_applied: filter_params
      })
    rescue
      error ->
        Logger.error("Failed to get autonomic responses: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve autonomic responses"
        })
    end
  end

  @doc """
  GET /api/algedonic/responses - List autonomic responses (legacy endpoint)
  """
  def list_autonomic_responses(conn, params) do
    try do
      filter_params = %{
        response_type: Map.get(params, "type"),
        trigger_signal: Map.get(params, "signal_id"),
        system_level: Map.get(params, "system_level"),
        time_range: parse_time_range(Map.get(params, "time_range", "1h")),
        effectiveness_threshold: parse_float(Map.get(params, "min_effectiveness", "0.0")),
        limit: parse_integer(Map.get(params, "limit", "100"))
      }
      
      responses = AutonomicResponse.list_responses(filter_params)
      
      enriched_responses = Enum.map(responses, fn response ->
        Map.merge(response, %{
          trigger_signal: AlgedonicSystem.get_signal(response.signal_id),
          effectiveness_score: AutonomicResponse.calculate_effectiveness(response.id),
          system_impact: AutonomicResponse.measure_system_impact(response.id),
          related_responses: AutonomicResponse.find_related_responses(response.id)
        })
      end)
      
      conn
      |> json(%{
        success: true,
        responses: enriched_responses,
        count: length(responses),
        analytics: %{
          response_types: AutonomicResponse.get_response_type_distribution(responses),
          avg_effectiveness: AutonomicResponse.calculate_avg_effectiveness(responses),
          system_adaptation_rate: AutonomicResponse.measure_adaptation_rate(responses),
          pain_vs_pleasure_responses: AutonomicResponse.analyze_response_triggers(responses)
        },
        filters_applied: filter_params
      })
    rescue
      error ->
        Logger.error("Failed to list autonomic responses: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve autonomic responses"
        })
    end
  end

  # Private helper functions

  defp validate_pain_signal_params(params) do
    required_fields = ["source_system", "severity", "description"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        severity = params["severity"]
        source_system = params["source_system"]
        
        cond do
          severity not in ["low", "medium", "high", "critical"] ->
            {:error, :invalid_params, "Severity must be one of: low, medium, high, critical"}
          
          source_system not in ["s1", "s2", "s3", "s4", "s5", "external", "internal"] ->
            {:error, :invalid_params, "Invalid source system"}
          
          true ->
            validated = %{
              source_system: source_system,
              severity: severity,
              description: params["description"],
              pain_type: Map.get(params, "pain_type", "generic"),
              propagation_path: Map.get(params, "propagation_path", ["system5"]),
              immediate_action_required: Map.get(params, "immediate_action", false),
              context_data: Map.get(params, "context", %{})
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_pleasure_signal_params(params) do
    required_fields = ["source_system", "intensity", "reward_context"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        intensity = params["intensity"]
        source_system = params["source_system"]
        
        cond do
          intensity not in ["very_low", "low", "medium", "high", "very_high"] ->
            {:error, :invalid_params, "Intensity must be one of: very_low, low, medium, high, very_high"}
          
          source_system not in ["s1", "s2", "s3", "s4", "s5", "external", "internal"] ->
            {:error, :invalid_params, "Invalid source system"}
          
          true ->
            validated = %{
              source_system: source_system,
              intensity: intensity,
              reward_context: params["reward_context"],
              pleasure_type: Map.get(params, "pleasure_type", "achievement"),
              behavior_to_reinforce: Map.get(params, "behavior_to_reinforce"),
              learning_context: Map.get(params, "learning_context", %{})
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_required_fields(params, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      is_nil(params[field]) or params[field] == ""
    end)
    
    if length(missing_fields) == 0 do
      {:ok, params}
    else
      {:error, :invalid_params, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp parse_time_range("1h"), do: {DateTime.utc_now() |> DateTime.add(-3600, :second), DateTime.utc_now()}
  defp parse_time_range("6h"), do: {DateTime.utc_now() |> DateTime.add(-21600, :second), DateTime.utc_now()}
  defp parse_time_range("24h"), do: {DateTime.utc_now() |> DateTime.add(-86400, :second), DateTime.utc_now()}
  defp parse_time_range("7d"), do: {DateTime.utc_now() |> DateTime.add(-604800, :second), DateTime.utc_now()}
  defp parse_time_range(_), do: {DateTime.utc_now() |> DateTime.add(-3600, :second), DateTime.utc_now()}

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> int_val
      :error -> 0
    end
  end
  defp parse_integer(_), do: 0

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp validate_bypass_params(params) do
    required_fields = ["bypass_type", "priority", "urgency_level"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        bypass_type = params["bypass_type"]
        priority = params["priority"]
        urgency_level = params["urgency_level"]
        
        cond do
          bypass_type not in ["emergency", "critical_alert", "system_failure", "security_breach", "resource_depletion"] ->
            {:error, :invalid_params, "Invalid bypass type"}
          
          priority not in ["low", "medium", "high", "critical", "emergency"] ->
            {:error, :invalid_params, "Invalid priority level"}
          
          urgency_level not in ["routine", "urgent", "critical", "immediate"] ->
            {:error, :invalid_params, "Invalid urgency level"}
          
          true ->
            validated = %{
              bypass_type: bypass_type,
              priority: priority,
              urgency_level: urgency_level,
              duration: parse_integer(Map.get(params, "duration", "300")),  # 5 minutes default
              override_safety: Map.get(params, "override_safety", false),
              context_data: Map.get(params, "context", %{}),
              description: params["description"] || "Emergency S1→S5 bypass",
              requester: Map.get(params, "requester", "system")
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end
end