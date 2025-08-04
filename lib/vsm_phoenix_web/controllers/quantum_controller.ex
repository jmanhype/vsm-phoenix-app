defmodule VsmPhoenixWeb.QuantumController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.VSM.QuantumLogic
  alias VsmPhoenix.VSM.System5
  
  require Logger

  @doc """
  POST /api/quantum/superposition - Create superposition state
  """
  def create_superposition(conn, params) do
    with {:ok, validated_params} <- validate_superposition_params(params),
         {:ok, state_id} <- QuantumLogic.create_superposition(validated_params) do
      
      Logger.info("Quantum superposition created: #{state_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        state_id: state_id,
        message: "Superposition state created successfully",
        details: %{
          states: validated_params.states,
          amplitudes: validated_params.amplitudes,
          coherence_time: validated_params.coherence_time
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid superposition parameters",
          details: errors
        })
      
      {:error, :decoherence} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Quantum decoherence detected",
          message: "System environment is too noisy for quantum state maintenance"
        })
      
      {:error, reason} ->
        Logger.error("Superposition creation failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Superposition creation failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/quantum/entangle - Entangle quantum states
  """
  def entangle_states(conn, params) do
    with {:ok, validated_params} <- validate_entanglement_params(params),
         {:ok, entanglement_id} <- QuantumLogic.entangle_states(validated_params) do
      
      Logger.info("Quantum entanglement created: #{entanglement_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        entanglement_id: entanglement_id,
        message: "Quantum states entangled successfully",
        details: %{
          state_ids: validated_params.state_ids,
          entanglement_type: validated_params.entanglement_type,
          correlation_strength: validated_params.correlation_strength
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid entanglement parameters",
          details: errors
        })
      
      {:error, :incompatible_states} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Incompatible quantum states",
          message: "The selected states cannot be entangled due to incompatible properties"
        })
      
      {:error, reason} ->
        Logger.error("Entanglement failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Entanglement failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/quantum/measure - Measure/collapse quantum state
  """
  def measure_state(conn, params) do
    with {:ok, validated_params} <- validate_measurement_params(params),
         {:ok, measurement_result} <- QuantumLogic.measure_state(validated_params) do
      
      Logger.info("Quantum measurement performed on state: #{validated_params.state_id}")
      
      conn
      |> json(%{
        success: true,
        measurement: measurement_result,
        message: "Quantum state measured and collapsed",
        details: %{
          collapsed_state: measurement_result.final_state,
          probability: measurement_result.probability,
          measurement_basis: validated_params.measurement_basis
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid measurement parameters",
          details: errors
        })
      
      {:error, :state_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Quantum state not found",
          message: "The specified quantum state does not exist or has already collapsed"
        })
      
      {:error, reason} ->
        Logger.error("Quantum measurement failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Measurement failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  POST /api/quantum/tunnel - Quantum tunneling operation
  """
  def quantum_tunnel(conn, params) do
    with {:ok, validated_params} <- validate_tunneling_params(params),
         {:ok, tunnel_result} <- QuantumLogic.quantum_tunnel(validated_params) do
      
      Logger.info("Quantum tunneling performed: #{tunnel_result.tunnel_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        tunnel_id: tunnel_result.tunnel_id,
        message: "Quantum tunneling completed successfully",
        details: %{
          barrier_height: validated_params.barrier_height,
          tunneling_probability: tunnel_result.probability,
          final_position: tunnel_result.final_position,
          energy_cost: tunnel_result.energy_cost
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid tunneling parameters",
          details: errors
        })
      
      {:error, :barrier_too_high} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Barrier too high for tunneling",
          message: "The energy barrier exceeds quantum tunneling capability"
        })
      
      {:error, :insufficient_energy} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Insufficient quantum energy",
          message: "Not enough quantum energy available for tunneling operation"
        })
      
      {:error, reason} ->
        Logger.error("Quantum tunneling failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Tunneling failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/quantum/states/:id - Get specific quantum state
  """
  def get_state(conn, %{"id" => state_id}) do
    case QuantumLogic.get_quantum_state(state_id) do
      {:ok, state} ->
        enriched_state = Map.merge(state, %{
          entanglement_info: QuantumLogic.get_entanglement_info(state_id),
          coherence_metrics: QuantumLogic.get_coherence_metrics(state_id),
          measurement_history: QuantumLogic.get_measurement_history(state_id)
        })
        
        conn
        |> json(%{
          success: true,
          state: enriched_state
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Quantum state not found",
          state_id: state_id
        })
      
      {:error, reason} ->
        Logger.error("Failed to get quantum state #{state_id}: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve quantum state"
        })
    end
  end

  @doc """
  DELETE /api/quantum/states/:id - Collapse/destroy quantum state
  """
  def destroy_state(conn, %{"id" => state_id}) do
    case QuantumLogic.destroy_quantum_state(state_id) do
      {:ok, destruction_result} ->
        Logger.info("Quantum state destroyed: #{state_id}")
        
        conn
        |> json(%{
          success: true,
          message: "Quantum state destroyed successfully",
          state_id: state_id,
          destruction_details: destruction_result
        })
      
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Quantum state not found",
          state_id: state_id
        })
      
      {:error, :entanglement_violation} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "Cannot destroy entangled state",
          message: "State is entangled with other states. Break entanglement first."
        })
      
      {:error, reason} ->
        Logger.error("Failed to destroy quantum state #{state_id}: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to destroy quantum state"
        })
    end
  end

  @doc """
  GET /api/quantum/states - List quantum states
  """
  def list_states(conn, params) do
    try do
      filter_params = %{
        state_type: Map.get(params, "type"),
        coherent_only: Map.get(params, "coherent_only", "false") == "true",
        entangled_only: Map.get(params, "entangled_only", "false") == "true"
      }
      
      states = QuantumLogic.list_quantum_states(filter_params)
      
      conn
      |> json(%{
        success: true,
        states: states,
        count: length(states),
        filters_applied: filter_params
      })
    rescue
      error ->
        Logger.error("Failed to list quantum states: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve quantum states"
        })
    end
  end

  @doc """
  GET /api/quantum/metrics - Quantum system metrics
  """
  def metrics(conn, _params) do
    try do
      metrics = %{
        active_states: QuantumLogic.count_active_states(),
        total_superpositions: QuantumLogic.count_superpositions(),
        entangled_pairs: QuantumLogic.count_entanglements(),
        coherence_time_avg: QuantumLogic.get_avg_coherence_time(),
        decoherence_rate: QuantumLogic.get_decoherence_rate(),
        tunneling_success_rate: QuantumLogic.get_tunneling_success_rate(),
        quantum_volume: QuantumLogic.calculate_quantum_volume(),
        system_fidelity: QuantumLogic.get_system_fidelity(),
        timestamp: DateTime.utc_now()
      }
      
      conn
      |> json(%{
        success: true,
        metrics: metrics
      })
    rescue
      error ->
        Logger.error("Failed to get quantum metrics: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve quantum metrics"
        })
    end
  end

  # Private helper functions

  defp validate_superposition_params(params) do
    required_fields = ["states", "amplitudes"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        states = params["states"]
        amplitudes = params["amplitudes"]
        
        cond do
          not is_list(states) or not is_list(amplitudes) ->
            {:error, :invalid_params, "States and amplitudes must be arrays"}
          
          length(states) != length(amplitudes) ->
            {:error, :invalid_params, "States and amplitudes arrays must have same length"}
          
          not validate_amplitude_normalization(amplitudes) ->
            {:error, :invalid_params, "Amplitude probabilities must sum to 1.0"}
          
          true ->
            validated = %{
              states: states,
              amplitudes: amplitudes,
              coherence_time: Map.get(params, "coherence_time", 1000),
              description: Map.get(params, "description", "Quantum superposition")
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_entanglement_params(params) do
    required_fields = ["state_ids", "entanglement_type"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        state_ids = params["state_ids"]
        entanglement_type = params["entanglement_type"]
        
        cond do
          not is_list(state_ids) or length(state_ids) < 2 ->
            {:error, :invalid_params, "At least 2 state IDs required for entanglement"}
          
          entanglement_type not in ["bell", "ghz", "cluster", "spin"] ->
            {:error, :invalid_params, "Invalid entanglement type"}
          
          true ->
            validated = %{
              state_ids: state_ids,
              entanglement_type: entanglement_type,
              correlation_strength: Map.get(params, "correlation_strength", 1.0),
              description: Map.get(params, "description", "Quantum entanglement")
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_measurement_params(params) do
    required_fields = ["state_id"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        validated = %{
          state_id: params["state_id"],
          measurement_basis: Map.get(params, "measurement_basis", "computational"),
          collapse: Map.get(params, "collapse", true)
        }
        
        {:ok, validated}
      
      error -> error
    end
  end

  defp validate_tunneling_params(params) do
    required_fields = ["barrier_height", "particle_energy"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        validated = %{
          barrier_height: params["barrier_height"],
          particle_energy: params["particle_energy"],
          barrier_width: Map.get(params, "barrier_width", 1.0),
          particle_mass: Map.get(params, "particle_mass", 1.0)
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

  defp validate_amplitude_normalization(amplitudes) do
    total = Enum.reduce(amplitudes, 0, fn amp, acc ->
      case Float.parse(to_string(amp)) do
        {float_val, _} -> acc + (float_val * float_val)  # |amplitude|^2
        :error -> acc + 1000  # Force failure for invalid numbers
      end
    end)
    
    abs(total - 1.0) < 0.0001  # Allow small floating point errors
  end
end