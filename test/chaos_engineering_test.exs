defmodule VsmPhoenix.ChaosEngineeringTest do
  use ExUnit.Case
  alias VsmPhoenix.ChaosEngineering.{
    FaultInjector,
    CascadeSimulator,
    ResilienceAnalyzer,
    ChaosOrchestrator,
    ChaosMetrics,
    FaultRegistry
  }

  describe "FaultInjector" do
    test "injects single fault successfully" do
      {:ok, pid} = FaultInjector.start_link()
      
      {:ok, fault} = FaultInjector.inject_fault(
        :network_latency,
        {:system, :test},
        severity: :medium,
        duration: 1000
      )
      
      assert fault.type == :network_latency
      assert fault.severity == :medium
      assert fault.duration == 1000
      assert fault.id != nil
      
      # Clean up
      FaultInjector.clear_fault(fault.id)
      GenServer.stop(pid)
    end

    test "injects random fault" do
      {:ok, pid} = FaultInjector.start_link()
      
      {:ok, fault} = FaultInjector.inject_random_fault(duration: 500)
      
      assert fault.id != nil
      assert fault.type in [:network_latency, :network_partition, :process_crash, :memory_pressure]
      
      GenServer.stop(pid)
    end

    test "injects cascade faults" do
      {:ok, pid} = FaultInjector.start_link()
      
      {:ok, faults} = FaultInjector.inject_cascade(
        {:system, :primary_database},
        depth: 2,
        spread: 2
      )
      
      assert is_list(faults)
      assert length(faults) > 0
      
      GenServer.stop(pid)
    end

    test "lists active faults" do
      {:ok, pid} = FaultInjector.start_link()
      
      {:ok, fault1} = FaultInjector.inject_fault(:network_latency, {:system, :test1})
      {:ok, fault2} = FaultInjector.inject_fault(:memory_pressure, {:system, :test2})
      
      active_faults = FaultInjector.list_active_faults()
      
      assert length(active_faults) == 2
      assert Enum.any?(active_faults, fn f -> f.id == fault1.id end)
      assert Enum.any?(active_faults, fn f -> f.id == fault2.id end)
      
      GenServer.stop(pid)
    end
  end

  describe "CascadeSimulator" do
    test "simulates cascade failure" do
      {:ok, pid} = CascadeSimulator.start_link()
      
      initial_failure = %{
        component: :primary_database,
        type: :database_failure
      }
      
      {:ok, cascade} = CascadeSimulator.simulate_cascade(
        initial_failure,
        max_depth: 3,
        probability: 0.8
      )
      
      assert cascade.id != nil
      assert cascade.initial_failure.component == :primary_database
      assert cascade.blast_radius >= 0
      assert is_list(cascade.affected_components)
      assert is_list(cascade.failure_sequence)
      
      GenServer.stop(pid)
    end

    test "analyzes blast radius" do
      {:ok, pid} = CascadeSimulator.start_link()
      
      {:ok, analysis} = CascadeSimulator.analyze_blast_radius(
        :auth_service,
        :service_failure
      )
      
      assert analysis.component == :auth_service
      assert analysis.failure_type == :service_failure
      assert is_number(analysis.total_affected)
      assert is_list(analysis.direct_impact)
      assert is_number(analysis.risk_score)
      
      GenServer.stop(pid)
    end

    test "predicts cascade path" do
      {:ok, pid} = CascadeSimulator.start_link()
      
      initial_failure = %{
        component: :load_balancer,
        type: :load_balancer_failure
      }
      
      {:ok, prediction} = CascadeSimulator.predict_cascade_path(initial_failure)
      
      assert prediction.initial_failure == initial_failure
      assert is_list(prediction.likely_affected)
      assert is_number(prediction.estimated_blast_radius)
      assert is_list(prediction.recommended_mitigations)
      
      GenServer.stop(pid)
    end

    test "gets dependency graph" do
      {:ok, pid} = CascadeSimulator.start_link()
      
      {:ok, graph} = CascadeSimulator.get_dependency_graph()
      
      assert is_map(graph)
      assert Map.has_key?(graph, :nodes)
      assert Map.has_key?(graph, :edges)
      assert is_list(graph.nodes)
      assert is_list(graph.edges)
      
      GenServer.stop(pid)
    end
  end

  describe "ResilienceAnalyzer" do
    test "runs resilience analysis" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      {:ok, analysis, metrics} = ResilienceAnalyzer.analyze_resilience(
        duration: 5000,
        intensity: :low
      )
      
      assert is_map(analysis)
      assert Map.has_key?(analysis, :resilience_score)
      assert Map.has_key?(analysis, :fault_injection)
      assert Map.has_key?(analysis, :cascade_analysis)
      assert Map.has_key?(analysis, :recovery_analysis)
      
      assert metrics.id != nil
      assert is_number(metrics.mttr)
      assert is_number(metrics.availability)
      
      GenServer.stop(pid)
    end

    test "runs single resilience test" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      {:ok, result} = ResilienceAnalyzer.run_resilience_test("Single Component Failure")
      
      assert result.test_name == "Single Component Failure"
      assert is_boolean(result.success)
      assert is_number(result.duration)
      
      GenServer.stop(pid)
    end

    test "runs test suite" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      {:ok, results} = ResilienceAnalyzer.run_test_suite(:quick)
      
      assert is_list(results)
      assert length(results) > 0
      
      Enum.each(results, fn result ->
        assert Map.has_key?(result, :test_name)
        assert Map.has_key?(result, :success)
        assert Map.has_key?(result, :duration)
      end)
      
      GenServer.stop(pid)
    end

    test "generates resilience report" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      # Run some analysis first
      {:ok, _analysis, _metrics} = ResilienceAnalyzer.analyze_resilience(duration: 1000)
      
      {:ok, report} = ResilienceAnalyzer.generate_report(time_range: :last_hour)
      
      assert report.id != nil
      assert report.overall_score != nil
      assert is_map(report.metrics)
      assert is_list(report.strengths)
      assert is_list(report.weaknesses)
      assert is_list(report.recommendations)
      
      GenServer.stop(pid)
    end

    test "identifies single points of failure" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      {:ok, spofs} = ResilienceAnalyzer.identify_single_points_of_failure()
      
      assert is_list(spofs)
      
      if length(spofs) > 0 do
        spof = List.first(spofs)
        assert Map.has_key?(spof, :component)
        assert Map.has_key?(spof, :risk_level)
        assert Map.has_key?(spof, :impact)
        assert Map.has_key?(spof, :mitigation)
      end
      
      GenServer.stop(pid)
    end

    test "benchmarks recovery times" do
      {:ok, pid} = ResilienceAnalyzer.start_link()
      
      {:ok, benchmarks} = ResilienceAnalyzer.benchmark_recovery_times()
      
      assert is_list(benchmarks)
      assert length(benchmarks) > 0
      
      Enum.each(benchmarks, fn benchmark ->
        assert Map.has_key?(benchmark, :scenario)
        assert Map.has_key?(benchmark, :recovery_time_ms)
        assert is_number(benchmark.recovery_time_ms)
      end)
      
      GenServer.stop(pid)
    end
  end

  describe "ChaosOrchestrator" do
    test "validates experiment specification" do
      {:ok, pid} = ChaosOrchestrator.start_link()
      
      experiment_spec = ChaosOrchestrator.database_resilience_experiment()
      
      result = ChaosOrchestrator.validate_experiment(experiment_spec)
      
      assert result == :ok
      
      GenServer.stop(pid)
    end

    test "runs predefined database resilience experiment" do
      {:ok, pid} = ChaosOrchestrator.start_link(dry_run: true)
      
      experiment_spec = ChaosOrchestrator.database_resilience_experiment()
      
      {:ok, experiment} = ChaosOrchestrator.run_experiment(experiment_spec)
      
      assert experiment.id == "exp_db_resilience"
      assert experiment.name == "Database Resilience Test"
      assert experiment.type == :resilience
      
      GenServer.stop(pid)
    end

    test "runs network partition experiment" do
      {:ok, pid} = ChaosOrchestrator.start_link(dry_run: true)
      
      experiment_spec = ChaosOrchestrator.network_partition_experiment()
      
      {:ok, experiment} = ChaosOrchestrator.run_experiment(experiment_spec)
      
      assert experiment.id == "exp_net_partition"
      assert experiment.name == "Network Partition Resilience"
      assert experiment.type == :network
      
      GenServer.stop(pid)
    end

    test "lists experiments" do
      {:ok, pid} = ChaosOrchestrator.start_link(dry_run: true)
      
      experiment1 = ChaosOrchestrator.database_resilience_experiment()
      experiment2 = ChaosOrchestrator.network_partition_experiment()
      
      {:ok, _} = ChaosOrchestrator.run_experiment(experiment1)
      {:ok, _} = ChaosOrchestrator.run_experiment(experiment2)
      
      {:ok, experiments} = ChaosOrchestrator.list_experiments()
      
      assert length(experiments) >= 2
      
      GenServer.stop(pid)
    end
  end

  describe "ChaosMetrics" do
    test "records and retrieves fault metrics" do
      {:ok, pid} = ChaosMetrics.start_link()
      
      fault = %{
        id: "test_fault",
        type: :network_latency,
        severity: :medium,
        target: {:system, :test},
        duration: 5000
      }
      
      ChaosMetrics.record_fault_injection(fault)
      
      # Wait a bit for processing
      Process.sleep(100)
      
      {:ok, metrics} = ChaosMetrics.get_metrics("fault.injected", :last_hour)
      
      assert length(metrics) >= 1
      
      GenServer.stop(pid)
    end

    test "records recovery metrics" do
      {:ok, pid} = ChaosMetrics.start_link()
      
      ChaosMetrics.record_recovery(:database, 3000)
      
      Process.sleep(100)
      
      {:ok, metrics} = ChaosMetrics.get_metrics("recovery.time", :last_hour)
      
      assert length(metrics) >= 1
      
      GenServer.stop(pid)
    end

    test "gets dashboard data" do
      {:ok, pid} = ChaosMetrics.start_link()
      
      # Record some sample data
      fault = %{
        id: "test_fault",
        type: :network_latency,
        severity: :medium,
        target: {:system, :test},
        duration: 5000
      }
      
      ChaosMetrics.record_fault_injection(fault)
      ChaosMetrics.record_recovery(:database, 2000)
      
      Process.sleep(100)
      
      {:ok, dashboard} = ChaosMetrics.get_dashboard_data()
      
      assert Map.has_key?(dashboard, :fault_metrics)
      assert Map.has_key?(dashboard, :recovery_metrics)
      assert Map.has_key?(dashboard, :experiment_metrics)
      
      GenServer.stop(pid)
    end

    test "exports metrics in JSON format" do
      {:ok, pid} = ChaosMetrics.start_link()
      
      ChaosMetrics.record_metric("test.metric", 42, %{tag: "test"})
      
      Process.sleep(100)
      
      {:ok, exported} = ChaosMetrics.export_metrics(:json)
      
      assert is_binary(exported)
      assert String.contains?(exported, "test.metric")
      
      GenServer.stop(pid)
    end
  end

  describe "FaultRegistry" do
    test "lists fault types" do
      {:ok, pid} = FaultRegistry.start_link()
      
      {:ok, faults} = FaultRegistry.list_fault_types()
      
      assert is_map(faults)
      assert map_size(faults) > 0
      
      # Check for some expected fault types
      assert Map.has_key?(faults, :network_latency)
      assert Map.has_key?(faults, :process_crash)
      assert Map.has_key?(faults, :byzantine_fault)
      
      GenServer.stop(pid)
    end

    test "gets fault definition" do
      {:ok, pid} = FaultRegistry.start_link()
      
      {:ok, fault_def} = FaultRegistry.get_fault_definition(:network_latency)
      
      assert fault_def.id == :network_latency
      assert fault_def.name == "Network Latency"
      assert fault_def.type == :network
      assert fault_def.category == :infrastructure
      assert is_map(fault_def.parameters)
      assert is_map(fault_def.severity_levels)
      
      GenServer.stop(pid)
    end

    test "lists faults by category" do
      {:ok, pid} = FaultRegistry.start_link()
      
      {:ok, infrastructure_faults} = FaultRegistry.list_fault_types(:infrastructure)
      
      assert is_map(infrastructure_faults)
      assert map_size(infrastructure_faults) > 0
      
      # All faults should be infrastructure category
      Enum.each(infrastructure_faults, fn {_id, fault} ->
        assert fault.category == :infrastructure
      end)
      
      GenServer.stop(pid)
    end

    test "gets fault catalog" do
      {:ok, pid} = FaultRegistry.start_link()
      
      {:ok, catalog} = FaultRegistry.get_fault_catalog()
      
      assert Map.has_key?(catalog, :total_faults)
      assert Map.has_key?(catalog, :enabled_faults)
      assert Map.has_key?(catalog, :categories)
      assert Map.has_key?(catalog, :fault_types)
      
      assert is_number(catalog.total_faults)
      assert catalog.total_faults > 0
      assert is_list(catalog.categories)
      assert is_list(catalog.fault_types)
      
      GenServer.stop(pid)
    end

    test "registers custom fault type" do
      {:ok, pid} = FaultRegistry.start_link()
      
      custom_fault = %FaultRegistry.FaultDefinition{
        id: :custom_test_fault,
        name: "Custom Test Fault",
        type: :custom,
        category: :test,
        description: "A custom fault for testing",
        parameters: %{intensity: {1, 10}},
        severity_levels: %{low: %{intensity: 3}}
      }
      
      :ok = FaultRegistry.register_fault_type(custom_fault)
      
      {:ok, retrieved_fault} = FaultRegistry.get_fault_definition(:custom_test_fault)
      
      assert retrieved_fault.id == :custom_test_fault
      assert retrieved_fault.name == "Custom Test Fault"
      
      GenServer.stop(pid)
    end

    test "enables and disables fault types" do
      {:ok, pid} = FaultRegistry.start_link()
      
      # Disable a fault type
      :ok = FaultRegistry.disable_fault_type(:network_latency)
      
      {:ok, fault_def} = FaultRegistry.get_fault_definition(:network_latency)
      assert fault_def.enabled == false
      
      # Re-enable it
      :ok = FaultRegistry.enable_fault_type(:network_latency)
      
      {:ok, fault_def} = FaultRegistry.get_fault_definition(:network_latency)
      assert fault_def.enabled == true
      
      GenServer.stop(pid)
    end
  end

  describe "Integration Tests" do
    test "full chaos engineering workflow" do
      # Start all services
      {:ok, registry_pid} = FaultRegistry.start_link()
      {:ok, metrics_pid} = ChaosMetrics.start_link()
      {:ok, injector_pid} = FaultInjector.start_link()
      {:ok, simulator_pid} = CascadeSimulator.start_link()
      {:ok, analyzer_pid} = ResilienceAnalyzer.start_link()
      {:ok, orchestrator_pid} = ChaosOrchestrator.start_link(dry_run: true)
      
      # 1. Get fault catalog
      {:ok, catalog} = FaultRegistry.get_fault_catalog()
      assert catalog.total_faults > 0
      
      # 2. Run a chaos experiment
      experiment_spec = ChaosOrchestrator.database_resilience_experiment()
      {:ok, experiment} = ChaosOrchestrator.run_experiment(experiment_spec)
      assert experiment.status in [:running, :dry_run_completed]
      
      # 3. Inject some faults manually
      {:ok, fault} = FaultInjector.inject_fault(
        :network_latency,
        {:system, :test},
        severity: :low
      )
      assert fault.id != nil
      
      # 4. Simulate a cascade
      initial_failure = %{component: :auth_service, type: :service_failure}
      {:ok, cascade} = CascadeSimulator.simulate_cascade(initial_failure)
      assert cascade.blast_radius >= 0
      
      # 5. Run resilience analysis
      {:ok, _analysis, metrics} = ResilienceAnalyzer.analyze_resilience(duration: 1000)
      assert is_number(metrics.availability)
      
      # 6. Check metrics
      {:ok, dashboard} = ChaosMetrics.get_dashboard_data()
      assert Map.has_key?(dashboard, :fault_metrics)
      
      # Clean up
      GenServer.stop(orchestrator_pid)
      GenServer.stop(analyzer_pid)
      GenServer.stop(simulator_pid)
      GenServer.stop(injector_pid)
      GenServer.stop(metrics_pid)
      GenServer.stop(registry_pid)
    end
  end
end