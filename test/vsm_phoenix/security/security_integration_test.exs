defmodule VsmPhoenix.Security.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Security.{
    CryptoUtils,
    BloomFilter,
    MessageValidator,
    AuditLogger
  }

  setup do
    # Start security supervisor
    {:ok, _} = start_supervised(VsmPhoenix.Security.Supervisor)
    :ok
  end

  describe "CryptoUtils" do
    test "generates secure keys" do
      key1 = CryptoUtils.generate_key()
      key2 = CryptoUtils.generate_key()
      
      assert byte_size(key1) == 32
      assert key1 != key2
    end

    test "HMAC sign and verify" do
      key = CryptoUtils.generate_key()
      data = "Important message"
      
      signature = CryptoUtils.hmac_sign(data, key)
      assert CryptoUtils.hmac_verify(data, signature, key)
      
      # Wrong key should fail
      wrong_key = CryptoUtils.generate_key()
      refute CryptoUtils.hmac_verify(data, signature, wrong_key)
      
      # Modified data should fail
      refute CryptoUtils.hmac_verify("Modified message", signature, key)
    end

    test "RSA sign and verify" do
      {:ok, keypair} = CryptoUtils.generate_rsa_keypair()
      data = "Sign this message"
      
      {:ok, signature} = CryptoUtils.rsa_sign(data, keypair.private_key)
      {:ok, true} = CryptoUtils.rsa_verify(data, signature, keypair.public_key)
      
      # Wrong signature should fail
      {:ok, false} = CryptoUtils.rsa_verify(data, "wrong_signature", keypair.public_key)
    end

    test "encryption and decryption" do
      key = CryptoUtils.generate_key()
      plaintext = "Secret data that needs protection"
      
      {:ok, encrypted} = CryptoUtils.encrypt(plaintext, key)
      {:ok, decrypted} = CryptoUtils.decrypt(encrypted, key)
      
      assert decrypted == plaintext
      
      # Wrong key should fail
      wrong_key = CryptoUtils.generate_key()
      {:error, :decryption_failed} = CryptoUtils.decrypt(encrypted, wrong_key)
    end

    test "nonce generation is unique" do
      nonces = for _ <- 1..1000, do: CryptoUtils.generate_nonce()
      unique_nonces = Enum.uniq(nonces)
      
      assert length(nonces) == length(unique_nonces)
    end
  end

  describe "BloomFilter" do
    test "detects duplicate nonces" do
      nonce1 = CryptoUtils.generate_nonce()
      nonce2 = CryptoUtils.generate_nonce()
      
      assert {:ok, :new} = BloomFilter.add(nonce1)
      assert {:ok, :duplicate} = BloomFilter.add(nonce1)
      assert {:ok, :new} = BloomFilter.add(nonce2)
      
      assert BloomFilter.contains?(nonce1)
      assert BloomFilter.contains?(nonce2)
      refute BloomFilter.contains?("never_added")
    end

    test "provides accurate statistics" do
      # Add some elements
      for i <- 1..100 do
        BloomFilter.add("element_#{i}")
      end
      
      stats = BloomFilter.stats()
      
      assert stats.element_count >= 100
      assert stats.fill_ratio > 0 and stats.fill_ratio < 1
      assert stats.estimated_false_positive_rate < 0.01
    end

    test "handles high throughput" do
      # Simulate high-throughput nonce checking
      tasks = for i <- 1..1000 do
        Task.async(fn ->
          nonce = "nonce_#{i}_#{System.unique_integer()}"
          BloomFilter.add(nonce)
        end)
      end
      
      results = Task.await_many(tasks)
      assert length(results) == 1000
    end
  end

  describe "MessageValidator" do
    test "signs and verifies messages" do
      payload = %{action: "transfer", amount: 100, currency: "USD"}
      
      {:ok, signed_message} = MessageValidator.sign_message(payload, "user123")
      
      assert signed_message.payload == payload
      assert signed_message.sender_id == "user123"
      assert signed_message.nonce
      assert signed_message.timestamp
      assert signed_message.signature
      
      {:ok, verified_payload} = MessageValidator.verify_message(signed_message)
      assert verified_payload == payload
    end

    test "prevents replay attacks" do
      payload = %{action: "withdraw", amount: 1000}
      {:ok, signed_message} = MessageValidator.sign_message(payload)
      
      # First verification should succeed
      assert {:ok, _} = MessageValidator.verify_message(signed_message)
      
      # Replay should fail
      assert {:error, :replay_attack} = MessageValidator.verify_message(signed_message)
    end

    test "rejects expired messages" do
      payload = %{data: "test"}
      {:ok, signed_message} = MessageValidator.sign_message(payload)
      
      # Manually set old timestamp
      old_message = %{signed_message | timestamp: System.os_time(:millisecond) - :timer.minutes(2)}
      
      assert {:error, :expired_message} = MessageValidator.verify_message(old_message)
    end

    test "rejects tampered messages" do
      payload = %{secure: "data"}
      {:ok, signed_message} = MessageValidator.sign_message(payload)
      
      # Tamper with payload
      tampered = %{signed_message | payload: %{secure: "modified"}}
      assert {:error, :invalid_signature} = MessageValidator.verify_message(tampered)
      
      # Tamper with nonce
      tampered = %{signed_message | nonce: CryptoUtils.generate_nonce()}
      assert {:error, :invalid_signature} = MessageValidator.verify_message(tampered)
    end

    test "provides statistics" do
      # Generate some activity
      for _ <- 1..10 do
        {:ok, msg} = MessageValidator.sign_message(%{test: true})
        MessageValidator.verify_message(msg)
      end
      
      # Try replay attack
      {:ok, msg} = MessageValidator.sign_message(%{duplicate: true})
      MessageValidator.verify_message(msg)
      MessageValidator.verify_message(msg)  # This should fail
      
      stats = MessageValidator.stats()
      
      assert stats.messages_signed >= 11
      assert stats.messages_verified >= 11
      assert stats.replay_attacks_prevented >= 1
    end
  end

  describe "AuditLogger" do
    test "logs security events" do
      # Log various events
      AuditLogger.log_auth(true, "user123", %{ip_address: "192.168.1.1"})
      AuditLogger.log_auth(false, "user456", %{ip_address: "10.0.0.1"})
      
      AuditLogger.log_message_validation(true, nil, %{})
      AuditLogger.log_message_validation(false, :replay_attack, %{})
      
      # Allow time for buffer flush
      Process.sleep(100)
      
      # Query logs
      {:ok, logs} = AuditLogger.query_logs(%{})
      
      assert length(logs) >= 4
      assert Enum.any?(logs, & &1.type == :auth_success)
      assert Enum.any?(logs, & &1.type == :auth_failure)
      assert Enum.any?(logs, & &1.type == :replay_attack)
    end

    test "detects anomalies" do
      # Simulate multiple auth failures
      for i <- 1..10 do
        AuditLogger.log_auth(false, "attacker#{i}", %{
          ip_address: "192.168.1.#{i}",
          metadata: %{attempt: i}
        })
      end
      
      # Check stats for anomaly detection
      stats = AuditLogger.stats()
      
      assert stats.total_events >= 10
      assert stats.events_by_type[:auth_failure] >= 10
    end

    test "generates compliance reports" do
      # Generate various events
      for i <- 1..5 do
        AuditLogger.log_auth(true, "user#{i}", %{
          ip_address: "192.168.1.#{i}",
          correlation_id: "session_#{i}"
        })
      end
      
      AuditLogger.log_event(:configuration_change, :warning, %{
        actor: "admin",
        resource: "security_settings",
        action: "update"
      })
      
      # Allow buffer flush
      Process.sleep(100)
      
      {:ok, report} = AuditLogger.generate_compliance_report(period: :last_24_hours)
      
      assert report.total_events >= 6
      assert report.unique_actors >= 6
      assert report.compliance_status.authentication_tracking.has_actor_info
    end

    test "queries with filters" do
      # Log events with different severities
      AuditLogger.log_event(:system_access, :info, %{actor: "user1"})
      AuditLogger.log_event(:suspicious_activity, :warning, %{actor: "user2"})
      AuditLogger.log_event(:intrusion_detected, :critical, %{actor: "attacker"})
      
      Process.sleep(100)
      
      # Query critical events only
      {:ok, critical_logs} = AuditLogger.query_logs(%{severity: :critical})
      
      assert Enum.all?(critical_logs, & &1.severity == :critical)
    end
  end

  describe "End-to-end security flow" do
    test "complete message security lifecycle" do
      # 1. Create and sign a message
      sensitive_payload = %{
        action: "transfer_funds",
        amount: 50000,
        from_account: "ACC001",
        to_account: "ACC002",
        timestamp: DateTime.utc_now()
      }
      
      {:ok, signed_message} = MessageValidator.sign_message(sensitive_payload, "financial_system")
      
      # 2. Log the message creation
      AuditLogger.log_event(:message_created, :info, %{
        actor: "financial_system",
        correlation_id: signed_message.nonce,
        metadata: %{action: sensitive_payload.action}
      })
      
      # 3. Verify the message (simulating reception)
      {:ok, verified_payload} = MessageValidator.verify_message(signed_message)
      assert verified_payload == sensitive_payload
      
      # 4. Log successful validation
      AuditLogger.log_message_validation(true, nil, %{
        correlation_id: signed_message.nonce
      })
      
      # 5. Attempt replay attack
      {:error, :replay_attack} = MessageValidator.verify_message(signed_message)
      
      # 6. Log replay attack
      AuditLogger.log_message_validation(false, :replay_attack, %{
        correlation_id: signed_message.nonce,
        actor: "potential_attacker"
      })
      
      # 7. Check audit trail
      Process.sleep(100)
      {:ok, logs} = AuditLogger.query_logs(%{})
      
      related_logs = Enum.filter(logs, & &1.correlation_id == signed_message.nonce)
      assert length(related_logs) >= 3
      
      # 8. Verify statistics
      msg_stats = MessageValidator.stats()
      assert msg_stats.replay_attacks_prevented >= 1
      
      audit_stats = AuditLogger.stats()
      assert audit_stats.events_by_type[:replay_attack] >= 1
    end
  end
end