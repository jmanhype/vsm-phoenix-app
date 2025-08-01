#!/usr/bin/env elixir

# Test S3 Audit Bypass - Direct S1 inspection without S2 coordination

Mix.install([
  {:phoenix_pubsub, "~> 2.1"},
  {:jason, "~> 1.4"}
])

defmodule S3AuditBypassTest do
  @moduledoc """
  Demonstrates System 3's audit bypass capability to directly inspect S1 agents.
  
  This bypasses System 2 coordination completely, allowing S3 to:
  - Perform emergency diagnostics
  - Audit resource usage
  - Verify S1 state integrity
  - Investigate anomalies
  """
  
  def run do
    IO.puts("\n🔍 VSM System 3 Audit Bypass Test")
    IO.puts("=" <> String.duplicate("=", 50))
    
    # Ensure the application is running
    unless GenServer.whereis(VsmPhoenix.System3.Control) do
      IO.puts("❌ VSM application not running. Start with: mix phx.server")
      System.halt(1)
    end
    
    # Test 1: Direct audit of operations context
    test_direct_audit(:operations_context)
    
    # Test 2: Bulk audit of all S1 contexts
    test_bulk_audit()
    
    # Test 3: Resource audit
    test_resource_audit()
    
    # Test 4: Metrics collection
    test_metrics_audit()
    
    # Test 5: Audit with timeout handling
    test_audit_timeout()
    
    IO.puts("\n✅ All audit bypass tests completed!")
  end
  
  defp test_direct_audit(target) do
    IO.puts("\n📋 Test 1: Direct Audit of #{target}")
    IO.puts("-" <> String.duplicate("-", 40))
    
    case VsmPhoenix.System3.Control.audit(target) do
      {:ok, response} ->
        IO.puts("✓ Audit successful!")
        IO.puts("  Status: #{response["status"]}")
        IO.puts("  Context: #{response["context"]}")
        
        if state = response["state"] do
          IO.puts("  State dump:")
          IO.puts("    - Operational State: #{state["operational_state"]}")
          IO.puts("    - Health: #{state["health"]}")
          IO.puts("    - Active Operations: #{state["active_operations"]}")
          IO.puts("    - Resources: #{inspect(state["resources"])}")
          
          if metrics = state["metrics"] do
            IO.puts("    - Metrics: #{inspect(metrics)}")
          end
        end
        
      {:error, reason} ->
        IO.puts("❌ Audit failed: #{inspect(reason)}")
    end
  end
  
  defp test_bulk_audit do
    IO.puts("\n📋 Test 2: Bulk Audit of All S1 Agents")
    IO.puts("-" <> String.duplicate("-", 40))
    
    targets = [:operations_context]  # Add more S1 contexts as they exist
    
    case VsmPhoenix.System3.AuditChannel.bulk_audit(targets) do
      {:ok, results} ->
        IO.puts("✓ Bulk audit completed!")
        
        Enum.each(results, fn {target, result} ->
          case result do
            {:ok, response} ->
              IO.puts("  #{target}: SUCCESS - #{response["status"]}")
            {:error, reason} ->
              IO.puts("  #{target}: FAILED - #{inspect(reason)}")
          end
        end)
        
      error ->
        IO.puts("❌ Bulk audit failed: #{inspect(error)}")
    end
  end
  
  defp test_resource_audit do
    IO.puts("\n📋 Test 3: Resource Usage Audit")
    IO.puts("-" <> String.duplicate("-", 40))
    
    case VsmPhoenix.System3.Control.audit(:operations_context, operation: "get_resources") do
      {:ok, response} ->
        IO.puts("✓ Resource audit successful!")
        IO.puts("  Resources: #{inspect(response["resources"])}")
        
      {:error, reason} ->
        IO.puts("❌ Resource audit failed: #{inspect(reason)}")
    end
  end
  
  defp test_metrics_audit do
    IO.puts("\n📋 Test 4: Metrics Collection Audit")
    IO.puts("-" <> String.duplicate("-", 40))
    
    case VsmPhoenix.System3.Control.audit(:operations_context, operation: "get_metrics") do
      {:ok, response} ->
        IO.puts("✓ Metrics audit successful!")
        
        if metrics = response["metrics"] do
          Enum.each(metrics, fn {key, value} ->
            IO.puts("  #{key}: #{value}")
          end)
        end
        
      {:error, reason} ->
        IO.puts("❌ Metrics audit failed: #{inspect(reason)}")
    end
  end
  
  defp test_audit_timeout do
    IO.puts("\n📋 Test 5: Audit Timeout Handling")
    IO.puts("-" <> String.duplicate("-", 40))
    
    # Try to audit a non-existent context to trigger timeout
    case VsmPhoenix.System3.Control.audit(:non_existent_context) do
      {:ok, _} ->
        IO.puts("❓ Unexpected success on non-existent context")
        
      {:error, :timeout} ->
        IO.puts("✓ Timeout handled correctly!")
        
      {:error, reason} ->
        IO.puts("✓ Error handled: #{inspect(reason)}")
    end
  end
  
  defp display_security_warning do
    IO.puts("\n⚠️  SECURITY WARNING")
    IO.puts("-" <> String.duplicate("-", 40))
    IO.puts("The audit bypass feature allows System 3 to directly")
    IO.puts("inspect S1 agents without S2 coordination. This should")
    IO.puts("only be used for:")
    IO.puts("")
    IO.puts("  • Emergency diagnostics")
    IO.puts("  • Security audits")
    IO.puts("  • Resource investigations")
    IO.puts("  • Anomaly detection")
    IO.puts("")
    IO.puts("All audit operations are logged and emit telemetry events.")
  end
end

# Display security warning
S3AuditBypassTest.display_security_warning()

# Run the tests
S3AuditBypassTest.run()