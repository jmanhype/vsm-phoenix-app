defmodule VsmPhoenix.Repo.Migrations.CreateVsmMetrics do
  use Ecto.Migration

  def up do
    create table(:vsm_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :metric_type, :string, null: false # "performance", "viability", "variety", "health"
      add :metric_name, :string, null: false
      add :vsm_system, :integer, null: false # 1-5 for VSM systems
      add :component, :string # Specific component within the system
      add :value, :float, null: false
      add :unit, :string # "percentage", "count", "milliseconds", etc.
      add :threshold_min, :float
      add :threshold_max, :float
      add :status, :string, default: "normal" # "normal", "warning", "critical"
      
      # Context and metadata
      add :tags, :map, default: %{}
      add :dimensions, :map, default: %{}
      add :metadata, :map, default: %{}
      
      # Time series data
      add :timestamp, :utc_datetime, null: false
      add :aggregation_period, :string # "1m", "5m", "1h", "1d"
      add :sample_count, :integer, default: 1
      
      # Correlation tracking
      add :correlation_id, :uuid
      add :session_id, :string
      add :user_id, references(:users, type: :uuid)
      
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:vsm_metrics, [:metric_type])
    create index(:vsm_metrics, [:metric_name])
    create index(:vsm_metrics, [:vsm_system])
    create index(:vsm_metrics, [:component])
    create index(:vsm_metrics, [:status])
    create index(:vsm_metrics, [:timestamp])
    create index(:vsm_metrics, [:user_id])
    
    # Compound indexes for time series queries
    create index(:vsm_metrics, [:metric_type, :metric_name, :timestamp])
    create index(:vsm_metrics, [:vsm_system, :component, :timestamp])
    create index(:vsm_metrics, [:vsm_system, :metric_type, :timestamp])
    create index(:vsm_metrics, [:status, :timestamp])
  end

  def down do
    drop table(:vsm_metrics)
  end
end