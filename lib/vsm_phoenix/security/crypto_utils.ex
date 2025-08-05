defmodule VsmPhoenix.Security.CryptoUtils do
  @moduledoc """
  Cryptographic utilities for key generation, signing, and hashing.
  Provides a unified interface for all cryptographic operations.
  """

  require Logger

  # Algorithm configurations
  @hmac_algorithm :sha256
  @rsa_key_size 2048
  @aes_key_size 32  # 256 bits
  @default_hash_algorithm :sha256

  # Performance optimization: cache compiled crypto functions
  @compile {:inline, [
    hash: 2,
    constant_time_compare: 2,
    generate_random_bytes: 1
  ]}

  @doc """
  Generates a cryptographically secure random key.
  """
  def generate_key(size \\ @aes_key_size) do
    :crypto.strong_rand_bytes(size)
  end

  @doc """
  Generates an RSA key pair for asymmetric operations.
  """
  def generate_rsa_keypair(key_size \\ @rsa_key_size) do
    try do
      {public_key, private_key} = :crypto.generate_key(:rsa, {key_size, 65537})
      
      {:ok, %{
        public_key: encode_key(public_key),
        private_key: encode_key(private_key),
        algorithm: :rsa,
        key_size: key_size
      }}
    rescue
      error ->
        Logger.error("Failed to generate RSA keypair: #{inspect(error)}")
        {:error, :key_generation_failed}
    end
  end

  @doc """
  Signs data using HMAC-SHA256.
  """
  def hmac_sign(data, key) when is_binary(data) and is_binary(key) do
    :crypto.mac(:hmac, @hmac_algorithm, key, data)
  end

  @doc """
  Verifies HMAC signature with constant-time comparison.
  """
  def hmac_verify(data, signature, key) when is_binary(data) and is_binary(signature) and is_binary(key) do
    expected_signature = hmac_sign(data, key)
    constant_time_compare(signature, expected_signature)
  end

  @doc """
  Signs data using RSA private key.
  """
  def rsa_sign(data, private_key) when is_binary(data) do
    try do
      decoded_key = decode_key(private_key)
      signature = :crypto.sign(:rsa, :sha256, data, decoded_key)
      {:ok, Base.encode64(signature)}
    rescue
      error ->
        Logger.error("RSA signing failed: #{inspect(error)}")
        {:error, :signing_failed}
    end
  end

  @doc """
  Verifies RSA signature using public key.
  """
  def rsa_verify(data, signature, public_key) when is_binary(data) and is_binary(signature) do
    try do
      decoded_key = decode_key(public_key)
      decoded_signature = Base.decode64!(signature)
      
      case :crypto.verify(:rsa, :sha256, data, decoded_signature, decoded_key) do
        true -> {:ok, true}
        false -> {:ok, false}
      end
    rescue
      error ->
        Logger.error("RSA verification failed: #{inspect(error)}")
        {:error, :verification_failed}
    end
  end

  @doc """
  Computes hash of data using specified algorithm.
  """
  def hash(data, algorithm \\ @default_hash_algorithm) when is_binary(data) do
    :crypto.hash(algorithm, data)
  end

  @doc """
  Generates a secure random nonce.
  """
  def generate_nonce(size \\ 32) do
    nonce = generate_random_bytes(size)
    timestamp = System.os_time(:nanosecond)
    
    # Combine random bytes with timestamp for uniqueness
    hash(nonce <> <<timestamp::64>>)
  end

  @doc """
  Derives a key from password using PBKDF2.
  """
  def derive_key(password, salt, iterations \\ 100_000) when is_binary(password) and is_binary(salt) do
    :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, @aes_key_size)
  end

  @doc """
  Encrypts data using AES-256-GCM.
  """
  def encrypt(plaintext, key) when is_binary(plaintext) and byte_size(key) == @aes_key_size do
    iv = generate_random_bytes(16)  # 128-bit IV for AES-GCM
    
    try do
      {ciphertext, tag} = :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        key,
        iv,
        plaintext,
        "",  # No additional authenticated data
        true  # Encrypt mode
      )
      
      # Return IV + tag + ciphertext for easy transmission
      {:ok, iv <> tag <> ciphertext}
    rescue
      error ->
        Logger.error("Encryption failed: #{inspect(error)}")
        {:error, :encryption_failed}
    end
  end

  @doc """
  Decrypts data encrypted with AES-256-GCM.
  """
  def decrypt(encrypted, key) when is_binary(encrypted) and byte_size(key) == @aes_key_size do
    if byte_size(encrypted) < 32 do  # IV (16) + tag (16)
      {:error, :invalid_ciphertext}
    else
      <<iv::binary-16, tag::binary-16, ciphertext::binary>> = encrypted
      
      try do
        case :crypto.crypto_one_time_aead(
          :aes_256_gcm,
          key,
          iv,
          ciphertext,
          "",  # No additional authenticated data
          tag,
          false  # Decrypt mode
        ) do
          :error -> {:error, :decryption_failed}
          plaintext -> {:ok, plaintext}
        end
      rescue
        error ->
          Logger.error("Decryption failed: #{inspect(error)}")
          {:error, :decryption_failed}
      end
    end
  end

  # Private functions

  defp generate_random_bytes(size) do
    :crypto.strong_rand_bytes(size)
  end

  defp constant_time_compare(left, right) when byte_size(left) == byte_size(right) do
    constant_time_compare_bytes(left, right, 0) == 0
  end
  defp constant_time_compare(_left, _right), do: false

  defp constant_time_compare_bytes(<<>>, <<>>, acc), do: acc
  defp constant_time_compare_bytes(<<l, left::binary>>, <<r, right::binary>>, acc) do
    constant_time_compare_bytes(left, right, acc ||| (l ^^^ r))
  end

  defp encode_key(key) do
    Base.encode64(key)
  end

  defp decode_key(encoded_key) do
    Base.decode64!(encoded_key)
  end
end