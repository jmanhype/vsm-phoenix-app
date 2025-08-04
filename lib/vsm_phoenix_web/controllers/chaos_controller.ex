defmodule VsmPhoenixWeb.ChaosController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.VSM.ChaosEngineering
  alias VsmPhoenix.VSM.System5
  
  require Logger

  @doc """
  POST /api/chaos/experiments - Create chaos experiment
  """
  def create_experiment(conn, params) do
    with {:ok, validated_params} <- validate_experiment_params(params),
         {:ok, experiment_id} <- ChaosEngineering.create_experiment(validated_params) do
      
      Logger.info("Chaos experiment created: #{experiment_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        experiment_id: experiment_id,
        message: "Chaos experiment created successfully",
        details: validated_params
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid experiment parameters",
          details: errors
        })
      
      {:error, :experiment_limit_reached} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          success: false,
          error: "Maximum concurrent experiments reached",
          message: "Cannot create new experiment: system limit reached"
        })
      
      {:error, reason} ->
        Logger.error("Chaos experiment creation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Experiment creation failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/chaos/experiments/:id - Get experiment status
  """
  def get_experiment(conn, %{"id" => experiment_id}) do
    case ChaosEngineering.get_experiment_status(experiment_id) do
      {:ok, experiment} ->
        enriched_experiment = Map.merge(experiment, %{
          runtime_metrics: ChaosEngineering.get_experiment_metrics(experiment_id),
          fault_history: ChaosEngineering.get_experiment_fault_history(experiment_id),
          system_impact: ChaosEngineering.analyze_experiment_impact(experiment_id)
        })
        
        conn
        |> json(%{
          success: true,
          experiment: enriched_experiment
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Experiment not found",
          experiment_id: experiment_id
        })
      
      {:error, reason} ->
        Logger.error("Failed to get experiment #{experiment_id}: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve experiment status"
        })
    end
  end

  @doc """
  DELETE /api/chaos/experiments/:id - Stop experiment
  """
  def stop_experiment(conn, %{"id" => experiment_id}) do
    case ChaosEngineering.stop_experiment(experiment_id) do
      {:ok, stop_result} ->
        Logger.info("Chaos experiment stopped: #{experiment_id}")
        
        conn
        |> json(%{
          success: true,
          message: "Experiment stopped successfully",
          experiment_id: experiment_id,
          stop_details: stop_result
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Experiment not found",
          experiment_id: experiment_id
        })
      
      {:error, :already_stopped} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Experiment already stopped",
          experiment_id: experiment_id
        })
      
      {:error, reason} ->
        Logger.error("Failed to stop experiment #{experiment_id}: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to stop experiment"
        })
    end
  end

  @doc """
  POST /api/chaos/faults/:type - Inject specific fault type
  """
  def inject_fault_by_type(conn, %{"type" => fault_type} = params) do
    enhanced_params = Map.put(params, "fault_type", fault_type)
    inject_fault(conn, enhanced_params)
  end

  @doc """
  POST /api/chaos/scenarios - Run chaos scenario
  """
  def run_scenario(conn, params) do
    with {:ok, validated_params} <- validate_scenario_params(params),
         {:ok, scenario_id} <- ChaosEngineering.run_scenario(validated_params) do
      
      Logger.info("Chaos scenario started: #{scenario_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        scenario_id: scenario_id,
        message: "Chaos scenario started successfully",
        details: validated_params
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid scenario parameters",
          details: errors
        })
      
      {:error, reason} ->
        Logger.error("Chaos scenario execution failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Scenario execution failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/chaos/inject - Inject faults into the system (legacy endpoint)
  """
  def inject_fault(conn, params) do
    with {:ok, validated_params} <- validate_inject_params(params),
         {:ok, fault_id} <- ChaosEngineering.inject_fault(validated_params) do
      
      Logger.info("Chaos fault injected: #{fault_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        fault_id: fault_id,
        message: "Fault injected successfully",
        details: validated_params
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid parameters",
          details: errors
        })
      
      {:error, :system_protected} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "System is protected from chaos injection",
          message: "VSM System 5 has blocked the chaos operation"
        })
      
      {:error, reason} ->
        Logger.error("Chaos injection failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Chaos injection failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/chaos/faults - List active faults
  """
  def list_faults(conn, _params) do
    try do
      faults = ChaosEngineering.list_active_faults()
      
      conn
      |> json(%{
        success: true,
        faults: faults,
        count: length(faults)
      })
    rescue
      error ->
        Logger.error("Failed to list chaos faults: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve active faults"
        })
    end
  end

  @doc """
  DELETE /api/chaos/faults/:id - Remove fault
  """
  def remove_fault(conn, %{"id" => fault_id}) do
    case ChaosEngineering.remove_fault(fault_id) do
      :ok ->
        Logger.info("Chaos fault removed: #{fault_id}")
        
        conn
        |> json(%{
          success: true,
          message: "Fault removed successfully",
          fault_id: fault_id
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Fault not found",
          fault_id: fault_id
        })
      
      {:error, reason} ->
        Logger.error("Failed to remove chaos fault #{fault_id}: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to remove fault",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/chaos/metrics - Chaos metrics
  """
  def metrics(conn, _params) do
    try do
      metrics = %{
        active_faults: ChaosEngineering.count_active_faults(),
        total_injected: ChaosEngineering.get_total_injected(),
        recovery_time: ChaosEngineering.get_avg_recovery_time(),
        fault_types: ChaosEngineering.get_fault_distribution(),
        system_resilience: System5.get_resilience_score(),
        cascade_events: ChaosEngineering.count_cascade_events(),
        timestamp: DateTime.utc_now()
      }
      
      conn
      |> json(%{
        success: true,
        metrics: metrics
      })
    rescue
      error ->
        Logger.error("Failed to get chaos metrics: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve chaos metrics"
        })
    end
  end

  @doc """
  POST /api/chaos/cascade - Simulate cascading failure
  """
  def simulate_cascade(conn, params) do
    with {:ok, validated_params} <- validate_cascade_params(params),
         {:ok, cascade_id} <- ChaosEngineering.simulate_cascade(validated_params) do
      
      Logger.warning("Cascade failure simulation started: #{cascade_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        cascade_id: cascade_id,
        message: "Cascading failure simulation initiated",
        warning: "This will affect multiple system components",
        details: validated_params
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid cascade parameters",
          details: errors
        })
      
      {:error, :cascade_blocked} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Cascade simulation blocked",
          message: "System protection prevented cascading failure"
        })
      
      {:error, reason} ->
        Logger.error("Cascade simulation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Cascade simulation failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/chaos/resilience - Resilience analysis
  """
  def resilience_analysis(conn, _params) do
    try do
      analysis = %{
        overall_score: System5.get_resilience_score(),
        system_levels: %{
          s1: ChaosEngineering.analyze_s1_resilience(),
          s2: ChaosEngineering.analyze_s2_resilience(),
          s3: ChaosEngineering.analyze_s3_resilience(),
          s4: ChaosEngineering.analyze_s4_resilience(),
          s5: ChaosEngineering.analyze_s5_resilience()
        },
        recovery_patterns: ChaosEngineering.get_recovery_patterns(),
        weak_points: ChaosEngineering.identify_weak_points(),
        recommendations: ChaosEngineering.get_resilience_recommendations(),
        last_updated: DateTime.utc_now()
      }
      
      conn
      |> json(%{
        success: true,
        analysis: analysis
      })
    rescue
      error ->
        Logger.error("Failed to get resilience analysis: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve resilience analysis"
        })
    end
  end

  # Private helper functions

  defp validate_inject_params(params) do
    required_fields = ["fault_type", "target_system", "severity"]
    optional_fields = ["duration", "probability", "description"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        validated = %{
          fault_type: get_and_validate_fault_type(params["fault_type"]),
          target_system: get_and_validate_target(params["target_system"]),
          severity: get_and_validate_severity(params["severity"]),
          duration: Map.get(params, "duration", 60),
          probability: Map.get(params, "probability", 1.0),
          description: Map.get(params, "description", "Chaos engineering fault")
        }
        
        if Enum.any?(Map.values(validated), &(&1 == :invalid)) do
          {:error, :invalid_params, "Invalid field values"}
        else
          {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_cascade_params(params) do
    required_fields = ["initial_target", "propagation_pattern"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        validated = %{
          initial_target: params["initial_target"],
          propagation_pattern: params["propagation_pattern"],
          max_depth: Map.get(params, "max_depth", 3),
          delay_between_steps: Map.get(params, "delay_between_steps", 5),
          stop_condition: Map.get(params, "stop_condition", "manual")
        }
        
        {:ok, validated}
      
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

  defp get_and_validate_fault_type(fault_type) when fault_type in ["latency", "error", "timeout", "resource_exhaustion", "network_partition"] do
    fault_type
  end
  defp get_and_validate_fault_type(_), do: :invalid

  defp get_and_validate_target(target) when target in ["s1", "s2", "s3", "s4", "s5", "network", "database", "external_api"] do
    target
  end
  defp get_and_validate_target(_), do: :invalid

  defp get_and_validate_severity(severity) when severity in ["low", "medium", "high", "critical"] do
    severity
  end
  defp get_and_validate_severity(_), do: :invalid

  defp validate_experiment_params(params) do
    required_fields = ["name", "duration", "fault_types"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        fault_types = params["fault_types"]
        
        if not is_list(fault_types) or length(fault_types) == 0 do
          {:error, :invalid_params, "Fault types must be a non-empty array"}
        else
          validated = %{
            name: params["name"],
            duration: parse_integer(params["duration"]),
            fault_types: fault_types,
            target_systems: Map.get(params, "target_systems", ["s1", "s2", "s3"]),
            max_concurrent_faults: parse_integer(Map.get(params, "max_concurrent_faults", "3")),
            auto_recovery: Map.get(params, "auto_recovery", true),
            description: Map.get(params, "description", "Chaos engineering experiment")
          }
          
          {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_scenario_params(params) do
    required_fields = ["scenario_name", "steps"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        steps = params["steps"]
        
        if not is_list(steps) or length(steps) == 0 do
          {:error, :invalid_params, "Scenario steps must be a non-empty array"}
        else
          validated = %{
            scenario_name: params["scenario_name"],
            steps: steps,
            execution_mode: Map.get(params, "execution_mode", "sequential"),
            timeout: parse_integer(Map.get(params, "timeout", "3600")),
            rollback_on_failure: Map.get(params, "rollback_on_failure", true),
            description: Map.get(params, "description", "Chaos scenario execution")
          }
          
          {:ok, validated}
        end
      
      error -> error
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
end