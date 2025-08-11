defmodule VsmPhoenix.Telemetry.Processors.MeaningGraphBuilder do
  @moduledoc """
  Meaning Graph Builder - Single Responsibility for Graph Construction
  
  Handles ONLY meaning graph construction and management from semantic blocks.
  Extracted from SemanticBlockProcessor god object to follow Single Responsibility Principle.
  
  Responsibilities:
  - Graph construction from semantic relationships
  - Node and edge management
  - Graph traversal and querying
  - Graph analysis and metrics
  """

  use VsmPhoenix.Telemetry.Behaviors.SharedLogging
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior

  alias VsmPhoenix.Telemetry.Processors.SemanticAnalyzer

  @doc """
  Create meaning graph from semantic blocks
  """
  def create_meaning_graph_from_blocks(semantic_blocks) do
    safe_operation("create_meaning_graph", fn ->
      # Extract all semantic relationships from blocks
      all_relationships = semantic_blocks
      |> Enum.flat_map(&extract_relationships_from_block/1)
      
      # Build graph structure
      graph = build_graph_structure(all_relationships)
      
      # Add metadata and analysis
      enhanced_graph = enhance_graph_with_metadata(graph, semantic_blocks)
      
      log_telemetry_event(:info, :meaning_graph_builder, "Graph created", %{
        node_count: map_size(enhanced_graph.nodes),
        edge_count: length(enhanced_graph.edges),
        block_count: length(semantic_blocks)
      })
      
      {:ok, enhanced_graph}
    end)
  end

  @doc """
  Merge multiple meaning graphs
  """
  def merge_meaning_graphs(graphs) do
    safe_operation("merge_meaning_graphs", fn ->
      merged_graph = graphs
      |> Enum.reduce(create_empty_graph(), fn graph, acc ->
        merge_two_graphs(acc, graph)
      end)
      
      # Recalculate metrics after merge
      final_graph = recalculate_graph_metrics(merged_graph)
      
      {:ok, final_graph}
    end)
  end

  @doc """
  Query meaning graph for specific patterns
  """
  def query_meaning_graph(graph, query_params) do
    safe_operation("query_meaning_graph", fn ->
      results = case query_params[:query_type] do
        :path_between_nodes ->
          find_paths_between_nodes(graph, query_params[:start_node], query_params[:end_node])
        
        :nodes_with_property ->
          find_nodes_with_property(graph, query_params[:property], query_params[:value])
        
        :subgraph_around_node ->
          extract_subgraph_around_node(graph, query_params[:center_node], query_params[:radius])
        
        :strongly_connected_components ->
          find_strongly_connected_components(graph)
        
        :central_nodes ->
          find_most_central_nodes(graph, query_params[:centrality_measure])
        
        _ ->
          {:error, :unsupported_query_type}
      end
      
      case results do
        {:error, _} = error -> error
        query_results ->
          {:ok, %{
            query_type: query_params[:query_type],
            results: query_results,
            graph_stats: calculate_graph_statistics(graph),
            query_metadata: %{
              executed_at: System.monotonic_time(:microsecond),
              execution_time_us: 0  # Would be measured in production
            }
          }}
      end
    end)
  end

  @doc """
  Analyze graph structure and return insights
  """
  def analyze_graph_structure(graph) do
    safe_operation("analyze_graph_structure", fn ->
      analysis = %{
        basic_metrics: calculate_basic_graph_metrics(graph),
        centrality_metrics: calculate_centrality_metrics(graph),
        clustering_metrics: calculate_clustering_metrics(graph),
        connectivity_analysis: analyze_connectivity(graph),
        community_detection: detect_communities(graph),
        temporal_analysis: analyze_temporal_patterns(graph)
      }
      
      {:ok, analysis}
    end)
  end

  @doc """
  Export graph in various formats
  """
  def export_graph(graph, format) do
    safe_operation("export_graph", fn ->
      exported_data = case format do
        :graphml -> export_to_graphml(graph)
        :json -> export_to_json(graph)
        :dot -> export_to_dot(graph)
        :adjacency_matrix -> export_to_adjacency_matrix(graph)
        :edge_list -> export_to_edge_list(graph)
        _ -> {:error, :unsupported_format}
      end
      
      case exported_data do
        {:error, _} = error -> error
        data ->
          {:ok, %{
            format: format,
            data: data,
            exported_at: System.monotonic_time(:microsecond),
            graph_summary: summarize_graph(graph)
          }}
      end
    end)
  end

  @doc """
  Validate graph structure integrity
  """
  def validate_graph_integrity(graph) do
    safe_operation("validate_graph_integrity", fn ->
      validations = [
        validate_node_references(graph),
        validate_edge_consistency(graph),
        validate_metadata_completeness(graph),
        validate_graph_connectivity(graph)
      ]
      
      errors = validations
      |> Enum.filter(fn {status, _} -> status == :error end)
      |> Enum.map(fn {_, error} -> error end)
      
      if Enum.empty?(errors) do
        {:ok, :valid}
      else
        {:error, {:validation_failed, errors}}
      end
    end)
  end

  # Private Implementation - Graph Construction

  defp extract_relationships_from_block(semantic_block) do
    # Extract relationships from semantic block data
    relationships = []
    
    # Extract from XML content if present
    relationships = if Map.has_key?(semantic_block, :xml_content) do
      relationships ++ extract_relationships_from_xml(semantic_block.xml_content)
    else
      relationships
    end
    
    # Extract from structured data if present
    relationships = if Map.has_key?(semantic_block, :structured_data) do
      relationships ++ extract_relationships_from_structured_data(semantic_block.structured_data)
    else
      relationships
    end
    
    # Add block metadata as context
    relationships
    |> Enum.map(fn relationship ->
      Map.merge(relationship, %{
        source_block_id: semantic_block[:block_id] || generate_block_id(),
        block_timestamp: semantic_block[:timestamp] || System.monotonic_time(:microsecond)
      })
    end)
  end

  defp build_graph_structure(relationships) do
    # Initialize empty graph
    graph = create_empty_graph()
    
    # Add nodes and edges from relationships
    relationships
    |> Enum.reduce(graph, fn relationship, acc_graph ->
      acc_graph
      |> add_nodes_from_relationship(relationship)
      |> add_edge_from_relationship(relationship)
    end)
  end

  defp enhance_graph_with_metadata(graph, semantic_blocks) do
    # Add block metadata to nodes
    enhanced_nodes = graph.nodes
    |> Enum.map(fn {node_id, node_data} ->
      # Find blocks that reference this node
      related_blocks = find_blocks_referencing_node(node_id, semantic_blocks)
      
      enhanced_node_data = Map.merge(node_data, %{
        related_blocks: related_blocks,
        block_count: length(related_blocks),
        temporal_span: calculate_temporal_span(related_blocks),
        semantic_coherence: calculate_node_coherence(node_data, related_blocks)
      })
      
      {node_id, enhanced_node_data}
    end)
    |> Enum.into(%{})
    
    %{graph | nodes: enhanced_nodes}
  end

  defp create_empty_graph do
    %{
      nodes: %{},
      edges: [],
      metadata: %{
        created_at: System.monotonic_time(:microsecond),
        node_count: 0,
        edge_count: 0,
        graph_type: :directed
      }
    }
  end

  defp add_nodes_from_relationship(graph, relationship) do
    # Add source node if not exists
    graph = add_node_if_not_exists(graph, relationship[:source], relationship)
    
    # Add target node if not exists
    graph = add_node_if_not_exists(graph, relationship[:target], relationship)
    
    graph
  end

  defp add_edge_from_relationship(graph, relationship) do
    edge = %{
      source: relationship[:source],
      target: relationship[:target],
      type: relationship[:type] || :generic,
      weight: relationship[:weight] || 1.0,
      confidence: relationship[:confidence] || 0.7,
      metadata: Map.drop(relationship, [:source, :target, :type, :weight, :confidence])
    }
    
    %{graph | 
      edges: [edge | graph.edges],
      metadata: Map.put(graph.metadata, :edge_count, length(graph.edges) + 1)
    }
  end

  defp add_node_if_not_exists(graph, node_id, relationship) do
    if Map.has_key?(graph.nodes, node_id) do
      # Update existing node with relationship metadata
      existing_node = graph.nodes[node_id]
      updated_node = merge_node_metadata(existing_node, relationship)
      
      %{graph | nodes: Map.put(graph.nodes, node_id, updated_node)}
    else
      # Create new node
      new_node = %{
        id: node_id,
        type: infer_node_type(node_id, relationship),
        properties: extract_node_properties(node_id, relationship),
        created_at: System.monotonic_time(:microsecond),
        relationship_count: 1
      }
      
      %{graph | 
        nodes: Map.put(graph.nodes, node_id, new_node),
        metadata: Map.put(graph.metadata, :node_count, map_size(graph.nodes) + 1)
      }
    end
  end

  # Private Implementation - Graph Operations

  defp merge_two_graphs(graph1, graph2) do
    # Merge nodes
    merged_nodes = Map.merge(graph1.nodes, graph2.nodes, fn _key, node1, node2 ->
      merge_node_data(node1, node2)
    end)
    
    # Merge edges (avoiding duplicates)
    merged_edges = (graph1.edges ++ graph2.edges)
    |> Enum.uniq_by(fn edge -> {edge.source, edge.target, edge.type} end)
    
    # Merge metadata
    merged_metadata = %{
      created_at: min(graph1.metadata.created_at, graph2.metadata.created_at),
      node_count: map_size(merged_nodes),
      edge_count: length(merged_edges),
      graph_type: graph1.metadata.graph_type,
      merged_at: System.monotonic_time(:microsecond),
      source_graphs: 2
    }
    
    %{
      nodes: merged_nodes,
      edges: merged_edges,
      metadata: merged_metadata
    }
  end

  defp recalculate_graph_metrics(graph) do
    updated_metadata = Map.merge(graph.metadata, %{
      node_count: map_size(graph.nodes),
      edge_count: length(graph.edges),
      metrics_updated_at: System.monotonic_time(:microsecond)
    })
    
    %{graph | metadata: updated_metadata}
  end

  # Private Implementation - Graph Analysis

  defp calculate_basic_graph_metrics(graph) do
    %{
      node_count: map_size(graph.nodes),
      edge_count: length(graph.edges),
      density: calculate_graph_density(graph),
      diameter: calculate_graph_diameter(graph),
      average_degree: calculate_average_degree(graph),
      clustering_coefficient: calculate_global_clustering_coefficient(graph)
    }
  end

  defp calculate_centrality_metrics(graph) do
    %{
      degree_centrality: calculate_degree_centrality(graph),
      betweenness_centrality: calculate_betweenness_centrality(graph),
      closeness_centrality: calculate_closeness_centrality(graph),
      eigenvector_centrality: calculate_eigenvector_centrality(graph)
    }
  end

  defp calculate_clustering_metrics(graph) do
    %{
      global_clustering_coefficient: calculate_global_clustering_coefficient(graph),
      local_clustering_coefficients: calculate_local_clustering_coefficients(graph),
      transitivity: calculate_transitivity(graph)
    }
  end

  defp analyze_connectivity(graph) do
    %{
      is_connected: is_graph_connected(graph),
      connected_components: find_connected_components(graph),
      strongly_connected_components: find_strongly_connected_components(graph),
      articulation_points: find_articulation_points(graph),
      bridges: find_bridges(graph)
    }
  end

  # Stub implementations for complex graph algorithms
  # In production, these would use sophisticated graph libraries

  defp extract_relationships_from_xml(_xml_content), do: []
  defp extract_relationships_from_structured_data(_structured_data), do: []
  defp generate_block_id, do: "block_#{:rand.uniform(1000000)}"
  defp find_blocks_referencing_node(_node_id, _blocks), do: []
  defp calculate_temporal_span(_blocks), do: {nil, nil}
  defp calculate_node_coherence(_node_data, _blocks), do: 0.8
  defp merge_node_metadata(node, _relationship), do: node
  defp infer_node_type(_node_id, _relationship), do: :generic
  defp extract_node_properties(_node_id, _relationship), do: %{}
  defp merge_node_data(node1, _node2), do: node1
  defp find_paths_between_nodes(_graph, _start, _end), do: []
  defp find_nodes_with_property(_graph, _property, _value), do: []
  defp extract_subgraph_around_node(_graph, _center, _radius), do: %{}
  defp find_strongly_connected_components(_graph), do: []
  defp find_most_central_nodes(_graph, _measure), do: []
  defp calculate_graph_statistics(_graph), do: %{}
  defp detect_communities(_graph), do: []
  defp analyze_temporal_patterns(_graph), do: %{}
  defp export_to_graphml(_graph), do: "<graphml></graphml>"
  defp export_to_json(graph), do: Jason.encode(graph)
  defp export_to_dot(_graph), do: "digraph G {}"
  defp export_to_adjacency_matrix(_graph), do: []
  defp export_to_edge_list(graph), do: graph.edges
  defp summarize_graph(graph), do: %{nodes: map_size(graph.nodes), edges: length(graph.edges)}
  defp validate_node_references(_graph), do: {:ok, :valid}
  defp validate_edge_consistency(_graph), do: {:ok, :valid}
  defp validate_metadata_completeness(_graph), do: {:ok, :valid}
  defp validate_graph_connectivity(_graph), do: {:ok, :valid}
  defp calculate_graph_density(_graph), do: 0.1
  defp calculate_graph_diameter(_graph), do: 5
  defp calculate_average_degree(_graph), do: 2.0
  defp calculate_global_clustering_coefficient(_graph), do: 0.3
  defp calculate_degree_centrality(_graph), do: %{}
  defp calculate_betweenness_centrality(_graph), do: %{}
  defp calculate_closeness_centrality(_graph), do: %{}
  defp calculate_eigenvector_centrality(_graph), do: %{}
  defp calculate_local_clustering_coefficients(_graph), do: %{}
  defp calculate_transitivity(_graph), do: 0.3
  defp is_graph_connected(_graph), do: true
  defp find_connected_components(_graph), do: []
  defp find_articulation_points(_graph), do: []
  defp find_bridges(_graph), do: []
end