defmodule VsmPhoenixWeb.MetaVsmController do
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.VSM.MetaSystem
  alias VsmPhoenix.VSM.RecursiveStructure
  alias VsmPhoenix.VSM.GeneticEvolution
  alias VsmPhoenix.VSM.FractalAnalysis
  
  require Logger

  @doc """
  POST /api/meta-vsm/spawn - Spawn recursive VSM
  """
  def spawn_meta_vsm(conn, params) do
    with {:ok, validated_params} <- validate_spawn_params(params),
         {:ok, meta_vsm_id} <- MetaSystem.spawn_recursive_vsm(validated_params) do
      
      Logger.info("Meta-VSM spawned: #{meta_vsm_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        meta_vsm_id: meta_vsm_id,
        message: "Recursive VSM spawned successfully",
        details: %{
          parent_vsm: validated_params.parent_vsm,
          recursion_depth: validated_params.recursion_depth,
          genetic_template: validated_params.genetic_template,
          autonomous_behavior: validated_params.autonomous_behavior
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid spawn parameters",
          details: errors
        })
      
      {:error, :max_recursion_depth} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Maximum recursion depth exceeded",
          message: "Cannot spawn VSM: would exceed system recursion limits"
        })
      
      {:error, :genetic_incompatibility} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Genetic template incompatibility",
          message: "The genetic template is incompatible with the parent VSM structure"
        })
      
      {:error, reason} ->
        Logger.error("Meta-VSM spawn failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Meta-VSM spawn failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/meta-vsm/hierarchy - Get VSM hierarchy
  """
  def get_hierarchy(conn, params) do
    try do
      root_vsm_id = Map.get(params, "root_id")
      max_depth = parse_integer(Map.get(params, "max_depth", "10"))
      include_inactive = Map.get(params, "include_inactive", "false") == "true"
      
      hierarchy = RecursiveStructure.build_hierarchy_tree(%{
        root_id: root_vsm_id,
        max_depth: max_depth,
        include_inactive: include_inactive
      })
      
      enriched_hierarchy = RecursiveStructure.enrich_hierarchy_with_metrics(hierarchy)
      
      conn
      |> json(%{
        success: true,
        hierarchy: enriched_hierarchy,
        metadata: %{
          total_nodes: RecursiveStructure.count_hierarchy_nodes(enriched_hierarchy),
          max_depth_reached: RecursiveStructure.get_max_depth(enriched_hierarchy),
          active_vsms: RecursiveStructure.count_active_vsms(enriched_hierarchy),
          genetic_diversity: GeneticEvolution.measure_hierarchy_diversity(enriched_hierarchy)
        }
      })
    rescue
      error ->
        Logger.error("Failed to get VSM hierarchy: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve VSM hierarchy"
        })
    end
  end

  @doc """
  POST /api/meta-vsm/evolve - Evolve VSM genetics
  """
  def evolve_genetics(conn, params) do
    with {:ok, validated_params} <- validate_evolution_params(params),
         {:ok, evolution_result} <- GeneticEvolution.evolve_vsm_genetics(validated_params) do
      
      Logger.info("VSM genetic evolution completed: #{evolution_result.evolution_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        evolution_id: evolution_result.evolution_id,
        message: "VSM genetic evolution completed successfully",
        results: %{
          generations_processed: evolution_result.generations,
          fitness_improvement: evolution_result.fitness_delta,
          mutations_applied: evolution_result.mutations,
          crossover_events: evolution_result.crossovers,
          best_genome: evolution_result.best_genome,
          population_diversity: evolution_result.diversity_score
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid evolution parameters",
          details: errors
        })
      
      {:error, :population_too_small} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Population too small for evolution",
          message: "Need at least 4 VSM instances for genetic evolution"
        })
      
      {:error, :convergence_failed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Evolution convergence failed",
          message: "Genetic algorithm failed to converge within specified generations"
        })
      
      {:error, reason} ->
        Logger.error("VSM genetic evolution failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Genetic evolution failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  GET /api/meta-vsm/fractals - Fractal analysis
  """
  def fractal_analysis(conn, params) do
    try do
      analysis_params = %{
        vsm_id: Map.get(params, "vsm_id"),
        analysis_type: Map.get(params, "type", "comprehensive"),
        depth_limit: parse_integer(Map.get(params, "depth_limit", "7")),
        pattern_recognition: Map.get(params, "pattern_recognition", "true") == "true"
      }
      
      fractal_data = FractalAnalysis.analyze_vsm_fractals(analysis_params)
      
      enhanced_analysis = Map.merge(fractal_data, %{
        dimensional_analysis: FractalAnalysis.calculate_fractal_dimension(fractal_data),
        self_similarity: FractalAnalysis.measure_self_similarity(fractal_data),
        complexity_metrics: FractalAnalysis.calculate_complexity_metrics(fractal_data),
        recursive_patterns: FractalAnalysis.identify_recursive_patterns(fractal_data),
        emergence_indicators: FractalAnalysis.detect_emergence_indicators(fractal_data)
      })
      
      conn
      |> json(%{
        success: true,
        fractal_analysis: enhanced_analysis,
        visualization_data: FractalAnalysis.generate_visualization_data(enhanced_analysis),
        analysis_metadata: analysis_params
      })
    rescue
      error ->
        Logger.error("Failed to perform fractal analysis: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to perform fractal analysis"
        })
    end
  end

  @doc """
  GET /api/meta-vsm/lineage - Get VSM lineage
  """
  def get_lineage(conn, params) do
    try do
      vsm_id = Map.get(params, "vsm_id")
      
      if is_nil(vsm_id) do
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "VSM ID is required"
        })
      else
        lineage_data = RecursiveStructure.trace_vsm_lineage(vsm_id)
        
        enriched_lineage = Map.merge(lineage_data, %{
          genetic_flow: GeneticEvolution.trace_genetic_lineage(vsm_id),
          mutation_history: GeneticEvolution.get_mutation_history(vsm_id),
          fitness_evolution: GeneticEvolution.trace_fitness_evolution(vsm_id),
          branching_points: RecursiveStructure.identify_branching_points(lineage_data),
          convergence_events: RecursiveStructure.identify_convergence_events(lineage_data)
        })
        
        conn
        |> json(%{
          success: true,
          lineage: enriched_lineage,
          vsm_id: vsm_id,
          metadata: %{
            generations_traced: RecursiveStructure.count_generations(enriched_lineage),
            total_ancestors: RecursiveStructure.count_ancestors(enriched_lineage),
            total_descendants: RecursiveStructure.count_descendants(enriched_lineage),
            genetic_diversity_score: GeneticEvolution.calculate_lineage_diversity(enriched_lineage)
          }
        })
      end
    rescue
      error ->
        Logger.error("Failed to get VSM lineage: #{inspect(error)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Failed to retrieve VSM lineage"
        })
    end
  end

  @doc """
  POST /api/meta-vsm/merge - Merge VSM instances
  """
  def merge_vsms(conn, params) do
    with {:ok, validated_params} <- validate_merge_params(params),
         {:ok, merge_result} <- MetaSystem.merge_vsm_instances(validated_params) do
      
      Logger.info("Meta-VSMs merged: #{merge_result.merged_vsm_id}")
      
      conn
      |> put_status(:created)
      |> json(%{
        success: true,
        merged_vsm_id: merge_result.merged_vsm_id,
        message: "VSM instances merged successfully",
        merge_details: %{
          source_vsms: validated_params.source_vsms,
          merge_strategy: validated_params.merge_strategy,
          genetic_combination: merge_result.genetic_combination,
          capability_synthesis: merge_result.capability_synthesis,
          emergent_properties: merge_result.emergent_properties,
          resource_consolidation: merge_result.resource_consolidation
        }
      })
    else
      {:error, :invalid_params, errors} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: "Invalid merge parameters",
          details: errors
        })
      
      {:error, :incompatible_vsms} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Incompatible VSM instances",
          message: "The selected VSM instances cannot be merged due to incompatible genetic templates or capabilities"
        })
      
      {:error, :merge_conflict} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "Merge conflict detected",
          message: "Conflicting capabilities or resources prevent merging. Manual resolution required."
        })
      
      {:error, reason} ->
        Logger.error("VSM merge failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "VSM merge failed",
          reason: to_string(reason)
        })
    end
  end

  @doc """
  DELETE /api/meta-vsm/:id - Destroy meta-VSM
  """
  def destroy_meta_vsm(conn, %{"id" => vsm_id}) do
    with {:ok, destruction_plan} <- MetaSystem.plan_vsm_destruction(vsm_id),
         {:ok, destruction_result} <- MetaSystem.execute_destruction(destruction_plan) do
      
      Logger.warning("Meta-VSM destroyed: #{vsm_id}")
      
      conn
      |> json(%{
        success: true,
        message: "Meta-VSM destroyed successfully",
        destruction_details: %{
          vsm_id: vsm_id,
          child_vsms_affected: destruction_result.children_destroyed,
          resources_freed: destruction_result.resources_freed,
          cleanup_operations: destruction_result.cleanup_ops,
          destruction_type: destruction_result.destruction_type
        }
      })
    else
      {:error, :vsm_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: "Meta-VSM not found",
          vsm_id: vsm_id
        })
      
      {:error, :destruction_blocked} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          success: false,
          error: "Destruction blocked",
          message: "The Meta-VSM cannot be destroyed due to active dependencies or protection mechanisms"
        })
      
      {:error, :has_active_children} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          success: false,
          error: "Has active children",
          message: "Cannot destroy Meta-VSM with active child VSMs. Destroy children first or use cascade option."
        })
      
      {:error, reason} ->
        Logger.error("Meta-VSM destruction failed: #{inspect(reason)}")
        
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Destruction failed",
          reason: to_string(reason)
        })
    end
  end

  # Private helper functions

  defp validate_spawn_params(params) do
    required_fields = ["genetic_template"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        genetic_template = params["genetic_template"]
        
        if not is_map(genetic_template) do
          {:error, :invalid_params, "Genetic template must be an object"}
        else
          validated = %{
            parent_vsm: Map.get(params, "parent_vsm"),
            genetic_template: genetic_template,
            recursion_depth: parse_integer(Map.get(params, "recursion_depth", "1")),
            autonomous_behavior: Map.get(params, "autonomous_behavior", true),
            resource_limits: parse_resource_limits(Map.get(params, "resource_limits", %{})),
            evolution_enabled: Map.get(params, "evolution_enabled", true),
            description: Map.get(params, "description", "Recursive Meta-VSM")
          }
          
          {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_evolution_params(params) do
    required_fields = ["population", "fitness_function"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        population = params["population"]
        
        if not is_list(population) or length(population) < 2 do
          {:error, :invalid_params, "Population must be an array with at least 2 VSM IDs"}
        else
          validated = %{
            population: population,
            fitness_function: params["fitness_function"],
            generations: parse_integer(Map.get(params, "generations", "100")),
            mutation_rate: parse_float(Map.get(params, "mutation_rate", "0.1")),
            crossover_rate: parse_float(Map.get(params, "crossover_rate", "0.8")),
            selection_pressure: parse_float(Map.get(params, "selection_pressure", "2.0")),
            elitism_count: parse_integer(Map.get(params, "elitism_count", "1")),
            convergence_threshold: parse_float(Map.get(params, "convergence_threshold", "0.001"))
          }
          
          {:ok, validated}
        end
      
      error -> error
    end
  end

  defp validate_required_fields(params, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      is_nil(params[field]) or params[field] == ""
    end)
    
    if length(missing_fields) == 0 do
      {:ok, params}
    else
      {:error, :invalid_params, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, _} -> int_val
      :error -> 0
    end
  end
  defp parse_integer(_), do: 0

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_resource_limits(limits) when is_map(limits) do
    %{
      max_memory: parse_integer(Map.get(limits, "max_memory", "1024")),
      max_cpu: parse_float(Map.get(limits, "max_cpu", "1.0")),
      max_children: parse_integer(Map.get(limits, "max_children", "10")),
      max_depth: parse_integer(Map.get(limits, "max_depth", "5"))
    }
  end
  defp parse_resource_limits(_), do: %{max_memory: 1024, max_cpu: 1.0, max_children: 10, max_depth: 5}

  defp validate_merge_params(params) do
    required_fields = ["source_vsms", "merge_strategy"]
    
    case validate_required_fields(params, required_fields) do
      {:ok, _} ->
        source_vsms = params["source_vsms"]
        merge_strategy = params["merge_strategy"]
        
        cond do
          not is_list(source_vsms) or length(source_vsms) < 2 ->
            {:error, :invalid_params, "At least 2 source VSM IDs required for merging"}
          
          merge_strategy not in ["genetic_crossover", "capability_union", "hierarchical_integration", "emergent_synthesis"] ->
            {:error, :invalid_params, "Invalid merge strategy"}
          
          true ->
            validated = %{
              source_vsms: source_vsms,
              merge_strategy: merge_strategy,
              preserve_individuality: Map.get(params, "preserve_individuality", false),
              conflict_resolution: Map.get(params, "conflict_resolution", "automatic"),
              resource_allocation: Map.get(params, "resource_allocation", "proportional"),
              genetic_dominance: Map.get(params, "genetic_dominance", "balanced"),
              name: Map.get(params, "name", "Merged VSM"),
              description: Map.get(params, "description", "VSM created through merge operation")
            }
            
            {:ok, validated}
        end
      
      error -> error
    end
  end
end