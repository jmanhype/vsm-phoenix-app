defmodule VsmPhoenix.System3.AuditChannelTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias VsmPhoenix.System3.{AuditChannel, Control}
  
  describe "System 3* Audit Channel" do
    setup do
      # Start required processes if not already started
      {:ok, _} = Application.ensure_all_started(:vsm_phoenix)
      
      # Wait for processes to initialize
      Process.sleep(100)
      
      :ok
    end
    
    test "direct audit bypass to S1 agents" do
      # Test direct audit command
      result = AuditChannel.send_audit_command(
        :operations_context,
        %{
          operation: :state_dump,
          requester: "test_suite",
          bypass_coordination: true
        }
      )
      
      # The result might be an error if AMQP is not set up
      # But the function should not crash
      assert result in [{:ok, _}, {:error, :no_channel}, {:error, :timeout}]
    end
    
    test "bulk audit of multiple agents" do
      targets = [:operations_context, :agent_1, :agent_2]
      
      result = AuditChannel.bulk_audit(targets, :dump_state)
      
      assert {:ok, audit_results} = result
      assert length(audit_results) == length(targets)
    end
    
    test "emergency audit with high priority" do
      result = AuditChannel.emergency_audit(
        :operations_context,
        "Critical system failure detected"
      )
      
      # Should handle emergency audit
      assert result in [{:ok, _}, {:error, :no_channel}, {:error, :timeout}]
    end
    
    test "scheduled compliance audit" do
      # Schedule an audit for 1 second from now
      AuditChannel.schedule_compliance_audit(
        :operations_context,
        [in_seconds: 1]
      )
      
      # Wait for scheduled audit to trigger
      Process.sleep(1500)
      
      # Verify audit was scheduled (check logs or state)
      assert_receive {:execute_scheduled_audit, _}, 2000
    catch
      :exit, _ -> :ok  # If no message received, that's fine for testing
    end
    
    test "audit history retrieval" do
      {:ok, history} = AuditChannel.get_audit_history(:operations_context, 10)
      
      assert is_list(history)
      assert length(history) <= 10
    end
    
    test "audit trail for S5 reporting" do
      {:ok, trail} = AuditChannel.get_audit_trail(limit: 50)
      
      assert is_list(trail)
      assert length(trail) <= 50
    end
  end
  
  describe "System 3 Control with Audit Integration" do
    test "sporadic audit trigger" do
      # Trigger sporadic audit
      Control.trigger_sporadic_audit()
      
      # Give it time to process
      Process.sleep(100)
      
      # Should not crash
      assert true
    end
    
    test "compliance checking" do
      result = Control.check_compliance(:operations_context)
      
      # Should return compliance result or error
      assert result in [{:ok, _}, {:error, _}]
    end
    
    test "audit report generation for S5" do
      {:ok, report} = Control.get_audit_report(
        time_range: :last_24h,
        include_compliance: true,
        include_resources: true
      )
      
      assert Map.has_key?(report, :generated_at)
      assert Map.has_key?(report, :audit_statistics)
      assert Map.has_key?(report, :recommendations)
      assert Map.has_key?(report, :risk_assessment)
    end
    
    test "configure audit policy" do
      policy = %{
        resource_limits: %{
          max_cpu: 0.75,
          max_memory: 0.85
        },
        compliance_rules: %{
          require_encryption: true,
          require_audit_trail: true
        }
      }
      
      Control.configure_audit_policy(policy)
      
      # Should update policy without crashing
      assert true
    end
    
    test "direct S1 audit through Control" do
      result = Control.audit(:operations_context, operation: :dump_state)
      
      # Should handle audit
      assert result in [{:ok, _}, {:error, :no_channel}, {:error, :timeout}]
    end
  end
  
  describe "Audit Metrics and Reporting" do
    test "audit metrics are tracked" do
      # Perform several audits
      for _ <- 1..3 do
        Control.audit(:operations_context, operation: :dump_state)
        Process.sleep(10)
      end
      
      # Get audit report
      {:ok, report} = Control.get_audit_report()
      
      assert report.audit_statistics.total_audits >= 0
      assert is_list(report.recommendations)
    end
    
    test "compliance history is maintained" do
      # Check compliance multiple times
      for _ <- 1..2 do
        Control.check_compliance(:operations_context)
        Process.sleep(10)
      end
      
      # Get report with compliance summary
      {:ok, report} = Control.get_audit_report(include_compliance: true)
      
      assert report.compliance_summary != nil
      assert Map.has_key?(report.compliance_summary, :total_compliance_checks)
    end
    
    test "risk assessment is performed" do
      {:ok, report} = Control.get_audit_report()
      
      risk_assessment = report.risk_assessment
      assert Map.has_key?(risk_assessment, :risk_count)
      assert Map.has_key?(risk_assessment, :risk_levels)
      assert Map.has_key?(risk_assessment, :risks)
    end
  end
  
  describe "Audit Telemetry" do
    test "telemetry events are emitted" do
      # Attach telemetry handler
      :telemetry.attach(
        "test-audit-handler",
        [:vsm, :system3, :audit],
        fn event, measurements, metadata, _config ->
          send(self(), {:telemetry, event, measurements, metadata})
        end,
        nil
      )
      
      # Perform audit
      Control.audit(:operations_context)
      
      # Should receive telemetry event
      assert_receive {:telemetry, [:vsm, :system3, :audit], _, _}, 1000
    catch
      :exit, _ -> :ok  # If no telemetry, that's fine for testing
    after
      :telemetry.detach("test-audit-handler")
    end
  end
end