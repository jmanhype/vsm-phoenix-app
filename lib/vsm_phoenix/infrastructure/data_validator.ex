defmodule VsmPhoenix.Infrastructure.DataValidator do
  @moduledoc """
  Data validation utilities to prevent nil and malformed data issues.
  Provides guards, validation functions, and safe data access.
  """

  require Logger

  @doc """
  Validate and sanitize incoming data with a schema.
  """
  def validate_data(data, schema) when is_map(schema) do
    with {:ok, validated} <- validate_fields(data, schema),
         {:ok, sanitized} <- sanitize_data(validated, schema) do
      {:ok, sanitized}
    else
      {:error, reason} = error ->
        emit_telemetry(:validation_failed, reason)
        error
    end
  end

  @doc """
  Safe get with validation and default value.
  """
  def safe_get(data, key, default \\ nil, validator \\ nil)
  
  def safe_get(nil, _key, default, _validator), do: default
  
  def safe_get(data, key, default, nil) when is_map(data) do
    Map.get(data, key, default)
  end
  
  def safe_get(data, key, default, validator) when is_map(data) and is_function(validator, 1) do
    case Map.get(data, key) do
      nil -> default
      value ->
        if validator.(value) do
          value
        else
          Logger.warning("Validation failed for key #{inspect(key)}, using default")
          default
        end
    end
  end

  @doc """
  Safe get for nested maps.
  """
  def safe_get_in(data, keys, default \\ nil) when is_list(keys) do
    try do
      get_in(data, keys) || default
    rescue
      _ -> default
    end
  end

  @doc """
  Validate required fields are present and non-nil.
  """
  def validate_required(data, required_fields) when is_list(required_fields) do
    missing = Enum.filter(required_fields, fn field ->
      is_nil(safe_get(data, field))
    end)
    
    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  @doc """
  Validate data types match expected types.
  """
  def validate_types(data, type_specs) when is_map(type_specs) do
    errors = Enum.reduce(type_specs, [], fn {field, expected_type}, acc ->
      value = safe_get(data, field)
      
      if value != nil && !matches_type?(value, expected_type) do
        [{field, {:type_mismatch, expected_type, type_of(value)}} | acc]
      else
        acc
      end
    end)
    
    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:type_validation_failed, errors}}
    end
  end

  @doc """
  Validate string format (non-empty, length, pattern).
  """
  def validate_string(value, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 0)
    max_length = Keyword.get(opts, :max_length, :infinity)
    pattern = Keyword.get(opts, :pattern)
    non_empty = Keyword.get(opts, :non_empty, false)
    
    cond do
      !is_binary(value) ->
        {:error, :not_a_string}
        
      non_empty && String.trim(value) == "" ->
        {:error, :empty_string}
        
      String.length(value) < min_length ->
        {:error, {:too_short, min_length}}
        
      max_length != :infinity && String.length(value) > max_length ->
        {:error, {:too_long, max_length}}
        
      pattern && !Regex.match?(pattern, value) ->
        {:error, {:pattern_mismatch, pattern}}
        
      true ->
        :ok
    end
  end

  @doc """
  Validate number is within range.
  """
  def validate_number(value, opts \\ []) do
    min = Keyword.get(opts, :min, :negative_infinity)
    max = Keyword.get(opts, :max, :infinity)
    
    cond do
      !is_number(value) ->
        {:error, :not_a_number}
        
      min != :negative_infinity && value < min ->
        {:error, {:below_min, min}}
        
      max != :infinity && value > max ->
        {:error, {:above_max, max}}
        
      true ->
        :ok
    end
  end

  @doc """
  Validate list items and length.
  """
  def validate_list(value, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 0)
    max_length = Keyword.get(opts, :max_length, :infinity)
    item_validator = Keyword.get(opts, :item_validator)
    
    cond do
      !is_list(value) ->
        {:error, :not_a_list}
        
      length(value) < min_length ->
        {:error, {:too_few_items, min_length}}
        
      max_length != :infinity && length(value) > max_length ->
        {:error, {:too_many_items, max_length}}
        
      item_validator ->
        validate_list_items(value, item_validator)
        
      true ->
        :ok
    end
  end

  @doc """
  Sanitize data by removing nil values and empty strings.
  """
  def sanitize_map(data, opts \\ []) when is_map(data) do
    remove_nil = Keyword.get(opts, :remove_nil, true)
    remove_empty_strings = Keyword.get(opts, :remove_empty_strings, false)
    recursive = Keyword.get(opts, :recursive, true)
    
    data
    |> Enum.reject(fn {_k, v} ->
      (remove_nil && is_nil(v)) ||
      (remove_empty_strings && v == "")
    end)
    |> Enum.map(fn {k, v} ->
      if recursive && is_map(v) do
        {k, sanitize_map(v, opts)}
      else
        {k, v}
      end
    end)
    |> Map.new()
  end

  @doc """
  Guard macro for non-nil values.
  """
  defmacro is_not_nil(value) do
    quote do
      not is_nil(unquote(value))
    end
  end

  @doc """
  Guard macro for non-empty strings.
  """
  defmacro is_non_empty_string(value) do
    quote do
      is_binary(unquote(value)) and unquote(value) != ""
    end
  end

  # Private functions

  defp validate_fields(data, schema) do
    errors = Enum.reduce(schema, [], fn {field, rules}, acc ->
      value = safe_get(data, field)
      
      case validate_field_value(value, rules) do
        :ok -> acc
        {:error, reason} -> [{field, reason} | acc]
      end
    end)
    
    if Enum.empty?(errors) do
      {:ok, data}
    else
      {:error, {:validation_errors, errors}}
    end
  end

  defp validate_field_value(value, rules) when is_map(rules) do
    rules
    |> Enum.reduce_while(:ok, fn {rule, rule_value}, _acc ->
      case apply_validation_rule(value, rule, rule_value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_validation_rule(value, :required, true) when is_nil(value) do
    {:error, :required_field_missing}
  end

  defp apply_validation_rule(value, :type, expected_type) do
    if matches_type?(value, expected_type) do
      :ok
    else
      {:error, {:type_mismatch, expected_type}}
    end
  end

  defp apply_validation_rule(value, :validator, validator_fun) when is_function(validator_fun, 1) do
    if validator_fun.(value) do
      :ok
    else
      {:error, :custom_validation_failed}
    end
  end

  defp apply_validation_rule(_value, _rule, _rule_value), do: :ok

  defp sanitize_data(data, _schema) do
    # Additional sanitization based on schema can be added here
    {:ok, data}
  end

  defp matches_type?(value, :string), do: is_binary(value)
  defp matches_type?(value, :integer), do: is_integer(value)
  defp matches_type?(value, :float), do: is_float(value)
  defp matches_type?(value, :number), do: is_number(value)
  defp matches_type?(value, :boolean), do: is_boolean(value)
  defp matches_type?(value, :map), do: is_map(value)
  defp matches_type?(value, :list), do: is_list(value)
  defp matches_type?(value, :atom), do: is_atom(value)
  defp matches_type?(value, :any), do: true
  defp matches_type?(value, type) when is_function(type, 1), do: type.(value)
  defp matches_type?(_value, _type), do: false

  defp type_of(value) when is_binary(value), do: :string
  defp type_of(value) when is_integer(value), do: :integer
  defp type_of(value) when is_float(value), do: :float
  defp type_of(value) when is_boolean(value), do: :boolean
  defp type_of(value) when is_map(value), do: :map
  defp type_of(value) when is_list(value), do: :list
  defp type_of(value) when is_atom(value), do: :atom
  defp type_of(_value), do: :unknown

  defp validate_list_items(list, validator) when is_function(validator, 1) do
    errors = list
    |> Enum.with_index()
    |> Enum.reduce([], fn {item, index}, acc ->
      case validator.(item) do
        :ok -> acc
        true -> acc
        false -> [{index, :validation_failed} | acc]
        {:error, reason} -> [{index, reason} | acc]
      end
    end)
    
    if Enum.empty?(errors) do
      :ok
    else
      {:error, {:item_validation_failed, errors}}
    end
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:vsm_phoenix, :data_validator, event],
      %{count: 1},
      metadata
    )
  rescue
    _ -> :ok
  end
end