defmodule VsmPhoenix.MetaVsm.Genetics.DnaConfig do
  @moduledoc """
  DNA Configuration for META-VSM
  
  Defines the genetic blueprint that determines VSM behavior,
  structure, and capabilities. Like biological DNA, this configuration
  can be inherited, mutated, and evolved.
  """
  
  @base_genes %{
    # System 1 - Operational genes
    system1_config: %{
      agent_count: 3,
      response_time: 100,
      variety_handling: :adaptive,
      autonomy_level: 0.7,
      learning_rate: 0.1
    },
    
    # System 2 - Coordination genes
    system2_config: %{
      coordination_strategy: :distributed,
      conflict_resolution: :consensus,
      synchronization_interval: 1000,
      anti_oscillation: true
    },
    
    # System 3 - Control genes
    system3_config: %{
      resource_allocation: :dynamic,
      audit_frequency: 5000,
      control_strength: 0.6,
      delegation_threshold: 0.8
    },
    
    # System 4 - Intelligence genes
    system4_config: %{
      scanning_range: :wide,
      adaptation_speed: 0.3,
      innovation_rate: 0.2,
      pattern_recognition: true,
      model_building: true
    },
    
    # System 5 - Policy genes
    system5_config: %{
      governance_style: :adaptive,
      identity_strength: 0.9,
      policy_flexibility: 0.4,
      viability_threshold: 0.5,
      algedonic_sensitivity: 0.7
    },
    
    # Meta-level genes
    meta_config: %{
      evolution_enabled: true,
      mutation_rate: 0.05,
      crossover_rate: 0.7,
      selection_pressure: :moderate,
      lifespan: :unlimited,
      spawning_rate: 0.3,
      max_children: 5
    },
    
    # Fractal genes
    fractal_config: %{
      self_similarity: 0.8,
      recursion_pattern: :fibonacci,
      scale_invariance: true,
      dimension: 2.718  # e, for natural growth
    },
    
    # Behavioral genes
    behavioral_traits: %{
      aggression: 0.3,
      cooperation: 0.7,
      exploration: 0.6,
      exploitation: 0.4,
      risk_tolerance: 0.5
    }
  }
  
  @gene_constraints %{
    system1_config: %{
      agent_count: {1, 100},
      response_time: {10, 10000},
      autonomy_level: {0.0, 1.0},
      learning_rate: {0.0, 1.0}
    },
    system2_config: %{
      synchronization_interval: {100, 60000}
    },
    system3_config: %{
      control_strength: {0.0, 1.0},
      delegation_threshold: {0.0, 1.0}
    },
    system4_config: %{
      adaptation_speed: {0.0, 1.0},
      innovation_rate: {0.0, 1.0}
    },
    system5_config: %{
      identity_strength: {0.0, 1.0},
      policy_flexibility: {0.0, 1.0},
      viability_threshold: {0.0, 1.0},
      algedonic_sensitivity: {0.0, 1.0}
    },
    meta_config: %{
      mutation_rate: {0.0, 0.5},
      crossover_rate: {0.0, 1.0},
      spawning_rate: {0.0, 1.0},
      max_children: {0, 20}
    },
    fractal_config: %{
      self_similarity: {0.0, 1.0},
      dimension: {1.0, 3.0}
    },
    behavioral_traits: %{
      aggression: {0.0, 1.0},
      cooperation: {0.0, 1.0},
      exploration: {0.0, 1.0},
      exploitation: {0.0, 1.0},
      risk_tolerance: {0.0, 1.0}
    }
  }
  
  @doc """
  Generate primordial DNA for the first VSM (no parent)
  """
  def generate_primordial_dna do
    @base_genes
    |> add_unique_markers()
    |> add_epigenetic_layer()
  end
  
  @doc """
  Create DNA with specific traits emphasized
  """
  def generate_specialized_dna(specialization) do
    base = generate_primordial_dna()
    
    case specialization do
      :explorer ->
        base
        |> put_in([:behavioral_traits, :exploration], 0.9)
        |> put_in([:behavioral_traits, :risk_tolerance], 0.7)
        |> put_in([:system4_config, :scanning_range], :extra_wide)
        
      :optimizer ->
        base
        |> put_in([:behavioral_traits, :exploitation], 0.8)
        |> put_in([:system3_config, :control_strength], 0.8)
        |> put_in([:system3_config, :resource_allocation], :optimal)
        
      :innovator ->
        base
        |> put_in([:system4_config, :innovation_rate], 0.8)
        |> put_in([:meta_config, :mutation_rate], 0.15)
        |> put_in([:system4_config, :pattern_recognition], :advanced)
        
      :guardian ->
        base
        |> put_in([:system5_config, :identity_strength], 1.0)
        |> put_in([:system5_config, :viability_threshold], 0.7)
        |> put_in([:behavioral_traits, :aggression], 0.1)
        
      :replicator ->
        base
        |> put_in([:meta_config, :spawning_rate], 0.8)
        |> put_in([:meta_config, :max_children], 10)
        |> put_in([:fractal_config, :self_similarity], 0.95)
        
      _ ->
        base
    end
  end
  
  @doc """
  Merge two DNA configurations (for sexual reproduction or horizontal transfer)
  """
  def merge_dna(dna1, dna2) do
    merged = deep_merge_maps(dna1, dna2)
    
    # Apply constraints to ensure valid ranges
    apply_constraints(merged)
  end
  
  @doc """
  Apply a DNA fragment to existing DNA (like viral injection)
  """
  def inject_fragment(base_dna, fragment) do
    updated = deep_merge_maps(base_dna, fragment)
    apply_constraints(updated)
  end
  
  @doc """
  Generate a unique signature for DNA (like a fingerprint)
  """
  def signature(dna) do
    :crypto.hash(:sha256, :erlang.term_to_binary(dna))
    |> Base.encode16(case: :lower)
    |> String.slice(0..15)
  end
  
  @doc """
  Calculate similarity between two DNA configurations (0.0 to 1.0)
  """
  def similarity(dna1, dna2) do
    calculate_similarity(flatten_dna(dna1), flatten_dna(dna2))
  end
  
  @doc """
  Check if DNA is viable (meets minimum requirements)
  """
  def viable?(dna) do
    # Check critical genes
    dna.system5_config.viability_threshold > 0.2 and
    dna.system1_config.agent_count > 0 and
    dna.meta_config.lifespan != :zero and
    sum_behavioral_traits(dna.behavioral_traits) > 0.5
  end
  
  @doc """
  Apply epigenetic modifications based on environment
  """
  def apply_epigenetics(dna, environment) do
    case environment do
      :hostile ->
        dna
        |> update_in([:behavioral_traits, :aggression], &min(1.0, &1 * 1.5))
        |> update_in([:behavioral_traits, :cooperation], &(&1 * 0.8))
        |> update_in([:system5_config, :algedonic_sensitivity], &min(1.0, &1 * 1.3))
        
      :resource_scarce ->
        dna
        |> update_in([:system3_config, :control_strength], &min(1.0, &1 * 1.2))
        |> update_in([:behavioral_traits, :exploitation], &min(1.0, &1 * 1.3))
        |> update_in([:meta_config, :spawning_rate], &(&1 * 0.5))
        
      :cooperative ->
        dna
        |> update_in([:behavioral_traits, :cooperation], &min(1.0, &1 * 1.4))
        |> update_in([:system2_config, :conflict_resolution], fn _ -> :collaborative end)
        |> update_in([:behavioral_traits, :aggression], &(&1 * 0.5))
        
      :innovative ->
        dna
        |> update_in([:system4_config, :innovation_rate], &min(1.0, &1 * 1.5))
        |> update_in([:meta_config, :mutation_rate], &min(0.3, &1 * 1.5))
        |> update_in([:behavioral_traits, :exploration], &min(1.0, &1 * 1.3))
        
      _ ->
        dna
    end
  end
  
  @doc """
  Extract dominant traits from DNA
  """
  def dominant_traits(dna) do
    traits = []
    
    # Check behavioral dominance
    behavioral = dna.behavioral_traits
    traits = if behavioral.cooperation > 0.7, do: [:cooperative | traits], else: traits
    traits = if behavioral.aggression > 0.7, do: [:aggressive | traits], else: traits
    traits = if behavioral.exploration > 0.7, do: [:explorer | traits], else: traits
    traits = if behavioral.exploitation > 0.7, do: [:exploiter | traits], else: traits
    
    # Check system dominance
    traits = if dna.system4_config.innovation_rate > 0.6, do: [:innovative | traits], else: traits
    traits = if dna.system5_config.identity_strength > 0.8, do: [:stable | traits], else: traits
    traits = if dna.meta_config.spawning_rate > 0.6, do: [:reproductive | traits], else: traits
    
    traits
  end
  
  @doc """
  Create a DNA mutation template
  """
  def mutation_template(mutation_type) do
    case mutation_type do
      :beneficial ->
        %{
          system4_config: %{adaptation_speed: {:add, 0.1}},
          behavioral_traits: %{cooperation: {:add, 0.05}}
        }
        
      :neutral ->
        %{
          fractal_config: %{dimension: {:add, 0.01}}
        }
        
      :harmful ->
        %{
          system1_config: %{response_time: {:multiply, 1.5}},
          behavioral_traits: %{cooperation: {:subtract, 0.1}}
        }
        
      :radical ->
        %{
          meta_config: %{mutation_rate: {:set, 0.3}},
          behavioral_traits: %{
            exploration: {:set, rand_float()},
            risk_tolerance: {:set, rand_float()}
          }
        }
        
      _ ->
        %{}
    end
  end
  
  # Private functions
  
  defp add_unique_markers(dna) do
    Map.put(dna, :unique_id, generate_unique_id())
    |> Map.put(:creation_time, System.system_time(:second))
    |> Map.put(:lineage, [])
  end
  
  defp add_epigenetic_layer(dna) do
    Map.put(dna, :epigenetics, %{
      methylation_pattern: generate_methylation_pattern(),
      expression_modifiers: %{},
      environmental_memory: []
    })
  end
  
  defp generate_unique_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  defp generate_methylation_pattern do
    # Simulated epigenetic methylation pattern
    for _ <- 1..100, do: :rand.uniform() > 0.5
  end
  
  defp deep_merge_maps(map1, map2) do
    Map.merge(map1, map2, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) ->
        deep_merge_maps(v1, v2)
      _k, v1, v2 when is_number(v1) and is_number(v2) ->
        (v1 + v2) / 2  # Average numeric values
      _k, _v1, v2 ->
        v2  # Take second value for non-numeric, non-map values
    end)
  end
  
  defp apply_constraints(dna) do
    Enum.reduce(@gene_constraints, dna, fn {gene_group, constraints}, acc ->
      if Map.has_key?(acc, gene_group) do
        updated_group = Enum.reduce(constraints, acc[gene_group], fn {gene, {min, max}}, group ->
          if Map.has_key?(group, gene) and is_number(group[gene]) do
            Map.put(group, gene, constrain_value(group[gene], min, max))
          else
            group
          end
        end)
        Map.put(acc, gene_group, updated_group)
      else
        acc
      end
    end)
  end
  
  defp constrain_value(value, min, max) do
    value |> max(min) |> min(max)
  end
  
  defp flatten_dna(dna) do
    dna
    |> Map.delete(:unique_id)
    |> Map.delete(:creation_time)
    |> Map.delete(:lineage)
    |> Map.delete(:epigenetics)
    |> flatten_map([])
  end
  
  defp flatten_map(map, acc) when is_map(map) do
    Enum.reduce(map, acc, fn {_k, v}, acc ->
      case v do
        v when is_map(v) -> flatten_map(v, acc)
        v when is_number(v) -> [v | acc]
        _ -> acc
      end
    end)
  end
  
  defp flatten_map(_, acc), do: acc
  
  defp calculate_similarity(values1, values2) do
    if length(values1) == 0 or length(values2) == 0 do
      0.0
    else
      # Pad lists to same length
      max_len = max(length(values1), length(values2))
      v1 = pad_list(values1, max_len, 0)
      v2 = pad_list(values2, max_len, 0)
      
      # Calculate correlation coefficient
      pairs = Enum.zip(v1, v2)
      differences = Enum.map(pairs, fn {a, b} -> abs(a - b) end)
      avg_diff = Enum.sum(differences) / length(differences)
      
      # Convert to similarity (0 to 1)
      1.0 - min(1.0, avg_diff)
    end
  end
  
  defp pad_list(list, target_length, pad_value) do
    current_length = length(list)
    if current_length < target_length do
      list ++ List.duplicate(pad_value, target_length - current_length)
    else
      list
    end
  end
  
  defp sum_behavioral_traits(traits) do
    traits
    |> Map.values()
    |> Enum.filter(&is_number/1)
    |> Enum.sum()
  end
  
  defp rand_float do
    :rand.uniform()
  end
end