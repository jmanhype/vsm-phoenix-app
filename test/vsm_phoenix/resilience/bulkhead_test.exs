defmodule VsmPhoenix.Resilience.BulkheadTest do
  use ExUnit.Case, async: true
  alias VsmPhoenix.Resilience.Bulkhead
  
  setup do
    {:ok, bulkhead} = Bulkhead.start_link(
      name: :"test_bulkhead_#{System.unique_integer()}",
      max_concurrent: 3,
      max_waiting: 2,
      checkout_timeout: 100
    )
    
    {:ok, bulkhead: bulkhead}
  end
  
  describe "resource checkout" do
    test "successful checkout when resources available", %{bulkhead: bulkhead} do
      assert {:ok, {_, 1}} = Bulkhead.checkout(bulkhead)
      assert {:ok, {_, 2}} = Bulkhead.checkout(bulkhead)
      assert {:ok, {_, 3}} = Bulkhead.checkout(bulkhead)
    end
    
    test "returns same resource after checkin", %{bulkhead: bulkhead} do
      {:ok, resource} = Bulkhead.checkout(bulkhead)
      Bulkhead.checkin(bulkhead, resource)
      
      # Should be able to checkout again
      assert {:ok, _} = Bulkhead.checkout(bulkhead)
    end
    
    test "queues requests when all resources busy", %{bulkhead: bulkhead} do
      # Checkout all resources
      {:ok, r1} = Bulkhead.checkout(bulkhead)
      {:ok, r2} = Bulkhead.checkout(bulkhead)
      {:ok, r3} = Bulkhead.checkout(bulkhead)
      
      # Start a task that will wait in queue
      task = Task.async(fn ->
        Bulkhead.checkout(bulkhead, 1000)
      end)
      
      # Give task time to enter queue
      Process.sleep(50)
      
      # Return a resource
      Bulkhead.checkin(bulkhead, r1)
      
      # Task should get the resource
      assert {:ok, _} = Task.await(task)
    end
    
    test "rejects requests when queue is full", %{bulkhead: bulkhead} do
      # Checkout all resources
      for _ <- 1..3 do
        {:ok, _} = Bulkhead.checkout(bulkhead)
      end
      
      # Fill the queue
      for _ <- 1..2 do
        Task.async(fn -> Bulkhead.checkout(bulkhead, 5000) end)
      end
      
      # Give tasks time to enter queue
      Process.sleep(50)
      
      # Next request should be rejected
      assert {:error, :bulkhead_full} = Bulkhead.checkout(bulkhead)
    end
    
    test "timeout while waiting in queue", %{bulkhead: bulkhead} do
      # Checkout all resources
      for _ <- 1..3 do
        {:ok, _} = Bulkhead.checkout(bulkhead)
      end
      
      # Try to checkout with short timeout
      assert {:error, :timeout} = Bulkhead.checkout(bulkhead, 100)
    end
  end
  
  describe "with_resource helper" do
    test "executes function with resource", %{bulkhead: bulkhead} do
      assert {:ok, :result} = Bulkhead.with_resource(bulkhead, fn _resource ->
        :result
      end)
    end
    
    test "automatically returns resource after execution", %{bulkhead: bulkhead} do
      # Use all resources
      for _ <- 1..3 do
        Task.async(fn ->
          Bulkhead.with_resource(bulkhead, fn _ ->
            Process.sleep(100)
            :ok
          end)
        end)
      end
      
      # Give tasks time to checkout
      Process.sleep(50)
      
      # All resources should be busy
      state = Bulkhead.get_state(bulkhead)
      assert state.available == 0
      assert state.busy == 3
      
      # Wait for tasks to complete
      Process.sleep(100)
      
      # Resources should be returned
      state = Bulkhead.get_state(bulkhead)
      assert state.available == 3
      assert state.busy == 0
    end
    
    test "returns resource even if function crashes", %{bulkhead: bulkhead} do
      # This should not leak resources
      try do
        Bulkhead.with_resource(bulkhead, fn _ ->
          raise "boom"
        end)
      rescue
        _ -> :ok
      end
      
      # Resource should be available
      assert {:ok, _} = Bulkhead.checkout(bulkhead)
    end
  end
  
  describe "process monitoring" do
    test "releases resources when process dies", %{bulkhead: bulkhead} do
      # Spawn a process that checks out a resource and dies
      pid = spawn(fn ->
        {:ok, _resource} = Bulkhead.checkout(bulkhead)
        Process.sleep(50)
        # Process dies without checking in
      end)
      
      # Wait for process to die
      Process.sleep(100)
      refute Process.alive?(pid)
      
      # All resources should be available again
      state = Bulkhead.get_state(bulkhead)
      assert state.available == 3
      assert state.busy == 0
    end
  end
  
  describe "metrics" do
    test "tracks checkout metrics", %{bulkhead: bulkhead} do
      # Successful checkout
      {:ok, resource} = Bulkhead.checkout(bulkhead)
      
      metrics = Bulkhead.get_metrics(bulkhead)
      assert metrics.total_checkouts == 1
      assert metrics.successful_checkouts == 1
      assert metrics.current_usage == 1
      assert metrics.peak_usage == 1
      
      # Return resource
      Bulkhead.checkin(bulkhead, resource)
      
      metrics = Bulkhead.get_metrics(bulkhead)
      assert metrics.current_usage == 0
      assert metrics.peak_usage == 1  # Peak remains
    end
    
    test "tracks queue metrics", %{bulkhead: bulkhead} do
      # Fill all resources
      resources = for _ <- 1..3 do
        {:ok, r} = Bulkhead.checkout(bulkhead)
        r
      end
      
      # Create waiting requests
      tasks = for _ <- 1..2 do
        Task.async(fn -> Bulkhead.checkout(bulkhead, 5000) end)
      end
      
      # Give tasks time to queue
      Process.sleep(50)
      
      metrics = Bulkhead.get_metrics(bulkhead)
      assert metrics.queue_size == 2
      assert metrics.peak_queue_size == 2
      
      # Release resources to clear queue
      Enum.each(resources, &Bulkhead.checkin(bulkhead, &1))
      
      # Wait for tasks
      Enum.each(tasks, &Task.await/1)
      
      metrics = Bulkhead.get_metrics(bulkhead)
      assert metrics.queue_size == 0
      assert metrics.peak_queue_size == 2  # Peak remains
    end
    
    test "tracks rejections and timeouts", %{bulkhead: bulkhead} do
      # Fill resources and queue
      for _ <- 1..3 do
        {:ok, _} = Bulkhead.checkout(bulkhead)
      end
      
      for _ <- 1..2 do
        Task.async(fn -> Bulkhead.checkout(bulkhead, 5000) end)
      end
      
      Process.sleep(50)
      
      # Cause rejection
      {:error, :bulkhead_full} = Bulkhead.checkout(bulkhead)
      
      # Cause timeout
      {:error, :timeout} = Bulkhead.checkout(bulkhead, 50)
      
      Process.sleep(100)
      
      metrics = Bulkhead.get_metrics(bulkhead)
      assert metrics.rejected_checkouts == 1
      assert metrics.timeouts == 1
    end
  end
  
  describe "get_state" do
    test "returns current state info", %{bulkhead: bulkhead} do
      state = Bulkhead.get_state(bulkhead)
      assert state.available == 3
      assert state.busy == 0
      assert state.waiting == 0
      assert state.max_concurrent == 3
      assert state.max_waiting == 2
      
      # Checkout a resource
      {:ok, _} = Bulkhead.checkout(bulkhead)
      
      state = Bulkhead.get_state(bulkhead)
      assert state.available == 2
      assert state.busy == 1
    end
  end
end