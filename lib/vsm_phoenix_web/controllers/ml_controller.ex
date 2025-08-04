defmodule VsmPhoenixWeb.MLController do
  @moduledoc """
  API Controller for Machine Learning Engine functionality.
  Provides endpoints for anomaly detection, pattern recognition, 
  predictive analytics, and neural network training.
  """

  use VsmPhoenixWeb, :controller
  require Logger

  alias VsmPhoenix.ML.AnomalyDetection.AnomalyDetector
  alias VsmPhoenix.ML.PatternRecognition.PatternRecognizer
  alias VsmPhoenix.ML.Prediction.Predictor
  alias VsmPhoenix.ML.NeuralTraining.NeuralTrainer
  alias VsmPhoenix.ML.ModelStorage
  alias VsmPhoenix.ML.PerformanceMonitor
  alias VsmPhoenix.ML.GPUManager
  alias VsmPhoenix.ML.VsmIntegration

  # Anomaly Detection Endpoints

  def detect_anomaly(conn, %{"data" => data} = params) do
    try do
      case AnomalyDetector.detect(data) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Anomaly detection failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def batch_detect_anomalies(conn, %{"data_batch" => data_batch}) do
    try do
      case AnomalyDetector.batch_detect(data_batch) do
        {:ok, results} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            results: results,
            total_samples: length(results),
            anomalies_detected: Enum.count(results, & &1.is_anomaly),
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Batch anomaly detection failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def train_anomaly_detector(conn, %{"data" => data} = params) do
    options = Map.get(params, "options", []) |> atomize_keys()
    
    try do
      case AnomalyDetector.train(data, options) do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{success: true, message: message})
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Anomaly detector training failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Pattern Recognition Endpoints

  def recognize_pattern(conn, %{"data" => data, "pattern_type" => pattern_type}) do
    try do
      pattern_atom = String.to_atom(pattern_type)
      
      case PatternRecognizer.recognize_pattern(data, pattern_atom) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Pattern recognition failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def train_pattern_recognizer(conn, %{"model_type" => model_type, "data" => data} = params) do
    labels = Map.get(params, "labels", [])
    options = Map.get(params, "options", []) |> atomize_keys()
    
    try do
      result = case model_type do
        "cnn" -> PatternRecognizer.train_cnn(data, labels, options)
        "rnn" -> PatternRecognizer.train_rnn(data, labels, options)
        "transformer" -> PatternRecognizer.train_transformer(data, labels, options)
        _ -> {:error, "Unknown model type: #{model_type}"}
      end
      
      case result do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{success: true, message: message})
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Pattern recognizer training failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_pattern_library(conn, _params) do
    try do
      case PatternRecognizer.get_pattern_library() do
        {:ok, library} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            pattern_library: library,
            pattern_count: map_size(library)
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get pattern library failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Prediction Endpoints

  def predict_time_series(conn, %{"data" => data, "steps_ahead" => steps_ahead} = params) do
    model_type = Map.get(params, "model_type", "lstm") |> String.to_atom()
    
    try do
      case Predictor.predict_time_series(data, steps_ahead, model_type) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Time series prediction failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def predict_regression(conn, %{"data" => data} = params) do
    model_type = Map.get(params, "model_type", "linear") |> String.to_atom()
    
    try do
      case Predictor.predict_regression(data, model_type) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Regression prediction failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def predict_classification(conn, %{"data" => data} = params) do
    model_type = Map.get(params, "model_type", "logistic") |> String.to_atom()
    
    try do
      case Predictor.predict_classification(data, model_type) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Classification prediction failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def ensemble_predict(conn, %{"data" => data, "prediction_type" => prediction_type} = params) do
    options = Map.get(params, "options", []) |> atomize_keys()
    prediction_atom = String.to_atom(prediction_type)
    
    try do
      case Predictor.ensemble_predict(data, prediction_atom, options) do
        {:ok, result} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            result: result,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Ensemble prediction failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def train_predictor(conn, %{"model_type" => model_type, "data" => data, "targets" => targets} = params) do
    options = Map.get(params, "options", []) |> atomize_keys()
    
    try do
      result = case params["prediction_type"] do
        "time_series" -> Predictor.train_time_series(data, options)
        "regression" -> Predictor.train_regression(data, targets, options)
        "classification" -> Predictor.train_classification(data, targets, options)
        _ -> {:error, "Unknown prediction type"}
      end
      
      case result do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{success: true, message: message})
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Predictor training failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Neural Training Endpoints

  def train_neural_network(conn, %{"model_config" => model_config, "data" => data} = params) do
    options = Map.get(params, "options", []) |> atomize_keys()
    
    try do
      # This would require deserializing the model config
      # For now, return a placeholder response
      conn
      |> put_status(:accepted)
      |> json(%{
        success: true,
        message: "Neural network training initiated",
        training_id: generate_training_id()
      })
    rescue
      error ->
        Logger.error("Neural network training failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def hyperparameter_tuning(conn, %{"model_fn_config" => model_config, "data" => data} = params) do
    options = Map.get(params, "options", []) |> atomize_keys()
    
    try do
      # This would require more complex model function handling
      # For now, return a placeholder response
      conn
      |> put_status(:accepted)
      |> json(%{
        success: true,
        message: "Hyperparameter tuning initiated",
        tuning_id: generate_training_id()
      })
    rescue
      error ->
        Logger.error("Hyperparameter tuning failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_training_history(conn, _params) do
    try do
      case NeuralTrainer.get_training_history() do
        {:ok, history} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            training_history: history,
            session_count: length(history)
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get training history failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Model Storage Endpoints

  def save_model(conn, %{"model_name" => model_name, "model_data" => model_data} = params) do
    metadata = Map.get(params, "metadata", %{})
    
    try do
      case ModelStorage.save_model(model_name, model_data, metadata) do
        {:ok, saved_metadata} ->
          conn
          |> put_status(:created)
          |> json(%{
            success: true,
            message: "Model saved successfully",
            metadata: saved_metadata
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Model save failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def load_model(conn, %{"model_name" => model_name}) do
    try do
      case ModelStorage.load_model(model_name) do
        {:ok, model_data} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            model_data: model_data,
            loaded_at: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Model load failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def list_models(conn, _params) do
    try do
      case ModelStorage.list_models() do
        {:ok, models} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            models: models,
            model_count: length(models)
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("List models failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def delete_model(conn, %{"model_name" => model_name}) do
    try do
      case ModelStorage.delete_model(model_name) do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{success: true, message: message})
        
        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Model delete failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Performance Monitoring Endpoints

  def get_system_metrics(conn, _params) do
    try do
      case PerformanceMonitor.get_system_metrics() do
        {:ok, metrics} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            metrics: metrics,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get system metrics failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_model_metrics(conn, %{"model_name" => model_name}) do
    try do
      case PerformanceMonitor.get_model_metrics(model_name) do
        {:ok, metrics} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            metrics: metrics,
            model_name: model_name
          })
        
        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get model metrics failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_performance_report(conn, _params) do
    try do
      case PerformanceMonitor.get_performance_report() do
        {:ok, report} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            report: report,
            generated_at: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get performance report failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # GPU Management Endpoints

  def get_gpu_status(conn, _params) do
    try do
      case GPUManager.get_gpu_status() do
        {:ok, status} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            gpu_status: status,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get GPU status failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def cleanup_gpu_memory(conn, _params) do
    try do
      case GPUManager.cleanup_gpu_memory() do
        {:ok, message} ->
          conn
          |> put_status(:ok)
          |> json(%{success: true, message: message})
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("GPU memory cleanup failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # VSM Integration Endpoints

  def analyze_vsm_system(conn, %{"system_id" => system_id, "data" => data}) do
    try do
      system_id_int = String.to_integer(system_id)
      
      case VsmIntegration.analyze_system_data(system_id_int, data) do
        {:ok, analysis} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            analysis: analysis,
            system_id: system_id_int
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("VSM system analysis failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_ml_recommendations(conn, %{"system_id" => system_id}) do
    try do
      system_id_int = String.to_integer(system_id)
      
      case VsmIntegration.get_ml_recommendations(system_id_int) do
        {:ok, recommendations} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            recommendations: recommendations,
            system_id: system_id_int
          })
        
        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get ML recommendations failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  def get_system_health_assessment(conn, _params) do
    try do
      case VsmIntegration.get_system_health_assessment() do
        {:ok, assessment} ->
          conn
          |> put_status(:ok)
          |> json(%{
            success: true,
            health_assessment: assessment,
            timestamp: DateTime.utc_now()
          })
        
        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{success: false, error: reason})
      end
    rescue
      error ->
        Logger.error("Get system health assessment failed: #{inspect(error)}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Internal server error"})
    end
  end

  # Utility functions

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      item -> item
    end)
  end
  defp atomize_keys(other), do: other

  defp generate_training_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end
end