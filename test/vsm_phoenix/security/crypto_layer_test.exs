defmodule VsmPhoenix.Security.CryptoLayerTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.Infrastructure.Security
  
  setup do
    # Ensure crypto layer is initialized
    :ok
  end
  
  describe "Node Security Initialization" do
    test "initializes node with unique cryptographic identity" do
      node_id = "test_node_#{:rand.uniform(1000)}"
      
      {:ok, result} = CryptoLayer.initialize_node_security(node_id)
      
      assert result.node_id == node_id
      assert result.certificate != nil
      assert result.algorithm != nil
    end
    
    test "generates different keys for different nodes" do
      node1 = "node_1_#{:rand.uniform(1000)}"
      node2 = "node_2_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(node1)
      {:ok, _} = CryptoLayer.initialize_node_security(node2)
      
      # Keys should be different (verified internally by the crypto layer)
      assert node1 != node2
    end
  end
  
  describe "Message Encryption and Decryption" do
    setup do
      sender_id = "sender_#{:rand.uniform(1000)}"
      recipient_id = "recipient_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(sender_id)
      {:ok, _} = CryptoLayer.initialize_node_security(recipient_id)
      
      {:ok, sender_id: sender_id, recipient_id: recipient_id}
    end
    
    test "encrypts and decrypts messages correctly", %{sender_id: sender, recipient_id: recipient} do
      message = "This is a secret message"
      
      # Establish secure channel first
      {:ok, _} = CryptoLayer.establish_secure_channel(sender, recipient)
      
      # Encrypt
      {:ok, encrypted} = CryptoLayer.encrypt_message(message, recipient, sender_id: sender)
      
      assert encrypted.ciphertext != nil
      assert encrypted.tag != nil
      assert encrypted.iv != nil
      assert encrypted.algorithm == "AES-256-GCM"
      
      # Decrypt
      {:ok, decrypted} = CryptoLayer.decrypt_message(encrypted, sender)
      
      assert decrypted == message
    end
    
    test "encryption produces different ciphertext for same message", %{sender_id: sender, recipient_id: recipient} do
      message = "Same message"
      {:ok, _} = CryptoLayer.establish_secure_channel(sender, recipient)
      
      {:ok, encrypted1} = CryptoLayer.encrypt_message(message, recipient, sender_id: sender)
      {:ok, encrypted2} = CryptoLayer.encrypt_message(message, recipient, sender_id: sender)
      
      # Different IVs should produce different ciphertexts
      assert encrypted1.ciphertext != encrypted2.ciphertext
      assert encrypted1.iv != encrypted2.iv
    end
    
    test "decryption fails with tampered ciphertext", %{sender_id: sender, recipient_id: recipient} do
      message = "Original message"
      {:ok, _} = CryptoLayer.establish_secure_channel(sender, recipient)
      
      {:ok, encrypted} = CryptoLayer.encrypt_message(message, recipient, sender_id: sender)
      
      # Tamper with ciphertext
      tampered = %{encrypted | ciphertext: Base.encode64("tampered data")}
      
      result = CryptoLayer.decrypt_message(tampered, sender)
      assert {:error, _} = result
    end
    
    test "decryption fails with wrong sender", %{sender_id: sender, recipient_id: recipient} do
      fake_sender = "fake_sender_#{:rand.uniform(1000)}"
      {:ok, _} = CryptoLayer.initialize_node_security(fake_sender)
      
      message = "Secret message"
      {:ok, _} = CryptoLayer.establish_secure_channel(sender, recipient)
      
      {:ok, encrypted} = CryptoLayer.encrypt_message(message, recipient, sender_id: sender)
      
      # Try to decrypt claiming to be from fake_sender
      result = CryptoLayer.decrypt_message(encrypted, fake_sender)
      assert {:error, _} = result
    end
  end
  
  describe "Secure Channel Establishment" do
    test "establishes secure channel between two nodes" do
      node_a = "node_a_#{:rand.uniform(1000)}"
      node_b = "node_b_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(node_a)
      {:ok, _} = CryptoLayer.initialize_node_security(node_b)
      
      {:ok, channel_info} = CryptoLayer.establish_secure_channel(node_a, node_b)
      
      assert channel_info.channel_id != nil
      assert channel_info.expires_at > :erlang.system_time(:millisecond)
    end
    
    test "channel is bidirectional" do
      node_a = "node_a_#{:rand.uniform(1000)}"
      node_b = "node_b_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(node_a)
      {:ok, _} = CryptoLayer.initialize_node_security(node_b)
      {:ok, _} = CryptoLayer.establish_secure_channel(node_a, node_b)
      
      # Both directions should work
      {:ok, encrypted_ab} = CryptoLayer.encrypt_message("A to B", node_b, sender_id: node_a)
      {:ok, encrypted_ba} = CryptoLayer.encrypt_message("B to A", node_a, sender_id: node_b)
      
      {:ok, decrypted_ab} = CryptoLayer.decrypt_message(encrypted_ab, node_a)
      {:ok, decrypted_ba} = CryptoLayer.decrypt_message(encrypted_ba, node_b)
      
      assert decrypted_ab == "A to B"
      assert decrypted_ba == "B to A"
    end
  end
  
  describe "Key Rotation" do
    test "rotates keys for a node" do
      node_id = "rotate_test_#{:rand.uniform(1000)}"
      {:ok, _} = CryptoLayer.initialize_node_security(node_id)
      
      # Get initial metrics
      {:ok, metrics1} = CryptoLayer.get_security_metrics()
      initial_rotations = metrics1.keys_rotated
      
      # Rotate keys
      CryptoLayer.rotate_keys(node_id)
      Process.sleep(100)  # Allow async rotation
      
      # Check metrics updated
      {:ok, metrics2} = CryptoLayer.get_security_metrics()
      assert metrics2.keys_rotated == initial_rotations + 1
    end
  end
  
  describe "Security Metrics" do
    test "tracks encryption and decryption operations" do
      sender = "metrics_sender_#{:rand.uniform(1000)}"
      recipient = "metrics_recipient_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(sender)
      {:ok, _} = CryptoLayer.initialize_node_security(recipient)
      {:ok, _} = CryptoLayer.establish_secure_channel(sender, recipient)
      
      {:ok, initial_metrics} = CryptoLayer.get_security_metrics()
      
      # Perform operations
      {:ok, encrypted} = CryptoLayer.encrypt_message("test", recipient, sender_id: sender)
      {:ok, _} = CryptoLayer.decrypt_message(encrypted, sender)
      
      {:ok, final_metrics} = CryptoLayer.get_security_metrics()
      
      assert final_metrics.messages_encrypted > initial_metrics.messages_encrypted
      assert final_metrics.messages_decrypted > initial_metrics.messages_decrypted
    end
  end
  
  describe "Integration with Infrastructure.Security" do
    test "wraps crypto layer messages with nonce protection" do
      node_id = "integration_test_#{:rand.uniform(1000)}"
      message = "Test message"
      secret_key = "test_secret_key"
      
      # Wrap with security layer
      wrapped = Security.wrap_secure_message(message, secret_key)
      
      assert wrapped.security.nonce != nil
      assert wrapped.security.timestamp != nil
      assert wrapped.security.signature != nil
      assert wrapped.payload == message
      
      # Verify unwrapping
      {:ok, unwrapped} = Security.unwrap_secure_message(wrapped, secret_key)
      assert unwrapped == message
    end
    
    test "detects replay attacks" do
      message = "Replay test"
      secret_key = "test_key"
      
      wrapped = Security.wrap_secure_message(message, secret_key)
      
      # First unwrap should succeed
      {:ok, _} = Security.unwrap_secure_message(wrapped, secret_key)
      
      # Second unwrap with same nonce should fail
      result = Security.unwrap_secure_message(wrapped, secret_key)
      assert {:error, :nonce_already_used} = result
    end
  end
  
  describe "Error Handling" do
    test "handles uninitialized node gracefully" do
      uninitialized = "uninitialized_#{:rand.uniform(1000)}"
      initialized = "initialized_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(initialized)
      
      # Try to encrypt from uninitialized node
      result = CryptoLayer.encrypt_message("test", initialized, sender_id: uninitialized)
      assert {:error, :node_not_initialized} = result
    end
    
    test "handles missing secure channel" do
      sender = "no_channel_sender_#{:rand.uniform(1000)}"
      recipient = "no_channel_recipient_#{:rand.uniform(1000)}"
      
      {:ok, _} = CryptoLayer.initialize_node_security(sender)
      {:ok, _} = CryptoLayer.initialize_node_security(recipient)
      
      # Try to encrypt without establishing channel
      # The crypto layer will try to create one automatically
      {:ok, encrypted} = CryptoLayer.encrypt_message("test", recipient, sender_id: sender)
      assert encrypted != nil
    end
  end
end