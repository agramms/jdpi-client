# frozen_string_literal: true

require_relative "test_helper"

class TestTokenEncryption < Minitest::Test
  def setup
    @encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    @token_data = {
      "access_token" => "test_token_123",
      "scope" => "auth:token dict:read",
      "expires_at" => "2024-01-01T12:00:00Z",
      "client_id" => "test_client"
    }
  end

  def test_encrypt_and_decrypt_roundtrip
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    decrypted_data = JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)

    assert_equal @token_data["access_token"], decrypted_data["access_token"]
    assert_equal @token_data["scope"], decrypted_data["scope"]
    assert_equal @token_data["expires_at"], decrypted_data["expires_at"]
    assert_equal @token_data["client_id"], decrypted_data["client_id"]
  end

  def test_encrypted_data_structure
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)

    assert encrypted_data[:encrypted]
    assert_equal 1, encrypted_data[:version]
    assert_equal "AES-256-GCM", encrypted_data[:algorithm]
    assert encrypted_data[:salt]
    assert encrypted_data[:iv]
    assert encrypted_data[:auth_tag]
    assert encrypted_data[:ciphertext]
    assert encrypted_data[:encrypted_at]
  end

  def test_encrypted_data_is_different_each_time
    encrypted1 = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    encrypted2 = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)

    # Should be different due to random salt and IV
    refute_equal encrypted1[:salt], encrypted2[:salt]
    refute_equal encrypted1[:iv], encrypted2[:iv]
    refute_equal encrypted1[:ciphertext], encrypted2[:ciphertext]
  end

  def test_decrypt_with_wrong_key_fails
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    wrong_key = JDPIClient::TokenStorage::Encryption.generate_key

    assert_raises(JDPIClient::Errors::Unauthorized) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, wrong_key)
    end
  end

  def test_decrypt_with_tampered_data_fails
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)

    # Tamper with the ciphertext
    encrypted_data[:ciphertext] = Base64.strict_encode64("tampered_data")

    assert_raises(JDPIClient::Errors::Unauthorized) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)
    end
  end

  def test_decrypt_with_invalid_structure_fails
    invalid_data = { not_encrypted: true }

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(invalid_data, @encryption_key)
    end
  end

  def test_decrypt_with_missing_fields_fails
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    encrypted_data.delete(:auth_tag)

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)
    end
  end

  def test_decrypt_with_wrong_algorithm_fails
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    encrypted_data[:algorithm] = "AES-128-CBC"

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)
    end
  end

  def test_decrypt_with_wrong_version_fails
    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(@token_data, @encryption_key)
    encrypted_data[:version] = 2

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)
    end
  end

  def test_valid_encryption_key_validation
    # Valid keys
    assert JDPIClient::TokenStorage::Encryption.valid_encryption_key?("A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8S9t0U1v2W3x4Y5z6")
    assert JDPIClient::TokenStorage::Encryption.valid_encryption_key?("MySecureKey123WithMixedCaseAndNumbers456")

    # Invalid keys
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("short")
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("alllowercasewithoutanyuppercase")
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("ALLUPPERCASEWITHOUTANYLOWERCASE")
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("NoNumbersInThisKeyAtAll")
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("  SpacesAtBeginningAndEnd  ")
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?(nil)
    refute JDPIClient::TokenStorage::Encryption.valid_encryption_key?("")
  end

  def test_generate_key_creates_valid_key
    key = JDPIClient::TokenStorage::Encryption.generate_key
    assert_equal 44, key.length # 32 bytes as base64 = 44 characters
    assert key.match?(%r{\A[A-Za-z0-9+/]+=*\z}) # Valid base64 format
  end

  def test_generate_key_creates_unique_keys
    key1 = JDPIClient::TokenStorage::Encryption.generate_key
    key2 = JDPIClient::TokenStorage::Encryption.generate_key
    refute_equal key1, key2
  end

  def test_encryption_handles_complex_token_data
    complex_data = {
      "access_token" => "jwt.token.with.dots",
      "scope" => "auth:token dict:read dict:write spi:payment qr:generate",
      "expires_at" => Time.now.utc.iso8601,
      "client_id" => "complex-client-id-123",
      "metadata" => {
        "environment" => "production",
        "version" => "1.0.0",
        "features" => %w[encryption clustering]
      }
    }

    encrypted_data = JDPIClient::TokenStorage::Encryption.encrypt(complex_data, @encryption_key)
    decrypted_data = JDPIClient::TokenStorage::Encryption.decrypt(encrypted_data, @encryption_key)

    assert_equal complex_data["access_token"], decrypted_data["access_token"]
    assert_equal complex_data["metadata"]["environment"], decrypted_data["metadata"]["environment"]
    assert_equal complex_data["metadata"]["features"], decrypted_data["metadata"]["features"]
  end

  def test_encryption_error_handling
    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.encrypt(@token_data, nil)
    end

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.encrypt(@token_data, "")
    end
  end

  def test_base64_decode_error_handling
    invalid_encrypted_data = {
      encrypted: true,
      version: 1,
      algorithm: "AES-256-GCM",
      salt: "invalid_base64!!!",
      iv: "invalid_base64!!!",
      auth_tag: "invalid_base64!!!",
      ciphertext: "invalid_base64!!!"
    }

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(invalid_encrypted_data, @encryption_key)
    end
  end
end
