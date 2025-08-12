defmodule VsmPhoenix.Telemetry.SignalAggregator.Statistics do
  @moduledoc """
  Statistics Module for Signal Aggregation
  
  Provides essential statistical functions for signal processing and analysis.
  Extracted to resolve integration gap after god object refactoring.
  
  Functions:
  - Basic statistics: mean, median, mode
  - Variability measures: variance, standard_deviation
  - Distribution analysis: percentile
  - Advanced metrics: correlation, covariance
  """

  @doc """
  Calculate the arithmetic mean (average) of a list of numbers
  """
  def mean([]), do: 0.0
  def mean(values) when is_list(values) do
    numeric_values = Enum.filter(values, &is_number/1)
    case numeric_values do
      [] -> 0.0
      nums -> Enum.sum(nums) / length(nums)
    end
  end
  def mean(value) when is_number(value), do: value

  @doc """
  Calculate the median (middle value) of a list of numbers
  """
  def median([]), do: 0.0
  def median(values) when is_list(values) do
    numeric_values = 
      values
      |> Enum.filter(&is_number/1)
      |> Enum.sort()
    
    case numeric_values do
      [] -> 0.0
      nums ->
        length = length(nums)
        if rem(length, 2) == 0 do
          # Even number of elements - average of middle two
          mid1 = Enum.at(nums, div(length, 2) - 1)
          mid2 = Enum.at(nums, div(length, 2))
          (mid1 + mid2) / 2
        else
          # Odd number of elements - middle element
          Enum.at(nums, div(length, 2))
        end
    end
  end
  def median(value) when is_number(value), do: value

  @doc """
  Calculate the mode (most frequent value) of a list
  Returns the first mode found if multiple modes exist
  """
  def mode([]), do: 0.0
  def mode(values) when is_list(values) do
    numeric_values = Enum.filter(values, &is_number/1)
    case numeric_values do
      [] -> 0.0
      [single] -> single
      nums ->
        frequency_map = Enum.frequencies(nums)
        {mode_value, _frequency} = Enum.max_by(frequency_map, fn {_value, freq} -> freq end)
        mode_value
    end
  end
  def mode(value) when is_number(value), do: value

  @doc """
  Calculate the variance of a list of numbers
  """
  def variance([]), do: 0.0
  def variance(values) when is_list(values) do
    numeric_values = Enum.filter(values, &is_number/1)
    case numeric_values do
      [] -> 0.0
      [_single] -> 0.0
      nums ->
        mean_val = mean(nums)
        squared_diffs = Enum.map(nums, fn x -> :math.pow(x - mean_val, 2) end)
        mean(squared_diffs)
    end
  end
  def variance(value) when is_number(value), do: 0.0

  @doc """
  Calculate the standard deviation of a list of numbers
  """
  def standard_deviation([]), do: 0.0
  def standard_deviation(values) when is_list(values) do
    values
    |> variance()
    |> :math.sqrt()
  end
  def standard_deviation(value) when is_number(value), do: 0.0

  @doc """
  Calculate the percentile of a list of numbers
  """
  def percentile([], _p), do: 0.0
  def percentile(values, p) when is_list(values) and is_number(p) and p >= 0 and p <= 100 do
    numeric_values = 
      values
      |> Enum.filter(&is_number/1)
      |> Enum.sort()
    
    case numeric_values do
      [] -> 0.0
      nums ->
        n = length(nums)
        index = (p / 100) * (n - 1)
        
        if index == trunc(index) do
          # Exact index
          Enum.at(nums, trunc(index))
        else
          # Interpolate between two values
          lower_index = trunc(index)
          upper_index = min(lower_index + 1, n - 1)
          lower_val = Enum.at(nums, lower_index)
          upper_val = Enum.at(nums, upper_index)
          
          fraction = index - lower_index
          lower_val + fraction * (upper_val - lower_val)
        end
    end
  end
  def percentile(values, p) when is_list(values), do: percentile(values, 50.0)
  def percentile(value, _p) when is_number(value), do: value

  @doc """
  Calculate correlation between two lists of numbers
  Returns Pearson correlation coefficient (-1 to 1)
  """
  def correlation([], []), do: 0.0
  def correlation(x_values, y_values) when is_list(x_values) and is_list(y_values) do
    x_nums = Enum.filter(x_values, &is_number/1)
    y_nums = Enum.filter(y_values, &is_number/1)
    
    min_length = min(length(x_nums), length(y_nums))
    
    if min_length < 2 do
      0.0
    else
      x_data = Enum.take(x_nums, min_length)
      y_data = Enum.take(y_nums, min_length)
      
      x_mean = mean(x_data)
      y_mean = mean(y_data)
      
      numerator = 
        Enum.zip(x_data, y_data)
        |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
        |> Enum.sum()
      
      x_variance = Enum.map(x_data, fn x -> :math.pow(x - x_mean, 2) end) |> Enum.sum()
      y_variance = Enum.map(y_data, fn y -> :math.pow(y - y_mean, 2) end) |> Enum.sum()
      
      denominator = :math.sqrt(x_variance * y_variance)
      
      if denominator == 0.0 do
        0.0
      else
        numerator / denominator
      end
    end
  end

  @doc """
  Calculate covariance between two lists of numbers
  """
  def covariance([], []), do: 0.0
  def covariance(x_values, y_values) when is_list(x_values) and is_list(y_values) do
    x_nums = Enum.filter(x_values, &is_number/1)
    y_nums = Enum.filter(y_values, &is_number/1)
    
    min_length = min(length(x_nums), length(y_nums))
    
    if min_length < 2 do
      0.0
    else
      x_data = Enum.take(x_nums, min_length)
      y_data = Enum.take(y_nums, min_length)
      
      x_mean = mean(x_data)
      y_mean = mean(y_data)
      
      covariances = 
        Enum.zip(x_data, y_data)
        |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
      
      mean(covariances)
    end
  end

  @doc """
  Calculate the range (max - min) of a list of numbers
  """
  def range([]), do: 0.0
  def range(values) when is_list(values) do
    numeric_values = Enum.filter(values, &is_number/1)
    case numeric_values do
      [] -> 0.0
      nums -> Enum.max(nums) - Enum.min(nums)
    end
  end
  def range(value) when is_number(value), do: 0.0

  @doc """
  Calculate the interquartile range (Q3 - Q1) of a list of numbers
  """
  def interquartile_range(values) when is_list(values) do
    q3 = percentile(values, 75)
    q1 = percentile(values, 25)
    q3 - q1
  end
  def interquartile_range(value) when is_number(value), do: 0.0

  @doc """
  Calculate various statistical measures in one pass
  Returns a map with multiple statistics
  """
  def summary_stats([]), do: %{count: 0, mean: 0.0, median: 0.0, min: 0.0, max: 0.0, std_dev: 0.0}
  def summary_stats(values) when is_list(values) do
    numeric_values = Enum.filter(values, &is_number/1)
    case numeric_values do
      [] -> summary_stats([])
      nums ->
        %{
          count: length(nums),
          mean: mean(nums),
          median: median(nums),
          min: Enum.min(nums),
          max: Enum.max(nums),
          std_dev: standard_deviation(nums),
          variance: variance(nums),
          range: range(nums),
          q1: percentile(nums, 25),
          q3: percentile(nums, 75),
          iqr: interquartile_range(nums)
        }
    end
  end
end