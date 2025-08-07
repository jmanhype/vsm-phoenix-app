defmodule VsmPhoenix.System5.Persistence.PolicyStore do
  @moduledoc """
  ETS-based persistence store for System5 policies.

  Features:
  - High-performance policy storage and retrieval
  - Versioning support for policy evolution
  - Policy categorization and tagging
  - Atomic updates and rollback capabilities
  - Policy effectiveness metrics tracking
  """

  use GenServer
  require Logger

  @table_name :system5_policy_store
  @version_table :system5_policy_versions
  @metrics_table :system5_policy_metrics

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def store_policy(policy_id, policy_data, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:store_policy, policy_id, policy_data, metadata})
  end

  def get_policy(policy_id) do
    GenServer.call(__MODULE__, {:get_policy, policy_id})
  end

  def get_policy_version(policy_id, version) do
    GenServer.call(__MODULE__, {:get_policy_version, policy_id, version})
  end

  def update_policy(policy_id, updates, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:update_policy, policy_id, updates, metadata})
  end

  def delete_policy(policy_id) do
    GenServer.call(__MODULE__, {:delete_policy, policy_id})
  end

  def list_policies(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_policies, filters})
  end

  def get_policy_history(policy_id) do
    GenServer.call(__MODULE__, {:get_policy_history, policy_id})
  end

  def record_policy_effectiveness(policy_id, metrics) do
    GenServer.cast(__MODULE__, {:record_effectiveness, policy_id, metrics})
  end

  def get_policy_metrics(policy_id) do
    GenServer.call(__MODULE__, {:get_policy_metrics, policy_id})
  end

  def search_policies(query) do
    GenServer.call(__MODULE__, {:search_policies, query})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("PolicyStore: Initializing ETS-based policy persistence")

    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@version_table, [:bag, :public, :named_table])
    :ets.new(@metrics_table, [:set, :public, :named_table])

    state = %{
      policy_count: 0,
      version_count: 0,
      last_cleanup: DateTime.utc_now()
    }

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:store_policy, policy_id, policy_data, metadata}, _from, state) do
    Logger.info("PolicyStore: Storing policy #{policy_id}")

    # Create versioned entry
    version = generate_version()
    timestamp = DateTime.utc_now()

    policy_record = %{
      id: policy_id,
      data: policy_data,
      metadata: metadata,
      version: version,
      created_at: timestamp,
      updated_at: timestamp,
      active: true
    }

    # Store in main table
    :ets.insert(@table_name, {policy_id, policy_record})

    # Store version history
    version_record = %{
      policy_id: policy_id,
      version: version,
      data: policy_data,
      metadata: metadata,
      created_at: timestamp
    }

    :ets.insert(@version_table, {{policy_id, version}, version_record})

    # Initialize metrics
    :ets.insert(
      @metrics_table,
      {policy_id,
       %{
         effectiveness: 1.0,
         usage_count: 0,
         success_count: 0,
         failure_count: 0,
         last_used: nil
       }}
    )

    new_state = %{
      state
      | policy_count: state.policy_count + 1,
        version_count: state.version_count + 1
    }

    {:reply, {:ok, policy_record}, new_state}
  end

  @impl true
  def handle_call({:get_policy, policy_id}, _from, state) do
    case :ets.lookup(@table_name, policy_id) do
      [{^policy_id, policy}] when policy.active ->
        {:reply, {:ok, policy}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_policy_version, policy_id, version}, _from, state) do
    case :ets.lookup(@version_table, {policy_id, version}) do
      [{{^policy_id, ^version}, version_record}] ->
        {:reply, {:ok, version_record}, state}

      _ ->
        {:reply, {:error, :version_not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_policy, policy_id, updates, metadata}, _from, state) do
    case :ets.lookup(@table_name, policy_id) do
      [{^policy_id, current_policy}] ->
        # Create new version
        new_version = generate_version()
        timestamp = DateTime.utc_now()

        # Merge updates
        updated_data = deep_merge(current_policy.data, updates)
        updated_metadata = Map.merge(current_policy.metadata, metadata)

        updated_policy = %{
          current_policy
          | data: updated_data,
            metadata: updated_metadata,
            version: new_version,
            updated_at: timestamp
        }

        # Update main table
        :ets.insert(@table_name, {policy_id, updated_policy})

        # Add to version history
        version_record = %{
          policy_id: policy_id,
          version: new_version,
          data: updated_data,
          metadata: updated_metadata,
          created_at: timestamp,
          previous_version: current_policy.version
        }

        :ets.insert(@version_table, {{policy_id, new_version}, version_record})

        new_state = %{state | version_count: state.version_count + 1}

        {:reply, {:ok, updated_policy}, new_state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:delete_policy, policy_id}, _from, state) do
    case :ets.lookup(@table_name, policy_id) do
      [{^policy_id, policy}] ->
        # Soft delete - mark as inactive
        deleted_policy = %{policy | active: false, deleted_at: DateTime.utc_now()}
        :ets.insert(@table_name, {policy_id, deleted_policy})

        new_state = %{state | policy_count: state.policy_count - 1}
        {:reply, :ok, new_state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:list_policies, filters}, _from, state) do
    policies =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, policy} -> policy end)
      |> Enum.filter(&filter_policy(&1, filters))
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

    {:reply, {:ok, policies}, state}
  end

  @impl true
  def handle_call({:get_policy_history, policy_id}, _from, state) do
    versions =
      :ets.select(@version_table, [
        {{{policy_id, :_}, :_}, [], [:"$_"]}
      ])
      |> Enum.map(fn {{_id, _v}, record} -> record end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:reply, {:ok, versions}, state}
  end

  @impl true
  def handle_call({:get_policy_metrics, policy_id}, _from, state) do
    case :ets.lookup(@metrics_table, policy_id) do
      [{^policy_id, metrics}] ->
        {:reply, {:ok, metrics}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:search_policies, query}, _from, state) do
    results =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, policy} -> policy end)
      |> Enum.filter(&policy_matches_query?(&1, query))
      # Limit results
      |> Enum.take(50)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_cast({:record_effectiveness, policy_id, metrics}, state) do
    case :ets.lookup(@metrics_table, policy_id) do
      [{^policy_id, current_metrics}] ->
        updated_metrics =
          Map.merge(current_metrics, metrics)
          |> Map.put(:last_used, DateTime.utc_now())
          |> Map.update(:usage_count, 1, &(&1 + 1))

        :ets.insert(@metrics_table, {policy_id, updated_metrics})

      _ ->
        Logger.warning("PolicyStore: Metrics update for unknown policy #{policy_id}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Logger.debug("PolicyStore: Running cleanup")

    # Clean up old versions (keep last 10 per policy)
    cleanup_old_versions()

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | last_cleanup: DateTime.utc_now()}}
  end

  # Private Functions

  defp generate_version do
    :erlang.unique_integer([:positive, :monotonic])
  end

  defp deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      deep_merge(v1, v2)
    end)
  end

  defp deep_merge(_v1, v2), do: v2

  defp filter_policy(policy, filters) do
    Enum.all?(filters, fn {key, value} ->
      case key do
        :active -> policy.active == value
        :type -> get_in(policy.data, [:type]) == value
        :after -> DateTime.compare(policy.created_at, value) == :gt
        :before -> DateTime.compare(policy.created_at, value) == :lt
        _ -> true
      end
    end)
  end

  defp policy_matches_query?(policy, query) when is_binary(query) do
    query_lower = String.downcase(query)

    # Search in policy ID
    # Search in policy data (simplified - in production would be more sophisticated)
    String.contains?(String.downcase(to_string(policy.id)), query_lower) ||
      String.contains?(String.downcase(inspect(policy.data)), query_lower)
  end

  defp cleanup_old_versions do
    # Group versions by policy
    all_versions = :ets.tab2list(@version_table)

    versions_by_policy = Enum.group_by(all_versions, fn {{policy_id, _}, _} -> policy_id end)

    Enum.each(versions_by_policy, fn {policy_id, versions} ->
      if length(versions) > 10 do
        # Sort by version (descending) and keep top 10
        sorted_versions =
          Enum.sort_by(versions, fn {{_, version}, _} -> version end, :desc)
          |> Enum.take(10)

        versions_to_keep = MapSet.new(sorted_versions, fn {{_, version}, _} -> version end)

        # Delete old versions
        Enum.each(versions, fn {{_, version}, _} = entry ->
          unless MapSet.member?(versions_to_keep, version) do
            :ets.delete_object(@version_table, entry)
          end
        end)
      end
    end)
  end

  defp schedule_cleanup do
    # Cleanup every hour
    Process.send_after(self(), :cleanup, :timer.hours(1))
  end
end
