defmodule VsmPhoenixWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid HTTP responses.
  
  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  
  use VsmPhoenixWeb, :controller
  
  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(VsmPhoenixWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end
  
  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(VsmPhoenixWeb.ErrorView)
    |> render(:"404")
  end
  
  # Handle unauthorized access
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized"})
  end
  
  # Handle forbidden access
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "Forbidden"})
  end
  
  # Handle bad request
  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Bad request"})
  end
  
  # Handle internal server error
  def call(conn, {:error, :internal_server_error}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "Internal server error"})
  end
  
  # Handle service unavailable
  def call(conn, {:error, :service_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "Service temporarily unavailable"})
  end
  
  # Handle too many requests (rate limiting)
  def call(conn, {:error, :too_many_requests}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{
      error: "Rate limit exceeded",
      message: "Too many requests. Please try again later.",
      retry_after: 60
    })
  end
  
  # Handle validation errors for Phase 2 systems
  def call(conn, {:error, :validation_failed, details}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      success: false,
      error: "Validation failed",
      validation_errors: details,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle system overload errors
  def call(conn, {:error, :system_overload, system}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{
      success: false,
      error: "System overload",
      message: "The #{system} system is currently overloaded. Please try again later.",
      affected_system: system,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle quantum decoherence errors
  def call(conn, {:error, :quantum_decoherence}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      success: false,
      error: "Quantum decoherence detected",
      message: "Quantum system coherence has been lost. Operation cannot be completed.",
      recommendation: "Retry with shorter coherence times or in a less noisy environment",
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle emergent intelligence errors
  def call(conn, {:error, :swarm_not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{
      success: false,
      error: "Swarm not found",
      message: "The requested swarm does not exist or has been terminated",
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle meta-VSM errors
  def call(conn, {:error, :vsm_spawn_failed, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      success: false,
      error: "VSM spawn failed",
      message: "Failed to spawn new VSM instance",
      reason: reason,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle algedonic system errors
  def call(conn, {:error, :signal_blocked, blocker}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      success: false,
      error: "Signal blocked",
      message: "Algedonic signal was blocked by system protection mechanisms",
      blocked_by: blocker,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle chaos engineering errors
  def call(conn, {:error, :experiment_limit_reached}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{
      success: false,
      error: "Experiment limit reached",
      message: "Maximum number of concurrent chaos experiments reached",
      recommendation: "Stop existing experiments or wait for completion",
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle generic errors with additional context
  def call(conn, {:error, error_type, context}) when is_map(context) do
    status_code = determine_status_code(error_type)
    
    conn
    |> put_status(status_code)
    |> json(%{
      success: false,
      error: to_string(error_type),
      context: context,
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle timeout errors
  def call(conn, {:error, :timeout}) do
    conn
    |> put_status(:request_timeout)
    |> json(%{
      success: false,
      error: "Request timeout",
      message: "The operation took too long to complete",
      timestamp: DateTime.utc_now()
    })
  end
  
  # Handle conflict errors
  def call(conn, {:error, :conflict, reason}) do
    conn
    |> put_status(:conflict)
    |> json(%{
      success: false,
      error: "Conflict detected",
      message: reason,
      timestamp: DateTime.utc_now()
    })
  end

  # Default fallback for any unhandled error
  def call(conn, {:error, reason}) do
    Logger.error("Unhandled error in fallback controller: #{inspect(reason)}")
    
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      success: false,
      error: "Internal error",
      message: "An unexpected error occurred",
      error_id: generate_error_id(),
      timestamp: DateTime.utc_now()
    })
  end

  # Helper functions
  
  defp determine_status_code(:not_found), do: :not_found
  defp determine_status_code(:unauthorized), do: :unauthorized
  defp determine_status_code(:forbidden), do: :forbidden
  defp determine_status_code(:bad_request), do: :bad_request
  defp determine_status_code(:unprocessable_entity), do: :unprocessable_entity
  defp determine_status_code(:service_unavailable), do: :service_unavailable
  defp determine_status_code(:too_many_requests), do: :too_many_requests
  defp determine_status_code(_), do: :internal_server_error

  defp generate_error_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end