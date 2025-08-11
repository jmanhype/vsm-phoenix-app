defmodule VsmPhoenix.Telemetry.Processors.XMLProcessor do
  @moduledoc """
  XML Processor - Single Responsibility for XML Operations
  
  Handles ONLY XML generation, parsing, and validation for semantic blocks.
  Extracted from SemanticBlockProcessor god object to follow Single Responsibility Principle.
  
  Responsibilities:
  - XML semantic block generation from structured data
  - XML parsing and validation
  - Schema version management
  - XML structure normalization
  """

  use VsmPhoenix.Telemetry.Behaviors.SharedLogging
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior

  @xml_schema_version "1.0"

  @doc """
  Generate XML semantic block from structured data
  """
  def generate_semantic_xml(signal_id, analysis_data, context_metadata, timestamp) do
    safe_operation("generate_semantic_xml", fn ->
      xml_content = construct_semantic_xml_internal(signal_id, analysis_data, context_metadata, timestamp)
      
      case validate_xml_structure(xml_content) do
        :ok -> 
          log_signal_event(:debug, signal_id, "XML generated successfully", %{
            xml_size_bytes: byte_size(xml_content)
          })
          {:ok, xml_content}
        {:error, reason} -> 
          log_signal_event(:error, signal_id, "XML validation failed", %{reason: reason})
          {:error, reason}
      end
    end)
  end

  @doc """
  Parse XML semantic block into structured data
  """
  def parse_semantic_xml(xml_content) do
    safe_operation("parse_semantic_xml", fn ->
      case validate_xml_format(xml_content) do
        :ok -> parse_xml_internal(xml_content)
        {:error, reason} -> {:error, {:invalid_xml, reason}}
      end
    end)
  end

  @doc """
  Validate XML semantic block structure
  """
  def validate_semantic_block_xml(xml_content) do
    safe_operation("validate_semantic_block", fn ->
      with :ok <- validate_xml_format(xml_content),
           :ok <- validate_schema_version(xml_content),
           :ok <- validate_required_elements(xml_content) do
        :ok
      else
        error -> error
      end
    end)
  end

  @doc """
  Extract metadata from XML semantic block
  """
  def extract_xml_metadata(xml_content) do
    safe_operation("extract_xml_metadata", fn ->
      case parse_xml_internal(xml_content) do
        {:ok, parsed_data} -> 
          metadata = %{
            signal_id: extract_signal_id(parsed_data),
            timestamp: extract_timestamp(parsed_data),
            schema_version: extract_schema_version(parsed_data),
            context_types: extract_context_types(parsed_data)
          }
          {:ok, metadata}
        error -> error
      end
    end)
  end

  # Private Implementation

  defp construct_semantic_xml_internal(signal_id, analysis_data, context_metadata, timestamp) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <semantic-block version="#{@xml_schema_version}" signal-id="#{signal_id}" timestamp="#{timestamp}">
      <metadata>
        <source>#{context_metadata[:source] || "unknown"}</source>
        <importance>#{context_metadata[:importance] || 0.5}</importance>
        <confidence>#{context_metadata[:confidence] || 0.8}</confidence>
        <processing-stage>#{context_metadata[:processing_stage] || "analysis"}</processing-stage>
      </metadata>
      
      <signal-analysis>
        #{format_signal_analysis_xml(analysis_data)}
      </signal-analysis>
      
      <pattern-recognition>
        #{format_pattern_analysis_xml(analysis_data[:patterns] || %{})}
      </pattern-recognition>
      
      <contextual-information>
        <temporal-context>
          <window-start>#{context_metadata[:temporal_window][:start] || timestamp - 60_000_000}</window-start>
          <window-end>#{context_metadata[:temporal_window][:end] || timestamp}</window-end>
          <phase>#{context_metadata[:system_phase] || "unknown"}</phase>
          <cycle>#{context_metadata[:processing_cycle] || 0}</cycle>
        </temporal-context>
        
        <causal-context>
          #{format_causal_relationships_xml(context_metadata[:causal_relationships] || [])}
        </causal-context>
        
        <system-context>
          <system-health>#{context_metadata[:system_health] || 0.8}</system-health>
          <load-factor>#{context_metadata[:load_factor] || 0.5}</load-factor>
          <resource-utilization>#{context_metadata[:resource_utilization] || 0.6}</resource-utilization>
        </system-context>
      </contextual-information>
      
      <semantic-relationships>
        #{format_semantic_relationships_xml(context_metadata[:semantic_relationships] || [])}
      </semantic-relationships>
      
      <performance-metrics>
        <efficiency-score>#{analysis_data[:efficiency_score] || 1.0}</efficiency-score>
        <processing-time>#{analysis_data[:processing_time_us] || 0}</processing-time>
        <accuracy-estimate>#{analysis_data[:accuracy_estimate] || 0.85}</accuracy-estimate>
        <resource-cost>#{analysis_data[:resource_cost] || 0.1}</resource-cost>
      </performance-metrics>
    </semantic-block>
    """
  end

  defp format_signal_analysis_xml(analysis_data) when is_map(analysis_data) do
    analysis_data
    |> Enum.map(fn {key, value} ->
      "<#{key}>#{format_xml_value(value)}</#{key}>"
    end)
    |> Enum.join("\n        ")
  end

  defp format_pattern_analysis_xml(patterns) when is_map(patterns) do
    patterns
    |> Enum.map(fn {pattern_type, pattern_data} ->
      """
      <pattern type="#{pattern_type}">
        <confidence>#{pattern_data[:confidence] || 0.7}</confidence>
        <frequency>#{pattern_data[:frequency] || "unknown"}</frequency>
        <characteristics>#{format_xml_value(pattern_data[:characteristics] || [])}</characteristics>
      </pattern>
      """
    end)
    |> Enum.join("")
  end

  defp format_causal_relationships_xml(relationships) when is_list(relationships) do
    relationships
    |> Enum.map(fn relationship ->
      """
      <causal-relationship>
        <cause>#{relationship[:cause]}</cause>
        <effect>#{relationship[:effect]}</effect>
        <strength>#{relationship[:strength] || 0.5}</strength>
        <confidence>#{relationship[:confidence] || 0.7}</confidence>
      </causal-relationship>
      """
    end)
    |> Enum.join("")
  end

  defp format_semantic_relationships_xml(relationships) when is_list(relationships) do
    relationships
    |> Enum.map(fn relationship ->
      """
      <semantic-relationship>
        <type>#{relationship[:type]}</type>
        <source>#{relationship[:source]}</source>
        <target>#{relationship[:target]}</target>
        <weight>#{relationship[:weight] || 1.0}</weight>
      </semantic-relationship>
      """
    end)
    |> Enum.join("")
  end

  defp format_xml_value(value) when is_list(value) do
    value |> Enum.join(", ")
  end

  defp format_xml_value(value) when is_map(value) do
    value |> inspect()
  end

  defp format_xml_value(value), do: to_string(value)

  defp validate_xml_structure(xml_content) do
    # Basic XML structure validation
    cond do
      not String.contains?(xml_content, "<?xml version=") ->
        {:error, :missing_xml_declaration}
      
      not String.contains?(xml_content, "<semantic-block") ->
        {:error, :missing_semantic_block_root}
      
      not String.contains?(xml_content, "</semantic-block>") ->
        {:error, :unclosed_semantic_block}
      
      true -> :ok
    end
  end

  defp validate_xml_format(xml_content) when is_binary(xml_content) do
    case String.trim(xml_content) do
      "" -> {:error, :empty_xml}
      trimmed when byte_size(trimmed) < 50 -> {:error, :xml_too_short}
      _ -> :ok
    end
  end

  defp validate_xml_format(_), do: {:error, :invalid_xml_format}

  defp validate_schema_version(xml_content) do
    if String.contains?(xml_content, "version=\"#{@xml_schema_version}\"") do
      :ok
    else
      {:error, :incompatible_schema_version}
    end
  end

  defp validate_required_elements(xml_content) do
    required_elements = ["<metadata>", "<signal-analysis>", "<contextual-information>"]
    
    missing_elements = required_elements
    |> Enum.filter(fn element -> not String.contains?(xml_content, element) end)
    
    if Enum.empty?(missing_elements) do
      :ok
    else
      {:error, {:missing_elements, missing_elements}}
    end
  end

  defp parse_xml_internal(xml_content) do
    # Simple XML parsing - in production, use proper XML library
    with {:ok, signal_id} <- extract_attribute(xml_content, "signal-id"),
         {:ok, timestamp} <- extract_attribute(xml_content, "timestamp"),
         {:ok, metadata} <- extract_section_content(xml_content, "metadata"),
         {:ok, analysis} <- extract_section_content(xml_content, "signal-analysis") do
      
      {:ok, %{
        signal_id: signal_id,
        timestamp: String.to_integer(timestamp),
        metadata: parse_metadata_section(metadata),
        analysis: parse_analysis_section(analysis)
      }}
    else
      error -> error
    end
  end

  defp extract_signal_id(parsed_data) do
    Map.get(parsed_data, :signal_id, "unknown")
  end

  defp extract_timestamp(parsed_data) do
    Map.get(parsed_data, :timestamp, System.monotonic_time(:microsecond))
  end

  defp extract_schema_version(parsed_data) do
    Map.get(parsed_data, :schema_version, @xml_schema_version)
  end

  defp extract_context_types(parsed_data) do
    # Extract context types from parsed data
    Map.get(parsed_data, :context_types, [])
  end

  defp extract_attribute(xml_content, attribute_name) do
    case Regex.run(~r/#{attribute_name}="([^"]+)"/, xml_content) do
      [_, value] -> {:ok, value}
      nil -> {:error, {:missing_attribute, attribute_name}}
    end
  end

  defp extract_section_content(xml_content, section_name) do
    case Regex.run(~r/<#{section_name}>(.*?)<\/#{section_name}>/s, xml_content) do
      [_, content] -> {:ok, String.trim(content)}
      nil -> {:error, {:missing_section, section_name}}
    end
  end

  defp parse_metadata_section(metadata_xml) do
    # Simple metadata parsing
    %{
      source: extract_element_text(metadata_xml, "source"),
      importance: parse_float(extract_element_text(metadata_xml, "importance")),
      confidence: parse_float(extract_element_text(metadata_xml, "confidence"))
    }
  end

  defp parse_analysis_section(analysis_xml) do
    # Simple analysis parsing - would be more sophisticated in production
    %{
      raw_xml: analysis_xml
    }
  end

  defp extract_element_text(xml, element_name) do
    case Regex.run(~r/<#{element_name}>([^<]+)<\/#{element_name}>/, xml) do
      [_, text] -> text
      nil -> nil
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {float_val, _} -> float_val
      :error -> 0.0
    end
  end
  defp parse_float(val), do: val
end