defmodule VsmPhoenix.ChaosEngineering.ChaosOrchestrator do
  @moduledoc """
  Orchestrates chaos engineering experiments and manages test campaigns.
  Coordinates fault injection, cascade simulation, and resilience analysis.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.ChaosEngineering.{FaultInjector, CascadeSimulator, ResilienceAnalyzer}

  defmodule Experiment do
    @enforce_keys [:id, :name, :type]
    defstruct [
      :id,
      :name,
      :type,
      :description,
      :hypothesis,
      :steps,
      :success_criteria,
      :rollback_plan,
      :status,
      :results,
      :started_at,
      :ended_at,
      :metadata
    ]
  end

  defmodule Campaign do
    @enforce_keys [:id, :name, :experiments]
    defstruct [
      :id,
      :name,
      :description,
      :experiments,
      :schedule,
      :status,
      :results,
      :started_at,
      :ended_at,
      :configuration
    ]
  end

  defmodule ExperimentStep do
    @enforce_keys [:id, :action, :target]
    defstruct [
      :id,
      :action,
      :target,
      :parameters,
      :duration,
      :validation,
      :rollback_action
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def run_experiment(experiment_spec) do
    GenServer.call(__MODULE__, {:run_experiment, experiment_spec}, 120_000)
  end

  def run_campaign(campaign_spec) do
    GenServer.call(__MODULE__, {:run_campaign, campaign_spec}, 300_000)
  end

  def schedule_campaign(campaign_spec, schedule) do
    GenServer.call(__MODULE__, {:schedule_campaign, campaign_spec, schedule})
  end

  def stop_experiment(experiment_id) do
    GenServer.call(__MODULE__, {:stop_experiment, experiment_id})
  end

  def get_experiment_status(experiment_id) do
    GenServer.call(__MODULE__, {:get_status, experiment_id})
  end

  def list_experiments do
    GenServer.call(__MODULE__, :list_experiments)
  end

  def get_experiment_results(experiment_id) do
    GenServer.call(__MODULE__, {:get_results, experiment_id})
  end

  def validate_experiment(experiment_spec) do
    GenServer.call(__MODULE__, {:validate_experiment, experiment_spec})
  end

  # Predefined Experiments

  def database_resilience_experiment do
    %Experiment{
      id: "exp_db_resilience",
      name: "Database Resilience Test",
      type: :resilience,
      description: "Test database failover and recovery mechanisms",
      hypothesis: "System maintains availability during database failures",
      steps: [
        %ExperimentStep{
          id: "step_1",
          action: :inject_fault,
          target: :primary_database,
          parameters: %{type: :connection_failure, severity: :critical},
          duration: 30_000,
          validation: &validate_database_failover/0
        },
        %ExperimentStep{
          id: "step_2",
          action: :verify_recovery,
          target: :database_cluster,
          parameters: %{expected_state: :healthy},
          validation: &validate_database_recovery/0
        }
      ],
      success_criteria: %{
        availability: 0.99,
        data_loss: false,
        failover_time: 5000
      }
    }
  end

  def network_partition_experiment do
    %Experiment{
      id: "exp_net_partition",
      name: "Network Partition Resilience",
      type: :network,
      description: "Test system behavior during network partitions",
      hypothesis: "System prevents split-brain and maintains consistency",
      steps: [
        %ExperimentStep{
          id: "step_1",
          action: :create_partition,
          target: :cluster_nodes,
          parameters: %{partition_type: :asymmetric},
          duration: 60_000
        },
        %ExperimentStep{
          id: "step_2",
          action: :verify_consistency,
          target: :distributed_state,
          validation: &validate_consistency/0
        }
      ],
      success_criteria: %{
        split_brain_prevented: true,
        consistency_maintained: true,
        partition_tolerance: true
      }
    }
  end

  def cascade_failure_experiment do
    %Experiment{
      id: "exp_cascade",
      name: "Cascade Failure Prevention",
      type: :cascade,
      description: "Test cascade failure prevention mechanisms",
      hypothesis: "Circuit breakers prevent cascade failures",
      steps: [
        %ExperimentStep{
          id: "step_1",
          action: :trigger_cascade,
          target: :critical_service,
          parameters: %{initial_failure: :database, max_depth: 5},
          duration: 45_000
        },
        %ExperimentStep{
          id: "step_2",
          action: :measure_blast_radius,
          target: :system,
          validation: &validate_blast_radius/0
        }
      ],
      success_criteria: %{
        max_affected_services: 3,
        circuit_breakers_triggered: true,
        recovery_complete: true
      }
    }
  end

  # Server Callbacks

  def init(opts) do
    state = %{
      experiments: %{},
      campaigns: %{},
      active_experiments: %{},
      scheduled_campaigns: %{},
      experiment_counter: 0,
      campaign_counter: 0,
      configuration: %{
        max_concurrent_experiments: Keyword.get(opts, :max_concurrent, 3),
        auto_rollback: Keyword.get(opts, :auto_rollback, true),
        safety_checks: Keyword.get(opts, :safety_checks, true),
        dry_run: Keyword.get(opts, :dry_run, false)
      },
      predefined_experiments: load_predefined_experiments()
    }

    {:ok, state}
  end

  def handle_call({:run_experiment, experiment_spec}, _from, state) do
    if map_size(state.active_experiments) >= state.configuration.max_concurrent_experiments do
      {:reply, {:error, :max_concurrent_experiments}, state}
    else
      case execute_experiment(experiment_spec, state) do
        {:ok, experiment, new_state} ->
          {:reply, {:ok, experiment}, new_state}
        
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def handle_call({:run_campaign, campaign_spec}, _from, state) do
    case execute_campaign(campaign_spec, state) do
      {:ok, campaign, new_state} ->
        {:reply, {:ok, campaign}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:schedule_campaign, campaign_spec, schedule}, _from, state) do
    campaign_id = "campaign_#{state.campaign_counter}"
    
    campaign = %Campaign{
      id: campaign_id,
      name: campaign_spec.name,
      experiments: campaign_spec.experiments,
      schedule: schedule,
      status: :scheduled
    }
    
    # Schedule the campaign
    schedule_next_run(campaign)
    
    new_state = %{state |
      scheduled_campaigns: Map.put(state.scheduled_campaigns, campaign_id, campaign),
      campaign_counter: state.campaign_counter + 1
    }
    
    {:reply, {:ok, campaign}, new_state}
  end

  def handle_call({:stop_experiment, experiment_id}, _from, state) do
    case Map.get(state.active_experiments, experiment_id) do
      nil ->
        {:reply, {:error, :experiment_not_found}, state}
      
      experiment ->
        stopped_experiment = stop_experiment_impl(experiment, state)
        
        new_state = %{state |
          active_experiments: Map.delete(state.active_experiments, experiment_id),
          experiments: Map.put(state.experiments, experiment_id, stopped_experiment)
        }
        
        {:reply, {:ok, stopped_experiment}, new_state}
    end
  end

  def handle_call({:get_status, experiment_id}, _from, state) do
    experiment = Map.get(state.active_experiments, experiment_id) ||
                 Map.get(state.experiments, experiment_id)
    
    if experiment do
      {:reply, {:ok, experiment.status}, state}
    else
      {:reply, {:error, :experiment_not_found}, state}
    end
  end

  def handle_call(:list_experiments, _from, state) do
    all_experiments = Map.values(state.experiments) ++ Map.values(state.active_experiments)
    {:reply, {:ok, all_experiments}, state}
  end

  def handle_call({:get_results, experiment_id}, _from, state) do
    experiment = Map.get(state.experiments, experiment_id)
    
    if experiment do
      {:reply, {:ok, experiment.results}, state}
    else
      {:reply, {:error, :experiment_not_found}, state}
    end
  end

  def handle_call({:validate_experiment, experiment_spec}, _from, state) do
    validation_result = validate_experiment_spec(experiment_spec, state)
    {:reply, validation_result, state}
  end

  def handle_info({:execute_step, experiment_id, step_index}, state) do
    case Map.get(state.active_experiments, experiment_id) do
      nil ->
        {:noreply, state}
      
      experiment ->
        new_state = execute_experiment_step(experiment, step_index, state)
        {:noreply, new_state}
    end
  end

  def handle_info({:complete_experiment, experiment_id}, state) do
    case Map.get(state.active_experiments, experiment_id) do
      nil ->
        {:noreply, state}
      
      experiment ->
        completed_experiment = complete_experiment(experiment)
        
        new_state = %{state |
          active_experiments: Map.delete(state.active_experiments, experiment_id),
          experiments: Map.put(state.experiments, experiment_id, completed_experiment)
        }
        
        {:noreply, new_state}
    end
  end

  def handle_info({:run_scheduled_campaign, campaign_id}, state) do
    case Map.get(state.scheduled_campaigns, campaign_id) do
      nil ->
        {:noreply, state}
      
      campaign ->
        case execute_campaign(campaign, state) do
          {:ok, _executed_campaign, new_state} ->
            # Reschedule if recurring
            if campaign.schedule[:recurring] do
              schedule_next_run(campaign)
            end
            
            {:noreply, new_state}
          
          {:error, _reason} ->
            # Reschedule on error
            schedule_next_run(campaign)
            {:noreply, state}
        end
    end
  end

  # Private Functions

  defp execute_experiment(experiment_spec, state) do
    experiment_id = experiment_spec.id || "exp_#{state.experiment_counter}"
    
    experiment = %{experiment_spec |
      id: experiment_id,
      status: :running,
      started_at: DateTime.utc_now(),
      results: %{}
    }
    
    # Safety checks
    if state.configuration.safety_checks do
      case perform_safety_checks(experiment) do
        :ok -> :ok
        {:error, reason} -> 
          return {:error, {:safety_check_failed, reason}}
      end
    end
    
    # Start experiment execution
    if state.configuration.dry_run do
      dry_run_experiment(experiment, state)
    else
      # Execute first step
      Process.send_after(self(), {:execute_step, experiment_id, 0}, 100)
      
      new_state = %{state |
        active_experiments: Map.put(state.active_experiments, experiment_id, experiment),
        experiment_counter: state.experiment_counter + 1
      }
      
      Logger.info("[Chaos] Starting experiment: #{experiment.name}")
      
      {:ok, experiment, new_state}
    end
  end

  defp execute_campaign(campaign_spec, state) do
    campaign_id = campaign_spec.id || "campaign_#{state.campaign_counter}"
    
    campaign = %{campaign_spec |
      id: campaign_id,
      status: :running,
      started_at: DateTime.utc_now(),
      results: []
    }
    
    # Execute experiments in sequence
    results = Enum.map(campaign.experiments, fn exp_spec ->
      case execute_experiment(exp_spec, state) do
        {:ok, experiment, _new_state} ->
          # Wait for completion
          wait_for_experiment_completion(experiment.id)
          get_experiment_results(experiment.id)
        
        {:error, reason} ->
          {:error, reason}
      end
    end)
    
    completed_campaign = %{campaign |
      status: :completed,
      ended_at: DateTime.utc_now(),
      results: results
    }
    
    new_state = %{state |
      campaigns: Map.put(state.campaigns, campaign_id, completed_campaign),
      campaign_counter: state.campaign_counter + 1
    }
    
    {:ok, completed_campaign, new_state}
  end

  defp execute_experiment_step(experiment, step_index, state) do
    steps = experiment.steps
    
    if step_index < length(steps) do
      step = Enum.at(steps, step_index)
      
      # Execute the step
      step_result = execute_step_action(step, state)
      
      # Update experiment results
      updated_experiment = update_experiment_results(experiment, step, step_result)
      
      # Check if step succeeded
      if step_succeeded?(step, step_result) do
        # Schedule next step
        next_index = step_index + 1
        
        if next_index < length(steps) do
          next_step = Enum.at(steps, next_index)
          delay = next_step.duration || 1000
          Process.send_after(self(), {:execute_step, experiment.id, next_index}, delay)
        else
          # All steps completed
          Process.send_after(self(), {:complete_experiment, experiment.id}, 100)
        end
        
        %{state |
          active_experiments: Map.put(state.active_experiments, experiment.id, updated_experiment)
        }
      else
        # Step failed - trigger rollback if configured
        if state.configuration.auto_rollback do
          rollback_experiment(updated_experiment, state)
        else
          failed_experiment = %{updated_experiment | status: :failed}
          
          %{state |
            active_experiments: Map.delete(state.active_experiments, experiment.id),
            experiments: Map.put(state.experiments, experiment.id, failed_experiment)
          }
        end
      end
    else
      state
    end
  end

  defp execute_step_action(step, state) do
    case step.action do
      :inject_fault ->
        inject_fault_action(step)
      
      :create_partition ->
        create_partition_action(step)
      
      :trigger_cascade ->
        trigger_cascade_action(step)
      
      :verify_recovery ->
        verify_recovery_action(step)
      
      :verify_consistency ->
        verify_consistency_action(step)
      
      :measure_blast_radius ->
        measure_blast_radius_action(step)
      
      _ ->
        {:error, :unknown_action}
    end
  end

  defp inject_fault_action(step) do
    fault_type = step.parameters[:type]
    severity = step.parameters[:severity]
    
    FaultInjector.inject_fault(
      fault_type,
      step.target,
      severity: severity,
      duration: step.duration
    )
  end

  defp create_partition_action(step) do
    partition_type = step.parameters[:partition_type]
    
    # Simulate network partition
    FaultInjector.inject_fault(
      :network_partition,
      step.target,
      severity: :critical,
      duration: step.duration,
      metadata: %{partition_type: partition_type}
    )
  end

  defp trigger_cascade_action(step) do
    initial_failure = %{
      component: step.parameters[:initial_failure],
      type: :service_failure
    }
    
    CascadeSimulator.simulate_cascade(
      initial_failure,
      max_depth: step.parameters[:max_depth] || 3
    )
  end

  defp verify_recovery_action(step) do
    expected_state = step.parameters[:expected_state]
    
    # Check system state
    actual_state = check_system_state(step.target)
    
    if actual_state == expected_state do
      {:ok, %{state: actual_state}}
    else
      {:error, {:unexpected_state, actual_state}}
    end
  end

  defp verify_consistency_action(step) do
    # Check data consistency
    consistency_check = check_data_consistency(step.target)
    
    {:ok, %{consistent: consistency_check}}
  end

  defp measure_blast_radius_action(step) do
    # Get cascade analysis
    {:ok, analysis} = CascadeSimulator.analyze_blast_radius(
      step.target,
      :general_failure
    )
    
    {:ok, analysis}
  end

  defp stop_experiment_impl(experiment, state) do
    # Clean up any active faults
    FaultInjector.clear_all_faults()
    
    # Trigger rollback if needed
    if state.configuration.auto_rollback do
      rollback_experiment(experiment, state)
    end
    
    %{experiment |
      status: :stopped,
      ended_at: DateTime.utc_now()
    }
  end

  defp complete_experiment(experiment) do
    # Analyze results
    final_results = analyze_experiment_results(experiment)
    
    # Determine success/failure
    status = if experiment_succeeded?(experiment, final_results) do
      :succeeded
    else
      :failed
    end
    
    %{experiment |
      status: status,
      ended_at: DateTime.utc_now(),
      results: final_results
    }
  end

  defp rollback_experiment(experiment, _state) do
    Logger.info("[Chaos] Rolling back experiment: #{experiment.name}")
    
    # Execute rollback actions for each step
    Enum.each(experiment.steps, fn step ->
      if step.rollback_action do
        step.rollback_action.()
      end
    end)
    
    # Clear all faults
    FaultInjector.clear_all_faults()
  end

  defp validate_experiment_spec(experiment_spec, _state) do
    validations = [
      validate_required_fields(experiment_spec),
      validate_steps(experiment_spec.steps),
      validate_success_criteria(experiment_spec.success_criteria)
    ]
    
    case Enum.find(validations, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp validate_required_fields(experiment_spec) do
    required = [:name, :type, :steps]
    
    missing = Enum.filter(required, fn field ->
      Map.get(experiment_spec, field) == nil
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_steps(nil), do: {:error, :no_steps}
  defp validate_steps([]), do: {:error, :no_steps}
  defp validate_steps(steps) when is_list(steps), do: :ok
  defp validate_steps(_), do: {:error, :invalid_steps}

  defp validate_success_criteria(nil), do: :ok
  defp validate_success_criteria(criteria) when is_map(criteria), do: :ok
  defp validate_success_criteria(_), do: {:error, :invalid_criteria}

  defp perform_safety_checks(experiment) do
    # Check if it's safe to run the experiment
    checks = [
      check_system_health(),
      check_active_alerts(),
      check_business_hours(),
      check_resource_availability()
    ]
    
    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp dry_run_experiment(experiment, state) do
    Logger.info("[Chaos] DRY RUN: Would execute experiment #{experiment.name}")
    
    # Simulate execution without actual effects
    simulated_results = simulate_experiment_execution(experiment)
    
    completed_experiment = %{experiment |
      status: :dry_run_completed,
      ended_at: DateTime.utc_now(),
      results: simulated_results
    }
    
    new_state = %{state |
      experiments: Map.put(state.experiments, experiment.id, completed_experiment)
    }
    
    {:ok, completed_experiment, new_state}
  end

  defp simulate_experiment_execution(experiment) do
    %{
      simulated: true,
      steps_executed: length(experiment.steps),
      predicted_outcome: :success,
      estimated_impact: :medium
    }
  end

  defp update_experiment_results(experiment, step, step_result) do
    results = Map.put(experiment.results, step.id, step_result)
    %{experiment | results: results}
  end

  defp step_succeeded?(step, step_result) do
    case step_result do
      {:ok, _} -> 
        # Run validation if specified
        if step.validation do
          step.validation.()
        else
          true
        end
      
      {:error, _} -> false
    end
  end

  defp experiment_succeeded?(experiment, results) do
    if experiment.success_criteria do
      Enum.all?(experiment.success_criteria, fn {key, expected_value} ->
        check_criterion(key, expected_value, results)
      end)
    else
      # No criteria specified, check if all steps succeeded
      Enum.all?(results, fn {_step_id, result} ->
        match?({:ok, _}, result)
      end)
    end
  end

  defp check_criterion(key, expected_value, results) do
    # Check if criterion is met in results
    case Map.get(results, key) do
      nil -> false
      actual_value -> actual_value == expected_value
    end
  end

  defp analyze_experiment_results(experiment) do
    # Aggregate and analyze all step results
    Map.merge(experiment.results, %{
      total_steps: length(experiment.steps),
      successful_steps: count_successful_steps(experiment.results),
      duration: calculate_experiment_duration(experiment),
      resilience_score: calculate_experiment_score(experiment.results)
    })
  end

  defp count_successful_steps(results) do
    Enum.count(results, fn {_step_id, result} ->
      match?({:ok, _}, result)
    end)
  end

  defp calculate_experiment_duration(experiment) do
    if experiment.started_at && experiment.ended_at do
      DateTime.diff(experiment.ended_at, experiment.started_at, :millisecond)
    else
      0
    end
  end

  defp calculate_experiment_score(results) do
    # Calculate a resilience score based on results
    successful = count_successful_steps(results)
    total = map_size(results)
    
    if total > 0 do
      successful / total
    else
      0
    end
  end

  defp wait_for_experiment_completion(experiment_id) do
    # Simplified waiting logic
    Process.sleep(5000)
  end

  defp schedule_next_run(campaign) do
    interval = campaign.schedule[:interval] || 3600_000  # Default 1 hour
    Process.send_after(self(), {:run_scheduled_campaign, campaign.id}, interval)
  end

  defp load_predefined_experiments do
    [
      database_resilience_experiment(),
      network_partition_experiment(),
      cascade_failure_experiment()
    ]
  end

  # Validation functions (stubs)
  defp validate_database_failover, do: true
  defp validate_database_recovery, do: true
  defp validate_consistency, do: true
  defp validate_blast_radius, do: true

  # System check functions (stubs)
  defp check_system_state(_target), do: :healthy
  defp check_data_consistency(_target), do: true
  defp check_system_health, do: :ok
  defp check_active_alerts, do: :ok
  defp check_business_hours, do: :ok
  defp check_resource_availability, do: :ok
end