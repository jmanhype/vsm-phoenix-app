defmodule VsmPhoenixWeb.EmergentController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.VSM.EmergentIntelligence
  alias VsmPhoenix.VSM.SwarmBehaviour
  alias VsmPhoenix.VSM.PatternDetection
  
  require Logger

  @doc """
  POST /api/emergent/swarm/init - Initialize swarm intelligence
  """
  def init_swarm(conn, params) do
    with {:ok, validated_params} <- validate_swarm_params(params),
         {:ok, swarm_id} <- SwarmBehaviour.initialize_swarm(validated_params) do
      
      Logger.info("Emergent swarm initialized: #{swarm_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        swarm_id: swarm_id,
        message: "Swarm intelligence initialized successfully",
        details: %{
          agent_count: validated_params.agent_count,
          behavior_rules: validated_params.behavior_rules,
          interaction_radius: validated_params.interaction_radius,
          learning_rate: validated_params.learning_rate
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid swarm parameters",
          details: errors
        })
      
      {:error, :resource_limit} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "Resource limit exceeded",
          message: "Cannot initialize swarm: system resource limits reached"
        })
      
      {:error, reason} ->
        Logger.error("Swarm initialization failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Swarm initialization failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/emergent/pattern/detect - Detect emergent patterns
  """
  def detect_patterns(conn, params) do
    with {:ok, validated_params} <- validate_pattern_params(params),
         {:ok, patterns} <- PatternDetection.detect_patterns(validated_params) do
      
      Logger.info("Pattern detection completed: #{length(patterns)} patterns found")
      
      conn
      |> json(%{
        success: true,
        patterns: patterns,
        count: length(patterns),
        detection_details: %{
          data_source: validated_params.data_source,
          pattern_types: validated_params.pattern_types,
          confidence_threshold: validated_params.confidence_threshold
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid pattern detection parameters",
          details: errors
        })
      
      {:error, :insufficient_data} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Insufficient data for pattern detection",
          message: "Need more data points to identify meaningful patterns"
        })
      
      {:error, reason} ->
        Logger.error("Pattern detection failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Pattern detection failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/emergent/behaviors - List emergent behaviors
  """
  def list_behaviors(conn, params) do
    try do
      filter_params = %{
        swarm_id: Map.get(params, "swarm_id"),
        behavior_type: Map.get(params, "type"),
        active_only: Map.get(params, "active_only", "false") == "true",
        min_complexity: parse_float(Map.get(params, "min_complexity", "0.0"))
      }
      
      behaviors = EmergentIntelligence.list_behaviors(filter_params)
      
      enriched_behaviors = Enum.map(behaviors, fn behavior ->
        Map.put(behavior, :emergence_metrics, EmergentIntelligence.get_emergence_metrics(behavior.id))
      end)
      
      conn
      |> json(%{
        success: true,
        behaviors: enriched_behaviors,
        count: length(behaviors),
        filters_applied: filter_params
      })
    rescue
      error ->
        Logger.error("Failed to list emergent behaviors: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve emergent behaviors"
        })
    end
  end

  @doc """
  POST /api/emergent/learn - Collective learning operation
  """
  def collective_learn(conn, params) do
    with {:ok, validated_params} <- validate_learning_params(params),
         {:ok, learning_result} <- EmergentIntelligence.collective_learn(validated_params) do
      
      Logger.info("Collective learning completed: #{learning_result.learning_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        learning_id: learning_result.learning_id,
        message: "Collective learning completed successfully",
        results: %{
          knowledge_gained: learning_result.knowledge_gained,
          pattern_improvements: learning_result.pattern_improvements,
          behavior_adaptations: learning_result.behavior_adaptations,
          convergence_rate: learning_result.convergence_rate
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid learning parameters",
          details: errors
        })
      
      {:error, :learning_plateau} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Learning plateau reached",
          message: "The swarm has reached a learning plateau and cannot improve further with current data"
        })
      
      {:error, :swarm_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Swarm not found",
          message: "The specified swarm does not exist or is not active"
        })
      
      {:error, reason} ->
        Logger.error("Collective learning failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Collective learning failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/emergent/consciousness - Check consciousness level
  """
  def get_consciousness_level(conn, params) do
    try do
      swarm_id = Map.get(params, "swarm_id")
      
      consciousness_data = if swarm_id do
        EmergentIntelligence.assess_swarm_consciousness(swarm_id)
      else
        EmergentIntelligence.assess_global_consciousness()
      end
      
      enhanced_consciousness = Map.merge(consciousness_data, %{
        consciousness_indicators: %{
          self_awareness: EmergentIntelligence.measure_self_awareness(swarm_id),
          intentionality: EmergentIntelligence.measure_intentionality(swarm_id),
          phenomenal_experience: EmergentIntelligence.measure_phenomenal_experience(swarm_id),
          higher_order_thoughts: EmergentIntelligence.detect_higher_order_thoughts(swarm_id)
        },
        consciousness_level: EmergentIntelligence.calculate_consciousness_level(consciousness_data),
        emergence_quality: EmergentIntelligence.assess_emergence_quality(consciousness_data),
        timestamp: DateTime.utc_now()
      })
      
      conn
      |> json(%{
        success: true,
        consciousness: enhanced_consciousness,
        swarm_id: swarm_id
      })
    rescue
      error ->
        Logger.error("Failed to assess consciousness: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to assess consciousness level"
        })
    end
  end

  @doc """
  POST /api/emergent/evolve - Evolution step
  """
  def evolve_step(conn, params) do
    with {:ok, validated_params} <- validate_evolution_params(params),
         {:ok, evolution_result} <- EmergentIntelligence.perform_evolution_step(validated_params) do
      
      Logger.info("Evolution step completed: #{evolution_result.evolution_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        evolution_id: evolution_result.evolution_id,
        message: "Evolution step completed successfully",
        results: %{
          fitness_improvement: evolution_result.fitness_delta,
          mutations_applied: evolution_result.mutations,
          selection_pressure: evolution_result.selection_pressure,
          population_diversity: evolution_result.diversity_metrics,
          emergent_properties: evolution_result.emergent_properties
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid evolution parameters",
          details: errors
        })
      
      {:error, :evolution_stagnation} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Evolution stagnation detected",
          message: "Population has reached evolutionary stagnation and cannot evolve further"
        })
      
      {:error, reason} ->
        Logger.error("Evolution step failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Evolution step failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/emergent/metrics - Swarm metrics
  """
  def get_swarm_metrics(conn, params) do
    try do
      swarm_id = Map.get(params, "swarm_id")
      
      metrics = if swarm_id do
        EmergentIntelligence.get_detailed_swarm_metrics(swarm_id)
      else
        EmergentIntelligence.get_global_swarm_metrics()
      end
      
      enhanced_metrics = Map.merge(metrics, %{
        performance_indicators: %{
          collective_intelligence: EmergentIntelligence.measure_collective_intelligence(swarm_id),
          adaptation_rate: EmergentIntelligence.measure_adaptation_rate(swarm_id),
          coordination_efficiency: SwarmBehaviour.measure_coordination_efficiency(swarm_id),
          emergent_behavior_count: EmergentIntelligence.count_emergent_behaviors(swarm_id)
        },
        health_indicators: %{
          agent_mortality_rate: SwarmBehaviour.calculate_mortality_rate(swarm_id),
          resource_utilization: SwarmBehaviour.measure_resource_utilization(swarm_id),
          communication_effectiveness: SwarmBehaviour.measure_communication_effectiveness(swarm_id)
        },
        timestamp: DateTime.utc_now()
      })
      
      conn
      |> json(%{
        success: true,
        metrics: enhanced_metrics,
        swarm_id: swarm_id
      })
    rescue
      error ->
        Logger.error("Failed to get swarm metrics: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve swarm metrics"
        })
    end
  end

  @doc """
  GET /api/emergent/intelligence - Swarm intelligence metrics (legacy endpoint)
  """
  def intelligence_metrics(conn, params) do
    try do
      swarm_id = Map.get(params, "swarm_id")
      
      metrics = if swarm_id do
        EmergentIntelligence.get_swarm_metrics(swarm_id)
      else
        EmergentIntelligence.get_global_metrics()
      end
      
      enhanced_metrics = Map.merge(metrics, %{
        emergence_indicators: %{
          collective_iq: EmergentIntelligence.calculate_collective_iq(swarm_id),
          swarm_coherence: SwarmBehaviour.get_coherence_score(swarm_id),
          adaptive_capacity: EmergentIntelligence.measure_adaptive_capacity(swarm_id),
          knowledge_distribution: EmergentIntelligence.analyze_knowledge_distribution(swarm_id)
        },
        pattern_complexity: PatternDetection.measure_pattern_complexity(swarm_id),
        behavioral_diversity: SwarmBehaviour.measure_behavioral_diversity(swarm_id),
        timestamp: DateTime.utc_now()
      })
      
      conn
      |> json(%{
        success: true,
        intelligence_metrics: enhanced_metrics,
        swarm_id: swarm_id
      })
    rescue
      error ->
        Logger.error("Failed to get intelligence metrics: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve intelligence metrics"
        })
    end
  end

  # Private helper functions

  defp validate_swarm_params(params) do
    required_fields = ["agent_count", "behavior_rules"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        agent_count = parse_integer(params["agent_count"])
        behavior_rules = params["behavior_rules"]
        
        cond do
          agent_count < 2 ->
            {:error, :invalid_params, "Agent count must be at least 2"}
          
          agent_count > 10000 ->
            {:error, :invalid_params, "Agent count cannot exceed 10000"}
          
          not is_list(behavior_rules) ->
            {:error, :invalid_params, "Behavior rules must be an array"}
          
          true ->
            validated = %{
              agent_count: agent_count,
              behavior_rules: behavior_rules,
              interaction_radius: parse_float(Map.get(params, "interaction_radius", "5.0")),
              learning_rate: parse_float(Map.get(params, "learning_rate", "0.1")),
              mutation_rate: parse_float(Map.get(params, "mutation_rate", "0.01")),
              environment_size: parse_float(Map.get(params, "environment_size", "100.0")),
              description: Map.get(params, "description", "Emergent swarm intelligence")
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_pattern_params(params) do
    required_fields = ["data_source"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        validated = %{
          data_source: params["data_source"],
          pattern_types: Map.get(params, "pattern_types", ["temporal", "spatial", "behavioral"]),
          confidence_threshold: parse_float(Map.get(params, "confidence_threshold", "0.7")),
          max_patterns: parse_integer(Map.get(params, "max_patterns", "100")),
          time_window: parse_integer(Map.get(params, "time_window", "3600"))
        }
        
        {:ok, validated}
      
      error -> error
    end
  end

  defp validate_learning_params(params) do
    required_fields = ["swarm_id", "learning_data"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        learning_data = params["learning_data"]
        
        if not is_list(learning_data) or length(learning_data) == 0 do
          {:error, :invalid_params, "Learning data must be a non-empty array"}
        else
          validated = %{
            swarm_id: params["swarm_id"],
            learning_data: learning_data,
            learning_algorithm: Map.get(params, "learning_algorithm", "collective_gradient"),
            max_iterations: parse_integer(Map.get(params, "max_iterations", "1000")),
            convergence_threshold: parse_float(Map.get(params, "convergence_threshold", "0.001")),
            distribute_knowledge: Map.get(params, "distribute_knowledge", true)
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

  defp validate_evolution_params(params) do
    required_fields = ["swarm_id", "evolution_type"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        evolution_type = params["evolution_type"]
        
        if evolution_type not in ["genetic", "memetic", "cultural", "behavioral"] do
          {:error, :invalid_params, "Invalid evolution type"}
        else
          validated = %{
            swarm_id: params["swarm_id"],
            evolution_type: evolution_type,
            selection_pressure: parse_float(Map.get(params, "selection_pressure", "1.0")),
            mutation_rate: parse_float(Map.get(params, "mutation_rate", "0.1")),
            crossover_rate: parse_float(Map.get(params, "crossover_rate", "0.7")),
            fitness_function: Map.get(params, "fitness_function", "collective_intelligence"),
            generations: parse_integer(Map.get(params, "generations", "1")),
            preserve_diversity: Map.get(params, "preserve_diversity", true)
          }
          
          {:ok, validated}
        end
      
      error -> error
    end
  end
end