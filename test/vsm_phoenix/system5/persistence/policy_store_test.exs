defmodule VsmPhoenix.System5.Persistence.PolicyStoreTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.Persistence.PolicyStore
  
  setup do
    # Ensure PolicyStore is started fresh for each test
    case GenServer.whereis(PolicyStore) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    {:ok, _pid} = PolicyStore.start_link()
    :ok
  end
  
  describe "store_policy/3" do
    test "stores a new policy successfully" do
      policy_id = "test_policy_1"
      policy_data = %{
        type: :governance,
        rules: ["rule1", "rule2"],
        constraints: %{budget: 1000}
      }
      metadata = %{source: "test", priority: :high}
      
      assert {:ok, policy} = PolicyStore.store_policy(policy_id, policy_data, metadata)
      assert policy.id == policy_id
      assert policy.data == policy_data
      assert policy.metadata == metadata
      assert policy.active == true
      assert policy.version == 1
    end
    
    test "initializes metrics for new policy" do
      policy_id = "test_policy_metrics"
      policy_data = %{type: :test}
      
      {:ok, _} = PolicyStore.store_policy(policy_id, policy_data)
      
      assert {:ok, metrics} = PolicyStore.get_policy_metrics(policy_id)
      assert metrics.effectiveness == 1.0
      assert metrics.usage_count == 0
      assert metrics.success_count == 0
      assert metrics.failure_count == 0
    end
  end
  
  describe "get_policy/1" do
    test "retrieves an existing policy" do
      policy_id = "test_policy_get"
      policy_data = %{type: :test}
      
      {:ok, stored} = PolicyStore.store_policy(policy_id, policy_data)
      {:ok, retrieved} = PolicyStore.get_policy(policy_id)
      
      assert retrieved.id == stored.id
      assert retrieved.data == stored.data
    end
    
    test "returns error for non-existent policy" do
      assert {:error, :not_found} = PolicyStore.get_policy("non_existent")
    end
  end
  
  describe "update_policy/3" do
    test "updates an existing policy and creates new version" do
      policy_id = "test_policy_update"
      initial_data = %{type: :governance, value: 100}
      
      {:ok, initial} = PolicyStore.store_policy(policy_id, initial_data)
      
      updates = %{value: 200, new_field: "added"}
      metadata = %{updated_by: "test"}
      
      assert {:ok, updated} = PolicyStore.update_policy(policy_id, updates, metadata)
      assert updated.id == policy_id
      assert updated.data.value == 200
      assert updated.data.new_field == "added"
      assert updated.data.type == :governance  # Original field preserved
      assert updated.version > initial.version
    end
    
    test "maintains version history" do
      policy_id = "test_policy_versions"
      
      {:ok, _} = PolicyStore.store_policy(policy_id, %{version: 1})
      {:ok, _} = PolicyStore.update_policy(policy_id, %{version: 2}, %{})
      {:ok, _} = PolicyStore.update_policy(policy_id, %{version: 3}, %{})
      
      {:ok, history} = PolicyStore.get_policy_history(policy_id)
      assert length(history) == 3
      assert [v3, v2, v1] = history
      assert v3.data.version == 3
      assert v2.data.version == 2
      assert v1.data.version == 1
    end
  end
  
  describe "delete_policy/1" do
    test "soft deletes a policy" do
      policy_id = "test_policy_delete"
      
      {:ok, _} = PolicyStore.store_policy(policy_id, %{type: :test})
      assert :ok = PolicyStore.delete_policy(policy_id)
      
      # Policy should not be retrievable after deletion
      assert {:error, :not_found} = PolicyStore.get_policy(policy_id)
    end
  end
  
  describe "list_policies/1" do
    test "lists all active policies" do
      # Store some policies
      {:ok, _} = PolicyStore.store_policy("policy_1", %{type: :governance})
      {:ok, _} = PolicyStore.store_policy("policy_2", %{type: :adaptation})
      {:ok, _} = PolicyStore.store_policy("policy_3", %{type: :governance})
      
      {:ok, policies} = PolicyStore.list_policies(%{})
      assert length(policies) >= 3
    end
    
    test "filters policies by type" do
      {:ok, _} = PolicyStore.store_policy("gov_1", %{type: :governance})
      {:ok, _} = PolicyStore.store_policy("adapt_1", %{type: :adaptation})
      {:ok, _} = PolicyStore.store_policy("gov_2", %{type: :governance})
      
      {:ok, governance_policies} = PolicyStore.list_policies(%{type: :governance})
      assert Enum.all?(governance_policies, fn p -> p.data.type == :governance end)
    end
    
    test "filters out deleted policies" do
      {:ok, _} = PolicyStore.store_policy("active_policy", %{type: :test})
      {:ok, _} = PolicyStore.store_policy("deleted_policy", %{type: :test})
      
      PolicyStore.delete_policy("deleted_policy")
      
      {:ok, policies} = PolicyStore.list_policies(%{active: true})
      refute Enum.any?(policies, fn p -> p.id == "deleted_policy" end)
    end
  end
  
  describe "record_policy_effectiveness/2" do
    test "updates policy metrics" do
      policy_id = "test_policy_effectiveness"
      
      {:ok, _} = PolicyStore.store_policy(policy_id, %{type: :test})
      
      PolicyStore.record_policy_effectiveness(policy_id, %{
        usage_count: 5,
        success_count: 4,
        failure_count: 1
      })
      
      {:ok, metrics} = PolicyStore.get_policy_metrics(policy_id)
      assert metrics.usage_count == 5
      assert metrics.success_count == 4
      assert metrics.failure_count == 1
    end
  end
  
  describe "search_policies/1" do
    test "searches policies by query string" do
      {:ok, _} = PolicyStore.store_policy("search_test_1", %{
        type: :governance,
        description: "Budget allocation policy"
      })
      {:ok, _} = PolicyStore.store_policy("search_test_2", %{
        type: :adaptation,
        description: "Performance optimization"
      })
      
      {:ok, results} = PolicyStore.search_policies("budget")
      assert length(results) >= 1
      assert Enum.any?(results, fn p -> p.id == "search_test_1" end)
    end
  end
  
  describe "version management" do
    test "retrieves specific policy version" do
      policy_id = "versioned_policy"
      
      {:ok, v1} = PolicyStore.store_policy(policy_id, %{content: "version 1"})
      {:ok, v2} = PolicyStore.update_policy(policy_id, %{content: "version 2"}, %{})
      
      {:ok, retrieved_v1} = PolicyStore.get_policy_version(policy_id, v1.version)
      assert retrieved_v1.data.content == "version 1"
      
      {:ok, retrieved_v2} = PolicyStore.get_policy_version(policy_id, v2.version)
      assert retrieved_v2.data.content == "version 2"
    end
  end
end