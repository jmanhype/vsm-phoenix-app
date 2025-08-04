defmodule VsmPhoenix.ML.ModelStorage do
  @moduledoc """
  Model Storage and Management System for ML models.
  Handles persistence, loading, versioning, and metadata management.
  """

  use GenServer
  require Logger

  defstruct [
    storage_path: nil,
    models: %{},
    metadata: %{},
    compression_enabled: true
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    storage_path = Keyword.get(opts, :storage_path, "priv/ml_models/")
    File.mkdir_p!(storage_path)

    state = %__MODULE__{
      storage_path: storage_path,
      compression_enabled: Keyword.get(opts, :compression, true)
    }

    # Load existing models
    {:ok, load_existing_models(state)}
  end

  @impl true
  def handle_call({:save_model, model_name, model_data, metadata}, _from, state) do
    try do
      file_path = Path.join(state.storage_path, "#{model_name}.model")
      metadata_path = Path.join(state.storage_path, "#{model_name}.meta")
      
      # Serialize and save model
      serialized_model = :erlang.term_to_binary(model_data)
      compressed_model = if state.compression_enabled do
        :zlib.compress(serialized_model)
      else
        serialized_model
      end
      
      File.write!(file_path, compressed_model)
      
      # Save metadata
      full_metadata = Map.merge(metadata, %{
        created_at: DateTime.utc_now(),
        compressed: state.compression_enabled,
        size_bytes: byte_size(compressed_model),
        version: generate_version()
      })
      
      File.write!(metadata_path, :erlang.term_to_binary(full_metadata))
      
      # Update state
      new_models = Map.put(state.models, model_name, file_path)
      new_metadata = Map.put(state.metadata, model_name, full_metadata)
      
      new_state = %{state | models: new_models, metadata: new_metadata}
      
      Logger.info("Model '#{model_name}' saved successfully")
      {:reply, {:ok, full_metadata}, new_state}
    rescue
      error ->
        Logger.error("Failed to save model '#{model_name}': #{inspect(error)}")
        {:reply, {:error, Exception.message(error)}, state}
    end
  end

  @impl true
  def handle_call({:load_model, model_name}, _from, state) do
    case Map.get(state.models, model_name) do
      nil ->
        {:reply, {:error, "Model '#{model_name}' not found"}, state}
      
      file_path ->
        try do
          # Load model data
          compressed_data = File.read!(file_path)
          
          model_data = if state.compression_enabled do
            :zlib.uncompress(compressed_data) |> :erlang.binary_to_term()
          else
            :erlang.binary_to_term(compressed_data)
          end
          
          metadata = Map.get(state.metadata, model_name, %{})
          
          result = %{
            model: model_data,
            metadata: metadata,
            loaded_at: DateTime.utc_now()
          }
          
          Logger.info("Model '#{model_name}' loaded successfully")
          {:reply, {:ok, result}, state}
        rescue
          error ->
            Logger.error("Failed to load model '#{model_name}': #{inspect(error)}")
            {:reply, {:error, Exception.message(error)}, state}
        end
    end
  end

  @impl true
  def handle_call(:list_models, _from, state) do
    models_info = 
      state.metadata
      |> Enum.map(fn {name, metadata} ->
        %{
          name: name,
          created_at: metadata[:created_at],
          version: metadata[:version],
          size_bytes: metadata[:size_bytes],
          compressed: metadata[:compressed]
        }
      end)
    
    {:reply, {:ok, models_info}, state}
  end

  @impl true
  def handle_call({:delete_model, model_name}, _from, state) do
    case Map.get(state.models, model_name) do
      nil ->
        {:reply, {:error, "Model '#{model_name}' not found"}, state}
      
      file_path ->
        try do
          # Delete model file
          File.rm!(file_path)
          
          # Delete metadata file
          metadata_path = Path.join(state.storage_path, "#{model_name}.meta")
          if File.exists?(metadata_path), do: File.rm!(metadata_path)
          
          # Update state
          new_models = Map.delete(state.models, model_name)
          new_metadata = Map.delete(state.metadata, model_name)
          
          new_state = %{state | models: new_models, metadata: new_metadata}
          
          Logger.info("Model '#{model_name}' deleted successfully")
          {:reply, {:ok, "Model deleted"}, new_state}
        rescue
          error ->
            Logger.error("Failed to delete model '#{model_name}': #{inspect(error)}")
            {:reply, {:error, Exception.message(error)}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_model_metadata, model_name}, _from, state) do
    case Map.get(state.metadata, model_name) do
      nil -> {:reply, {:error, "Model '#{model_name}' not found"}, state}
      metadata -> {:reply, {:ok, metadata}, state}
    end
  end

  # Public API
  def save_model(model_name, model_data, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:save_model, model_name, model_data, metadata})
  end

  def load_model(model_name) do
    GenServer.call(__MODULE__, {:load_model, model_name})
  end

  def list_models do
    GenServer.call(__MODULE__, :list_models)
  end

  def delete_model(model_name) do
    GenServer.call(__MODULE__, {:delete_model, model_name})
  end

  def get_model_metadata(model_name) do
    GenServer.call(__MODULE__, {:get_model_metadata, model_name})
  end

  # Private functions
  
  defp load_existing_models(state) do
    model_files = 
      state.storage_path
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".model"))
    
    {models, metadata} = 
      Enum.reduce(model_files, {%{}, %{}}, fn file, {models_acc, meta_acc} ->
        model_name = Path.basename(file, ".model")
        file_path = Path.join(state.storage_path, file)
        metadata_path = Path.join(state.storage_path, "#{model_name}.meta")
        
        metadata = if File.exists?(metadata_path) do
          File.read!(metadata_path) |> :erlang.binary_to_term()
        else
          %{created_at: File.stat!(file_path).mtime, version: "unknown"}
        end
        
        {
          Map.put(models_acc, model_name, file_path),
          Map.put(meta_acc, model_name, metadata)
        }
      end)
    
    Logger.info("Loaded #{map_size(models)} existing models")
    %{state | models: models, metadata: metadata}
  end

  defp generate_version do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "v#{timestamp}"
  end
end