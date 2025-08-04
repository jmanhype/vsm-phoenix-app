defmodule VsmPhoenix.EmergentIntelligence.CollectiveLearning do
  @moduledoc """
  Implements collective learning mechanisms for the swarm.
  Enables the swarm to learn from collective experiences and improve over time.
  """

  require Logger
  alias VsmPhoenix.S5.{RecursionManager, MetasystemManager}

  @learning_rate 0.1
  @memory_capacity 10000
  @experience_threshold 100
  @pattern_recognition_threshold 0.7

  defstruct [
    :knowledge_base,
    :experience_buffer,
    :learned_patterns,
    :performance_history,
    :adaptation_rules,
    :neural_weights,
    :created_at,
    :updated_at
  ]

  @doc """
  Apply collective learning from experiences
  """
  def apply_learning(state, experiences) do
    # Process experiences
    processed = process_experiences(experiences)
    
    # Extract patterns
    patterns = extract_patterns(processed)
    
    # Update knowledge base
    updated_knowledge = update_knowledge_base(state.collective_memory, patterns)
    
    # Adapt agent behaviors
    adapted_agents = adapt_agent_behaviors(state.agents, patterns)
    
    # Update neural weights
    new_weights = update_neural_weights(
      Map.get(state, :neural_weights, initialize_weights()),
      processed
    )
    
    # Generate new adaptation rules
    new_rules = generate_adaptation_rules(patterns, state.decision_history)
    
    %{state |
      collective_memory: updated_knowledge,
      agents: adapted_agents,
      neural_weights: new_weights,
      adaptation_rules: new_rules,
      learning_buffer: [],
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Learn from a specific outcome
  """
  def learn_from_outcome(state, decision, outcome) do
    # Calculate reward signal
    reward = calculate_reward(decision, outcome)
    
    # Update decision weights
    updated_weights = reinforce_decision_path(
      Map.get(state, :neural_weights, initialize_weights()),
      decision,
      reward
    )
    
    # Store experience
    experience = %{
      decision: decision,
      outcome: outcome,
      reward: reward,
      context: extract_context(state),
      timestamp: DateTime.utc_now()
    }
    
    # Add to experience buffer
    new_buffer = [experience | Map.get(state, :experience_buffer, [])]
    |> Enum.take(@memory_capacity)
    
    %{state |
      neural_weights: updated_weights,
      experience_buffer: new_buffer
    }
  end

  @doc """
  Extract learned knowledge
  """
  def extract_knowledge(state) do
    %{
      patterns: Map.get(state, :learned_patterns, []),
      rules: Map.get(state, :adaptation_rules, []),
      insights: generate_insights(state),
      performance_trends: analyze_performance_trends(state)
    }
  end

  @doc """
  Transfer learning to new domain
  """
  def transfer_learning(source_state, target_domain) do
    # Extract transferable knowledge
    transferable = extract_transferable_knowledge(source_state)
    
    # Adapt to target domain
    adapted = adapt_knowledge_to_domain(transferable, target_domain)
    
    # Initialize new state with transferred knowledge
    %{
      collective_memory: %{
        shared_knowledge: adapted.knowledge,
        collective_experiences: [],
        emergent_insights: adapted.insights,
        synchronization_patterns: []
      },
      learned_patterns: adapted.patterns,
      adaptation_rules: adapted.rules,
      neural_weights: adapted.weights
    }
  end

  @doc """
  Perform meta-learning (learning to learn)
  """
  def meta_learn(learning_history) do
    # Analyze learning patterns
    learning_patterns = analyze_learning_patterns(learning_history)
    
    # Identify effective strategies
    effective_strategies = identify_effective_strategies(learning_history)
    
    # Optimize learning parameters
    optimized_params = optimize_learning_parameters(learning_patterns)
    
    %{
      learning_patterns: learning_patterns,
      effective_strategies: effective_strategies,
      optimized_parameters: optimized_params,
      meta_insights: generate_meta_insights(learning_patterns)
    }
  end

  # Private Functions

  defp process_experiences(experiences) do
    experiences
    |> Enum.map(&normalize_experience/1)
    |> Enum.filter(&relevant_experience?/1)
    |> Enum.map(&extract_features/1)
  end

  defp normalize_experience(exp) do
    %{
      decision: Map.get(exp, :decision),
      context: Map.get(exp, :context),
      agents: Map.get(exp, :agents, %{}),
      consciousness: Map.get(exp, :consciousness, 0.5),
      timestamp: Map.get(exp, :timestamp, DateTime.utc_now())
    }
  end

  defp relevant_experience?(exp) do
    # Filter out noise and irrelevant experiences
    Map.get(exp, :consciousness, 0) > 0.3
  end

  defp extract_features(exp) do
    %{
      features: [
        consciousness_feature(exp),
        decision_complexity_feature(exp),
        agent_participation_feature(exp),
        context_richness_feature(exp)
      ],
      original: exp
    }
  end

  defp consciousness_feature(exp) do
    {:consciousness, Map.get(exp, :consciousness, 0.5)}
  end

  defp decision_complexity_feature(exp) do
    decision = Map.get(exp, :decision, %{})
    complexity = calculate_decision_complexity(decision)
    {:complexity, complexity}
  end

  defp agent_participation_feature(exp) do
    agents = Map.get(exp, :agents, %{})
    participation = map_size(agents) / max(1, 10)  # Normalize
    {:participation, participation}
  end

  defp context_richness_feature(exp) do
    context = Map.get(exp, :context, %{})
    richness = map_size(context) / max(1, 20)  # Normalize
    {:context_richness, richness}
  end

  defp calculate_decision_complexity(decision) do
    # Calculate complexity based on decision structure
    case decision do
      %{action: _, parameters: params} when is_map(params) ->
        map_size(params) / 10
      _ ->
        0.1
    end
  end

  defp extract_patterns(processed_experiences) do
    # Group similar experiences
    grouped = group_similar_experiences(processed_experiences)
    
    # Extract patterns from groups
    Enum.map(grouped, fn group ->
      %{
        pattern_type: identify_pattern_type(group),
        frequency: length(group),
        features: aggregate_features(group),
        confidence: calculate_pattern_confidence(group),
        examples: Enum.take(group, 3)
      }
    end)
    |> Enum.filter(& &1.confidence > @pattern_recognition_threshold)
  end

  defp group_similar_experiences(experiences) do
    # Simple clustering based on feature similarity
    experiences
    |> Enum.group_by(&feature_signature/1)
    |> Map.values()
  end

  defp feature_signature(exp) do
    # Create a signature for grouping similar experiences
    exp.features
    |> Enum.map(fn {key, value} ->
      {key, round(value * 10) / 10}  # Quantize to reduce variations
    end)
    |> Enum.sort()
  end

  defp identify_pattern_type(group) do
    # Identify the type of pattern in the group
    first = List.first(group)
    
    cond do
      high_consciousness_pattern?(group) -> :high_consciousness_decision
      convergence_pattern?(group) -> :convergence_behavior
      exploration_pattern?(group) -> :exploration_strategy
      exploitation_pattern?(group) -> :exploitation_strategy
      true -> :general_pattern
    end
  end

  defp high_consciousness_pattern?(group) do
    avg_consciousness = Enum.reduce(group, 0.0, fn exp, acc ->
      {_, consciousness} = List.keyfind(exp.features, :consciousness, 0, {:consciousness, 0})
      acc + consciousness
    end) / length(group)
    
    avg_consciousness > 0.7
  end

  defp convergence_pattern?(group) do
    # Check if experiences show convergence
    consciousness_values = Enum.map(group, fn exp ->
      {_, c} = List.keyfind(exp.features, :consciousness, 0, {:consciousness, 0})
      c
    end)
    
    variance = calculate_variance(consciousness_values)
    variance < 0.1
  end

  defp exploration_pattern?(group) do
    # Check for exploration patterns
    Enum.any?(group, fn exp ->
      decision = exp.original.decision
      Map.get(decision, :action) in [:explore, :search, :discover]
    end)
  end

  defp exploitation_pattern?(group) do
    # Check for exploitation patterns
    Enum.any?(group, fn exp ->
      decision = exp.original.decision
      Map.get(decision, :action) in [:exploit, :optimize, :refine]
    end)
  end

  defp aggregate_features(group) do
    # Aggregate features across the group
    feature_keys = group
    |> List.first()
    |> Map.get(:features, [])
    |> Enum.map(fn {key, _} -> key end)
    
    Enum.map(feature_keys, fn key ->
      values = Enum.map(group, fn exp ->
        {_, value} = List.keyfind(exp.features, key, 0, {key, 0})
        value
      end)
      
      {key, %{
        mean: Enum.sum(values) / length(values),
        variance: calculate_variance(values),
        min: Enum.min(values),
        max: Enum.max(values)
      }}
    end)
  end

  defp calculate_variance(values) do
    if length(values) < 2 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      sum_squared = Enum.reduce(values, 0.0, fn val, acc ->
        acc + :math.pow(val - mean, 2)
      end)
      sum_squared / length(values)
    end
  end

  defp calculate_pattern_confidence(group) do
    # Calculate confidence based on group size and consistency
    size_factor = min(1.0, length(group) / 10)
    
    # Calculate consistency
    consistency = calculate_group_consistency(group)
    
    (size_factor + consistency) / 2
  end

  defp calculate_group_consistency(group) do
    # Calculate how consistent the group members are
    if length(group) < 2 do
      1.0
    else
      feature_variances = group
      |> List.first()
      |> Map.get(:features, [])
      |> Enum.map(fn {key, _} ->
        values = Enum.map(group, fn exp ->
          {_, value} = List.keyfind(exp.features, key, 0, {key, 0})
          value
        end)
        calculate_variance(values)
      end)
      
      avg_variance = Enum.sum(feature_variances) / length(feature_variances)
      1.0 / (1.0 + avg_variance)
    end
  end

  defp update_knowledge_base(memory, patterns) do
    shared_knowledge = Map.get(memory, :shared_knowledge, %{})
    
    # Add new patterns to shared knowledge
    updated_knowledge = Enum.reduce(patterns, shared_knowledge, fn pattern, acc ->
      key = pattern_to_knowledge_key(pattern)
      
      existing = Map.get(acc, key, %{occurrences: 0, strength: 0.0})
      
      updated = %{
        occurrences: existing.occurrences + pattern.frequency,
        strength: (existing.strength + pattern.confidence) / 2,
        last_seen: DateTime.utc_now(),
        pattern: pattern
      }
      
      Map.put(acc, key, updated)
    end)
    
    # Add emergent insights
    insights = generate_insights_from_patterns(patterns)
    
    %{memory |
      shared_knowledge: updated_knowledge,
      emergent_insights: insights ++ Map.get(memory, :emergent_insights, [])
    }
  end

  defp pattern_to_knowledge_key(pattern) do
    "pattern_#{pattern.pattern_type}_#{:erlang.phash2(pattern.features)}"
  end

  defp generate_insights_from_patterns(patterns) do
    patterns
    |> Enum.filter(& &1.confidence > 0.8)
    |> Enum.map(fn pattern ->
      %{
        type: :pattern_insight,
        pattern_type: pattern.pattern_type,
        insight: describe_pattern_insight(pattern),
        confidence: pattern.confidence,
        discovered_at: DateTime.utc_now()
      }
    end)
  end

  defp describe_pattern_insight(pattern) do
    case pattern.pattern_type do
      :high_consciousness_decision ->
        "High consciousness leads to better collective decisions"
      :convergence_behavior ->
        "Swarm exhibits strong convergence under these conditions"
      :exploration_strategy ->
        "Exploration yields valuable discoveries in this context"
      :exploitation_strategy ->
        "Exploitation is optimal for these resources"
      _ ->
        "Pattern detected with #{pattern.frequency} occurrences"
    end
  end

  defp adapt_agent_behaviors(agents, patterns) do
    # Adapt agent behaviors based on learned patterns
    Map.new(agents, fn {id, agent} ->
      adapted = apply_behavioral_adaptations(agent, patterns)
      {id, adapted}
    end)
  end

  defp apply_behavioral_adaptations(agent, patterns) do
    # Apply adaptations based on patterns
    relevant_patterns = Enum.filter(patterns, fn pattern ->
      pattern_relevant_to_agent?(pattern, agent)
    end)
    
    if length(relevant_patterns) > 0 do
      # Update contribution score based on pattern success
      new_score = calculate_adapted_score(agent, relevant_patterns)
      
      # Update capabilities based on successful patterns
      new_capabilities = adapt_capabilities(agent.capabilities, relevant_patterns)
      
      %{agent |
        contribution_score: new_score,
        capabilities: new_capabilities
      }
    else
      agent
    end
  end

  defp pattern_relevant_to_agent?(pattern, agent) do
    # Check if pattern is relevant to agent's capabilities
    pattern_capabilities = extract_pattern_capabilities(pattern)
    
    Enum.any?(pattern_capabilities, fn cap ->
      cap in agent.capabilities
    end)
  end

  defp extract_pattern_capabilities(pattern) do
    # Extract capabilities associated with pattern
    case pattern.pattern_type do
      :exploration_strategy -> [:exploration, :search]
      :exploitation_strategy -> [:optimization, :execution]
      :high_consciousness_decision -> [:coordination, :analysis]
      _ -> []
    end
  end

  defp calculate_adapted_score(agent, patterns) do
    # Calculate new score based on pattern success
    pattern_bonus = Enum.reduce(patterns, 0.0, fn pattern, acc ->
      acc + pattern.confidence * 0.1
    end)
    
    new_score = agent.contribution_score + pattern_bonus
    max(0.0, min(1.0, new_score))
  end

  defp adapt_capabilities(capabilities, patterns) do
    # Add new capabilities based on successful patterns
    new_caps = Enum.flat_map(patterns, fn pattern ->
      if pattern.confidence > 0.85 do
        extract_pattern_capabilities(pattern)
      else
        []
      end
    end)
    
    Enum.uniq(capabilities ++ new_caps)
  end

  defp initialize_weights do
    # Initialize neural network weights
    %{
      input_hidden: initialize_layer_weights(10, 20),
      hidden_hidden: initialize_layer_weights(20, 20),
      hidden_output: initialize_layer_weights(20, 10)
    }
  end

  defp initialize_layer_weights(input_size, output_size) do
    # Xavier initialization
    limit = :math.sqrt(6.0 / (input_size + output_size))
    
    for i <- 1..input_size, j <- 1..output_size, into: %{} do
      {{i, j}, (:rand.uniform() - 0.5) * 2 * limit}
    end
  end

  defp update_neural_weights(weights, processed_experiences) do
    # Update weights using gradient descent
    Enum.reduce(processed_experiences, weights, fn exp, acc_weights ->
      # Forward pass
      input = experience_to_input_vector(exp)
      {output, activations} = forward_pass(input, acc_weights)
      
      # Calculate error
      target = experience_to_target_vector(exp)
      error = calculate_error(output, target)
      
      # Backward pass
      gradients = backward_pass(error, activations, acc_weights)
      
      # Update weights
      apply_gradients(acc_weights, gradients, @learning_rate)
    end)
  end

  defp experience_to_input_vector(exp) do
    # Convert experience to input vector
    exp.features
    |> Enum.map(fn {_, value} -> value end)
    |> pad_or_truncate(10)
  end

  defp experience_to_target_vector(exp) do
    # Create target vector based on experience outcome
    consciousness = case List.keyfind(exp.features, :consciousness, 0) do
      {_, value} -> value
      _ -> 0.5
    end
    
    # Simple target: high consciousness is good
    List.duplicate(consciousness, 10)
  end

  defp pad_or_truncate(list, target_length) do
    current_length = length(list)
    
    cond do
      current_length == target_length -> list
      current_length < target_length ->
        list ++ List.duplicate(0.0, target_length - current_length)
      true ->
        Enum.take(list, target_length)
    end
  end

  defp forward_pass(input, weights) do
    # Simple feedforward neural network
    hidden1 = activate_layer(input, weights.input_hidden)
    hidden2 = activate_layer(hidden1, weights.hidden_hidden)
    output = activate_layer(hidden2, weights.hidden_output)
    
    {output, %{input: input, hidden1: hidden1, hidden2: hidden2, output: output}}
  end

  defp activate_layer(input, layer_weights) do
    # Calculate layer activation
    output_size = layer_weights
    |> Map.keys()
    |> Enum.map(fn {_, j} -> j end)
    |> Enum.max()
    
    for j <- 1..output_size do
      sum = Enum.reduce(1..length(input), 0.0, fn i, acc ->
        weight = Map.get(layer_weights, {i, j}, 0.0)
        input_val = Enum.at(input, i - 1, 0.0)
        acc + weight * input_val
      end)
      
      # ReLU activation
      max(0.0, sum)
    end
  end

  defp calculate_error(output, target) do
    # Mean squared error
    Enum.zip(output, target)
    |> Enum.map(fn {o, t} -> o - t end)
  end

  defp backward_pass(error, activations, weights) do
    # Simplified backpropagation
    %{
      input_hidden: calculate_layer_gradients(
        activations.input,
        activations.hidden1,
        error
      ),
      hidden_hidden: calculate_layer_gradients(
        activations.hidden1,
        activations.hidden2,
        error
      ),
      hidden_output: calculate_layer_gradients(
        activations.hidden2,
        activations.output,
        error
      )
    }
  end

  defp calculate_layer_gradients(input, output, error) do
    # Calculate gradients for a layer
    for i <- 1..length(input), j <- 1..length(output), into: %{} do
      input_val = Enum.at(input, i - 1, 0.0)
      error_val = Enum.at(error, min(j - 1, length(error) - 1), 0.0)
      {{i, j}, input_val * error_val}
    end
  end

  defp apply_gradients(weights, gradients, learning_rate) do
    # Apply gradients to weights
    %{
      input_hidden: update_layer_weights(
        weights.input_hidden,
        gradients.input_hidden,
        learning_rate
      ),
      hidden_hidden: update_layer_weights(
        weights.hidden_hidden,
        gradients.hidden_hidden,
        learning_rate
      ),
      hidden_output: update_layer_weights(
        weights.hidden_output,
        gradients.hidden_output,
        learning_rate
      )
    }
  end

  defp update_layer_weights(weights, gradients, learning_rate) do
    Map.merge(weights, gradients, fn _key, w, g ->
      w - learning_rate * g
    end)
  end

  defp generate_adaptation_rules(patterns, decision_history) do
    # Generate rules based on patterns and history
    pattern_rules = Enum.map(patterns, &pattern_to_rule/1)
    
    # Extract rules from decision history
    history_rules = extract_rules_from_history(decision_history)
    
    # Combine and prioritize rules
    all_rules = pattern_rules ++ history_rules
    |> Enum.uniq_by(& &1.condition)
    |> Enum.sort_by(& &1.priority, :desc)
    |> Enum.take(100)  # Keep top 100 rules
    
    all_rules
  end

  defp pattern_to_rule(pattern) do
    %{
      condition: pattern_to_condition(pattern),
      action: pattern_to_action(pattern),
      confidence: pattern.confidence,
      priority: pattern.confidence * pattern.frequency,
      source: :pattern
    }
  end

  defp pattern_to_condition(pattern) do
    # Convert pattern to rule condition
    case pattern.pattern_type do
      :high_consciousness_decision ->
        fn state -> state.consciousness_level > 0.7 end
      :convergence_behavior ->
        fn state -> state.state == :converging end
      :exploration_strategy ->
        fn state -> Map.get(state, :resource_scarcity, false) end
      :exploitation_strategy ->
        fn state -> Map.get(state, :resource_abundance, false) end
      _ ->
        fn _state -> true end
    end
  end

  defp pattern_to_action(pattern) do
    # Convert pattern to rule action
    case pattern.pattern_type do
      :high_consciousness_decision -> :maintain_consciousness
      :convergence_behavior -> :promote_convergence
      :exploration_strategy -> :explore_environment
      :exploitation_strategy -> :exploit_resources
      _ -> :continue
    end
  end

  defp extract_rules_from_history(history) do
    # Extract rules from decision history
    history
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [decision1, decision2] ->
      if decision2.consciousness_level > decision1.consciousness_level do
        %{
          condition: fn state -> 
            similar_context?(state, decision1.context)
          end,
          action: decision2.decision.action,
          confidence: decision2.consciousness_level,
          priority: 0.5,
          source: :history
        }
      else
        nil
      end
    end)
    |> Enum.filter(& &1 != nil)
  end

  defp similar_context?(state, context) do
    # Check if current state is similar to context
    state_keys = Map.keys(state) |> MapSet.new()
    context_keys = Map.keys(context) |> MapSet.new()
    
    intersection = MapSet.intersection(state_keys, context_keys) |> MapSet.size()
    union = MapSet.union(state_keys, context_keys) |> MapSet.size()
    
    if union > 0 do
      intersection / union > 0.5
    else
      false
    end
  end

  defp calculate_reward(decision, outcome) do
    # Calculate reward based on outcome
    success = Map.get(outcome, :success, false)
    efficiency = Map.get(outcome, :efficiency, 0.5)
    quality = Map.get(outcome, :quality, 0.5)
    
    base_reward = if success, do: 1.0, else: -0.5
    base_reward * efficiency * quality
  end

  defp reinforce_decision_path(weights, decision, reward) do
    # Reinforce the decision path in neural weights
    # Simplified: just scale weights slightly based on reward
    scale_factor = 1.0 + reward * 0.01
    
    %{
      input_hidden: scale_weights(weights.input_hidden, scale_factor),
      hidden_hidden: scale_weights(weights.hidden_hidden, scale_factor),
      hidden_output: scale_weights(weights.hidden_output, scale_factor)
    }
  end

  defp scale_weights(layer_weights, factor) do
    Map.new(layer_weights, fn {key, weight} ->
      {key, weight * factor}
    end)
  end

  defp extract_context(state) do
    # Extract relevant context from state
    %{
      agent_count: map_size(Map.get(state, :agents, %{})),
      consciousness_level: Map.get(state, :consciousness_level, 0.5),
      swarm_state: Map.get(state, :state, :unknown),
      pattern_count: length(Map.get(state, :emergence_patterns, []))
    }
  end

  defp generate_insights(state) do
    patterns = Map.get(state, :learned_patterns, [])
    experiences = Map.get(state, :experience_buffer, [])
    
    insights = []
    
    # Insight: Pattern effectiveness
    if length(patterns) > 5 do
      insight = analyze_pattern_effectiveness(patterns)
      insights = [insight | insights]
    end
    
    # Insight: Learning rate optimization
    if length(experiences) > 100 do
      insight = analyze_learning_rate(experiences)
      insights = [insight | insights]
    end
    
    # Insight: Emergence conditions
    if length(patterns) > 10 do
      insight = analyze_emergence_conditions(patterns)
      insights = [insight | insights]
    end
    
    insights
  end

  defp analyze_pattern_effectiveness(patterns) do
    high_confidence = Enum.filter(patterns, & &1.confidence > 0.8)
    
    %{
      type: :pattern_effectiveness,
      insight: "#{length(high_confidence)} highly effective patterns identified",
      data: %{
        total_patterns: length(patterns),
        high_confidence: length(high_confidence),
        avg_confidence: Enum.sum(Enum.map(patterns, & &1.confidence)) / length(patterns)
      }
    }
  end

  defp analyze_learning_rate(experiences) do
    # Analyze if learning rate should be adjusted
    recent = Enum.take(experiences, 50)
    older = Enum.slice(experiences, 50, 50)
    
    recent_performance = calculate_average_performance(recent)
    older_performance = calculate_average_performance(older)
    
    improvement = recent_performance - older_performance
    
    %{
      type: :learning_rate_analysis,
      insight: if(improvement > 0, do: "Learning improving", else: "Learning plateaued"),
      data: %{
        recent_performance: recent_performance,
        older_performance: older_performance,
        improvement: improvement,
        recommended_rate: if(improvement > 0, do: @learning_rate * 1.1, else: @learning_rate * 0.9)
      }
    }
  end

  defp calculate_average_performance(experiences) do
    if length(experiences) == 0 do
      0.5
    else
      Enum.reduce(experiences, 0.0, fn exp, acc ->
        acc + Map.get(exp, :reward, 0.5)
      end) / length(experiences)
    end
  end

  defp analyze_emergence_conditions(patterns) do
    # Analyze conditions that lead to emergence
    emergence_patterns = Enum.filter(patterns, fn p ->
      p.pattern_type in [:convergence_behavior, :self_assembly]
    end)
    
    conditions = Enum.flat_map(emergence_patterns, fn p ->
      extract_emergence_conditions(p)
    end)
    |> Enum.frequencies()
    
    %{
      type: :emergence_conditions,
      insight: "Key conditions for emergence identified",
      data: conditions
    }
  end

  defp extract_emergence_conditions(pattern) do
    # Extract conditions from pattern features
    pattern.features
    |> Enum.filter(fn {_, stats} ->
      stats.mean > 0.6
    end)
    |> Enum.map(fn {key, _} -> key end)
  end

  defp analyze_performance_trends(state) do
    history = Map.get(state, :performance_history, [])
    
    if length(history) < 10 do
      %{trend: :insufficient_data}
    else
      recent = Enum.take(history, 20)
      
      %{
        trend: calculate_trend(recent),
        average_performance: calculate_average(recent),
        volatility: calculate_volatility(recent),
        prediction: predict_future_performance(recent)
      }
    end
  end

  defp calculate_trend(values) do
    # Simple linear regression for trend
    if length(values) < 2 do
      :flat
    else
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))
      
      first_avg = calculate_average(first_half)
      second_avg = calculate_average(second_half)
      
      cond do
        second_avg > first_avg * 1.1 -> :improving
        second_avg < first_avg * 0.9 -> :declining
        true -> :stable
      end
    end
  end

  defp calculate_average(values) do
    if length(values) == 0 do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end

  defp calculate_volatility(values) do
    if length(values) < 2 do
      0.0
    else
      avg = calculate_average(values)
      variance = Enum.reduce(values, 0.0, fn val, acc ->
        acc + :math.pow(val - avg, 2)
      end) / length(values)
      :math.sqrt(variance)
    end
  end

  defp predict_future_performance(recent) do
    # Simple prediction based on trend
    trend = calculate_trend(recent)
    current = List.first(recent, 0.5)
    
    case trend do
      :improving -> min(1.0, current * 1.1)
      :declining -> max(0.0, current * 0.9)
      _ -> current
    end
  end

  defp extract_transferable_knowledge(source_state) do
    %{
      patterns: Map.get(source_state, :learned_patterns, [])
      |> Enum.filter(& &1.confidence > 0.7),
      
      rules: Map.get(source_state, :adaptation_rules, [])
      |> Enum.filter(& &1.confidence > 0.6),
      
      weights: Map.get(source_state, :neural_weights, initialize_weights()),
      
      insights: Map.get(source_state.collective_memory, :emergent_insights, [])
    }
  end

  defp adapt_knowledge_to_domain(transferable, target_domain) do
    %{
      knowledge: adapt_knowledge(transferable.patterns, target_domain),
      patterns: adapt_patterns(transferable.patterns, target_domain),
      rules: adapt_rules(transferable.rules, target_domain),
      weights: scale_weights_for_domain(transferable.weights, target_domain),
      insights: filter_relevant_insights(transferable.insights, target_domain)
    }
  end

  defp adapt_knowledge(patterns, _target_domain) do
    # Convert patterns to knowledge entries
    Map.new(patterns, fn pattern ->
      {pattern_to_knowledge_key(pattern), pattern}
    end)
  end

  defp adapt_patterns(patterns, target_domain) do
    # Adapt patterns to new domain
    Enum.map(patterns, fn pattern ->
      %{pattern | 
        confidence: pattern.confidence * domain_similarity(pattern, target_domain)
      }
    end)
    |> Enum.filter(& &1.confidence > 0.5)
  end

  defp domain_similarity(_pattern, _target_domain) do
    # Calculate domain similarity
    0.8  # Placeholder
  end

  defp adapt_rules(rules, _target_domain) do
    # Adapt rules to new domain
    Enum.map(rules, fn rule ->
      %{rule | priority: rule.priority * 0.8}  # Reduce priority for transfer
    end)
  end

  defp scale_weights_for_domain(weights, _target_domain) do
    # Scale weights for new domain
    scale_factor = 0.5  # Conservative transfer
    
    %{
      input_hidden: scale_weights(weights.input_hidden, scale_factor),
      hidden_hidden: scale_weights(weights.hidden_hidden, scale_factor),
      hidden_output: scale_weights(weights.hidden_output, scale_factor)
    }
  end

  defp filter_relevant_insights(insights, _target_domain) do
    # Filter insights relevant to target domain
    insights  # For now, keep all
  end

  defp analyze_learning_patterns(learning_history) do
    # Analyze patterns in how the system learns
    %{
      learning_curve: extract_learning_curve(learning_history),
      plateau_points: identify_plateaus(learning_history),
      breakthrough_moments: identify_breakthroughs(learning_history),
      cyclical_patterns: detect_cycles(learning_history)
    }
  end

  defp extract_learning_curve(history) do
    # Extract the learning curve
    Enum.map(history, fn entry ->
      Map.get(entry, :performance, 0.5)
    end)
  end

  defp identify_plateaus(history) do
    # Identify learning plateaus
    []  # Simplified
  end

  defp identify_breakthroughs(history) do
    # Identify breakthrough moments
    []  # Simplified
  end

  defp detect_cycles(history) do
    # Detect cyclical patterns in learning
    []  # Simplified
  end

  defp identify_effective_strategies(learning_history) do
    # Identify which learning strategies were effective
    strategies = Enum.map(learning_history, fn entry ->
      Map.get(entry, :strategy, :unknown)
    end)
    |> Enum.frequencies()
    
    # Return strategies with their effectiveness scores
    Map.new(strategies, fn {strategy, count} ->
      {strategy, count / length(learning_history)}
    end)
  end

  defp optimize_learning_parameters(patterns) do
    # Optimize learning parameters based on patterns
    %{
      learning_rate: optimize_learning_rate(patterns),
      batch_size: optimize_batch_size(patterns),
      memory_capacity: optimize_memory_capacity(patterns),
      exploration_rate: optimize_exploration_rate(patterns)
    }
  end

  defp optimize_learning_rate(_patterns) do
    # Optimize learning rate
    @learning_rate  # Keep current for now
  end

  defp optimize_batch_size(_patterns) do
    # Optimize batch size
    @experience_threshold
  end

  defp optimize_memory_capacity(_patterns) do
    # Optimize memory capacity
    @memory_capacity
  end

  defp optimize_exploration_rate(_patterns) do
    # Optimize exploration vs exploitation
    0.3  # 30% exploration
  end

  defp generate_meta_insights(patterns) do
    # Generate insights about the learning process itself
    [
      %{
        type: :meta_learning,
        insight: "Learning accelerates with pattern recognition",
        confidence: 0.85
      },
      %{
        type: :meta_learning,
        insight: "Transfer learning effective across similar domains",
        confidence: 0.75
      }
    ]
  end
end