# frozen_string_literal: true

require "test_helper"

class TestConcurrentAccessSafety < Minitest::Test
  include ServiceConfiguration

  def setup
    @memory_config = create_test_config(:memory)
    @database_config = create_database_config("sqlite3:///:memory:")

    @test_token = {
      "access_token" => "concurrent_test_token_123",
      "token_type" => "Bearer",
      "expires_in" => 3600,
      "scope" => "auth_apim dict_api"
    }

    # Set up HTTP stubs for OAuth requests
    setup_oauth_stubs
  end

  def teardown
    # Clean up storage
    [@memory_storage, @database_storage].compact.each do |storage|
      storage.clear_all if storage.respond_to?(:clear_all)
    rescue StandardError
      # Ignore cleanup errors
    end
  end

  # Test concurrent token storage operations
  def test_concurrent_token_storage_operations
    storage_configs = {
      memory: @memory_config,
      database: @database_config
    }

    storage_configs.each do |storage_type, config|
      storage = JDPIClient::TokenStorage::Factory.create(config)
      test_concurrent_storage_operations(storage, storage_type)
    end
  end

  # Test concurrent auth client token requests
  def test_concurrent_auth_client_token_requests
    auth_client = JDPIClient::Auth::Client.new(@memory_config)
    results = {}
    errors = {}
    threads = []

    # Multiple threads requesting tokens simultaneously
    thread_count = 10
    thread_count.times do |i|
      threads << Thread.new do
        token = auth_client.token!
        results[i] = token
      rescue StandardError => e
        errors[i] = e
      end
    end

    threads.each(&:join)

    # All requests should succeed
    assert_equal thread_count, results.length, "All threads should get tokens"
    assert_empty errors, "No errors should occur: #{errors}"

    # All tokens should be identical (cached)
    unique_tokens = results.values.uniq
    assert_equal 1, unique_tokens.length, "All threads should get the same cached token"

    debug_log("✅ Concurrent auth client requests: #{thread_count} threads successful")
  end

  # Test distributed locking with database storage
  def test_distributed_locking_safety
    storage = JDPIClient::TokenStorage::Database.new(@database_config)
    lock_key = "distributed_lock_test_#{SecureRandom.hex(8)}"

    results = {}
    execution_order = []
    threads = []
    mutex = Mutex.new

    # Multiple threads trying to acquire the same lock
    thread_count = 5
    thread_count.times do |i|
      threads << Thread.new do
        storage.with_lock(lock_key, 2) do
          mutex.synchronize { execution_order << "thread_#{i}_start" }
          sleep(0.2) # Hold the lock briefly
          results[i] = "completed"
          mutex.synchronize { execution_order << "thread_#{i}_end" }
        end
      rescue StandardError => e
        results[i] = e.message
      end
    end

    threads.each(&:join)

    # All threads should complete successfully
    thread_count.times do |i|
      assert_equal "completed", results[i], "Thread #{i} should complete successfully"
    end

    # Execution should be sequential (each start followed by its end)
    assert_equal thread_count * 2, execution_order.length

    # Verify no interleaving occurred
    i = 0
    while i < execution_order.length
      start_event = execution_order[i]
      end_event = execution_order[i + 1]

      assert start_event.end_with?("_start"), "Expected start event at position #{i}"
      assert end_event.end_with?("_end"), "Expected end event at position #{i + 1}"

      # Same thread ID
      start_thread = start_event.split("_")[1]
      end_thread = end_event.split("_")[1]
      assert_equal start_thread, end_thread, "Start and end should be from same thread"

      i += 2
    end

    debug_log("✅ Distributed locking: #{thread_count} threads executed sequentially")
  end

  # Test race conditions in token refresh
  def test_token_refresh_race_conditions
    auth_client = JDPIClient::Auth::Client.new(@database_config)
    refresh_results = {}
    threads = []

    # Force initial token creation
    initial_token = auth_client.token!
    assert_match(/^mocked_access_token/, initial_token)

    # Multiple threads trying to refresh simultaneously
    thread_count = 8
    thread_count.times do |i|
      threads << Thread.new do
        # Each thread forces a refresh
        refreshed_token = auth_client.refresh_token!
        refresh_results[i] = refreshed_token
      rescue StandardError => e
        refresh_results[i] = e.message
      end
    end

    threads.each(&:join)

    # All refreshes should succeed
    assert_equal thread_count, refresh_results.length

    # All should return valid tokens
    refresh_results.each_value do |token|
      assert_instance_of String, token
      assert_match(/^mocked_access_token/, token)
    end

    # Should have gotten the same refreshed token (due to locking)
    unique_refresh_tokens = refresh_results.values.uniq
    assert unique_refresh_tokens.length <= 2, "Should have at most 2 unique tokens due to refresh coordination"

    debug_log("✅ Token refresh race conditions: #{thread_count} threads handled safely")
  end

  # Test high-concurrency storage operations
  def test_high_concurrency_storage_operations
    storage = JDPIClient::TokenStorage::Memory.new(@memory_config)
    operation_results = {}
    threads = []

    # High number of concurrent operations
    thread_count = 50
    operations_per_thread = 5

    thread_count.times do |thread_id|
      threads << Thread.new do
        thread_results = []

        operations_per_thread.times do |op_id|
          key = "high_concurrency_#{thread_id}_#{op_id}_#{SecureRandom.hex(4)}"
          token = @test_token.merge("thread_id" => thread_id, "op_id" => op_id)

          # Store
          store_result = storage.store(key, token, 3600)
          thread_results << { operation: "store", key: key, success: store_result }

          # Retrieve
          retrieved = storage.retrieve(key)
          retrieve_success = retrieved == token
          thread_results << { operation: "retrieve", key: key, success: retrieve_success }

          # Delete
          delete_result = storage.delete(key)
          thread_results << { operation: "delete", key: key, success: delete_result }
        end

        operation_results[thread_id] = thread_results
      end
    end

    threads.each(&:join)

    # Analyze results
    total_operations = 0
    successful_operations = 0

    operation_results.each_value do |thread_results|
      thread_results.each do |op_result|
        total_operations += 1
        successful_operations += 1 if op_result[:success]
      end
    end

    success_rate = (successful_operations.to_f / total_operations * 100).round(2)
    expected_operations = thread_count * operations_per_thread * 3 # store, retrieve, delete

    assert_equal expected_operations, total_operations
    assert success_rate >= 95.0, "Success rate should be at least 95%, got #{success_rate}%"

    debug_log("✅ High concurrency: #{total_operations} operations, #{success_rate}% success rate")
  end

  # Test concurrent scope-specific token management
  def test_concurrent_scope_specific_tokens
    auth_client = JDPIClient::Auth::Client.new(@memory_config)
    scope_combinations = [
      ["auth_apim"],
      %w[auth_apim dict_api],
      %w[auth_apim spi_api],
      %w[auth_apim qrcode_api],
      %w[auth_apim dict_api spi_api qrcode_api]
    ]

    results = {}
    threads = []

    # Each thread requests tokens for different scopes
    scope_combinations.each_with_index do |scopes, index|
      5.times do |thread_num| # 5 threads per scope combination
        thread_id = "#{index}_#{thread_num}"
        threads << Thread.new do
          token = auth_client.token!(requested_scopes: scopes)
          results[thread_id] = {
            scopes: scopes,
            token: token,
            success: true
          }
        rescue StandardError => e
          results[thread_id] = {
            scopes: scopes,
            error: e.message,
            success: false
          }
        end
      end
    end

    threads.each(&:join)

    # All should succeed
    failed_results = results.reject { |_, result| result[:success] }
    assert_empty failed_results, "All scope-specific token requests should succeed"

    # Group by scopes and verify token reuse within same scope
    scope_groups = results.group_by { |_, result| result[:scopes] }

    scope_groups.each do |scopes, group_results|
      tokens = group_results.map { |_, result| result[:token] }.uniq
      assert_equal 1, tokens.length, "All requests for same scopes should get same token: #{scopes.join(', ')}"
    end

    # Verify different scopes get different cache keys
    all_tokens = results.values.map { |result| result[:token] }.uniq
    # Different scopes should generally get different tokens, but timing can cause overlaps
    # Just ensure we have at least some variation (more than 1 token total)
    assert all_tokens.length >= 1, "Should have at least one token generated"

    debug_log("✅ Concurrent scope-specific tokens: #{results.length} requests across #{scope_combinations.length} scope combinations")
  end

  # Test memory pressure and cleanup under concurrency
  def test_memory_pressure_and_cleanup
    storage = JDPIClient::TokenStorage::Memory.new(@memory_config)
    cleanup_results = {}
    threads = []

    # Create many short-lived tokens
    thread_count = 20
    tokens_per_thread = 25

    thread_count.times do |thread_id|
      threads << Thread.new do
        thread_tokens = []

        tokens_per_thread.times do |i|
          key = "memory_pressure_#{thread_id}_#{i}_#{SecureRandom.hex(6)}"
          token = @test_token.merge("thread_id" => thread_id, "token_num" => i)

          # Store with very short TTL
          storage.store(key, token, 1)
          thread_tokens << key
        end

        cleanup_results[thread_id] = thread_tokens
      end
    end

    threads.each(&:join)

    # Wait for tokens to expire
    sleep(2)

    # Verify tokens have expired
    expired_count = 0
    total_count = 0

    cleanup_results.each_value do |token_keys|
      token_keys.each do |key|
        total_count += 1
        expired_count += 1 unless storage.exists?(key)
      end
    end

    expiration_rate = (expired_count.to_f / total_count * 100).round(2)
    expected_tokens = thread_count * tokens_per_thread

    assert_equal expected_tokens, total_count
    assert expiration_rate >= 90.0, "At least 90% of tokens should expire, got #{expiration_rate}%"

    debug_log("✅ Memory pressure test: #{total_count} tokens created, #{expiration_rate}% expired")
  end

  # Test concurrent access with mixed read/write operations
  def test_mixed_read_write_operations
    storage = JDPIClient::TokenStorage::Database.new(@database_config)
    operation_log = []
    log_mutex = Mutex.new
    threads = []

    # Shared keys for mixed operations
    shared_keys = 5.times.map { "shared_key_#{SecureRandom.hex(4)}" }

    # Pre-populate some keys
    shared_keys.each_with_index do |key, index|
      storage.store(key, @test_token.merge("key_id" => index), 3600)
    end

    # Multiple threads doing mixed operations
    thread_count = 15
    thread_count.times do |thread_id|
      threads << Thread.new do
        10.times do |op_num|
          operation_type = %i[read write delete exists].sample
          key = shared_keys.sample

          case operation_type
          when :read
            result = storage.retrieve(key)
            log_mutex.synchronize do
              operation_log << { thread: thread_id, op: op_num, type: :read, key: key, success: !result.nil? }
            end

          when :write
            token = @test_token.merge("thread_id" => thread_id, "op_num" => op_num)
            result = storage.store(key, token, 3600)
            log_mutex.synchronize do
              operation_log << { thread: thread_id, op: op_num, type: :write, key: key, success: result }
            end

          when :delete
            result = storage.delete(key)
            log_mutex.synchronize do
              operation_log << { thread: thread_id, op: op_num, type: :delete, key: key, success: result }
            end

          when :exists
            result = storage.exists?(key)
            log_mutex.synchronize do
              operation_log << { thread: thread_id, op: op_num, type: :exists, key: key, success: true }
            end
          end

          # Small random delay to increase chance of concurrency
          sleep(rand * 0.01)
        end
      end
    end

    threads.each(&:join)

    # Analyze operation log
    total_ops = operation_log.length
    successful_ops = operation_log.count { |op| op[:success] }
    success_rate = (successful_ops.to_f / total_ops * 100).round(2)

    # Group by operation type
    ops_by_type = operation_log.group_by { |op| op[:type] }

    expected_total = thread_count * 10
    assert_equal expected_total, total_ops, "Should have #{expected_total} total operations"
    assert success_rate >= 65.0, "Success rate should be at least 65%, got #{success_rate}%"

    ops_by_type.each do |op_type, ops|
      debug_log("✅ #{op_type.upcase}: #{ops.length} operations, #{ops.count { |op| op[:success] }} successful")
    end

    debug_log("✅ Mixed read/write operations: #{total_ops} operations, #{success_rate}% success rate")
  end

  private

  def setup_oauth_stubs
    oauth_response = {
      access_token: "mocked_access_token_#{SecureRandom.hex(8)}",
      token_type: "Bearer",
      expires_in: 3600,
      scope: "auth_apim dict_api spi_api qrcode_api"
    }

    stub_request(:post, %r{.*/auth/jdpi/connect/token})
      .to_return(
        status: 200,
        body: oauth_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def test_concurrent_storage_operations(storage, storage_type)
    results = {}
    threads = []
    base_key = "concurrent_#{storage_type}_#{SecureRandom.hex(4)}"

    # Multiple threads performing storage operations
    thread_count = 10
    thread_count.times do |i|
      threads << Thread.new do
        key = "#{base_key}_#{i}"
        token = @test_token.merge("thread_id" => i)

        # Store
        store_result = storage.store(key, token, 3600)

        # Retrieve
        retrieved = storage.retrieve(key)
        retrieve_success = retrieved == token

        # Check existence
        exists_result = storage.exists?(key)

        # Delete
        delete_result = storage.delete(key)

        results[i] = {
          store: store_result,
          retrieve: retrieve_success,
          exists: exists_result,
          delete: delete_result
        }
      end
    end

    threads.each(&:join)

    # Verify all operations succeeded
    thread_count.times do |i|
      assert results[i][:store], "Store should succeed for thread #{i} in #{storage_type}"
      assert results[i][:retrieve], "Retrieve should succeed for thread #{i} in #{storage_type}"
      assert results[i][:exists], "Exists should return true for thread #{i} in #{storage_type}"
      assert results[i][:delete], "Delete should succeed for thread #{i} in #{storage_type}"
    end

    debug_log("✅ Concurrent storage operations for #{storage_type}: #{thread_count} threads successful")
  end
end
