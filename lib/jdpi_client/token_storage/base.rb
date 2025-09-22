# frozen_string_literal: true

module JDPIClient
  module TokenStorage
    # Abstract base class for token storage implementations
    class Base
      def initialize(config)
        @config = config
      end

      # Store a token with the given key and expiration
      # @param key [String] The cache key for the token
      # @param token_data [Hash] Token data including access_token, expires_at, etc.
      # @param ttl [Integer] Time to live in seconds
      def store(key, token_data, ttl)
        raise NotImplementedError, "Subclasses must implement #store"
      end

      # Retrieve a token by key
      # @param key [String] The cache key for the token
      # @return [Hash, nil] Token data or nil if not found/expired
      def retrieve(key)
        raise NotImplementedError, "Subclasses must implement #retrieve"
      end

      # Check if a token exists and is not expired
      # @param key [String] The cache key for the token
      # @return [Boolean] True if token exists and is valid
      def exists?(key)
        token_data = retrieve(key)
        return false unless token_data

        expires_at = Time.parse(token_data[:expires_at]) rescue nil
        return false unless expires_at

        Time.now < expires_at
      end

      # Delete a token by key
      # @param key [String] The cache key for the token
      def delete(key)
        raise NotImplementedError, "Subclasses must implement #delete"
      end

      # Clear all tokens (useful for testing)
      def clear_all
        raise NotImplementedError, "Subclasses must implement #clear_all"
      end

      # Health check for the storage backend
      # @return [Boolean] True if storage is accessible
      def healthy?
        raise NotImplementedError, "Subclasses must implement #healthy?"
      end

      protected

      # Generate a storage key for the given client_id and scope
      # @param client_id [String] OAuth client ID
      # @param scope [String] OAuth scope string
      # @return [String] Storage key
      def storage_key(client_id, scope = "default")
        scope_hash = Digest::SHA256.hexdigest(scope)[0..7]
        "#{@config.token_storage_key_prefix}:#{client_id}:#{scope_hash}"
      end

      # Encrypt token data if encryption is enabled
      # @param data [Hash] Token data to encrypt
      # @return [Hash] Encrypted or original data
      def encrypt_if_enabled(data)
        return data unless @config.token_encryption_enabled?

        require_relative "encryption"
        JDPIClient::TokenStorage::Encryption.encrypt(data, @config.token_encryption_key)
      end

      # Decrypt token data if encryption is enabled
      # @param data [Hash] Potentially encrypted token data
      # @return [Hash] Decrypted or original data
      def decrypt_if_enabled(data)
        return data unless @config.token_encryption_enabled?
        return data unless data.is_a?(Hash) && (data[:encrypted] || data['encrypted'])

        require_relative "encryption"
        JDPIClient::TokenStorage::Encryption.decrypt(data, @config.token_encryption_key)
      end
    end
  end
end