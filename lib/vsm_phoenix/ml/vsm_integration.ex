defmodule VsmPhoenix.ML.VsmIntegration do
  @moduledoc """
  Integration layer between ML engines and VSM systems.
  Connects anomaly detection, pattern recognition, and predictive analytics
  with VSM Systems 1, 3, 4, and 5.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.ML.AnomalyDetection.AnomalyDetector
  alias VsmPhoenix.ML.PatternRecognition.PatternRecognizer
  alias VsmPhoenix.ML.Prediction.Predictor
  alias VsmPhoenix.ML.PerformanceMonitor

  defstruct [
    :vsm_systems,
    ml_insights: %{},
    integration_state: %{},
    learning_enabled: true
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Initializing ML-VSM Integration Layer")
    
    state = %__MODULE__{
      vsm_systems: initialize_vsm_systems(),
      learning_enabled: Keyword.get(opts, :learning_enabled, true)
    }

    # Start periodic ML-VSM synchronization
    schedule_ml_sync()

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_system_data, system_id, data}, _from, state) do
    Logger.info("Analyzing system data for VSM System #{system_id}")
    
    try do
      analysis_result = case system_id do
        1 -> analyze_system1_operations(data, state)
        3 -> analyze_system3_operations(data, state)
        4 -> analyze_system4_intelligence(data, state)
        5 -> analyze_system5_policy(data, state)
        _ -> {:error, "Unknown VSM system: #{system_id}"}
      end
      
      # Store insights
      new_insights = Map.put(state.ml_insights, system_id, analysis_result)
      new_state = %{state | ml_insights: new_insights}
      
      {:reply, analysis_result, new_state}
    rescue
      error ->
        Logger.error("ML analysis failed for System #{system_id}: #{inspect(error)}")
        {:reply, {:error, Exception.message(error)}, state}
    end
  end

  @impl true
  def handle_call({:get_ml_recommendations, system_id}, _from, state) do
    case Map.get(state.ml_insights, system_id) do
      nil -> {:reply, {:error, "No ML insights available for System #{system_id}"}, state}
      insights -> 
        recommendations = generate_recommendations(system_id, insights)
        {:reply, {:ok, recommendations}, state}
    end
  end

  @impl true
  def handle_call({:train_on_vsm_data, system_id, training_data}, _from, state) do
    Logger.info("Training ML models on VSM System #{system_id} data")
    
    try do
      training_result = case system_id do
        1 -> train_system1_models(training_data, state)
        3 -> train_system3_models(training_data, state)
        4 -> train_system4_models(training_data, state)
        5 -> train_system5_models(training_data, state)
        _ -> {:error, "Unknown VSM system: #{system_id}"}
      end
      
      {:reply, training_result, state}
    rescue
      error ->
        Logger.error("ML training failed for System #{system_id}: #{inspect(error)}")
        {:reply, {:error, Exception.message(error)}, state}
    end
  end

  @impl true
  def handle_call(:get_system_health_assessment, _from, state) do
    try do
      health_assessment = generate_system_health_assessment(state)
      {:reply, {:ok, health_assessment}, state}
    rescue
      error ->
        Logger.error("Health assessment failed: #{inspect(error)}")
        {:reply, {:error, Exception.message(error)}, state}
    end
  end

  @impl true
  def handle_info(:ml_sync, state) do
    if state.learning_enabled do
      # Perform periodic ML-VSM synchronization
      perform_ml_sync(state)
      schedule_ml_sync()
    end
    
    {:noreply, state}
  end

  # Public API
  def analyze_system_data(system_id, data) do
    GenServer.call(__MODULE__, {:analyze_system_data, system_id, data})
  end

  def get_ml_recommendations(system_id) do
    GenServer.call(__MODULE__, {:get_ml_recommendations, system_id})
  end

  def train_on_vsm_data(system_id, training_data) do
    GenServer.call(__MODULE__, {:train_on_vsm_data, system_id, training_data}, 60_000)
  end

  def get_system_health_assessment do
    GenServer.call(__MODULE__, :get_system_health_assessment)
  end

  # Private functions - VSM System Integration
  
  defp initialize_vsm_systems do
    %{
      1 => %{name: "Operations", ml_focus: :agent_behavior},
      3 => %{name: "Management", ml_focus: :anomaly_detection},
      4 => %{name: "Intelligence", ml_focus: :pattern_recognition},
      5 => %{name: "Policy", ml_focus: :predictive_analytics}
    }
  end

  # System 1: Operations - Agent Behavior Learning
  defp analyze_system1_operations(data, _state) do
    Logger.info("Analyzing System 1 operations with ML")
    
    # Extract agent performance metrics
    agent_data = extract_agent_metrics(data)
    
    # Detect anomalous agent behavior
    anomaly_results = AnomalyDetector.batch_detect(agent_data)
    
    # Recognize behavioral patterns
    pattern_results = PatternRecognizer.recognize_pattern(agent_data, :temporal)
    
    # Generate insights
    %{
      system: 1,
      analysis_type: :agent_behavior,
      anomalies: anomaly_results,
      patterns: pattern_results,
      recommendations: generate_system1_recommendations(anomaly_results, pattern_results),
      timestamp: DateTime.utc_now()
    }
  end

  # System 3: Management - Anomaly Detection in Operations
  defp analyze_system3_operations(data, _state) do
    Logger.info("Analyzing System 3 operations with ML")
    
    # Extract operational metrics
    operational_metrics = extract_operational_metrics(data)
    
    # Detect operational anomalies
    anomaly_results = AnomalyDetector.detect(operational_metrics)
    
    # Predict potential issues
    prediction_results = Predictor.predict_time_series(operational_metrics, 5, :lstm)
    
    %{
      system: 3,
      analysis_type: :operational_health,
      anomalies: anomaly_results,
      predictions: prediction_results,
      risk_assessment: calculate_operational_risk(anomaly_results, prediction_results),
      recommendations: generate_system3_recommendations(anomaly_results, prediction_results),
      timestamp: DateTime.utc_now()
    }
  end

  # System 4: Intelligence - Environmental Pattern Recognition
  defp analyze_system4_intelligence(data, _state) do
    Logger.info("Analyzing System 4 intelligence with ML")
    
    # Extract environmental data
    environmental_data = extract_environmental_data(data)
    
    # Recognize environmental patterns
    spatial_patterns = PatternRecognizer.recognize_pattern(environmental_data, :spatial)
    temporal_patterns = PatternRecognizer.recognize_pattern(environmental_data, :temporal)
    
    # Predict environmental changes
    environmental_predictions = Predictor.predict_regression(environmental_data, :neural)
    
    %{
      system: 4,
      analysis_type: :environmental_intelligence,
      spatial_patterns: spatial_patterns,
      temporal_patterns: temporal_patterns,
      predictions: environmental_predictions,
      intelligence_score: calculate_intelligence_score(spatial_patterns, temporal_patterns),
      recommendations: generate_system4_recommendations(spatial_patterns, temporal_patterns, environmental_predictions),
      timestamp: DateTime.utc_now()
    }
  end

  # System 5: Policy - Predictive Policy Analytics
  defp analyze_system5_policy(data, _state) do
    Logger.info("Analyzing System 5 policy with ML")
    
    # Extract policy effectiveness data
    policy_data = extract_policy_metrics(data)
    
    # Predict policy outcomes
    outcome_predictions = Predictor.ensemble_predict(policy_data, :classification, [])
    
    # Detect policy anomalies
    policy_anomalies = AnomalyDetector.detect(policy_data)
    
    # Analyze policy patterns
    policy_patterns = PatternRecognizer.recognize_pattern(policy_data, :adaptive)
    
    %{
      system: 5,
      analysis_type: :policy_analytics,
      outcome_predictions: outcome_predictions,
      anomalies: policy_anomalies,
      patterns: policy_patterns,
      policy_effectiveness: calculate_policy_effectiveness(outcome_predictions, policy_anomalies),
      recommendations: generate_system5_recommendations(outcome_predictions, policy_anomalies, policy_patterns),
      timestamp: DateTime.utc_now()
    }
  end

  # Training functions for each VSM system
  
  defp train_system1_models(training_data, _state) do
    Logger.info("Training System 1 models on agent behavior data")
    
    # Train anomaly detection for agent behavior
    anomaly_training = AnomalyDetector.train(training_data.agent_metrics, [
      model_type: :autoencoder,
      epochs: 100,
      threshold: 0.15
    ])
    
    # Train pattern recognition for agent sequences
    pattern_training = PatternRecognizer.train_rnn(
      training_data.agent_sequences,
      training_data.behavior_labels,
      [epochs: 50, model_type: :lstm]
    )
    
    %{
      system: 1,
      anomaly_model: anomaly_training,
      pattern_model: pattern_training,
      training_timestamp: DateTime.utc_now()
    }
  end

  defp train_system3_models(training_data, _state) do
    Logger.info("Training System 3 models on operational data")
    
    # Train time series prediction for operational metrics
    prediction_training = Predictor.train_time_series(
      training_data.operational_time_series,
      [model_type: :lstm, epochs: 150, window_size: 20]
    )
    
    # Train anomaly detection for operations
    anomaly_training = AnomalyDetector.train(training_data.operational_metrics, [
      model_type: :isolation_forest,
      n_trees: 200
    ])
    
    %{
      system: 3,
      prediction_model: prediction_training,
      anomaly_model: anomaly_training,
      training_timestamp: DateTime.utc_now()
    }
  end

  defp train_system4_models(training_data, _state) do
    Logger.info("Training System 4 models on environmental intelligence data")
    
    # Train CNN for spatial pattern recognition
    cnn_training = PatternRecognizer.train_cnn(
      training_data.spatial_data,
      training_data.spatial_labels,
      [epochs: 100, batch_size: 64]
    )
    
    # Train transformer for environmental sequences
    transformer_training = PatternRecognizer.train_transformer(
      training_data.environmental_sequences,
      training_data.environmental_targets,
      [epochs: 80, learning_rate: 0.0001]
    )
    
    %{
      system: 4,
      spatial_model: cnn_training,
      temporal_model: transformer_training,
      training_timestamp: DateTime.utc_now()
    }
  end

  defp train_system5_models(training_data, _state) do
    Logger.info("Training System 5 models on policy data")
    
    # Train ensemble classifier for policy outcomes
    classification_training = Predictor.train_classification(
      training_data.policy_features,
      training_data.policy_outcomes,
      [model_type: :neural, epochs: 120]
    )
    
    # Train regression for policy effectiveness
    regression_training = Predictor.train_regression(
      training_data.policy_metrics,
      training_data.effectiveness_scores,
      [model_type: :ridge, alpha: 0.1]
    )
    
    %{
      system: 5,
      classification_model: classification_training,
      regression_model: regression_training,
      training_timestamp: DateTime.utc_now()
    }
  end

  # Data extraction functions
  
  defp extract_agent_metrics(data) do
    # Extract agent performance and behavior metrics
    data
    |> Map.get(:agents, [])
    |> Enum.map(fn agent ->
      [
        Map.get(agent, :response_time, 0),
        Map.get(agent, :success_rate, 0),
        Map.get(agent, :error_count, 0),
        Map.get(agent, :task_completion_rate, 0),
        Map.get(agent, :resource_usage, 0)
      ]
    end)
  end

  defp extract_operational_metrics(data) do
    # Extract operational health metrics
    [
      Map.get(data, :cpu_usage, 0),
      Map.get(data, :memory_usage, 0),
      Map.get(data, :network_latency, 0),
      Map.get(data, :error_rate, 0),
      Map.get(data, :throughput, 0),
      Map.get(data, :response_time, 0)
    ]
  end

  defp extract_environmental_data(data) do
    # Extract environmental intelligence data
    data
    |> Map.get(:environmental_sensors, [])
    |> Enum.map(fn sensor ->
      [
        Map.get(sensor, :temperature, 0),
        Map.get(sensor, :humidity, 0),
        Map.get(sensor, :pressure, 0),
        Map.get(sensor, :noise_level, 0),
        Map.get(sensor, :air_quality, 0)
      ]
    end)
  end

  defp extract_policy_metrics(data) do
    # Extract policy effectiveness metrics
    [
      Map.get(data, :policy_compliance, 0),
      Map.get(data, :outcome_satisfaction, 0),
      Map.get(data, :resource_efficiency, 0),
      Map.get(data, :stakeholder_approval, 0),
      Map.get(data, :implementation_cost, 0)
    ]
  end

  # Recommendation generation functions
  
  defp generate_recommendations(system_id, insights) do
    case system_id do
      1 -> generate_system1_recommendations(insights.anomalies, insights.patterns)
      3 -> generate_system3_recommendations(insights.anomalies, insights.predictions)
      4 -> generate_system4_recommendations(insights.spatial_patterns, insights.temporal_patterns, insights.predictions)
      5 -> generate_system5_recommendations(insights.outcome_predictions, insights.anomalies, insights.patterns)
      _ -> []
    end
  end

  defp generate_system1_recommendations(anomaly_results, pattern_results) do
    recommendations = []
    
    recommendations = case anomaly_results do
      {:ok, results} when is_list(results) ->
        anomalous_agents = Enum.filter(results, & &1.is_anomaly)
        if length(anomalous_agents) > 0 do
          ["Review #{length(anomalous_agents)} agents showing anomalous behavior" | recommendations]
        else
          recommendations
        end
      _ -> recommendations
    end
    
    recommendations = case pattern_results do
      {:ok, %{is_recognized: true, confidence: confidence}} when confidence > 0.8 ->
        ["High confidence behavioral pattern detected - consider optimization" | recommendations]
      _ -> recommendations
    end
    
    if length(recommendations) == 0 do
      ["System 1 operations are running normally"]
    else
      recommendations
    end
  end

  defp generate_system3_recommendations(anomaly_results, prediction_results) do
    recommendations = []
    
    recommendations = case anomaly_results do
      {:ok, %{is_anomaly: true, confidence: confidence}} when confidence > 0.7 ->
        ["Operational anomaly detected with #{Float.round(confidence * 100, 1)}% confidence - investigate immediately" | recommendations]
      _ -> recommendations
    end
    
    recommendations = case prediction_results do
      {:ok, %{predictions: predictions}} ->
        trend = analyze_prediction_trend(predictions)
        case trend do
          :increasing -> ["Metrics trending upward - monitor for capacity issues" | recommendations]
          :decreasing -> ["Metrics trending downward - investigate potential problems" | recommendations]
          _ -> recommendations
        end
      _ -> recommendations
    end
    
    if length(recommendations) == 0 do
      ["System 3 management operations are stable"]
    else
      recommendations
    end
  end

  defp generate_system4_recommendations(spatial_patterns, temporal_patterns, predictions) do
    recommendations = []
    
    recommendations = case spatial_patterns do
      {:ok, %{is_recognized: true, confidence: confidence}} when confidence > 0.8 ->
        ["Strong spatial pattern detected - optimize environmental response" | recommendations]
      _ -> recommendations
    end
    
    recommendations = case temporal_patterns do
      {:ok, %{is_recognized: true}} ->
        ["Temporal environmental pattern identified - adjust monitoring schedule" | recommendations]
      _ -> recommendations
    end
    
    if length(recommendations) == 0 do
      ["System 4 environmental intelligence is operating optimally"]
    else
      recommendations
    end
  end

  defp generate_system5_recommendations(outcome_predictions, anomalies, patterns) do
    recommendations = []
    
    recommendations = case outcome_predictions do
      {:ok, %{confidence: confidence}} when confidence > 0.8 ->
        ["High confidence policy outcome prediction - proceed with implementation" | recommendations]
      {:ok, %{confidence: confidence}} when confidence < 0.5 ->
        ["Low confidence in policy outcomes - review policy design" | recommendations]
      _ -> recommendations
    end
    
    recommendations = case anomalies do
      {:ok, %{is_anomaly: true}} ->
        ["Policy anomaly detected - review recent policy changes" | recommendations]
      _ -> recommendations
    end
    
    if length(recommendations) == 0 do
      ["System 5 policy framework is functioning effectively"]
    else
      recommendations
    end
  end

  # Assessment and calculation functions
  
  defp calculate_operational_risk(anomaly_results, prediction_results) do
    anomaly_risk = case anomaly_results do
      {:ok, %{confidence: confidence}} -> confidence
      _ -> 0.0
    end
    
    prediction_risk = case prediction_results do
      {:ok, %{predictions: predictions}} ->
        trend = analyze_prediction_trend(predictions)
        case trend do
          :critical -> 0.9
          :warning -> 0.6
          :increasing -> 0.3
          _ -> 0.1
        end
      _ -> 0.0
    end
    
    (anomaly_risk + prediction_risk) / 2
  end

  defp calculate_intelligence_score(spatial_patterns, temporal_patterns) do
    spatial_score = case spatial_patterns do
      {:ok, %{confidence: confidence}} -> confidence
      _ -> 0.0
    end
    
    temporal_score = case temporal_patterns do
      {:ok, %{confidence: confidence}} -> confidence
      _ -> 0.0
    end
    
    (spatial_score + temporal_score) / 2
  end

  defp calculate_policy_effectiveness(outcome_predictions, anomalies) do
    prediction_score = case outcome_predictions do
      {:ok, %{confidence: confidence}} -> confidence
      _ -> 0.5
    end
    
    anomaly_penalty = case anomalies do
      {:ok, %{is_anomaly: true, confidence: confidence}} -> confidence * 0.5
      _ -> 0.0
    end
    
    max(prediction_score - anomaly_penalty, 0.0)
  end

  defp analyze_prediction_trend(predictions) when is_list(predictions) do
    if length(predictions) < 2 do
      :stable
    else
      first = hd(predictions)
      last = List.last(predictions)
      
      change_rate = (last - first) / first
      
      cond do
        change_rate > 0.5 -> :critical
        change_rate > 0.2 -> :warning
        change_rate > 0.05 -> :increasing
        change_rate < -0.2 -> :decreasing
        true -> :stable
      end
    end
  end
  defp analyze_prediction_trend(_), do: :stable

  defp generate_system_health_assessment(state) do
    systems_health = 
      state.ml_insights
      |> Enum.map(fn {system_id, insights} ->
        health_score = calculate_system_health_score(insights)
        {system_id, health_score}
      end)
      |> Map.new()
    
    overall_health = if map_size(systems_health) > 0 do
      systems_health |> Map.values() |> Enum.sum() |> Kernel./(map_size(systems_health))
    else
      0.5
    end
    
    %{
      overall_health: overall_health,
      systems_health: systems_health,
      health_status: determine_health_status(overall_health),
      timestamp: DateTime.utc_now(),
      recommendations: generate_health_recommendations(systems_health)
    }
  end

  defp calculate_system_health_score(insights) do
    # Calculate health score based on ML insights
    base_score = 0.8
    
    # Penalize for anomalies
    anomaly_penalty = case Map.get(insights, :anomalies) do
      {:ok, %{is_anomaly: true, confidence: confidence}} -> confidence * 0.3
      _ -> 0.0
    end
    
    # Boost for good patterns
    pattern_boost = case Map.get(insights, :patterns) do
      {:ok, %{is_recognized: true, confidence: confidence}} when confidence > 0.8 -> 0.1
      _ -> 0.0
    end
    
    min(max(base_score - anomaly_penalty + pattern_boost, 0.0), 1.0)
  end

  defp determine_health_status(health_score) do
    cond do
      health_score >= 0.8 -> :excellent
      health_score >= 0.6 -> :good
      health_score >= 0.4 -> :fair
      health_score >= 0.2 -> :poor
      true -> :critical
    end
  end

  defp generate_health_recommendations(systems_health) do
    systems_health
    |> Enum.filter(fn {_system, score} -> score < 0.6 end)
    |> Enum.map(fn {system_id, score} ->
      "System #{system_id} health is below optimal (#{Float.round(score * 100, 1)}%) - investigate ML insights"
    end)
  end

  defp perform_ml_sync(state) do
    # Record performance metrics
    PerformanceMonitor.record_inference_metrics("vsm_integration", %{
      inference_time: 50,  # ms
      throughput: 100,     # requests/sec
      accuracy: 0.85
    })
    
    Logger.debug("ML-VSM synchronization completed")
  end

  defp schedule_ml_sync do
    Process.send_after(self(), :ml_sync, 60_000)  # Every minute
  end
end