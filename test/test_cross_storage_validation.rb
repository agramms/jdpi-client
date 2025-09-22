# frozen_string_literal: true

require "test_helper"

class TestCrossStorageValidation < Minitest::Test
  include ServiceConfiguration

  def setup
    @base_config = create_test_config(:memory)
    @test_client_id = "cross_storage_test_client"
    @test_scopes = %w[auth_apim dict_api spi_api]

    # Common test token data
    @test_token = {
      "access_token" => "cross_storage_test_token_12345",
      "token_type" => "Bearer",
      "expires_in" => 3600,
      "scope" => @test_scopes.join(" "),
      "created_at" => Time.now.utc.iso8601
    }

    @sensitive_token = {
      "access_token" => "very_secret_cross_storage_token",
      "refresh_token" => "very_secret_refresh_token",
      "scope" => "admin:all sensitive:data",
      "user_id" => "sensitive_user_123"
    }

    # Set up different storage configurations
    setup_storage_configs
  end

  def teardown
    # Clean up all storage backends
    [@memory_storage, @database_storage].compact.each do |storage|
      storage.clear_all if storage.respond_to?(:clear_all)
    rescue StandardError
      # Ignore cleanup errors
    end
  end

  # Test cache key consistency across all storage types
  def test_cache_key_consistency_across_storages
    scope_combinations = [
      ["auth_apim"],
      %w[auth_apim dict_api],
      %w[auth_apim spi_api qrcode_api],
      %w[auth_apim dict_api spi_api qrcode_api]
    ]

    scope_combinations.each do |scopes|
      # Generate cache key using scope manager
      cache_key1 = JDPIClient::Auth::ScopeManager.cache_key(@test_client_id, scopes, @base_config)
      cache_key2 = JDPIClient::Auth::ScopeManager.cache_key(@test_client_id, scopes.dup, @base_config)

      # Same scopes should generate identical cache keys
      assert_equal cache_key1, cache_key2, "Cache keys should be identical for same scopes"

      # Different scope orders should generate same cache key (normalization)
      shuffled_scopes = scopes.shuffle
      cache_key3 = JDPIClient::Auth::ScopeManager.cache_key(@test_client_id, shuffled_scopes, @base_config)
      assert_equal cache_key1, cache_key3, "Cache keys should be identical regardless of scope order"

      # Verify cache key structure
      assert_includes cache_key1, @base_config.token_storage_key_prefix
      assert_includes cache_key1, @test_client_id

      debug_log("✅ Cache key consistency verified for scopes: #{scopes.join(', ')}")
    end
  end

  # Test scope fingerprint uniqueness and consistency
  def test_scope_fingerprint_uniqueness
    scope_sets = [
      ["auth_apim"],
      %w[auth_apim dict_api],
      %w[auth_apim spi_api],
      %w[auth_apim qrcode_api],
      %w[auth_apim dict_api spi_api],
      %w[auth_apim dict_api qrcode_api],
      %w[auth_apim spi_api qrcode_api],
      %w[auth_apim dict_api spi_api qrcode_api]
    ]

    fingerprints = {}

    scope_sets.each do |scopes|
      normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
      fingerprint = JDPIClient::Auth::ScopeManager.scope_fingerprint(normalized)

      # Fingerprint should be consistent
      fingerprint2 = JDPIClient::Auth::ScopeManager.scope_fingerprint(normalized)
      assert_equal fingerprint, fingerprint2

      # Fingerprint should be 16 characters (SHA256 first 16 chars)
      assert_equal 16, fingerprint.length
      assert_match(/^[a-f0-9]{16}$/, fingerprint)

      # Should be unique for different scope combinations
      if fingerprints.key?(fingerprint)
        flunk "Scope fingerprint collision detected: #{scopes.join(', ')} vs #{fingerprints[fingerprint].join(', ')}"
      end

      fingerprints[fingerprint] = scopes
      debug_log("✅ Scope fingerprint #{fingerprint} for: #{scopes.join(', ')}")
    end

    # Verify we have unique fingerprints for all combinations
    assert_equal scope_sets.length, fingerprints.length, "All scope combinations should have unique fingerprints"
  end

  # Test encryption consistency across storage backends
  def test_encryption_consistency_across_backends
    return unless @base_config.token_encryption_enabled?

    storage_backends = {
      memory: @memory_storage,
      database: @database_storage
    }.compact # Remove nil storage backends

    test_key = "cross_storage_encryption_test_#{SecureRandom.hex(8)}"

    storage_backends.each do |backend_name, storage|
      # Skip if storage doesn't have encryption enabled
      storage_config = storage.instance_variable_get(:@config)
      next unless storage_config&.token_encryption_enabled?

      # Store encrypted token
      result = storage.store(test_key, @sensitive_token, 3600)
      assert result, "Failed to store token in #{backend_name} storage"

      # Retrieve and verify decryption
      retrieved = storage.retrieve(test_key)
      assert_equal @sensitive_token, retrieved, "Encryption/decryption mismatch in #{backend_name} storage"

      # Verify token exists
      assert storage.exists?(test_key), "Token should exist in #{backend_name} storage"

      # Clean up
      assert storage.delete(test_key), "Failed to delete token from #{backend_name} storage"
      refute storage.exists?(test_key), "Token should not exist after deletion in #{backend_name} storage"

      debug_log("✅ Encryption consistency verified for #{backend_name} storage")
    end
  end

  # Test data serialization consistency
  def test_data_serialization_consistency
    complex_token = {
      "access_token" => "complex_test_token",
      "metadata" => {
        "created_by" => "test_suite",
        "features" => %w[feature1 feature2],
        "config" => {
          "timeout" => 300,
          "retries" => 3,
          "encrypted" => true
        }
      },
      "timestamps" => {
        "created_at" => Time.now.utc.iso8601,
        "expires_at" => (Time.now + 3600).utc.iso8601
      },
      "scope" => @test_scopes.join(" ")
    }

    storage_backends = {
      memory: @memory_storage,
      database: @database_storage
    }.compact # Remove nil storage backends

    test_key = "serialization_test_#{SecureRandom.hex(8)}"

    storage_backends.each do |backend_name, storage|
      next unless storage # Skip if storage is not available

      # Store complex token
      result = storage.store(test_key, complex_token, 3600)
      assert result, "Failed to store complex token in #{backend_name}"

      # Retrieve and verify structure
      retrieved = storage.retrieve(test_key)
      assert_equal complex_token, retrieved, "Serialization mismatch in #{backend_name}"

      # Verify nested structures
      assert_equal complex_token["metadata"]["features"], retrieved["metadata"]["features"]
      assert_equal complex_token["metadata"]["config"]["timeout"], retrieved["metadata"]["config"]["timeout"]

      # Clean up
      storage.delete(test_key)

      debug_log("✅ Data serialization consistency verified for #{backend_name} storage")
    end
  end

  # Test TTL behavior consistency
  def test_ttl_behavior_consistency
    storage_backends = {
      memory: @memory_storage,
      database: @database_storage
    }

    storage_backends.each do |backend_name, storage|
      # Test normal TTL
      normal_key = "ttl_normal_#{backend_name}_#{SecureRandom.hex(4)}"
      storage.store(normal_key, @test_token, 3600)
      assert storage.exists?(normal_key), "Token with normal TTL should exist in #{backend_name}"

      # Test short TTL
      short_key = "ttl_short_#{backend_name}_#{SecureRandom.hex(4)}"
      storage.store(short_key, @test_token, 1)
      assert storage.exists?(short_key), "Token with short TTL should initially exist in #{backend_name}"

      # Wait for expiration
      sleep(1.5)
      refute storage.exists?(short_key), "Token with short TTL should expire in #{backend_name}"
      assert_nil storage.retrieve(short_key), "Expired token should return nil in #{backend_name}"

      # Test zero TTL
      zero_key = "ttl_zero_#{backend_name}_#{SecureRandom.hex(4)}"
      storage.store(zero_key, @test_token, 0)
      sleep(0.1)
      refute storage.exists?(zero_key), "Token with zero TTL should immediately expire in #{backend_name}"

      # Clean up
      storage.delete(normal_key)

      debug_log("✅ TTL behavior consistency verified for #{backend_name} storage")
    end
  end

  # Test scope compatibility checking
  def test_scope_compatibility_checking
    test_cases = [
      {
        token_scopes: %w[auth_apim dict_api spi_api],
        requested_scopes: %w[auth_apim dict_api],
        compatible: true,
        description: "subset scopes should be compatible"
      },
      {
        token_scopes: %w[auth_apim dict_api],
        requested_scopes: %w[auth_apim dict_api spi_api],
        compatible: false,
        description: "superset scopes should not be compatible"
      },
      {
        token_scopes: %w[auth_apim dict_api],
        requested_scopes: %w[auth_apim dict_api],
        compatible: true,
        description: "identical scopes should be compatible"
      },
      {
        token_scopes: %w[auth_apim spi_api],
        requested_scopes: %w[auth_apim dict_api],
        compatible: false,
        description: "different scopes should not be compatible"
      }
    ]

    test_cases.each do |test_case|
      result = JDPIClient::Auth::ScopeManager.scopes_compatible?(
        test_case[:token_scopes],
        test_case[:requested_scopes]
      )

      assert_equal test_case[:compatible], result, test_case[:description]
      debug_log("✅ Scope compatibility: #{test_case[:description]} - #{result ? 'compatible' : 'incompatible'}")
    end
  end

  # Test storage statistics consistency
  def test_storage_statistics_consistency
    storage_backends = {
      memory: @memory_storage,
      database: @database_storage
    }

    storage_backends.each do |backend_name, storage|
      next unless storage.respond_to?(:stats)

      # Add some test data
      3.times do |i|
        key = "stats_test_#{backend_name}_#{i}_#{SecureRandom.hex(4)}"
        storage.store(key, @test_token, 3600)
      end

      # Get statistics
      stats = storage.stats
      assert_instance_of Hash, stats, "Stats should return a hash for #{backend_name}"

      # Common statistics fields that should exist
      case backend_name
      when :memory
        assert_includes stats, :total_tokens
        assert_includes stats, :encryption_enabled
      when :database
        assert_includes stats, :table_name
        assert_includes stats, :total_tokens
        assert_includes stats, :active_tokens
        assert_includes stats, :database_adapter
      end

      debug_log("✅ Storage statistics consistency verified for #{backend_name}: #{stats.keys.join(', ')}")
    end
  end

  # Test error handling consistency across storages
  def test_error_handling_consistency
    storage_backends = {
      memory: @memory_storage,
      database: @database_storage
    }

    storage_backends.each do |backend_name, storage|
      # Test retrieving non-existent key
      result = storage.retrieve("nonexistent_#{SecureRandom.hex(8)}")
      assert_nil result, "Non-existent key should return nil in #{backend_name}"

      # Test checking existence of non-existent key
      exists_result = storage.exists?("nonexistent_#{SecureRandom.hex(8)}")
      refute exists_result, "Non-existent key should return false for exists? in #{backend_name}"

      # Test deleting non-existent key
      delete_result = storage.delete("nonexistent_#{SecureRandom.hex(8)}")
      # Memory storage returns true even for non-existent keys, database returns false
      if backend_name == :memory
        # Memory storage doesn't track if key existed before deletion
        assert [true, false].include?(delete_result), "Delete result should be boolean in #{backend_name}"
      else
        refute delete_result, "Deleting non-existent key should return false in #{backend_name}"
      end

      debug_log("✅ Error handling consistency verified for #{backend_name} storage")
    end
  end

  # Test cache key prefix isolation
  def test_cache_key_prefix_isolation
    # Create configs with different prefixes
    config1 = @base_config.dup
    config1.token_scope_prefix = "prefix1"

    config2 = @base_config.dup
    config2.token_scope_prefix = "prefix2"

    # Generate cache keys with different prefixes
    key1 = JDPIClient::Auth::ScopeManager.cache_key(@test_client_id, @test_scopes, config1)
    key2 = JDPIClient::Auth::ScopeManager.cache_key(@test_client_id, @test_scopes, config2)

    # Keys should be different due to different prefixes
    refute_equal key1, key2, "Different prefixes should generate different cache keys"

    # Verify prefix is included
    assert_includes key1, "prefix1"
    assert_includes key2, "prefix2"

    # Test storage isolation
    storage = @memory_storage

    # Store tokens with different prefixed keys
    storage.store(key1, @test_token.merge("prefix" => "one"), 3600)
    storage.store(key2, @test_token.merge("prefix" => "two"), 3600)

    # Verify isolation
    token1 = storage.retrieve(key1)
    token2 = storage.retrieve(key2)

    assert_equal "one", token1["prefix"]
    assert_equal "two", token2["prefix"]

    debug_log("✅ Cache key prefix isolation verified")
  end

  private

  def setup_storage_configs
    # Memory storage (always available)
    @memory_storage = JDPIClient::TokenStorage::Memory.new(@base_config)

    # Database storage (SQLite)
    begin
      database_config = create_database_config("sqlite3:///:memory:")
      @database_storage = JDPIClient::TokenStorage::Database.new(database_config)
    rescue StandardError => e
      @database_storage = nil
      debug_log("⚠️  Database storage not available: #{e.message}")
    end

    # NOTE: Redis and DynamoDB would require more complex mocking setup
    # for cross-storage tests, so we focus on Memory and Database here
  end
end
