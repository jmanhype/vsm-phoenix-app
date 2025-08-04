defmodule VsmPhoenix.EventFactory do
  @moduledoc """
  Factory for creating test events for VSM systems.
  """
  
  alias VsmPhoenix.Events.Event
  
  def build(:event) do
    %Event{
      id: Ecto.UUID.generate(),
      event_type: "system.operation.completed",
      event_source: "system1.operations",
      aggregate_id: Ecto.UUID.generate(),
      aggregate_type: "Operation",
      event_version: 1,
      correlation_id: Ecto.UUID.generate(),
      causation_id: Ecto.UUID.generate(),
      data: %{
        operation_id: Ecto.UUID.generate(),
        status: "completed",
        result: "success",
        duration_ms: 150
      },
      metadata: %{
        user_id: Ecto.UUID.generate(),
        ip_address: "192.168.1.100",
        user_agent: "VSMAgent/1.0"
      },
      stream_name: "operations-#{Ecto.UUID.generate()}",
      stream_version: 1,
      vsm_system: 1,
      vsm_component: "operations",
      viability_impact: 0.1,
      variety_level: 2,
      processed: false,
      failed_attempts: 0,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end
  
  def build(:system_event, system) do
    build(:event)
    |> Map.put(:event_source, "system#{system}")
    |> Map.put(:vsm_system, system)
    |> Map.put(:vsm_component, get_system_component(system))
    |> Map.put(:event_type, get_system_event_type(system))
  end
  
  def build(:viability_event) do
    build(:event)
    |> Map.put(:event_type, "system.viability.assessed")
    |> Map.put(:event_source, "system5.queen")
    |> Map.put(:vsm_system, 5)
    |> Map.put(:vsm_component, "queen")
    |> Map.put(:viability_impact, 0.8)
    |> Map.put(:data, %{
      viability_score: 0.85,
      threshold: 0.7,
      systems_status: %{
        system1: "healthy",
        system2: "healthy", 
        system3: "healthy",
        system4: "healthy",
        system5: "healthy"
      }
    })
  end
  
  def build(:variety_event) do
    build(:event)
    |> Map.put(:event_type, "system.variety.detected")
    |> Map.put(:event_source, "system4.intelligence")
    |> Map.put(:vsm_system, 4)
    |> Map.put(:vsm_component, "intelligence")
    |> Map.put(:variety_level, 4)
    |> Map.put(:data, %{
      variety_source: "external_api",
      variety_type: "data_structure",
      complexity_score: 0.75,
      adaptation_required: true
    })
  end
  
  def build(:chaos_event) do
    build(:event)
    |> Map.put(:event_type, "chaos.fault.injected")
    |> Map.put(:event_source, "chaos.injector")
    |> Map.put(:vsm_system, 3)
    |> Map.put(:vsm_component, "control")
    |> Map.put(:data, %{
      fault_type: "latency",
      target_component: "database",
      fault_config: %{
        delay_ms: 500,
        probability: 0.1
      },
      experiment_id: Ecto.UUID.generate()
    })
  end
  
  def build(:quantum_event) do
    build(:event)
    |> Map.put(:event_type, "quantum.state.measured")
    |> Map.put(:event_source, "quantum.analyzer")
    |> Map.put(:data, %{
      state_id: Ecto.UUID.generate(),
      measurement_result: "collapse",
      probability: 0.6,
      entangled_states: [Ecto.UUID.generate(), Ecto.UUID.generate()]
    })
  end
  
  def build(:ml_event) do
    build(:event)
    |> Map.put(:event_type, "ml.model.trained")
    |> Map.put(:event_source, "ml.trainer")
    |> Map.put(:data, %{
      model_id: Ecto.UUID.generate(),
      accuracy: 0.89,
      loss: 0.12,
      epochs: 100,
      training_time_ms: 45000
    })
  end
  
  def build(:security_event) do
    build(:event)
    |> Map.put(:event_type, "security.authentication.failed")
    |> Map.put(:event_source, "auth.service")
    |> Map.put(:data, %{
      user_id: Ecto.UUID.generate(),
      ip_address: "192.168.1.100",
      reason: "invalid_password",
      attempt_count: 3
    })
    |> Map.put(:metadata, %{
      severity: "medium",
      risk_score: 6
    })
  end
  
  def build(:processed_event) do
    build(:event)
    |> Map.put(:processed, true)
    |> Map.put(:processed_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
  
  def build(:failed_event) do
    build(:event)
    |> Map.put(:failed_attempts, 3)
    |> Map.put(:last_error, "Processing timeout after 30 seconds")
  end
  
  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end
  
  def insert!(factory_name, attributes \\ []) do
    factory_name
    |> build(attributes)
    |> VsmPhoenix.Repo.insert!()
  end
  
  # Helper functions
  
  defp get_system_component(1), do: "operations"
  defp get_system_component(2), do: "coordinator"
  defp get_system_component(3), do: "control"
  defp get_system_component(4), do: "intelligence"
  defp get_system_component(5), do: "queen"
  defp get_system_component(_), do: "unknown"
  
  defp get_system_event_type(1), do: "system1.operation.executed"
  defp get_system_event_type(2), do: "system2.coordination.synced"
  defp get_system_event_type(3), do: "system3.resource.optimized"
  defp get_system_event_type(4), do: "system4.environment.scanned"
  defp get_system_event_type(5), do: "system5.policy.synthesized"
  defp get_system_event_type(_), do: "system.unknown.event"
  
  def create_event_stream(count \\ 10) do
    1..count
    |> Enum.map(fn i ->
      insert!(:event, %{
        stream_name: "test-stream",
        stream_version: i,
        global_position: i
      })
    end)
  end
  
  def create_system_events do
    1..5
    |> Enum.map(&insert!(:system_event, &1))
  end
  
  def create_processed_events(count \\ 5) do
    1..count |> Enum.map(fn _ -> insert!(:processed_event) end)
  end
  
  def create_failed_events(count \\ 3) do
    1..count |> Enum.map(fn _ -> insert!(:failed_event) end)
  end
end