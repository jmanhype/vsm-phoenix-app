defmodule VsmPhoenix.VarietyEngineering.Supervisor do
  @moduledoc """
  Supervisor for Variety Engineering components.
  
  Manages filters and amplifiers that implement Ashby's Law of Requisite Variety
  across the VSM hierarchy by balancing information flows between systems.
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🔧 Starting Variety Engineering Supervisor...")
    
    children = [
      # Variety Metrics Collector
      {VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator, []},
      {VsmPhoenix.VarietyEngineering.Metrics.BalanceMonitor, []},
      
      # Upward Filters (Attenuation)
      {VsmPhoenix.VarietyEngineering.Filters.S1ToS2, []},
      {VsmPhoenix.VarietyEngineering.Filters.S2ToS3, []},
      {VsmPhoenix.VarietyEngineering.Filters.S3ToS4, []},
      {VsmPhoenix.VarietyEngineering.Filters.S4ToS5, []},
      
      # Downward Amplifiers
      {VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4, []},
      {VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3, []},
      {VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2, []},
      {VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Get variety metrics for all system levels
  """
  def get_variety_metrics do
    VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.get_all_metrics()
  end
  
  @doc """
  Get variety balance status
  """
  def get_balance_status do
    VsmPhoenix.VarietyEngineering.Metrics.BalanceMonitor.get_balance_status()
  end
  
  @doc """
  Adjust filter threshold for a specific boundary
  """
  def adjust_filter_threshold(boundary, new_threshold) do
    case boundary do
      :s1_to_s2 -> VsmPhoenix.VarietyEngineering.Filters.S1ToS2.set_threshold(new_threshold)
      :s2_to_s3 -> VsmPhoenix.VarietyEngineering.Filters.S2ToS3.set_threshold(new_threshold)
      :s3_to_s4 -> VsmPhoenix.VarietyEngineering.Filters.S3ToS4.set_threshold(new_threshold)
      :s4_to_s5 -> VsmPhoenix.VarietyEngineering.Filters.S4ToS5.set_threshold(new_threshold)
      _ -> {:error, :invalid_boundary}
    end
  end
  
  @doc """
  Adjust amplification factor for a specific boundary
  """
  def adjust_amplification_factor(boundary, new_factor) do
    case boundary do
      :s5_to_s4 -> VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4.set_factor(new_factor)
      :s4_to_s3 -> VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3.set_factor(new_factor)
      :s3_to_s2 -> VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2.set_factor(new_factor)
      :s2_to_s1 -> VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1.set_factor(new_factor)
      _ -> {:error, :invalid_boundary}
    end
  end
end