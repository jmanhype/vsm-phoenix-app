defmodule VsmPhoenix.Telemetry.Processors.ContextHierarchyManager do
  @moduledoc """
  Context Hierarchy Manager - Single Responsibility for Context Organization
  
  Handles ONLY context hierarchy construction and management from telemetry data.
  Extracted from SemanticBlockProcessor god object to follow Single Responsibility Principle.
  
  Responsibilities:
  - Hierarchical context organization
  - Temporal context window management
  - Context relationship mapping
  - Context querying and retrieval
  """

  use VsmPhoenix.Telemetry.Behaviors.SharedLogging
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior

  alias VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore

  @context_levels [:system, :component, :signal, :sample]
  @temporal_window_types [:sliding, :tumbling, :session, :landmark]

  @doc """
  Build context hierarchy from signal data and temporal windows
  """
  def build_context_hierarchy(signal_ids, temporal_window) do
    safe_operation("build_context_hierarchy", fn ->
      # Create hierarchy structure
      hierarchy = create_base_hierarchy_structure()
      
      # Add signal contexts
      hierarchy_with_signals = signal_ids
      |> Enum.reduce(hierarchy, fn signal_id, acc ->
        add_signal_context_to_hierarchy(acc, signal_id, temporal_window)
      end)
      
      # Organize by temporal relationships
      temporal_hierarchy = organize_by_temporal_relationships(hierarchy_with_signals, temporal_window)
      
      # Add cross-signal relationships
      final_hierarchy = add_cross_signal_relationships(temporal_hierarchy, signal_ids)
      
      log_telemetry_event(:info, :context_hierarchy_manager, "Hierarchy built", %{
        signal_count: length(signal_ids),
        hierarchy_depth: calculate_hierarchy_depth(final_hierarchy),
        context_nodes: count_context_nodes(final_hierarchy)
      })
      
      {:ok, final_hierarchy}
    end)
  end

  @doc """
  Query context hierarchy for specific patterns or relationships
  """
  def query_context_hierarchy(hierarchy, query_params) do
    safe_operation("query_context_hierarchy", fn ->
      results = case query_params[:query_type] do
        :ancestors ->
          find_context_ancestors(hierarchy, query_params[:context_id])
        
        :descendants ->
          find_context_descendants(hierarchy, query_params[:context_id])
        
        :siblings ->
          find_context_siblings(hierarchy, query_params[:context_id])
        
        :temporal_neighbors ->
          find_temporal_neighbors(hierarchy, query_params[:context_id], query_params[:time_window])
        
        :path_between_contexts ->
          find_path_between_contexts(hierarchy, query_params[:start_context], query_params[:end_context])
        
        :contexts_at_level ->
          find_contexts_at_level(hierarchy, query_params[:level])
        
        _ ->
          {:error, :unsupported_query_type}
      end
      
      case results do
        {:error, _} = error -> error
        query_results ->
          {:ok, %{
            query_type: query_params[:query_type],
            results: query_results,
            hierarchy_stats: calculate_hierarchy_statistics(hierarchy),
            query_metadata: create_query_metadata()
          }}
      end
    end)
  end

  @doc """
  Merge multiple context hierarchies
  """
  def merge_context_hierarchies(hierarchies) do
    safe_operation("merge_context_hierarchies", fn ->
      merged_hierarchy = hierarchies
      |> Enum.reduce(create_base_hierarchy_structure(), fn hierarchy, acc ->
        merge_two_hierarchies(acc, hierarchy)
      end)
      
      # Reconcile conflicts and validate structure
      reconciled_hierarchy = reconcile_hierarchy_conflicts(merged_hierarchy)
      validated_hierarchy = validate_hierarchy_structure(reconciled_hierarchy)
      
      {:ok, validated_hierarchy}
    end)
  end

  @doc """
  Update context hierarchy with new temporal data
  """
  def update_hierarchy_with_temporal_data(hierarchy, signal_id, new_temporal_window) do
    safe_operation("update_hierarchy_temporal", fn ->
      # Find existing context for signal
      existing_context = find_signal_context(hierarchy, signal_id)
      
      updated_hierarchy = case existing_context do
        nil ->
          # Add new context
          add_signal_context_to_hierarchy(hierarchy, signal_id, new_temporal_window)
        
        context ->
          # Update existing context
          update_existing_context_temporal_data(hierarchy, context, new_temporal_window)
      end
      
      # Recompute temporal relationships
      final_hierarchy = recompute_temporal_relationships(updated_hierarchy)
      
      {:ok, final_hierarchy}
    end)
  end

  @doc """
  Analyze context hierarchy structure and patterns
  """
  def analyze_hierarchy_structure(hierarchy) do
    safe_operation("analyze_hierarchy_structure", fn ->
      analysis = %{
        structural_metrics: calculate_structural_metrics(hierarchy),
        temporal_patterns: analyze_temporal_patterns(hierarchy),
        relationship_patterns: analyze_relationship_patterns(hierarchy),
        context_distribution: analyze_context_distribution(hierarchy),
        hierarchy_health: assess_hierarchy_health(hierarchy)
      }
      
      {:ok, analysis}
    end)
  end

  @doc """
  Export context hierarchy in various formats
  """
  def export_hierarchy(hierarchy, format) do
    safe_operation("export_hierarchy", fn ->
      exported_data = case format do
        :json -> export_to_json(hierarchy)
        :xml -> export_to_xml(hierarchy)
        :yaml -> export_to_yaml(hierarchy)
        :tree_view -> export_to_tree_view(hierarchy)
        :adjacency_list -> export_to_adjacency_list(hierarchy)
        _ -> {:error, :unsupported_format}
      end
      
      case exported_data do
        {:error, _} = error -> error
        data ->
          {:ok, %{
            format: format,
            data: data,
            exported_at: System.monotonic_time(:microsecond),
            hierarchy_summary: summarize_hierarchy(hierarchy)
          }}
      end
    end)
  end

  # Private Implementation - Hierarchy Construction

  defp create_base_hierarchy_structure do
    %{
      root: %{
        id: :system_root,
        type: :system,
        level: 0,
        children: [],
        metadata: %{
          created_at: System.monotonic_time(:microsecond),
          context_type: :system_wide
        }
      },
      nodes: %{},
      relationships: [],
      temporal_index: %{},
      metadata: %{
        created_at: System.monotonic_time(:microsecond),
        version: "1.0",
        total_nodes: 0,
        max_depth: 0
      }
    }
  end

  defp add_signal_context_to_hierarchy(hierarchy, signal_id, temporal_window) do
    # Get signal configuration and data
    signal_config = get_signal_configuration(signal_id)
    signal_data = get_signal_temporal_data(signal_id, temporal_window)
    
    # Create context node for signal
    signal_context = create_signal_context_node(signal_id, signal_config, signal_data, temporal_window)
    
    # Find appropriate parent context
    parent_context = find_appropriate_parent_context(hierarchy, signal_context)
    
    # Add to hierarchy
    updated_hierarchy = add_context_node_to_hierarchy(hierarchy, signal_context, parent_context)
    
    # Update temporal index
    update_temporal_index(updated_hierarchy, signal_context, temporal_window)
  end

  defp organize_by_temporal_relationships(hierarchy, temporal_window) do
    # Group contexts by temporal proximity
    temporal_groups = group_contexts_by_temporal_proximity(hierarchy, temporal_window)
    
    # Create temporal relationship links
    temporal_relationships = create_temporal_relationships(temporal_groups)
    
    # Add temporal relationships to hierarchy
    %{hierarchy | relationships: hierarchy.relationships ++ temporal_relationships}
  end

  defp add_cross_signal_relationships(hierarchy, signal_ids) do
    # Find correlations between signals
    cross_signal_relationships = signal_ids
    |> Enum.flat_map(fn signal_id ->
      find_cross_signal_correlations(hierarchy, signal_id, signal_ids -- [signal_id])
    end)
    
    # Add to hierarchy
    %{hierarchy | relationships: hierarchy.relationships ++ cross_signal_relationships}
  end

  # Private Implementation - Hierarchy Operations

  defp merge_two_hierarchies(hierarchy1, hierarchy2) do
    # Merge nodes
    merged_nodes = Map.merge(hierarchy1.nodes, hierarchy2.nodes, fn _key, node1, node2 ->
      merge_context_nodes(node1, node2)
    end)
    
    # Merge relationships
    merged_relationships = (hierarchy1.relationships ++ hierarchy2.relationships)
    |> Enum.uniq_by(fn rel -> {rel[:source], rel[:target], rel[:type]} end)
    
    # Merge temporal indices
    merged_temporal_index = Map.merge(hierarchy1.temporal_index, hierarchy2.temporal_index)
    
    # Update metadata
    merged_metadata = %{
      created_at: min(hierarchy1.metadata.created_at, hierarchy2.metadata.created_at),
      version: "1.0",
      total_nodes: map_size(merged_nodes),
      max_depth: max(hierarchy1.metadata.max_depth, hierarchy2.metadata.max_depth),
      merged_at: System.monotonic_time(:microsecond)
    }
    
    %{
      root: merge_root_nodes(hierarchy1.root, hierarchy2.root),
      nodes: merged_nodes,
      relationships: merged_relationships,
      temporal_index: merged_temporal_index,
      metadata: merged_metadata
    }
  end

  defp reconcile_hierarchy_conflicts(hierarchy) do
    # Check for conflicting relationships
    conflict_free_relationships = remove_conflicting_relationships(hierarchy.relationships)
    
    # Validate parent-child consistency
    validated_nodes = validate_parent_child_consistency(hierarchy.nodes)
    
    # Update hierarchy
    %{hierarchy | 
      relationships: conflict_free_relationships,
      nodes: validated_nodes
    }
  end

  defp validate_hierarchy_structure(hierarchy) do
    # Validate tree structure
    case validate_tree_structure(hierarchy) do
      :ok -> 
        # Validate temporal consistency
        case validate_temporal_consistency(hierarchy) do
          :ok -> hierarchy
          {:error, _reason} -> fix_temporal_inconsistencies(hierarchy)
        end
      {:error, _reason} -> 
        fix_tree_structure_issues(hierarchy)
    end
  end

  # Private Implementation - Context Analysis

  defp calculate_structural_metrics(hierarchy) do
    %{
      total_nodes: map_size(hierarchy.nodes),
      max_depth: calculate_max_hierarchy_depth(hierarchy),
      average_branching_factor: calculate_average_branching_factor(hierarchy),
      leaf_node_count: count_leaf_nodes(hierarchy),
      internal_node_count: count_internal_nodes(hierarchy)
    }
  end

  defp analyze_temporal_patterns(hierarchy) do
    %{
      temporal_coverage: calculate_temporal_coverage(hierarchy),
      temporal_density: calculate_temporal_density(hierarchy),
      temporal_gaps: identify_temporal_gaps(hierarchy),
      temporal_clusters: identify_temporal_clusters(hierarchy)
    }
  end

  defp analyze_relationship_patterns(hierarchy) do
    %{
      relationship_types: count_relationship_types(hierarchy),
      relationship_density: calculate_relationship_density(hierarchy),
      strongly_connected_components: find_strongly_connected_components_in_hierarchy(hierarchy),
      cycles: detect_cycles_in_hierarchy(hierarchy)
    }
  end

  defp analyze_context_distribution(hierarchy) do
    %{
      contexts_per_level: count_contexts_per_level(hierarchy),
      signal_distribution: analyze_signal_distribution(hierarchy),
      temporal_distribution: analyze_temporal_distribution(hierarchy)
    }
  end

  defp assess_hierarchy_health(hierarchy) do
    %{
      structural_integrity: assess_structural_integrity(hierarchy),
      temporal_consistency: assess_temporal_consistency(hierarchy),
      relationship_coherence: assess_relationship_coherence(hierarchy),
      overall_health_score: calculate_overall_health_score(hierarchy)
    }
  end

  # Stub implementations for complex hierarchy operations
  # In production, these would contain sophisticated algorithms

  defp get_signal_configuration(_signal_id), do: %{}
  defp get_signal_temporal_data(_signal_id, _temporal_window), do: []
  defp create_signal_context_node(signal_id, _config, _data, temporal_window) do
    %{
      id: "context_#{signal_id}",
      type: :signal,
      level: 2,
      signal_id: signal_id,
      temporal_window: temporal_window,
      created_at: System.monotonic_time(:microsecond)
    }
  end
  defp find_appropriate_parent_context(_hierarchy, _context), do: :system_root
  defp add_context_node_to_hierarchy(hierarchy, context, _parent) do
    %{hierarchy | nodes: Map.put(hierarchy.nodes, context.id, context)}
  end
  defp update_temporal_index(hierarchy, _context, _temporal_window), do: hierarchy
  defp group_contexts_by_temporal_proximity(_hierarchy, _temporal_window), do: []
  defp create_temporal_relationships(_temporal_groups), do: []
  defp find_cross_signal_correlations(_hierarchy, _signal_id, _other_signals), do: []
  defp merge_context_nodes(node1, _node2), do: node1
  defp merge_root_nodes(root1, _root2), do: root1
  defp remove_conflicting_relationships(relationships), do: relationships
  defp validate_parent_child_consistency(nodes), do: nodes
  defp validate_tree_structure(_hierarchy), do: :ok
  defp validate_temporal_consistency(_hierarchy), do: :ok
  defp fix_temporal_inconsistencies(hierarchy), do: hierarchy
  defp fix_tree_structure_issues(hierarchy), do: hierarchy
  defp find_signal_context(_hierarchy, _signal_id), do: nil
  defp update_existing_context_temporal_data(hierarchy, _context, _new_temporal_window), do: hierarchy
  defp recompute_temporal_relationships(hierarchy), do: hierarchy
  defp calculate_hierarchy_depth(_hierarchy), do: 3
  defp count_context_nodes(_hierarchy), do: 10
  defp calculate_hierarchy_statistics(_hierarchy), do: %{}
  defp create_query_metadata, do: %{executed_at: System.monotonic_time(:microsecond)}
  defp find_context_ancestors(_hierarchy, _context_id), do: []
  defp find_context_descendants(_hierarchy, _context_id), do: []
  defp find_context_siblings(_hierarchy, _context_id), do: []
  defp find_temporal_neighbors(_hierarchy, _context_id, _time_window), do: []
  defp find_path_between_contexts(_hierarchy, _start, _end), do: []
  defp find_contexts_at_level(_hierarchy, _level), do: []
  defp calculate_max_hierarchy_depth(_hierarchy), do: 3
  defp calculate_average_branching_factor(_hierarchy), do: 2.0
  defp count_leaf_nodes(_hierarchy), do: 5
  defp count_internal_nodes(_hierarchy), do: 5
  defp calculate_temporal_coverage(_hierarchy), do: 0.8
  defp calculate_temporal_density(_hierarchy), do: 0.6
  defp identify_temporal_gaps(_hierarchy), do: []
  defp identify_temporal_clusters(_hierarchy), do: []
  defp count_relationship_types(_hierarchy), do: %{}
  defp calculate_relationship_density(_hierarchy), do: 0.3
  defp find_strongly_connected_components_in_hierarchy(_hierarchy), do: []
  defp detect_cycles_in_hierarchy(_hierarchy), do: []
  defp count_contexts_per_level(_hierarchy), do: %{}
  defp analyze_signal_distribution(_hierarchy), do: %{}
  defp analyze_temporal_distribution(_hierarchy), do: %{}
  defp assess_structural_integrity(_hierarchy), do: :good
  defp assess_temporal_consistency(_hierarchy), do: :good
  defp assess_relationship_coherence(_hierarchy), do: :good
  defp calculate_overall_health_score(_hierarchy), do: 0.85
  defp export_to_json(hierarchy), do: Jason.encode(hierarchy)
  defp export_to_xml(_hierarchy), do: "<hierarchy></hierarchy>"
  defp export_to_yaml(_hierarchy), do: "hierarchy: {}"
  defp export_to_tree_view(_hierarchy), do: "Root\n  ├── Context1\n  └── Context2"
  defp export_to_adjacency_list(_hierarchy), do: []
  defp summarize_hierarchy(hierarchy), do: %{nodes: map_size(hierarchy.nodes)}
end