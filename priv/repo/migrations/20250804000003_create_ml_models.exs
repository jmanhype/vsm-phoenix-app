defmodule VsmPhoenix.Repo.Migrations.CreateMlModels do
  use Ecto.Migration

  def up do
    create table(:ml_models, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :type, :string, null: false # "neural_network", "decision_tree", "clustering", etc.
      add :version, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "training" # training, active, archived, failed
      
      # Model configuration
      add :config, :map, null: false
      add :hyperparameters, :map, default: %{}
      add :architecture, :map
      
      # Training data
      add :training_data_path, :string
      add :validation_data_path, :string
      add :test_data_path, :string
      
      # Model performance metrics
      add :accuracy, :float
      add :precision, :float
      add :recall, :float
      add :f1_score, :float
      add :loss, :float
      add :validation_loss, :float
      add :training_metrics, :map, default: %{}
      
      # Model artifacts
      add :model_path, :string
      add :weights_path, :string
      add :checkpoint_path, :string
      add :model_size_bytes, :bigint
      
      # Training information
      add :training_started_at, :utc_datetime
      add :training_completed_at, :utc_datetime
      add :training_duration_seconds, :integer
      add :epochs_completed, :integer
      add :total_epochs, :integer
      
      # Deployment information
      add :deployed_at, :utc_datetime
      add :deployment_url, :string
      add :deployment_config, :map
      
      # VSM integration
      add :vsm_system, :integer # Which VSM system uses this model
      add :purpose, :string # "optimization", "prediction", "classification", etc.
      add :input_features, {:array, :string}
      add :output_labels, {:array, :string}
      
      # Ownership and access
      add :created_by_id, references(:users, type: :uuid)
      add :updated_by_id, references(:users, type: :uuid)
      add :team_id, :uuid
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:ml_models, [:name, :version])
    create index(:ml_models, [:type])
    create index(:ml_models, [:status])
    create index(:ml_models, [:vsm_system])
    create index(:ml_models, [:purpose])
    create index(:ml_models, [:created_by_id])
    create index(:ml_models, [:training_started_at])
    create index(:ml_models, [:deployed_at])
  end

  def down do
    drop table(:ml_models)
  end
end