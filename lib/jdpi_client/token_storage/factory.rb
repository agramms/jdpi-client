# frozen_string_literal: true

module JDPIClient
  module TokenStorage
    # Factory for creating token storage adapters based on configuration
    class Factory
      class << self
        # Create a token storage adapter based on configuration
        # @param config [JDPIClient::Config] Configuration object
        # @return [JDPIClient::TokenStorage::Base] Storage adapter instance
        def create(config)
          unless config.respond_to?(:validate_token_storage_config!)
            raise ArgumentError, "Expected JDPIClient::Config object, got #{config.class}"
          end

          config.validate_token_storage_config!

          case config.token_storage_adapter
          when :memory
            require_relative "memory"
            Memory.new(config)
          when :redis
            require_relative "redis"
            Redis.new(config)
          when :dynamodb
            require_relative "dynamodb"
            DynamoDB.new(config)
          when :database
            require_relative "database"
            Database.new(config)
          else
            raise JDPIClient::Errors::ConfigurationError,
                  "Unknown token storage adapter: #{config.token_storage_adapter}. " \
                  "Supported adapters: :memory, :redis, :dynamodb, :database"
          end
        end

        # Get list of available storage adapters
        # @return [Array<Symbol>] Available adapter names
        def available_adapters
          %i[memory redis dynamodb database]
        end

        # Check if an adapter is available (dependencies installed)
        # @param adapter [Symbol] Adapter name to check
        # @return [Boolean] True if adapter dependencies are available
        def adapter_available?(adapter)
          case adapter
          when :memory
            true # Always available
          when :redis
            redis_available?
          when :dynamodb
            dynamodb_available?
          when :database
            database_available?
          else
            false
          end
        end

        # Get information about all adapters
        # @return [Hash] Adapter information
        def adapter_info
          {
            memory: {
              available: true,
              description: "In-memory storage (not shared across instances)",
              dependencies: [],
              use_cases: ["Development", "Single instance deployments", "Testing"]
            },
            redis: {
              available: redis_available?,
              description: "Redis-based distributed storage",
              dependencies: ["redis"],
              use_cases: ["Clustered applications", "High performance", "Auto-expiration"]
            },
            dynamodb: {
              available: dynamodb_available?,
              description: "AWS DynamoDB distributed storage",
              dependencies: ["aws-sdk-dynamodb"],
              use_cases: ["AWS environments", "Serverless applications", "Global distribution"]
            },
            database: {
              available: database_available?,
              description: "SQL database storage (ActiveRecord or SQLite)",
              dependencies: ["sqlite3 (fallback)", "activerecord (optional)"],
              use_cases: ["Existing database infrastructure", "Transactional consistency", "Complex queries"]
            }
          }
        end

        private

        # Check if Redis dependencies are available
        # @return [Boolean] True if Redis gem is available
        def redis_available?
          require "redis"
          true
        rescue LoadError
          false
        end

        # Check if DynamoDB dependencies are available
        # @return [Boolean] True if AWS SDK is available
        def dynamodb_available?
          require "aws-sdk-dynamodb"
          true
        rescue LoadError
          false
        end

        # Check if database dependencies are available
        # @return [Boolean] True if database dependencies are available
        def database_available?
          # Check for ActiveRecord first
          return true if defined?(ActiveRecord::Base)

          # Fall back to SQLite
          require "sqlite3"
          true
        rescue LoadError
          false
        end
      end
    end
  end
end
