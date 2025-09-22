# frozen_string_literal: true

require_relative "base"
require "monitor"

module JDPIClient
  module TokenStorage
    # In-memory token storage adapter (default behavior)
    # This adapter provides thread-safe in-memory token caching
    # but tokens are not shared across process instances
    class Memory < Base
      include MonitorMixin

      def initialize(config)
        super
        @tokens = {}
        @expiry_times = {}
      end

      # Store a token with the given key and expiration
      # @param key [String] The cache key for the token
      # @param token_data [Hash] Token data including access_token, expires_at, etc.
      # @param ttl [Integer] Time to live in seconds
      def store(key, token_data, ttl)
        synchronize do
          # Clean up expired tokens before storing
          cleanup_expired_tokens

          # Store the token data (optionally encrypted)
          @tokens[key] = encrypt_if_enabled(token_data)
          @expiry_times[key] = Time.now + ttl

          # Log warning about local storage if configured
          log_local_storage_warning if @config.warn_on_local_tokens

          true
        end
      end

      # Retrieve a token by key
      # @param key [String] The cache key for the token
      # @return [Hash, nil] Token data or nil if not found/expired
      def retrieve(key)
        synchronize do
          # Clean up expired tokens
          cleanup_expired_tokens

          # Check if token exists and is not expired
          return nil unless @tokens.key?(key)
          return nil unless @expiry_times[key] && Time.now < @expiry_times[key]

          # Return decrypted token data
          token_data = @tokens[key]
          decrypt_if_enabled(token_data)
        end
      end

      # Check if a token exists and is not expired
      # @param key [String] The cache key for the token
      # @return [Boolean] True if token exists and is valid
      def exists?(key)
        synchronize do
          return false unless @tokens.key?(key)
          return false unless @expiry_times[key]

          Time.now < @expiry_times[key]
        end
      end

      # Delete a token by key
      # @param key [String] The cache key for the token
      def delete(key)
        synchronize do
          @tokens.delete(key)
          @expiry_times.delete(key)
          true
        end
      end

      # Clear all tokens (useful for testing)
      def clear_all
        synchronize do
          @tokens.clear
          @expiry_times.clear
          true
        end
      end

      # Health check for the storage backend
      # @return [Boolean] True if storage is accessible
      def healthy?
        # Memory storage is always healthy
        true
      end

      # Get statistics about the memory storage
      # @return [Hash] Storage statistics
      def stats
        synchronize do
          cleanup_expired_tokens
          {
            total_tokens: @tokens.size,
            expired_tokens_cleaned: 0, # We clean automatically
            memory_adapter: true,
            encryption_enabled: @config.token_encryption_enabled?
          }
        end
      end

      private

      # Remove expired tokens from memory
      def cleanup_expired_tokens
        now = Time.now
        expired_keys = @expiry_times.select { |_key, expiry| expiry <= now }.keys

        expired_keys.each do |key|
          @tokens.delete(key)
          @expiry_times.delete(key)
        end
      end

      # Log a warning about using local token storage
      def log_local_storage_warning
        return unless @config.logger
        return if @warning_logged # Only log once per instance

        @config.logger.warn(
          "JDPI Token Storage Warning: Using in-memory storage. " \
          "Tokens are not shared across application instances. " \
          "Consider configuring Redis, DynamoDB, or database storage " \
          "for clustered environments to stay within JDPI's 50-token limit."
        )
        @warning_logged = true
      end
    end
  end
end