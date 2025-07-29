defmodule VsmPhoenix.TidewaveIntegration do
  @moduledoc """
  Integration with Tidewave market intelligence system
  
  Provides market data and intelligence to System 4
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System4.Intelligence
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def fetch_market_data(query) do
    GenServer.call(@name, {:fetch_market_data, query})
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Tidewave Integration initializing...")
    
    tidewave_enabled = Application.get_env(:vsm_phoenix, :vsm)[:intelligence][:tidewave_enabled]
    
    state = %{
      enabled: tidewave_enabled,
      connection_status: :disconnected,
      last_sync: nil
    }
    
    if tidewave_enabled do
      # Schedule periodic sync
      :timer.send_interval(300_000, self(), :sync_data)  # Every 5 minutes
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:fetch_market_data, query}, _from, state) do
    if state.enabled do
      result = fetch_from_tidewave(query)
      {:reply, result, state}
    else
      {:reply, {:error, :tidewave_disabled}, state}
    end
  end
  
  @impl true
  def handle_info(:sync_data, state) do
    if state.enabled do
      insights = fetch_market_insights()
      Intelligence.integrate_tidewave_insights(insights)
      
      new_state = %{state | last_sync: DateTime.utc_now()}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  defp fetch_from_tidewave(_query) do
    # Mock implementation - would integrate with actual Tidewave
    {:ok, %{
      market_trends: ["AI adoption", "sustainability focus"],
      sentiment: 0.7,
      volatility: 0.3
    }}
  end
  
  defp fetch_market_insights do
    # Mock market insights
    %{
      market: %{
        direction: :growth,
        volatility: :moderate,
        key_drivers: ["digital_transformation", "sustainability"]
      },
      timestamp: DateTime.utc_now()
    }
  end
end