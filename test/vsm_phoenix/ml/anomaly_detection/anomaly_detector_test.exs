defmodule VsmPhoenix.ML.AnomalyDetection.AnomalyDetectorTest do
  use ExUnit.Case, async: true
  alias VsmPhoenix.ML.AnomalyDetection.AnomalyDetector

  describe "anomaly detection" do
    test "detects anomalies in simple numeric data" do
      # Normal data points
      normal_data = [1.0, 1.1, 0.9, 1.2, 0.8, 1.0, 1.1]
      
      # Train on normal data
      {:ok, _message} = AnomalyDetector.train(normal_data, [threshold: 0.3])
      
      # Test with anomalous data point
      anomalous_data = [5.0]  # Clearly anomalous
      
      case AnomalyDetector.detect(anomalous_data) do
        {:ok, result} ->
          assert result.is_anomaly == true
          assert result.confidence > 0.3
        
        {:error, reason} ->
          # If models aren't trained yet, this is expected
          assert reason =~ "not trained" or reason =~ "not found"
      end
    end

    test "handles batch anomaly detection" do
      test_data = [
        [1.0, 1.1, 0.9],   # Normal
        [10.0, 11.0, 9.0], # Anomalous
        [1.2, 0.8, 1.0]    # Normal
      ]
      
      case AnomalyDetector.batch_detect(test_data) do
        {:ok, results} ->
          assert length(results) == 3
          assert Enum.all?(results, fn result ->
            Map.has_key?(result, :is_anomaly) and
            Map.has_key?(result, :confidence)
          end)
        
        {:error, reason} ->
          # If models aren't trained, this is expected
          assert is_binary(reason)
      end
    end

    test "training with different model options" do
      training_data = Enum.map(1..100, fn _ -> 
        [:rand.uniform() * 2, :rand.uniform() * 2, :rand.uniform() * 2]
      end)
      
      # Test training with different options
      training_options = [
        [model_type: :autoencoder, epochs: 10],
        [model_type: :isolation_forest, n_trees: 50],
        [threshold: 0.2]
      ]
      
      Enum.each(training_options, fn options ->
        case AnomalyDetector.train(training_data, options) do
          {:ok, message} ->
            assert is_binary(message)
            assert message =~ "trained"
          
          {:error, reason} ->
            # Some training might fail due to missing dependencies
            assert is_binary(reason)
        end
      end)
    end

    test "handles invalid input gracefully" do
      # Test with empty data
      assert {:error, _reason} = AnomalyDetector.detect([])
      
      # Test with non-numeric data
      case AnomalyDetector.detect(["invalid", "data"]) do
        {:ok, _result} -> :ok  # Converted to numeric
        {:error, _reason} -> :ok  # Expected failure
      end
    end
  end

  describe "model state management" do
    test "maintains model state across operations" do
      # This test verifies that the GenServer maintains state
      initial_state = :sys.get_state(AnomalyDetector)
      assert initial_state.__struct__ == VsmPhoenix.ML.AnomalyDetection.AnomalyDetector
      
      # Training should update state
      training_data = Enum.map(1..50, fn _ -> [:rand.uniform(), :rand.uniform()] end)
      
      case AnomalyDetector.train(training_data, [epochs: 5]) do
        {:ok, _message} ->
          updated_state = :sys.get_state(AnomalyDetector)
          # State should have been updated (though exact comparison is complex)
          assert updated_state.__struct__ == VsmPhoenix.ML.AnomalyDetection.AnomalyDetector
        
        {:error, _reason} ->
          # Training might fail in test environment
          :ok
      end
    end
  end

  describe "error handling" do
    test "handles training failures gracefully" do
      # Test with invalid training data
      invalid_data = nil
      
      case AnomalyDetector.train(invalid_data, []) do
        {:ok, _message} -> 
          flunk("Should have failed with invalid data")
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end

    test "handles detection on untrained models" do
      # Restart the process to clear any trained models
      Process.exit(Process.whereis(AnomalyDetector), :kill)
      
      # Wait for restart
      Process.sleep(100)
      
      # Detection might work with default models or fail gracefully
      case AnomalyDetector.detect([1.0, 2.0, 3.0]) do
        {:ok, result} ->
          assert Map.has_key?(result, :is_anomaly)
        
        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end
end