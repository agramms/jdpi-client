# frozen_string_literal: true

require "openssl"
require "securerandom"
require "multi_json"
require "digest"
require "base64"

module JDPIClient
  module TokenStorage
    # Handles encryption and decryption of token data using AES-256-GCM
    module Encryption
      ALGORITHM = "AES-256-GCM"
      KEY_ITERATIONS = 100_000
      AUTH_DATA = "jdpi_client_token_v1"

      class << self
        # Encrypt token data using AES-256-GCM
        # @param data [Hash] Token data to encrypt
        # @param encryption_key [String] Base encryption key
        # @return [Hash] Encrypted data structure
        def encrypt(data, encryption_key)
          raise JDPIClient::Errors::ConfigurationError, "Encryption key cannot be nil" if encryption_key.nil?

          # Generate random salt and IV
          salt = SecureRandom.bytes(32)
          iv = SecureRandom.bytes(12)

          # Derive encryption key using PBKDF2
          cipher = OpenSSL::Cipher.new(ALGORITHM)
          derived_key = derive_key(encryption_key, salt)

          # Encrypt the data
          cipher.encrypt
          cipher.key = derived_key
          cipher.iv = iv
          cipher.auth_data = AUTH_DATA

          # Serialize and encrypt
          plaintext = MultiJson.dump(data)
          ciphertext = cipher.update(plaintext) + cipher.final
          auth_tag = cipher.auth_tag

          {
            encrypted: true,
            version: 1,
            algorithm: ALGORITHM,
            salt: Base64.strict_encode64(salt),
            iv: Base64.strict_encode64(iv),
            auth_tag: Base64.strict_encode64(auth_tag),
            ciphertext: Base64.strict_encode64(ciphertext),
            encrypted_at: Time.now.utc.iso8601
          }
        rescue OpenSSL::Cipher::CipherError => e
          raise JDPIClient::Errors::ConfigurationError, "Token encryption failed: #{e.message}"
        end

        # Decrypt token data
        # @param encrypted_data [Hash] Encrypted data structure
        # @param encryption_key [String] Base encryption key
        # @return [Hash] Decrypted token data
        def decrypt(encrypted_data, encryption_key)
          validate_encrypted_data!(encrypted_data)

          # Extract components
          salt = Base64.strict_decode64(encrypted_data[:salt])
          iv = Base64.strict_decode64(encrypted_data[:iv])
          auth_tag = Base64.strict_decode64(encrypted_data[:auth_tag])
          ciphertext = Base64.strict_decode64(encrypted_data[:ciphertext])

          # Derive the same key
          cipher = OpenSSL::Cipher.new(ALGORITHM)
          derived_key = derive_key(encryption_key, salt)

          # Decrypt
          cipher.decrypt
          cipher.key = derived_key
          cipher.iv = iv
          cipher.auth_tag = auth_tag
          cipher.auth_data = AUTH_DATA

          plaintext = cipher.update(ciphertext) + cipher.final
          MultiJson.load(plaintext)
        rescue OpenSSL::Cipher::CipherError => e
          raise JDPIClient::Errors::Unauthorized, "Token decryption failed: #{e.message}"
        rescue ArgumentError => e
          raise JDPIClient::Errors::ConfigurationError, "Invalid encrypted token format: #{e.message}"
        end

        # Verify that the encryption key is secure
        # @param key [String] Encryption key to validate
        # @return [Boolean] True if key meets security requirements
        def valid_encryption_key?(key)
          return false unless key.is_a?(String)
          return false if key.length < 32 # Minimum 256-bit entropy
          return false if key.strip != key # No leading/trailing whitespace
          return false if key == key.downcase || key == key.upcase # Must have mixed case
          return false unless key =~ /[A-Za-z]/ && key =~ /[0-9]/ # Must have letters and numbers

          true
        end

        # Generate a secure encryption key
        # @return [String] A secure random encryption key
        def generate_key
          # Generate 32 bytes (256 bits) of random data and encode as hex
          SecureRandom.hex(32)
        end

        private

        # Derive an encryption key using PBKDF2
        # @param password [String] Base password
        # @param salt [String] Salt bytes
        # @return [String] Derived key
        def derive_key(password, salt)
          OpenSSL::PKCS5.pbkdf2_hmac(
            password,
            salt,
            KEY_ITERATIONS,
            32, # 256 bits
            OpenSSL::Digest::SHA256.new
          )
        end

        # Validate encrypted data structure
        # @param data [Hash] Encrypted data to validate
        def validate_encrypted_data!(data)
          unless data.is_a?(Hash) && data[:encrypted]
            raise JDPIClient::Errors::ConfigurationError, "Invalid encrypted token data"
          end

          required_fields = [:version, :algorithm, :salt, :iv, :auth_tag, :ciphertext]
          missing_fields = required_fields - data.keys

          unless missing_fields.empty?
            raise JDPIClient::Errors::ConfigurationError,
                  "Encrypted token missing required fields: #{missing_fields.join(', ')}"
          end

          unless data[:algorithm] == ALGORITHM
            raise JDPIClient::Errors::ConfigurationError,
                  "Unsupported encryption algorithm: #{data[:algorithm]}"
          end

          unless data[:version] == 1
            raise JDPIClient::Errors::ConfigurationError,
                  "Unsupported encryption version: #{data[:version]}"
          end
        end
      end
    end
  end
end