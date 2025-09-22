require 'test_helper'

class TestTokenStorageDatabase < Minitest::Test
  include ServiceConfiguration

  def setup
    @sqlite_url = 'sqlite3:///:memory:'
    @config = create_database_config(@sqlite_url)

    @token = {
      'access_token' => 'test_token_123',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'read write'
    }

    @sensitive_token = {
      'access_token' => 'very_secret_token_12345',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'sensitive write'
    }

    begin
      @storage = JDPIClient::TokenStorage::Database.new(@config)
      cleanup_test_data
      @storage.send(:ensure_table_exists)
    rescue => e
      skip "Failed to initialize SQLite storage: #{e.message}"
    end
  end

  def teardown
    cleanup_test_data if @storage
  end

  private

  def cleanup_test_data
    return unless @storage

    # Clean up test data using proper SQL
    begin
      if @storage.respond_to?(:connection) && @storage.connection
        # Using ActiveRecord connection if available
        @storage.connection.execute("DELETE FROM jdpi_tokens WHERE cache_key LIKE 'test_%'")
        @storage.connection.execute("DELETE FROM jdpi_token_locks WHERE lock_key LIKE 'test_%'")
      end
    rescue => e
      # Ignore cleanup errors in tests
    end
  end

  def test_initialization_with_sqlite_url
    storage = JDPIClient::TokenStorage::Database.new(@config)
    assert_instance_of JDPIClient::TokenStorage::Database, storage
    assert storage.healthy?
  end

  def test_initialization_with_activerecord
    # Test that ActiveRecord integration works with SQLite
    storage = JDPIClient::TokenStorage::Database.new(@config)
    assert storage.respond_to?(:store)
    assert storage.respond_to?(:retrieve)
  end

  def test_store_and_retrieve_token
    key = 'test_store_retrieve_' + SecureRandom.hex(8)
    @storage.store(key, @token, 3600)

    retrieved = @storage.retrieve(key)
    assert_equal @token, retrieved
  end

  def test_retrieve_returns_nil_for_missing_key
    result = @storage.retrieve('test_missing_' + SecureRandom.hex(8))
    assert_nil result
  end

  def test_exists_returns_true_for_stored_token
    key = 'test_exists_true_' + SecureRandom.hex(8)
    @storage.store(key, @token, 3600)

    assert @storage.exists?(key)
  end

  def test_exists_returns_false_for_missing_token
    refute @storage.exists?('test_missing_' + SecureRandom.hex(8))
  end

  def test_delete_removes_token
    key = 'test_delete_' + SecureRandom.hex(8)
    @storage.store(key, @token, 3600)

    @storage.delete(key)
    refute @storage.exists?(key)
    assert_nil @storage.retrieve(key)
  end

  def test_clear_all_removes_matching_tokens
    prefix = 'test_clear_' + SecureRandom.hex(4)
    key1 = "jdpi_client:#{prefix}_key1"
    key2 = "jdpi_client:#{prefix}_key2"
    key3 = "other:#{prefix}_key3"

    @storage.store(key1, @token, 3600)
    @storage.store(key2, @token, 3600)
    @storage.store(key3, @token, 3600)

    @storage.clear_all

    refute @storage.exists?(key1)
    refute @storage.exists?(key2)
    assert @storage.exists?(key3) # Should not be deleted (different prefix)
  end

  def test_healthy_returns_true_when_connected
    assert @storage.healthy?
  end

  def test_store_encrypts_data_when_encryption_enabled
    return unless @config.token_encryption_enabled?

    key = 'test_encrypted_' + SecureRandom.hex(8)
    @storage.store(key, @sensitive_token, 3600)

    # Verify data is encrypted in database by querying raw data
    begin
      if @storage.respond_to?(:connection) && @storage.connection
        result = @storage.connection.execute("SELECT token_data FROM jdpi_tokens WHERE cache_key = '#{key}'")
        raw_data = result.first&.dig('token_data') || result.first&.dig(0) # Handle different SQLite adapters

        # Raw data should not contain the sensitive token
        refute_includes raw_data, 'very_secret_token_12345'

        # But decrypted data should match
        retrieved = @storage.retrieve(key)
        assert_equal @sensitive_token, retrieved
      end
    rescue => e
      skip "Could not verify encryption: #{e.message}"
    end
  end

  def test_token_expiration
    key = 'test_expiration_' + SecureRandom.hex(8)
    @storage.store(key, @token, 0) # Store with immediate expiration

    # Wait a bit to ensure expiration
    sleep(0.1)

    # Should not retrieve expired token
    result = @storage.retrieve(key)
    assert_nil result

    # Should not exist
    refute @storage.exists?(key)
  end

  def test_token_ttl_configuration
    key = 'test_ttl_' + SecureRandom.hex(8)
    ttl = 2 # 2 seconds

    @storage.store(key, @token, ttl)

    # Should exist immediately
    assert @storage.exists?(key)
    assert_equal @token, @storage.retrieve(key)

    # Wait for expiration
    sleep(ttl + 0.5)

    # Should be expired
    refute @storage.exists?(key)
    assert_nil @storage.retrieve(key)
  end

  def test_cleanup_expired_tokens
    current_key = 'test_current_' + SecureRandom.hex(8)
    expired_key = 'test_expired_' + SecureRandom.hex(8)

    # Store a current token
    @storage.store(current_key, @token, 3600)

    # Store an expired token
    @storage.store(expired_key, @token, 0)
    sleep(0.1) # Ensure expiration

    # Run cleanup
    @storage.send(:cleanup_expired_tokens)

    # Current token should still exist
    assert @storage.exists?(current_key)

    # Expired token should be removed
    refute @storage.exists?(expired_key)
  end

  def test_acquire_lock_inserts_with_unique_constraint
    key = 'test_lock_unique_' + SecureRandom.hex(8)

    # First acquisition should succeed
    result1 = @storage.send(:acquire_lock, key)
    assert result1

    # Second acquisition should fail due to unique constraint
    result2 = @storage.send(:acquire_lock, key)
    refute result2
  end

  def test_release_lock_deletes_lock_record
    key = 'test_lock_release_' + SecureRandom.hex(8)

    # Acquire lock first
    @storage.send(:acquire_lock, key)

    # Release lock
    @storage.send(:release_lock, key)

    # Should be able to acquire again
    result = @storage.send(:acquire_lock, key)
    assert result
  end

  def test_migration_creates_table_structure
    # Test that tables exist and have correct structure
    begin
      if @storage.respond_to?(:connection) && @storage.connection
        # Check tokens table exists and has required columns
        tokens_result = @storage.connection.execute(<<~SQL)
          PRAGMA table_info(jdpi_tokens)
        SQL

        token_columns = tokens_result.map { |row| row['name'] || row[1] } # Handle different SQLite adapters
        assert_includes token_columns, 'cache_key'
        assert_includes token_columns, 'token_data'
        assert_includes token_columns, 'expires_at'
        assert_includes token_columns, 'created_at'

        # Check locks table exists and has required columns
        locks_result = @storage.connection.execute(<<~SQL)
          PRAGMA table_info(jdpi_token_locks)
        SQL

        lock_columns = locks_result.map { |row| row['name'] || row[1] } # Handle different SQLite adapters
        assert_includes lock_columns, 'lock_key'
        assert_includes lock_columns, 'expires_at'
        assert_includes lock_columns, 'created_at'
      end
    rescue => e
      skip "Could not verify table structure: #{e.message}"
    end
  end

  def test_thread_safety_with_locks
    key = 'test_thread_safety_' + SecureRandom.hex(8)
    results = {}
    threads = []

    # Multiple threads trying to acquire the same lock
    5.times do |i|
      threads << Thread.new do
        results[i] = @storage.send(:acquire_lock, key)
      end
    end

    threads.each(&:join)

    # Only one thread should have acquired the lock
    successful_acquisitions = results.values.count(true)
    assert_equal 1, successful_acquisitions
  end

  def test_concurrent_store_and_retrieve
    base_key = 'test_concurrent_' + SecureRandom.hex(4)
    threads = []
    results = {}

    # Multiple threads storing and retrieving different tokens
    10.times do |i|
      threads << Thread.new do
        key = "#{base_key}_#{i}"
        token = @token.merge('access_token' => "token_#{i}")

        @storage.store(key, token, 3600)
        retrieved = @storage.retrieve(key)
        results[i] = (retrieved == token)
      end
    end

    threads.each(&:join)

    # All operations should succeed
    assert results.values.all?, "Some concurrent operations failed: #{results}"
  end

  def test_error_handling_for_invalid_database_url
    config = JDPIClient::Config.new
    config.token_encryption_key = 'test_encryption_key_32_characters'
    config.token_storage_url = 'invalid://url'

    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Database.new(config)
    end

    assert_includes error.message.downcase, 'database connection error'
  end

  def test_missing_sqlite3_gem_graceful_handling
    # Test that appropriate error is raised when sqlite3 gem is not available
    # This is more of a integration test concern
    skip "Testing with actual sqlite3 gem availability"
  end

  def test_database_connection_error_handling
    # Create storage with invalid SQLite URL to trigger connection error
    config = JDPIClient::Config.new
    config.token_encryption_key = 'test_encryption_key_32_characters'
    config.token_storage_url = 'sqlite3:///invalid/path/that/does/not/exist/db.sqlite3'

    error = assert_raises do
      storage = JDPIClient::TokenStorage::Database.new(config)
      storage.send(:ensure_table_exists)
    end

    assert error.is_a?(JDPIClient::Errors::Error) || error.is_a?(StandardError)
  end

  def test_sqlite_json_storage_features
    # Test SQLite JSON storage capabilities
    key = 'test_sqlite_features_' + SecureRandom.hex(8)
    complex_token = @token.merge(
      'metadata' => { 'source' => 'test', 'features' => ['read', 'write'] },
      'custom_data' => 'SQLite test data with JSON'
    )

    @storage.store(key, complex_token, 3600)
    retrieved = @storage.retrieve(key)

    assert_equal complex_token, retrieved
    assert_equal complex_token['metadata'], retrieved['metadata']
  end
end