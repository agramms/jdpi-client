# frozen_string_literal: true

require_relative "base"
require "multi_json"

module JDPIClient
  module TokenStorage
    # DynamoDB-based token storage adapter for AWS environments
    # Provides distributed token caching with automatic TTL expiration
    class DynamoDB < Base
      LOCK_ATTRIBUTE = "lock_acquired_at"
      LOCK_TTL = 30 # seconds
      CONDITION_CHECK_RETRIES = 3

      def initialize(config)
        super
        @table_name = @config.token_storage_options[:table_name]
        @dynamodb = connect_to_dynamodb
        validate_table_schema
      end

      # Store a token with the given key and expiration
      # @param key [String] The cache key for the token
      # @param token_data [Hash] Token data including access_token, expires_at, etc.
      # @param ttl [Integer] Time to live in seconds
      def store(key, token_data, ttl)
        # Encrypt token data if encryption is enabled
        data_to_store = encrypt_if_enabled(token_data)
        expires_at = Time.now.to_i + ttl

        item = {
          token_key: key,
          token_data: MultiJson.dump(data_to_store),
          expires_at: expires_at,
          created_at: Time.now.to_i,
          ttl: expires_at # DynamoDB TTL attribute
        }

        @dynamodb.put_item(
          table_name: @table_name,
          item: item
        )

        true
      rescue StandardError => e
        handle_dynamodb_error(e, "store token")
        false
      end

      # Retrieve a token by key
      # @param key [String] The cache key for the token
      # @return [Hash, nil] Token data or nil if not found/expired
      def retrieve(key)
        result = @dynamodb.get_item(
          table_name: @table_name,
          key: { token_key: key },
          consistent_read: false # Eventually consistent is fine for tokens
        )

        return nil unless result.item

        # Check if token is expired (extra safety beyond DynamoDB TTL)
        expires_at = result.item["expires_at"]
        return nil if expires_at && expires_at < Time.now.to_i

        # Deserialize and decrypt if needed
        token_data = MultiJson.load(result.item["token_data"])
        decrypt_if_enabled(token_data)
      rescue StandardError => e
        handle_dynamodb_error(e, "retrieve token")
        nil
      end

      # Check if a token exists and is not expired
      # @param key [String] The cache key for the token
      # @return [Boolean] True if token exists and is valid
      def exists?(key)
        result = @dynamodb.get_item(
          table_name: @table_name,
          key: { token_key: key },
          projection_expression: "expires_at"
        )

        return false unless result.item

        expires_at = result.item["expires_at"]
        expires_at && expires_at >= Time.now.to_i
      rescue StandardError => e
        handle_dynamodb_error(e, "check token existence")
        false
      end

      # Delete a token by key
      # @param key [String] The cache key for the token
      def delete(key)
        @dynamodb.delete_item(
          table_name: @table_name,
          key: { token_key: key }
        )

        true
      rescue StandardError => e
        handle_dynamodb_error(e, "delete token")
        false
      end

      # Clear all tokens (useful for testing)
      def clear_all
        # Scan for all items with our prefix and delete them
        prefix = @config.token_storage_key_prefix

        loop do
          result = @dynamodb.scan(
            table_name: @table_name,
            filter_expression: "begins_with(token_key, :prefix)",
            expression_attribute_values: {
              ":prefix" => prefix
            },
            projection_expression: "token_key"
          )

          break if result.items.empty?

          # Delete items in batches
          delete_requests = result.items.map do |item|
            {
              delete_request: {
                key: { token_key: item["token_key"] }
              }
            }
          end

          # Process in batches of 25 (DynamoDB limit)
          delete_requests.each_slice(25) do |batch|
            @dynamodb.batch_write_item(
              request_items: {
                @table_name => batch
              }
            )
          end

          # Continue if there are more items
          break unless result.last_evaluated_key
        end

        true
      rescue StandardError => e
        handle_dynamodb_error(e, "clear all tokens")
        false
      end

      # Health check for the storage backend
      # @return [Boolean] True if DynamoDB table is accessible
      def healthy?
        @dynamodb.describe_table(table_name: @table_name)
        true
      rescue StandardError
        false
      end

      # Acquire a distributed lock using conditional writes
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time in seconds
      # @return [Boolean] True if lock was acquired
      def acquire_lock(key, ttl = LOCK_TTL)
        lock_key = "#{key}:lock"
        lock_expires_at = Time.now.to_i + ttl
        lock_value = SecureRandom.hex(16)

        # Try to create lock item with condition that it doesn't exist
        @dynamodb.put_item(
          table_name: @table_name,
          item: {
            token_key: lock_key,
            lock_value: lock_value,
            expires_at: lock_expires_at,
            ttl: lock_expires_at
          },
          condition_expression: "attribute_not_exists(token_key)"
        )

        @current_lock_key = lock_key
        @current_lock_value = lock_value
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        # Lock already exists
        false
      rescue StandardError => e
        handle_dynamodb_error(e, "acquire lock")
        false
      end

      # Release a distributed lock
      # @return [Boolean] True if lock was released
      def release_lock
        return false unless @current_lock_key && @current_lock_value

        # Only delete the lock if we still own it
        @dynamodb.delete_item(
          table_name: @table_name,
          key: { token_key: @current_lock_key },
          condition_expression: "lock_value = :lock_value",
          expression_attribute_values: {
            ":lock_value" => @current_lock_value
          }
        )

        @current_lock_key = nil
        @current_lock_value = nil
        true
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        # We no longer own the lock (it expired)
        false
      rescue StandardError => e
        handle_dynamodb_error(e, "release lock")
        false
      end

      # Execute a block with a distributed lock
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time
      # @yield Block to execute with lock
      def with_lock(key, ttl = LOCK_TTL)
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
          if retries >= CONDITION_CHECK_RETRIES
            raise JDPIClient::Errors::ServerError,
                  "Could not acquire DynamoDB lock after #{CONDITION_CHECK_RETRIES} retries"
          end

          sleep(0.1 * retries) # Exponential backoff
        end
      end

      # Get DynamoDB storage statistics
      # @return [Hash] Storage statistics
      def stats
        table_description = @dynamodb.describe_table(table_name: @table_name)
        table = table_description.table

        {
          table_name: @table_name,
          table_status: table.table_status,
          item_count: table.item_count,
          table_size_bytes: table.table_size_bytes,
          read_capacity: table.provisioned_throughput&.read_capacity_units,
          write_capacity: table.provisioned_throughput&.write_capacity_units,
          encryption_enabled: @config.token_encryption_enabled?
        }
      rescue StandardError => e
        handle_dynamodb_error(e, "get stats")
        { error: e.message }
      end

      private

      # Establish connection to DynamoDB
      # @return [Aws::DynamoDB::Client] DynamoDB client instance
      def connect_to_dynamodb
        begin
          require "aws-sdk-dynamodb"
        rescue LoadError
          raise JDPIClient::Errors::ConfigurationError,
                "AWS SDK for DynamoDB is required for DynamoDB token storage. " \
                "Add 'gem \"aws-sdk-dynamodb\"' to your Gemfile."
        end

        client_options = parse_dynamodb_options
        ::Aws::DynamoDB::Client.new(client_options)
      rescue StandardError => e
        raise JDPIClient::Errors::ConfigurationError,
              "DynamoDB connection error: #{e.message}"
      end

      # Parse DynamoDB client options from config
      # @return [Hash] DynamoDB client options
      def parse_dynamodb_options
        options = @config.token_storage_options.dup
        options.delete(:table_name) # Remove table name from client options

        # Set region if not specified
        options[:region] ||= ENV["AWS_REGION"] || "us-east-1"

        # Configure credentials if provided
        if @config.token_storage_options[:access_key_id]
          options[:credentials] = Aws::Credentials.new(
            @config.token_storage_options[:access_key_id],
            @config.token_storage_options[:secret_access_key]
          )
        end

        # Local DynamoDB support for testing
        options[:endpoint] = @config.token_storage_options[:endpoint] if @config.token_storage_options[:endpoint]

        options
      end

      # Validate that the DynamoDB table has the required schema
      def validate_table_schema
        table_description = @dynamodb.describe_table(table_name: @table_name)
        table = table_description.table

        # Check key schema
        key_schema = table.key_schema
        hash_key = key_schema.find { |k| k.key_type == "HASH" }

        unless hash_key&.attribute_name == "token_key"
          raise JDPIClient::Errors::ConfigurationError,
                "DynamoDB table must have 'token_key' as the hash key"
        end

        # Check for TTL attribute
        ttl_description = @dynamodb.describe_time_to_live(table_name: @table_name)
        ttl_status = ttl_description.time_to_live_description&.time_to_live_status

        if ttl_status != "ENABLED"
          @config.logger&.warn(
            "DynamoDB TTL is not enabled on table #{@table_name}. " \
            "Expired tokens will not be automatically removed."
          )
        end
      rescue Aws::DynamoDB::Errors::ResourceNotFoundException
        raise JDPIClient::Errors::ConfigurationError,
              "DynamoDB table '#{@table_name}' does not exist"
      end

      # Handle DynamoDB errors consistently
      # @param error [Exception] The error that occurred
      # @param operation [String] Description of the operation
      def handle_dynamodb_error(error, operation)
        error_message = "DynamoDB #{operation} failed: #{error.message}"

        @config.logger&.error(error_message)

        # Re-raise as appropriate JDPI client error
        case error
        when Aws::DynamoDB::Errors::ProvisionedThroughputExceededException
          raise JDPIClient::Errors::RateLimited, "DynamoDB throughput exceeded during #{operation}"
        when Aws::DynamoDB::Errors::ResourceNotFoundException
          raise JDPIClient::Errors::ConfigurationError, "DynamoDB table not found during #{operation}"
        when Aws::DynamoDB::Errors::ServiceError
          raise JDPIClient::Errors::ServerError, error_message
        else
          raise JDPIClient::Errors::ServerError, error_message
        end
      end
    end
  end
end
