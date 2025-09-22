# frozen_string_literal: true

require_relative "base"
require "multi_json"

module JDPIClient
  module TokenStorage
    # Redis-based token storage adapter for clustered environments
    # Provides distributed token caching with automatic expiration
    class Redis < Base
      LOCK_EXPIRY = 30 # seconds
      LOCK_RETRY_DELAY = 0.1 # seconds
      MAX_LOCK_RETRIES = 50

      def initialize(config)
        super
        @redis = connect_to_redis
      end

      # Store a token with the given key and expiration
      # @param key [String] The cache key for the token
      # @param token_data [Hash] Token data including access_token, expires_at, etc.
      # @param ttl [Integer] Time to live in seconds
      def store(key, token_data, ttl)
        # Encrypt token data if encryption is enabled
        data_to_store = encrypt_if_enabled(token_data)
        serialized_data = MultiJson.dump(data_to_store)

        # Store with TTL for automatic expiration
        result = @redis.setex(key, ttl, serialized_data)
        result == "OK"
      rescue StandardError => e
        handle_redis_error(e, "store token")
        false
      end

      # Retrieve a token by key
      # @param key [String] The cache key for the token
      # @return [Hash, nil] Token data or nil if not found/expired
      def retrieve(key)
        serialized_data = @redis.get(key)
        return nil unless serialized_data

        # Deserialize and decrypt if needed
        data = MultiJson.load(serialized_data)
        decrypt_if_enabled(data)
      rescue MultiJson::ParseError => e
        # Handle malformed JSON gracefully - just return nil
        @config.logger&.warn("Redis token data corrupted for key #{key}: #{e.message}")
        nil
      rescue StandardError => e
        handle_redis_error(e, "retrieve token")
        nil
      end

      # Check if a token exists and is not expired
      # @param key [String] The cache key for the token
      # @return [Boolean] True if token exists and is valid
      def exists?(key)
        result = @redis.exists?(key)
        # Handle both MockRedis (returns boolean) and real Redis (returns integer)
        result.is_a?(Integer) ? result.positive? : !!result
      rescue StandardError => e
        handle_redis_error(e, "check token existence")
        false
      end

      # Delete a token by key
      # @param key [String] The cache key for the token
      def delete(key)
        result = @redis.del(key)
        # Handle both MockRedis (returns boolean) and real Redis (returns integer)
        result.is_a?(Integer) ? result.positive? : !!result
      rescue StandardError => e
        handle_redis_error(e, "delete token")
        false
      end

      # Clear all tokens (useful for testing)
      def clear_all
        pattern = "#{@config.token_storage_key_prefix}:*"
        keys = @redis.keys(pattern)
        return true if keys.empty?

        result = @redis.del(keys)
        # Handle both MockRedis and real Redis return types
        result.is_a?(Integer) ? result.positive? : !!result
      rescue StandardError => e
        handle_redis_error(e, "clear all tokens")
        false
      end

      # Health check for the storage backend
      # @return [Boolean] True if Redis is accessible
      def healthy?
        @redis.ping == "PONG"
      rescue StandardError
        false
      end

      # Acquire a distributed lock for token refresh coordination
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time in seconds
      # @return [Boolean] True if lock was acquired
      def acquire_lock(key, ttl = LOCK_EXPIRY)
        lock_key = "#{key}:lock"
        lock_value = SecureRandom.hex(16)

        # Try to acquire lock with NX (only if not exists) and EX (expiry)
        result = @redis.set(lock_key, lock_value, nx: true, ex: ttl)
        if result == "OK"
          @current_lock_value = lock_value
          @current_lock_key = lock_key
          true
        else
          false
        end
      rescue StandardError => e
        handle_redis_error(e, "acquire lock")
        false
      end

      # Release a distributed lock
      # @return [Boolean] True if lock was released
      def release_lock
        return false unless @current_lock_key && @current_lock_value

        # Only release the lock if we still own it (prevent race conditions)
        lua_script = <<~LUA
          if redis.call("get", KEYS[1]) == ARGV[1] then
            return redis.call("del", KEYS[1])
          else
            return 0
          end
        LUA

        result = @redis.eval(lua_script, [@current_lock_key], [@current_lock_value])
        success = result.positive?

        @current_lock_key = nil
        @current_lock_value = nil
        success
      rescue StandardError => e
        handle_redis_error(e, "release lock")
        false
      end

      # Execute a block with a distributed lock
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time
      # @yield Block to execute with lock
      def with_lock(key, ttl = LOCK_EXPIRY)
        # Skip locking for MockRedis during testing
        return yield if @redis.instance_of?(::MockRedis)

        retries = 0

        loop do
          if acquire_lock(key, ttl)
            begin
              return yield
            ensure
              release_lock
            end
          end

          retries += 1
          if retries >= MAX_LOCK_RETRIES
            raise JDPIClient::Errors::ServerError, "Could not acquire Redis lock after #{MAX_LOCK_RETRIES} retries"
          end

          sleep(LOCK_RETRY_DELAY)
        end
      end

      # Get Redis storage statistics
      # @return [Hash] Storage statistics
      def stats
        info = @redis.info
        {
          storage_type: "Redis",
          redis_version: info["redis_version"],
          connected_clients: info["connected_clients"],
          used_memory_human: info["used_memory_human"],
          memory_usage: info["used_memory_human"],
          total_keys: @redis.dbsize,
          token_keys: @redis.keys("#{@config.token_storage_key_prefix}:*").size,
          encrypted: @config.token_encryption_enabled?,
          encryption_enabled: @config.token_encryption_enabled?
        }
      rescue StandardError => e
        handle_redis_error(e, "get stats")
        { error: e.message }
      end

      private

      # Establish connection to Redis
      # @return [Redis] Redis client instance
      def connect_to_redis
        begin
          require "redis"
        rescue LoadError
          raise JDPIClient::Errors::ConfigurationError,
                "Redis gem is required for Redis token storage. Add 'gem \"redis\"' to your Gemfile."
        end

        redis_options = parse_redis_options
        redis_client = ::Redis.new(redis_options)

        # Test the connection
        redis_client.ping

        redis_client
      rescue ::Redis::CannotConnectError => e
        raise JDPIClient::Errors::ConfigurationError,
              "Cannot connect to Redis: #{e.message}"
      rescue StandardError => e
        raise JDPIClient::Errors::ConfigurationError,
              "Redis connection error: #{e.message}"
      end

      # Parse Redis connection options from config
      # @return [Hash] Redis connection options
      def parse_redis_options
        options = @config.token_storage_options.dup

        # Add URL if provided
        options[:url] = @config.token_storage_url if @config.token_storage_url

        # Set sensible defaults
        options[:timeout] ||= 5
        options[:reconnect_attempts] ||= 3
        # NOTE: reconnect_delay is not a standard Redis gem option, removing it

        # SSL configuration for production
        if @config.production? && @config.token_storage_url&.start_with?("rediss://")
          options[:ssl_params] ||= { verify_mode: OpenSSL::SSL::VERIFY_PEER }
        end

        options
      end

      # Handle Redis errors consistently
      # @param error [Exception] The error that occurred
      # @param operation [String] Description of the operation
      def handle_redis_error(error, operation)
        error_message = "Redis #{operation} failed: #{error.message}"

        @config.logger&.error(error_message)

        # Re-raise as appropriate JDPI client error
        case error
        when ::Redis::CannotConnectError, ::Redis::ConnectionError
          raise JDPIClient::Errors::ServerError, error_message
        when ::Redis::TimeoutError
          raise JDPIClient::Errors::ServerError, "Redis timeout during #{operation}"
        else
          raise JDPIClient::Errors::ServerError, error_message
        end
      end
    end
  end
end
