defmodule VsmPhoenixWeb.VSMController do
  use VsmPhoenixWeb, :controller
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System1.Operations

  def status(conn, _params) do
    status = %{
      timestamp: DateTime.utc_now(),
      systems: %{
        system5: get_system_status(Queen),
        system4: get_system_status(Intelligence),
        system3: get_system_status(Control),
        system2: get_system_status(Coordinator),
        system1: get_system_status(:operations_context)
      },
      health: "operational",
      version: "1.0.0"
    }

    json(conn, status)
  end

  def system_status(conn, %{"level" => level}) do
    system_module = case level do
      "5" -> Queen
      "4" -> Intelligence
      "3" -> Control
      "2" -> Coordinator
      "1" -> :operations_context
      _ -> nil
    end

    if system_module do
      status = get_detailed_system_status(system_module)
      json(conn, status)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid system level. Must be 1-5."})
    end
  end

  def queen_decision(conn, params) do
    case Queen.make_policy_decision(params) do
      {:ok, decision} ->
        json(conn, %{
          status: "accepted",
          decision: decision,
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "rejected",
          reason: reason,
          timestamp: DateTime.utc_now()
        })
    end
  end

  def algedonic_signal(conn, %{"signal" => signal_type} = params) do
    case signal_type do
      "pleasure" ->
        :ok = Queen.send_pleasure_signal(params["intensity"] || 0.5, params["context"])
        json(conn, %{status: "pleasure_signal_sent", timestamp: DateTime.utc_now()})

      "pain" ->
        :ok = Queen.send_pain_signal(params["intensity"] || 0.5, params["context"])
        json(conn, %{status: "pain_signal_sent", timestamp: DateTime.utc_now()})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid signal type. Must be 'pleasure' or 'pain'."})
    end
  end

  defp get_system_status(module_or_name) do
    try do
      process_name = case module_or_name do
        atom when is_atom(atom) and atom != Operations -> atom
        _ -> module_or_name
      end
      
      case GenServer.whereis(process_name) do
        nil -> %{status: "not_running", pid: nil}
        pid -> %{status: "running", pid: inspect(pid)}
      end
    rescue
      _ -> %{status: "error", pid: nil}
    end
  end

  defp get_detailed_system_status(module_or_name) do
    try do
      process_name = case module_or_name do
        :operations_context -> :operations_context
        module -> module
      end
      
      case GenServer.whereis(process_name) do
        nil ->
          %{
            status: "not_running",
            pid: nil,
            details: %{error: "System not started"}
          }

        pid ->
          # Try to get system state (this would depend on each system's implementation)
          basic_status = %{
            status: "running",
            pid: inspect(pid),
            uptime: get_process_info(pid, :message_queue_len),
            memory: get_process_info(pid, :memory)
          }

          # Add system-specific details based on the module
          details = case module_or_name do
            Queen ->
              %{
                type: "Policy & Governance",
                description: "System 5 - Ultimate authority and policy decisions",
                capabilities: ["policy_governance", "strategic_planning", "system_balance"]
              }

            Intelligence ->
              %{
                type: "Intelligence & Future Planning",
                description: "System 4 - Environmental scanning and adaptation",
                capabilities: ["environmental_scanning", "future_planning", "tidewave_integration"]
              }

            Control ->
              %{
                type: "Control & Optimization",
                description: "System 3 - Resource allocation and optimization",
                capabilities: ["resource_control", "performance_optimization", "audit_management"]
              }

            Coordinator ->
              %{
                type: "Coordination & Anti-oscillation",
                description: "System 2 - Information flow coordination",
                capabilities: ["message_coordination", "anti_oscillation", "information_routing"]
              }

            :operations_context ->
              %{
                type: "Operations & Delivery",
                description: "System 1 - Primary operational activities",
                capabilities: ["order_processing", "customer_service", "inventory_management"]
              }
          end

          Map.put(basic_status, :details, details)
      end
    rescue
      error ->
        %{
          status: "error",
          pid: nil,
          details: %{error: inspect(error)}
        }
    end
  end

  defp get_process_info(pid, key) do
    case Process.info(pid, key) do
      {^key, value} -> value
      nil -> "unavailable"
    end
  end
end