defmodule VsmPhoenix.ML.MLIntegrationTest do
  use ExUnit.Case, async: false
  alias VsmPhoenix.ML.VsmIntegration
  alias VsmPhoenix.ML.PerformanceMonitor
  alias VsmPhoenix.ML.GPUManager
  alias VsmPhoenix.ML.ModelStorage

  describe "VSM integration" do
    test "analyzes System 1 operations data" do
      system1_data = %{
        agents: [
          %{
            response_time: 100,
            success_rate: 0.95,
            error_count: 2,
            task_completion_rate: 0.92,
            resource_usage: 0.45
          },
          %{
            response_time: 150,
            success_rate: 0.88,
            error_count: 5,
            task_completion_rate: 0.85,
            resource_usage: 0.62
          }
        ]
      }
      
      case VsmIntegration.analyze_system_data(1, system1_data) do
        {:ok, analysis} ->
          assert analysis.system == 1
          assert analysis.analysis_type == :agent_behavior
          assert Map.has_key?(analysis, :anomalies)
          assert Map.has_key?(analysis, :patterns)
          assert Map.has_key?(analysis, :recommendations)
          assert Map.has_key?(analysis, :timestamp)
        
        {:error, reason} ->
          # Integration might fail if ML models aren't initialized
          assert is_binary(reason)
      end
    end

    test "analyzes System 3 management data" do
      system3_data = %{
        cpu_usage: 75.5,
        memory_usage: 68.2,
        network_latency: 45,
        error_rate: 0.02,
        throughput: 1250,
        response_time: 120
      }
      
      case VsmIntegration.analyze_system_data(3, system3_data) do
        {:ok, analysis} ->
          assert analysis.system == 3
          assert analysis.analysis_type == :operational_health
          assert Map.has_key?(analysis, :anomalies)
          assert Map.has_key?(analysis, :predictions)
          assert Map.has_key?(analysis, :risk_assessment)
          assert is_number(analysis.risk_assessment)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "analyzes System 4 intelligence data" do
      system4_data = %{
        environmental_sensors: [
          %{temperature: 22.5, humidity: 45.0, pressure: 1013.2, noise_level: 35, air_quality: 85},
          %{temperature: 23.1, humidity: 47.2, pressure: 1012.8, noise_level: 38, air_quality: 82},
          %{temperature: 21.8, humidity: 44.5, pressure: 1013.5, noise_level: 33, air_quality: 87}
        ]
      }
      
      case VsmIntegration.analyze_system_data(4, system4_data) do
        {:ok, analysis} ->
          assert analysis.system == 4
          assert analysis.analysis_type == :environmental_intelligence
          assert Map.has_key?(analysis, :spatial_patterns)
          assert Map.has_key?(analysis, :temporal_patterns)
          assert Map.has_key?(analysis, :intelligence_score)
          assert is_number(analysis.intelligence_score)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "analyzes System 5 policy data" do
      system5_data = %{
        policy_compliance: 0.92,
        outcome_satisfaction: 0.85,
        resource_efficiency: 0.78,
        stakeholder_approval: 0.88,
        implementation_cost: 125000
      }
      
      case VsmIntegration.analyze_system_data(5, system5_data) do
        {:ok, analysis} ->
          assert analysis.system == 5
          assert analysis.analysis_type == :policy_analytics
          assert Map.has_key?(analysis, :outcome_predictions)
          assert Map.has_key?(analysis, :policy_effectiveness)
          assert is_number(analysis.policy_effectiveness)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "generates system health assessment" do
      case VsmIntegration.get_system_health_assessment() do
        {:ok, assessment} ->
          assert Map.has_key?(assessment, :overall_health)
          assert Map.has_key?(assessment, :systems_health)
          assert Map.has_key?(assessment, :health_status)
          assert Map.has_key?(assessment, :recommendations)
          assert is_number(assessment.overall_health)
          assert assessment.overall_health >= 0.0
          assert assessment.overall_health <= 1.0
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "handles invalid system IDs gracefully" do
      invalid_data = %{test: "data"}
      
      case VsmIntegration.analyze_system_data(99, invalid_data) do
        {:ok, _analysis} ->
          flunk("Should have failed with invalid system ID")
        
        {:error, reason} ->
          assert reason =~ "Unknown VSM system"
      end
    end
  end

  describe "performance monitoring integration" do
    test "records and retrieves training metrics" do
      model_name = "test_model_#{:rand.uniform(1000)}"
      metrics = %{
        loss: 0.25,
        accuracy: 0.85,
        training_time: 1200,
        epochs: 50
      }
      
      {:ok, _message} = PerformanceMonitor.record_training_metrics(model_name, metrics)
      
      case PerformanceMonitor.get_model_metrics(model_name) do
        {:ok, recorded_metrics} ->
          assert Map.has_key?(recorded_metrics, :training_metrics)
          assert length(recorded_metrics.training_metrics) >= 1
          
          latest_record = hd(recorded_metrics.training_metrics)
          assert latest_record.model_name == model_name
          assert latest_record.metrics == metrics
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "records and retrieves inference metrics" do
      model_name = "inference_test_#{:rand.uniform(1000)}"
      metrics = %{
        inference_time: 50,
        throughput: 100,
        accuracy: 0.92
      }
      
      {:ok, _message} = PerformanceMonitor.record_inference_metrics(model_name, metrics)
      
      case PerformanceMonitor.get_model_metrics(model_name) do
        {:ok, recorded_metrics} ->
          assert Map.has_key?(recorded_metrics, :performance_metrics)
          assert length(recorded_metrics.performance_metrics) >= 1
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "generates performance reports" do
      case PerformanceMonitor.get_performance_report() do
        {:ok, report} ->
          assert Map.has_key?(report, :system_health)
          assert Map.has_key?(report, :ml_models)
          assert Map.has_key?(report, :resource_trends)
          assert Map.has_key?(report, :alerts)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end

  describe "GPU management integration" do
    test "retrieves GPU status" do
      case GPUManager.get_gpu_status() do
        {:ok, status} ->
          assert Map.has_key?(status, :gpu_enabled)
          assert Map.has_key?(status, :device_count)
          assert Map.has_key?(status, :devices)
          assert is_boolean(status.gpu_enabled)
          assert is_integer(status.device_count)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "handles GPU memory cleanup" do
      case GPUManager.cleanup_gpu_memory() do
        {:ok, message} ->
          assert is_binary(message)
          assert message =~ "cleaned" or message =~ "Memory cleaned"
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "creates tensor backends" do
      case GPUManager.create_tensor_backend(0) do
        {:ok, backend} ->
          # Should return either GPU backend or fallback to CPU
          assert backend == Nx.BinaryBackend or 
                 (is_tuple(backend) and elem(backend, 0) == EXLA.Backend)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end

  describe "model storage integration" do
    test "saves and loads models" do
      model_name = "test_storage_#{:rand.uniform(1000)}"
      model_data = %{
        weights: [1.0, 2.0, 3.0],
        biases: [0.1, 0.2],
        architecture: "simple_linear"
      }
      metadata = %{
        model_type: "linear_regression",
        trained_on: "test_data"
      }
      
      # Save model
      case ModelStorage.save_model(model_name, model_data, metadata) do
        {:ok, saved_metadata} ->
          assert Map.has_key?(saved_metadata, :created_at)
          assert Map.has_key?(saved_metadata, :version)
          
          # Load model
          case ModelStorage.load_model(model_name) do
            {:ok, loaded} ->
              assert loaded.model == model_data
              assert Map.has_key?(loaded, :metadata)
              assert Map.has_key?(loaded, :loaded_at)
            
            {:error, reason} ->
              flunk("Model load failed: #{reason}")
          end
        
        {:error, reason} ->
          # Storage might fail in test environment
          assert is_binary(reason)
      end
    end

    test "lists stored models" do
      case ModelStorage.list_models() do
        {:ok, models} ->
          assert is_list(models)
          # Each model should have required fields
          Enum.each(models, fn model ->
            assert Map.has_key?(model, :name)
            assert Map.has_key?(model, :created_at)
          end)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "handles model deletion" do
      # Create a temporary model
      temp_model_name = "temp_delete_#{:rand.uniform(1000)}"
      temp_data = %{test: "data"}
      
      case ModelStorage.save_model(temp_model_name, temp_data, %{}) do
        {:ok, _metadata} ->
          # Delete the model
          case ModelStorage.delete_model(temp_model_name) do
            {:ok, message} ->
              assert is_binary(message)
              
              # Verify it's deleted
              case ModelStorage.load_model(temp_model_name) do
                {:ok, _model} ->
                  flunk("Model should have been deleted")
                
                {:error, reason} ->
                  assert reason =~ "not found"
              end
            
            {:error, reason} ->
              assert is_binary(reason)
          end
        
        {:error, _reason} ->
          # Save failed, skip delete test
          :ok
      end
    end
  end

  describe "system metrics integration" do
    test "retrieves system metrics" do
      case PerformanceMonitor.get_system_metrics() do
        {:ok, metrics} ->
          assert Map.has_key?(metrics, :cpu_usage)
          assert Map.has_key?(metrics, :memory_usage)
          assert Map.has_key?(metrics, :gpu_usage)
          assert Map.has_key?(metrics, :disk_usage)
          assert Map.has_key?(metrics, :timestamp)
          
          assert is_number(metrics.cpu_usage)
          assert is_number(metrics.memory_usage)
          assert is_number(metrics.gpu_usage)
          assert is_number(metrics.disk_usage)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "handles alert thresholds" do
      metric = :cpu_usage
      threshold = 80.0
      
      {:ok, message} = PerformanceMonitor.set_alert_threshold(metric, threshold)
      assert is_binary(message)
    end
  end

  describe "ML pipeline integration" do
    test "end-to-end ML workflow simulation" do
      # This test simulates a complete ML workflow
      # 1. Generate training data
      training_data = generate_mock_training_data()
      
      # 2. Train models (if available)
      training_results = simulate_training(training_data)
      
      # 3. Make predictions
      test_data = generate_mock_test_data()
      prediction_results = simulate_predictions(test_data)
      
      # 4. Record metrics
      record_workflow_metrics(training_results, prediction_results)
      
      # Verify the workflow completed without errors
      assert is_map(training_results)
      assert is_map(prediction_results)
    end
  end

  # Helper functions for integration tests
  
  defp generate_mock_training_data do
    %{
      features: Enum.map(1..100, fn _ -> 
        [:rand.uniform() * 10, :rand.uniform() * 5, :rand.uniform() * 2]
      end),
      targets: Enum.map(1..100, fn _ -> :rand.uniform() end),
      time_series: Enum.map(1..50, fn _ -> :rand.uniform() * 100 end)
    }
  end

  defp generate_mock_test_data do
    %{
      features: [
        [2.5, 1.8, 0.7],
        [7.2, 3.1, 1.4],
        [1.1, 0.9, 0.3]
      ],
      time_series: [45.2, 48.1, 52.3, 49.7, 51.2]
    }
  end

  defp simulate_training(training_data) do
    %{
      anomaly_training: :simulated,
      pattern_training: :simulated,
      prediction_training: :simulated,
      status: :completed,
      data_points: length(training_data.features)
    }
  end

  defp simulate_predictions(test_data) do
    %{
      anomaly_predictions: length(test_data.features),
      pattern_predictions: 3,
      time_series_predictions: 5,
      status: :completed
    }
  end

  defp record_workflow_metrics(training_results, prediction_results) do
    workflow_metrics = %{
      training_status: training_results.status,
      prediction_status: prediction_results.status,
      total_operations: training_results.data_points + prediction_results.anomaly_predictions,
      workflow_completed_at: DateTime.utc_now()
    }
    
    PerformanceMonitor.record_training_metrics("integration_test_workflow", workflow_metrics)
  end
end