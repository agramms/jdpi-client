# frozen_string_literal: true

require_relative "base"
require "multi_json"

module JDPIClient
  module TokenStorage
    # Database-based token storage adapter using ActiveRecord or raw SQL
    # Provides distributed token caching with database persistence
    class Database < Base
      DEFAULT_TABLE_NAME = "jdpi_client_tokens"
      LOCK_TIMEOUT = 30 # seconds
      CLEANUP_BATCH_SIZE = 1000

      def initialize(config)
        super
        @table_name = @config.token_storage_options[:table_name] || DEFAULT_TABLE_NAME
        @connection = establish_connection
        ensure_table_exists
      end

      # Store a token with the given key and expiration
      # @param key [String] The cache key for the token
      # @param token_data [Hash] Token data including access_token, expires_at, etc.
      # @param ttl [Integer] Time to live in seconds
      def store(key, token_data, ttl)
        # Encrypt token data if encryption is enabled
        data_to_store = encrypt_if_enabled(token_data)
        expires_at = Time.now + ttl

        token_record = {
          token_key: key,
          token_data: MultiJson.dump(data_to_store),
          expires_at: expires_at.utc.iso8601,
          created_at: Time.now.utc.iso8601,
          updated_at: Time.now.utc.iso8601
        }

        if active_record_available?
          upsert_with_active_record(token_record)
        else
          upsert_with_raw_sql(token_record)
        end

        true
      rescue => e
        handle_database_error(e, "store token")
        false
      end

      # Retrieve a token by key
      # @param key [String] The cache key for the token
      # @return [Hash, nil] Token data or nil if not found/expired
      def retrieve(key)
        if active_record_available?
          record = token_model.where(token_key: key)
                              .where("expires_at > ?", Time.now)
                              .first
          return nil unless record

          token_data = MultiJson.load(record.token_data)
        else
          result = @connection.execute(
            "SELECT token_data FROM #{@table_name} " \
            "WHERE token_key = ? AND expires_at > ?",
            [key, Time.now.utc.iso8601]
          )
          return nil if result.empty?

          # Handle both hash and array result formats
          raw_data = result.first.is_a?(Hash) ? result.first["token_data"] : result.first[0]
          token_data = MultiJson.load(raw_data)
        end

        decrypt_if_enabled(token_data)
      rescue => e
        handle_database_error(e, "retrieve token")
        nil
      end

      # Check if a token exists and is not expired
      # @param key [String] The cache key for the token
      # @return [Boolean] True if token exists and is valid
      def exists?(key)
        if active_record_available?
          token_model.where(token_key: key)
                     .where("expires_at > ?", Time.now)
                     .exists?
        else
          result = @connection.execute(
            "SELECT 1 FROM #{@table_name} " \
            "WHERE token_key = ? AND expires_at > ? LIMIT 1",
            [key, Time.now.utc.iso8601]
          )
          !result.empty?
        end
      rescue => e
        handle_database_error(e, "check token existence")
        false
      end

      # Delete a token by key
      # @param key [String] The cache key for the token
      def delete(key)
        if active_record_available?
          token_model.where(token_key: key).delete_all > 0
        else
          @connection.execute(
            "DELETE FROM #{@table_name} WHERE token_key = ?",
            [key]
          )
          @connection.changes > 0 # SQLite syntax, may vary by database
        end
      rescue => e
        handle_database_error(e, "delete token")
        false
      end

      # Clear all tokens (useful for testing)
      def clear_all
        prefix = @config.token_storage_key_prefix

        if active_record_available?
          token_model.where("token_key LIKE ?", "#{prefix}%").delete_all
        else
          @connection.execute(
            "DELETE FROM #{@table_name} WHERE token_key LIKE ?",
            ["#{prefix}%"]
          )
        end

        true
      rescue => e
        handle_database_error(e, "clear all tokens")
        false
      end

      # Health check for the storage backend
      # @return [Boolean] True if database is accessible
      def healthy?
        if active_record_available?
          token_model.connection.execute("SELECT 1")
        else
          @connection.execute("SELECT 1")
        end
        true
      rescue
        false
      end

      # Clean up expired tokens (should be run periodically)
      # @return [Integer] Number of tokens cleaned up
      def cleanup_expired_tokens
        deleted_count = 0

        if active_record_available?
          deleted_count = token_model.where("expires_at <= ?", Time.now).delete_all
        else
          @connection.execute(
            "DELETE FROM #{@table_name} WHERE expires_at <= ?",
            [Time.now.utc.iso8601]
          )
          deleted_count = @connection.changes
        end

        deleted_count
      rescue => e
        handle_database_error(e, "cleanup expired tokens")
        0
      end

      # Acquire a distributed lock using database transactions
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time in seconds
      # @return [Boolean] True if lock was acquired
      def acquire_lock(key, ttl = LOCK_TIMEOUT)
        lock_key = "#{key}:lock"
        lock_expires_at = Time.now + ttl

        if active_record_available?
          acquire_lock_with_active_record(lock_key, lock_expires_at)
        else
          acquire_lock_with_raw_sql(lock_key, lock_expires_at)
        end
      rescue => e
        handle_database_error(e, "acquire lock")
        false
      end

      # Release a distributed lock
      # @return [Boolean] True if lock was released
      def release_lock
        return false unless @current_lock_key

        success = delete(@current_lock_key)
        @current_lock_key = nil
        success
      end

      # Execute a block with a distributed lock
      # @param key [String] The lock key
      # @param ttl [Integer] Lock expiration time in seconds
      # @yield Block to execute with lock
      def with_lock(key, ttl = LOCK_TIMEOUT)
        retries = 0
        max_retries = 30 # 3 seconds with 0.1s sleep

        loop do
          if acquire_lock(key, ttl)
            begin
              return yield
            ensure
              release_lock
            end
          end

          retries += 1
          if retries >= max_retries
            raise JDPIClient::Errors::ServerError, "Could not acquire database lock after #{max_retries} retries"
          end

          sleep(0.1)
        end
      end

      # Get database storage statistics
      # @return [Hash] Storage statistics
      def stats
        if active_record_available?
          total_count = token_model.count
          expired_count = token_model.where("expires_at <= ?", Time.now).count
          active_count = total_count - expired_count
        else
          total_result = @connection.execute("SELECT COUNT(*) FROM #{@table_name}")
          expired_result = @connection.execute(
            "SELECT COUNT(*) FROM #{@table_name} WHERE expires_at <= ?",
            [Time.now.utc.iso8601]
          )

          # Handle both hash and array result formats
          total_count = total_result.first.is_a?(Hash) ? total_result.first["COUNT(*)"] : total_result.first[0]
          expired_count = expired_result.first.is_a?(Hash) ? expired_result.first["COUNT(*)"] : expired_result.first[0]
          active_count = total_count - expired_count
        end

        {
          table_name: @table_name,
          total_tokens: total_count,
          active_tokens: active_count,
          expired_tokens: expired_count,
          encryption_enabled: @config.token_encryption_enabled?,
          database_adapter: database_adapter_name
        }
      rescue => e
        handle_database_error(e, "get stats")
        { error: e.message }
      end

      private

      # Establish database connection
      def establish_connection
        if active_record_available?
          # Use existing ActiveRecord connection
          ActiveRecord::Base.connection
        else
          # Fall back to SQLite for simple cases
          establish_sqlite_connection
        end
      rescue => e
        raise JDPIClient::Errors::ConfigurationError,
              "Database connection error: #{e.message}"
      end

      # Check if ActiveRecord is available
      # @return [Boolean] True if ActiveRecord is loaded
      def active_record_available?
        defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
      end

      # Establish SQLite connection as fallback
      def establish_sqlite_connection
        begin
          require "sqlite3"
        rescue LoadError
          raise JDPIClient::Errors::ConfigurationError,
                "SQLite3 gem is required for database token storage when ActiveRecord is not available. " \
                "Add 'gem \"sqlite3\"' to your Gemfile or configure ActiveRecord."
        end

        # Handle different URL formats
        if @config.token_storage_url&.start_with?("sqlite3://")
          # Parse sqlite3:// URLs
          path = @config.token_storage_url.sub("sqlite3://", "")
          path = ":memory:" if path.empty? || path == "/:memory:"
          SQLite3::Database.new(path)
        else
          # Use configured path or default file
          db_path = @config.token_storage_options[:database_path] || "jdpi_tokens.db"
          SQLite3::Database.new(db_path)
        end
      end

      # Get ActiveRecord model for token storage
      def token_model
        @token_model ||= Class.new(ActiveRecord::Base) do
          self.table_name = @table_name
        end
      end

      # Create table if it doesn't exist
      def ensure_table_exists
        if active_record_available?
          ensure_table_exists_with_active_record
        else
          ensure_table_exists_with_sqlite
        end
      end

      # Ensure table exists using ActiveRecord migrations
      def ensure_table_exists_with_active_record
        return if ActiveRecord::Base.connection.table_exists?(@table_name)

        ActiveRecord::Base.connection.create_table(@table_name) do |t|
          t.string :token_key, null: false, limit: 255
          t.text :token_data, null: false
          t.datetime :expires_at, null: false
          t.timestamps null: false
        end

        ActiveRecord::Base.connection.add_index(@table_name, :token_key, unique: true)
        ActiveRecord::Base.connection.add_index(@table_name, :expires_at)
      end

      # Ensure table exists using raw SQLite
      def ensure_table_exists_with_sqlite
        @connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS #{@table_name} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            token_key VARCHAR(255) NOT NULL UNIQUE,
            token_data TEXT NOT NULL,
            expires_at DATETIME NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
          )
        SQL

        @connection.execute("CREATE INDEX IF NOT EXISTS idx_#{@table_name}_expires_at ON #{@table_name}(expires_at)")
      end

      # Upsert token using ActiveRecord
      def upsert_with_active_record(token_record)
        # Use upsert if available (Rails 6+), otherwise use find_or_initialize_by
        if token_model.respond_to?(:upsert)
          token_model.upsert(token_record)
        else
          record = token_model.find_or_initialize_by(token_key: token_record[:token_key])
          record.assign_attributes(token_record)
          record.save!
        end
      end

      # Upsert token using raw SQL
      def upsert_with_raw_sql(token_record)
        @connection.execute(<<~SQL, token_record.values)
          INSERT OR REPLACE INTO #{@table_name}
          (token_key, token_data, expires_at, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?)
        SQL
      end

      # Acquire lock using ActiveRecord
      def acquire_lock_with_active_record(lock_key, lock_expires_at)
        token_model.transaction do
          # Try to create lock record
          existing_lock = token_model.find_by(token_key: lock_key)

          if existing_lock&.expires_at && existing_lock.expires_at > Time.now
            return false # Lock still active
          end

          # Create or update lock
          lock_record = {
            token_key: lock_key,
            token_data: MultiJson.dump({ lock: true }),
            expires_at: lock_expires_at,
            created_at: Time.now.utc.iso8601,
            updated_at: Time.now.utc.iso8601
          }

          if existing_lock
            existing_lock.update!(lock_record)
          else
            token_model.create!(lock_record)
          end

          @current_lock_key = lock_key
          true
        end
      end

      # Acquire lock using raw SQL
      def acquire_lock_with_raw_sql(lock_key, lock_expires_at)
        # Clean up expired lock first
        @connection.execute(
          "DELETE FROM #{@table_name} WHERE token_key = ? AND expires_at <= ?",
          [lock_key, Time.now.utc.iso8601]
        )

        # Try to insert new lock
        begin
          @connection.execute(<<~SQL, [lock_key, MultiJson.dump({ lock: true }), lock_expires_at.utc.iso8601, Time.now.utc.iso8601, Time.now.utc.iso8601])
            INSERT INTO #{@table_name}
            (token_key, token_data, expires_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
          SQL

          @current_lock_key = lock_key
          true
        rescue SQLite3::ConstraintException
          false # Lock already exists
        end
      end

      # Get database adapter name
      def database_adapter_name
        if active_record_available?
          ActiveRecord::Base.connection.adapter_name
        else
          "SQLite"
        end
      end

      # Get connection error classes that might be available
      def connection_error_classes
        classes = []
        classes << ActiveRecord::ConnectionNotEstablished if defined?(ActiveRecord::ConnectionNotEstablished)
        classes << SQLite3::BusyException if defined?(SQLite3::BusyException)
        classes << PG::ConnectionBad if defined?(PG::ConnectionBad)
        classes
      end

      # Get constraint error classes that might be available
      def constraint_error_classes
        classes = []
        classes << ActiveRecord::RecordNotUnique if defined?(ActiveRecord::RecordNotUnique)
        classes << SQLite3::ConstraintException if defined?(SQLite3::ConstraintException)
        classes << PG::UniqueViolation if defined?(PG::UniqueViolation)
        classes
      end

      # Handle database errors consistently
      # @param error [Exception] The error that occurred
      # @param operation [String] Description of the operation
      def handle_database_error(error, operation)
        error_message = "Database #{operation} failed: #{error.message}"

        if @config.logger
          @config.logger.error(error_message)
        end

        # Re-raise as appropriate JDPI client error
        connection_errors = connection_error_classes
        constraint_errors = constraint_error_classes

        if connection_errors.any? { |klass| error.is_a?(klass) }
          raise JDPIClient::Errors::ServerError, "Database connection lost during #{operation}"
        elsif constraint_errors.any? { |klass| error.is_a?(klass) }
          # This is expected for lock contention
          raise error
        else
          raise JDPIClient::Errors::ServerError, error_message
        end
      end
    end
  end
end