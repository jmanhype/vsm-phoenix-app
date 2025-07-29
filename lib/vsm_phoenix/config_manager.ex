defmodule VsmPhoenix.ConfigManager do
  @moduledoc """
  Configuration management for VSM system
  
  Manages dynamic configuration and system parameters
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def get_config(system, key) do
    GenServer.call(@name, {:get_config, system, key})
  end
  
  def update_config(system, key, value) do
    GenServer.call(@name, {:update_config, system, key, value})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Config Manager initializing...")
    
    state = %{
      config: load_vsm_config(),
      config_history: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:get_config, system, key}, _from, state) do
    value = get_in(state.config, [system, key])
    {:reply, value, state}
  end
  
  @impl true
  def handle_call({:update_config, system, key, value}, _from, state) do
    old_value = get_in(state.config, [system, key])
    new_config = put_in(state.config, [system, key], value)
    
    change_record = %{
      timestamp: DateTime.utc_now(),
      system: system,
      key: key,
      old_value: old_value,
      new_value: value
    }
    
    new_history = [change_record | state.config_history] |> Enum.take(100)
    new_state = %{state | config: new_config, config_history: new_history}
    
    # Broadcast config change
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:config",
      {:config_update, system, key, value}
    )
    
    {:reply, :ok, new_state}
  end
  
  defp load_vsm_config do
    Application.get_env(:vsm_phoenix, :vsm, %{})
  end
end