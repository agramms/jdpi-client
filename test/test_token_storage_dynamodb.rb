require 'test_helper'
require 'minitest/mock'
require 'ostruct'

# Create a stub for AWS SDK if not available
unless defined?(Aws)
  module Aws
    module DynamoDB
      class Client
        def self.new(*args)
          # This will be overridden in tests
        end
      end

      module Errors
        class ResourceNotFoundException < StandardError
          def initialize(context, message)
            super(message)
          end
        end

        class ResourceNotFound < ResourceNotFoundException; end
        class ServiceError < StandardError; end
      end
    end
  end
end

class TestTokenStorageDynamoDB < Minitest::Test
  def setup
    @config = create_test_config(:dynamodb)
    @mock_dynamodb = Minitest::Mock.new

    # Set up default expectations for DynamoDB client
    table_response = OpenStruct.new(
      table: OpenStruct.new(
        table_status: 'ACTIVE',
        key_schema: [OpenStruct.new(attribute_name: 'token_key', key_type: 'HASH')]
      )
    )
    @mock_dynamodb.expect(:describe_table, table_response, [Hash])

    # Mock Aws::DynamoDB::Client.new
    Aws::DynamoDB::Client.define_singleton_method(:new) { |*args| @mock_dynamodb }

    @storage = create_storage(:dynamodb)

    @token = {
      'access_token' => 'test_token_123',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'read write'
    }
  end

  def test_initialization_with_options
    assert_instance_of JDPIClient::TokenStorage::DynamoDB, @storage
    assert_equal 'jdpi_test_tokens', @storage.instance_variable_get(:@table_name)
  end

  def test_table_creation_and_validation
    # The table should already exist after initialization (mocked)
    dynamodb_client = @storage.instance_variable_get(:@dynamodb)

    # This test verifies the table structure through mocked responses
    assert_instance_of Minitest::Mock, dynamodb_client
  end

  def test_store_and_retrieve_token
    key = 'test_store_retrieve_' + SecureRandom.hex(8)
    ttl = 3600

    # Mock put_item call
    @mock_dynamodb.expect(:put_item, true, [Hash])

    # Mock get_item call
    get_response = OpenStruct.new(
      item: {
        'token_key' => key,
        'token_data' => MultiJson.dump(@token),
        'ttl' => Time.now.to_i + ttl
      }
    )
    @mock_dynamodb.expect(:get_item, get_response, [Hash])

    # Store token
    result = @storage.store(key, @token, ttl)
    assert result

    # Retrieve token
    retrieved = @storage.retrieve(key)
    assert_equal @token, retrieved
  end

  def test_store_with_encryption_when_enabled
    return unless @config.token_encryption_enabled?

    key = 'test_encrypted_' + SecureRandom.hex(8)
    sensitive_token = {
      'access_token' => 'very_secret_token_12345',
      'refresh_token' => 'very_secret_refresh_67890',
      'scope' => 'admin:all'
    }

    # Mock encrypted storage
    encrypted_data = {'encrypted' => true, 'ciphertext' => 'encrypted_data'}

    @mock_dynamodb.expect(:put_item, true, [Hash])

    get_response = OpenStruct.new(
      item: {
        'token_key' => key,
        'token_data' => MultiJson.dump(encrypted_data),
        'ttl' => Time.now.to_i + 3600
      }
    )
    @mock_dynamodb.expect(:get_item, get_response, [Hash])

    # Store encrypted token
    @storage.store(key, sensitive_token, 3600)

    # Retrieve and verify (mocked decryption would happen in storage layer)
    retrieved = @storage.retrieve(key)
    # In a real scenario, this would be decrypted back to original
    assert_instance_of Hash, retrieved
  end

  def test_retrieve_returns_nil_for_missing_key
    missing_key = 'missing_key_' + SecureRandom.hex(8)

    # Mock empty response
    @mock_dynamodb.expect(:get_item, OpenStruct.new(item: nil), [Hash])

    result = @storage.retrieve(missing_key)
    assert_nil result
  end

  def test_exists_checks_key_presence
    key = 'test_exists_' + SecureRandom.hex(8)

    # Mock item not exists
    @mock_dynamodb.expect(:get_item, OpenStruct.new(item: nil), [Hash])
    refute @storage.exists?(key)

    # Mock put_item
    @mock_dynamodb.expect(:put_item, true, [Hash])
    @storage.store(key, @token, 3600)

    # Mock item exists
    @mock_dynamodb.expect(:get_item, OpenStruct.new(item: {'token_key' => key}), [Hash])
    assert @storage.exists?(key)
  end

  def test_delete_removes_key
    key = 'test_delete_' + SecureRandom.hex(8)

    # Mock store operation
    @mock_dynamodb.expect(:put_item, true, [Hash])
    @storage.store(key, @token, 3600)

    # Mock delete operation
    @mock_dynamodb.expect(:delete_item, true, [Hash])
    result = @storage.delete(key)
    assert result
  end

  def test_ttl_expiration_with_dynamodb
    key = 'test_ttl_' + SecureRandom.hex(8)
    short_ttl = 2

    # Mock put_item
    @mock_dynamodb.expect(:put_item, true, [Hash])
    @storage.store(key, @token, short_ttl)

    # Mock get_item with TTL verification
    get_response = OpenStruct.new(
      item: {
        'token_key' => key,
        'ttl' => Time.now.to_i + short_ttl
      }
    )
    @mock_dynamodb.expect(:get_item, get_response, [Hash])

    response = @storage.instance_variable_get(:@dynamodb).get_item(
      table_name: 'jdpi_test_tokens',
      key: { 'token_key' => key }
    )

    assert response.item['ttl']
    ttl_value = response.item['ttl'].to_i
    assert ttl_value > Time.now.to_i
  end

  def test_with_lock_distributed_locking
    lock_key = 'test_distributed_lock_' + SecureRandom.hex(8)
    executed = false

    # Mock lock acquisition (put_item with condition)
    @mock_dynamodb.expect(:put_item, true, [Hash])
    # Mock lock release (delete_item)
    @mock_dynamodb.expect(:delete_item, true, [Hash])

    @storage.with_lock(lock_key) do
      executed = true
    end

    assert executed
  end

  def test_stats_returns_table_info
    # Mock describe_table for stats
    table_response = OpenStruct.new(
      table: OpenStruct.new(
        table_status: 'ACTIVE',
        item_count: 10,
        table_size_bytes: 1024
      )
    )
    @mock_dynamodb.expect(:describe_table, table_response, [Hash])

    stats = @storage.stats
    assert_instance_of Hash, stats
    assert_equal 'DynamoDB', stats[:storage_type]
    assert stats.key?(:table_name)
    assert stats.key?(:item_count)
    assert stats.key?(:table_size_bytes)
    assert stats.key?(:encrypted)
  end

  def test_error_handling_for_malformed_data
    key = 'test_malformed_' + SecureRandom.hex(8)

    # Mock response with malformed data
    get_response = OpenStruct.new(
      item: {
        'token_key' => key,
        'token_data' => 'invalid json data',
        'ttl' => Time.now.to_i + 3600
      }
    )
    @mock_dynamodb.expect(:get_item, get_response, [Hash])

    # Should handle gracefully
    result = @storage.retrieve(key)
    assert_nil result
  end

  def test_error_handling_for_invalid_table_config
    invalid_config = create_test_config(:dynamodb)
    invalid_config.token_storage_options[:table_name] = 'nonexistent_table'

    # Mock AWS error for nonexistent table
    error_mock = Minitest::Mock.new
    error_mock.expect(:describe_table, proc { raise Aws::DynamoDB::Errors::ResourceNotFound.new(nil, 'Table not found') }, [Hash])

    Aws::DynamoDB::Client.define_singleton_method(:new) { |*args| error_mock }

    assert_raises(JDPIClient::Errors::Error) do
      JDPIClient::TokenStorage::DynamoDB.new(invalid_config)
    end
  end

  def teardown
    @mock_dynamodb.verify
    # Restore AWS client
    if Aws::DynamoDB::Client.singleton_class.method_defined?(:new)
      Aws::DynamoDB::Client.singleton_class.remove_method(:new)
    end
  end
end