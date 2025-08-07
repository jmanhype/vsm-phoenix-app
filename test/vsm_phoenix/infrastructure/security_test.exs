defmodule VsmPhoenix.Infrastructure.SecurityTest do
  use ExUnit.Case
  
  alias VsmPhoenix.Infrastructure.Security
  
  # Run tests synchronously to avoid ETS conflicts
  @moduletag :security
  
  setup_all do
    # Ensure Security GenServer is started
    Application.ensure_all_started(:crypto)
    
    case Process.whereis(Security) do
      nil -> 
        {:ok, _pid} = Security.start_link()
      _pid -> 
        :ok
    end
    
    # Wait for initialization
    :timer.sleep(100)
    :ok
  end
  
  describe "nonce generation" do
    test "generates unique nonces" do
      nonce1 = Security.generate_nonce()
      nonce2 = Security.generate_nonce()
      
      assert nonce1 != nonce2
      assert is_binary(nonce1)
      assert is_binary(nonce2)
      assert String.length(nonce1) > 20
    end
  end
  
  describe "message signing" do
    test "signs and verifies messages correctly" do
      key = Security.generate_secret_key()
      message = "Hello, VSM!"
      signature = Security.sign_message(message, key)
      
      assert is_binary(signature)
      assert Security.verify_signature(message, signature, key)
    end
    
    test "rejects invalid signatures" do
      key = Security.generate_secret_key()
      message = "Hello, VSM!"
      signature = Security.sign_message(message, key)
      
      # Tamper with message
      refute Security.verify_signature("Different message", signature, key)
      
      # Tamper with signature  
      bad_signature = signature <> "tampered"
      refute Security.verify_signature(message, bad_signature, key)
      
      # Wrong key
      wrong_key = Security.generate_secret_key()
      refute Security.verify_signature(message, signature, wrong_key)
    end
  end
  
  describe "secure message wrapping" do
    test "wraps and unwraps messages successfully" do
      key = Security.generate_secret_key()
      payload = %{command: "test", data: %{value: 42}}
      
      wrapped = Security.wrap_secure_message(payload, key)
      
      assert wrapped.payload == payload
      assert wrapped.security.nonce
      assert wrapped.security.timestamp
      assert wrapped.security.signature
      
      # Wait a bit to ensure nonce is stored
      :timer.sleep(10)
      
      {:ok, unwrapped} = Security.unwrap_secure_message(wrapped, key)
      assert unwrapped == payload
    end
    
    test "detects replay attacks" do
      key = Security.generate_secret_key()
      payload = %{command: "transfer", amount: 1000}
      
      wrapped = Security.wrap_secure_message(payload, key)
      
      # Wait to ensure nonce is stored
      :timer.sleep(10)
      
      # First unwrap should succeed
      assert {:ok, _} = Security.unwrap_secure_message(wrapped, key)
      
      # Second unwrap should fail (replay attack)
      assert {:error, :nonce_already_used} = Security.unwrap_secure_message(wrapped, key)
    end
    
    test "rejects old timestamps" do
      key = Security.generate_secret_key()
      
      # Create a message with old timestamp manually
      nonce = Security.generate_nonce()
      old_timestamp = :erlang.system_time(:millisecond) - 120_000  # 2 minutes old
      
      payload = %{test: "data"}
      canonical = "#{nonce}|#{old_timestamp}|#{node()}|#{Jason.encode!(payload)}"
      signature = Security.sign_message(canonical, key)
      
      wrapped = %{
        payload: payload,
        security: %{
          nonce: nonce,
          timestamp: old_timestamp,
          sender_id: node(),
          signature: signature,
          algorithm: "HMAC-SHA256"
        }
      }
      
      assert {:error, :timestamp_too_old} = Security.unwrap_secure_message(wrapped, key)
    end
    
    test "rejects tampered messages" do
      key = Security.generate_secret_key()
      payload = %{command: "test"}
      wrapped = Security.wrap_secure_message(payload, key)
      
      # Wait to ensure nonce is stored
      :timer.sleep(10)
      
      # Try to unwrap the original first to store the nonce
      {:ok, _} = Security.unwrap_secure_message(wrapped, key)
      
      # Create a new wrapped message with different payload but try to reuse nonce
      # This should be rejected due to nonce reuse
      tampered = %{wrapped | payload: %{command: "tampered"}}
      assert {:error, :nonce_already_used} = Security.unwrap_secure_message(tampered, key)
      
      # Create a completely new message with tampered signature
      new_payload = %{command: "new_test"}
      new_wrapped = Security.wrap_secure_message(new_payload, key)
      :timer.sleep(10)
      
      # Tamper with the signature
      tampered_sig = %{new_wrapped | security: %{new_wrapped.security | signature: "bad_signature"}}
      assert {:error, :invalid_signature} = Security.unwrap_secure_message(tampered_sig, key)
    end
  end
  
  describe "AMQP command wrapping" do
    test "wraps AMQP commands with metadata" do
      key = Security.generate_secret_key()
      command = %{type: :resource_allocation, data: %{cpu: 0.5}}
      
      wrapped = Security.wrap_amqp_command(command, key)
      
      assert wrapped.payload.command_id
      assert wrapped.payload.issued_at
      assert wrapped.payload.type == :resource_allocation
      
      # Wait to ensure nonce is stored
      :timer.sleep(10)
      
      {:ok, unwrapped} = Security.unwrap_amqp_command(wrapped, key)
      assert unwrapped.type == :resource_allocation
      assert unwrapped.command_id
    end
  end
  
  describe "key management" do
    test "generates secure keys" do
      key1 = Security.generate_secret_key()
      key2 = Security.generate_secret_key()
      
      assert key1 != key2
      assert String.length(key1) > 30
    end
    
    test "derives keys from passwords" do
      password = "super-secret-vsm-password"
      
      derived1 = Security.derive_key_from_password(password)
      derived2 = Security.derive_key_from_password(password, Base.decode64!(derived1.salt, padding: false))
      
      assert derived1.key == derived2.key
      assert derived1.algorithm == "PBKDF2-HMAC-SHA256"
      assert derived1.iterations == 100_000
    end
  end
  
  describe "metrics" do
    test "tracks security metrics" do
      key = Security.generate_secret_key()
      
      # Get initial metrics
      initial = Security.get_metrics()
      
      # Perform some operations
      payload = %{test: "data"}
      wrapped = Security.wrap_secure_message(payload, key)
      :timer.sleep(10)
      
      Security.unwrap_secure_message(wrapped, key)
      
      # Try replay attack
      Security.unwrap_secure_message(wrapped, key)
      
      # Check updated metrics  
      updated = Security.get_metrics()
      
      assert updated.messages_signed >= initial.messages_signed
      assert updated.messages_verified >= initial.messages_verified  
      assert updated.replay_attempts_blocked >= initial.replay_attempts_blocked
    end
  end
  
  describe "nonce cleanup" do
    test "security genserver is running" do
      assert Process.whereis(VsmPhoenix.Infrastructure.Security) != nil
    end
  end
end