require 'test_helper'
require 'logger'
require 'stringio'

class TestComprehensiveCoverage < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.token_encryption_key = 'test_encryption_key_32_characters_long'
  end

  def test_config_methods_coverage
    # Test all config methods
    config = JDPIClient::Config.new

    # Test base_url for different environments
    config.jdpi_client_host = "api.prod.jdpi.com"
    assert_equal "https://api.prod.jdpi.com", config.base_url
    assert config.production?
    assert_equal "prod", config.environment

    config.jdpi_client_host = "api.homl.jdpi.com"
    assert_equal "http://api.homl.jdpi.com", config.base_url
    refute config.production?
    assert_equal "homl", config.environment

    # Test token storage helper methods
    config.token_storage_adapter = :memory
    refute config.shared_token_storage?

    config.token_storage_adapter = :redis
    assert config.shared_token_storage?

    config.token_encryption_key = nil
    refute config.token_encryption_enabled?

    config.token_encryption_key = ""
    refute config.token_encryption_enabled?

    config.token_encryption_key = "test_key"
    assert config.token_encryption_enabled?

    # Test key prefix generation
    config.token_scope_prefix = "custom"
    config.jdpi_client_host = "localhost"
    prefix = config.token_storage_key_prefix
    assert_includes prefix, "jdpi_client:tokens:custom:homl"
  end

  def test_jdpi_client_module_methods
    # Test module-level methods
    original_config = JDPIClient.instance_variable_get(:@config)

    # Test configure block
    JDPIClient.configure do |config|
      config.jdpi_client_host = "test.example.com"
      config.oauth_client_id = "test_client_id"
    end

    config = JDPIClient.config
    assert_equal "test.example.com", config.jdpi_client_host
    assert_equal "test_client_id", config.oauth_client_id

    # Test storage adapter methods
    available_adapters = JDPIClient.available_storage_adapters
    assert available_adapters.key?(:memory)

    assert JDPIClient.storage_adapter_available?(:memory)
    refute JDPIClient.storage_adapter_available?(:nonexistent)

    # Restore original config
    JDPIClient.instance_variable_set(:@config, original_config)
  end

  def test_error_classes
    # Test all error classes exist and inherit correctly
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::ConfigurationError.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::Unauthorized.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::Forbidden.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::NotFound.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::RateLimited.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::ServerError.superclass
    assert_equal JDPIClient::Errors::Error, JDPIClient::Errors::Validation.superclass

    # Test error factory method
    error400 = JDPIClient::Errors.from_response(400, {"message" => "Bad Request"})
    assert_instance_of JDPIClient::Errors::Validation, error400
    assert_equal "Bad Request", error400.message

    error401 = JDPIClient::Errors.from_response(401)
    assert_instance_of JDPIClient::Errors::Unauthorized, error401

    error403 = JDPIClient::Errors.from_response(403)
    assert_instance_of JDPIClient::Errors::Forbidden, error403

    error404 = JDPIClient::Errors.from_response(404)
    assert_instance_of JDPIClient::Errors::NotFound, error404

    error429 = JDPIClient::Errors.from_response(429)
    assert_instance_of JDPIClient::Errors::RateLimited, error429

    error500 = JDPIClient::Errors.from_response(500)
    assert_instance_of JDPIClient::Errors::ServerError, error500

    error502 = JDPIClient::Errors.from_response(502)
    assert_instance_of JDPIClient::Errors::ServerError, error502

    error_unknown = JDPIClient::Errors.from_response(999)
    assert_instance_of JDPIClient::Errors::Error, error_unknown
  end

  def test_http_client_coverage
    # Test HTTP client initialization and configuration
    token_provider = -> { "mock_token" }
    http = JDPIClient::HTTP.new(
      base: @config.base_url,
      token_provider: token_provider,
      logger: @config.logger,
      timeout: @config.timeout,
      open_timeout: @config.open_timeout
    )

    # Test connection configuration (access via instance variable)
    connection = http.instance_variable_get(:@conn)
    assert_instance_of Faraday::Connection, connection
  end

  def test_auth_client_edge_cases
    # Test auth client with various configurations
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"
    @config.token_storage_adapter = :memory
    @config.warn_on_local_tokens = false

    auth_client = JDPIClient::Auth::Client.new(@config)

    # Test to_proc method returns callable
    proc_obj = auth_client.to_proc
    assert_instance_of Proc, proc_obj

    # Test that client has config
    assert_equal @config, auth_client.instance_variable_get(:@config)
  end

  def test_scope_manager_edge_cases
    # Test ScopeManager with various edge cases

    # Test empty scopes
    empty_normalized = JDPIClient::Auth::ScopeManager.normalize_scopes([])
    assert_equal "", empty_normalized

    # Test nil scopes (returns default scope)
    nil_normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(nil)
    assert_equal "auth:token", nil_normalized

    # Test single scope
    single_scope = JDPIClient::Auth::ScopeManager.normalize_scopes("auth:token")
    assert_equal "auth:token", single_scope

    # Test scope compatibility edge cases
    assert JDPIClient::Auth::ScopeManager.scopes_compatible?("auth:token", "auth:token")
    assert JDPIClient::Auth::ScopeManager.scopes_compatible?("auth:token dict:read", "auth:token")
    refute JDPIClient::Auth::ScopeManager.scopes_compatible?("auth:token", "auth:token dict:read")

    # Test scopes_allowed? with various inputs
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?(nil, nil)
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?("auth:token", nil)
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?("auth:token", "auth:token dict:read")
    refute JDPIClient::Auth::ScopeManager.scopes_allowed?("auth:token dict:read", "auth:token")
  end

  def test_token_storage_factory_edge_cases
    # Test factory with all adapters
    factory = JDPIClient::TokenStorage::Factory

    # Test memory adapter (always available)
    assert factory.adapter_available?(:memory)
    memory_storage = factory.create(:memory)
    assert_instance_of JDPIClient::TokenStorage::Memory, memory_storage

    # Test redis adapter (should be unavailable without gem)
    redis_available = factory.adapter_available?(:redis)
    if redis_available
      redis_storage = factory.create(:redis)
      assert_instance_of JDPIClient::TokenStorage::Redis, redis_storage
    else
      error = assert_raises(JDPIClient::Errors::ConfigurationError) do
        factory.create(:redis)
      end
      assert_includes error.message, "not available"
    end

    # Test unknown adapter
    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      factory.create(:unknown)
    end
    assert_includes error.message, "Unknown storage adapter"

    # Test adapter info
    info = factory.adapter_info
    assert info.key?(:memory)
    assert info.key?(:redis)
    assert info.key?(:dynamodb)
    assert info.key?(:database)
  end

  def test_encryption_edge_cases
    encryption = JDPIClient::TokenStorage::Encryption

    # Valid key
    valid_key = encryption.generate_key
    assert_instance_of String, valid_key

    # Test encryption with various data types
    complex_data = {
      "string" => "test",
      "number" => 123,
      "boolean" => true,
      "null" => nil,
      "array" => [1, 2, 3],
      "nested" => {"key" => "value"}
    }

    encrypted = encryption.encrypt(complex_data, valid_key)
    decrypted = encryption.decrypt(encrypted, valid_key)
    assert_equal complex_data, decrypted

    # Test decryption with wrong key
    wrong_key = encryption.generate_key
    assert_raises(JDPIClient::Errors::Unauthorized) do
      encryption.decrypt(encrypted, wrong_key)
    end

    # Test decrypt with invalid data structure
    invalid_data = {encrypted: true, version: 1}
    assert_raises(JDPIClient::Errors::ConfigurationError) do
      encryption.decrypt(invalid_data, valid_key)
    end

    # Test decrypt with wrong version
    wrong_version = encrypted.dup
    wrong_version[:version] = 2
    assert_raises(JDPIClient::Errors::ConfigurationError) do
      encryption.decrypt(wrong_version, valid_key)
    end
  end

  def test_memory_storage_edge_cases
    storage = JDPIClient::TokenStorage::Memory.new(@config)

    # Test store with TTL of 0 (immediate expiration)
    storage.store("expire_now", {"token" => "test"}, 0)
    sleep(0.01)
    assert_nil storage.retrieve("expire_now")

    # Test warning suppression after first warning
    @config.warn_on_local_tokens = true
    log_output = StringIO.new
    logger = Logger.new(log_output)
    @config.logger = logger

    storage = JDPIClient::TokenStorage::Memory.new(@config)
    storage.store("key1", {"token" => "test"}, 3600)
    storage.store("key2", {"token" => "test"}, 3600)

    # Should only have one warning
    log_content = log_output.string
    warning_count = log_content.scan(/WARN/).length
    assert_equal 1, warning_count
  end

  def test_config_validation_edge_cases
    config = JDPIClient::Config.new

    # Test validation with different adapter combinations
    config.token_storage_adapter = :memory
    config.token_encryption_key = nil
    # Should not raise for memory adapter
    config.validate_token_storage_config!

    # Test Redis without URL
    config.token_storage_adapter = :redis
    config.token_storage_url = nil
    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      config.validate_token_storage_config!
    end
    assert_includes error.message, "Redis URL is required"

    # Test DynamoDB without table name
    config.token_storage_adapter = :dynamodb
    config.token_storage_options = {}
    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      config.validate_token_storage_config!
    end
    assert_includes error.message, "DynamoDB table name is required"

    # Test DynamoDB with nil table name
    config.token_storage_options = {table_name: nil}
    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      config.validate_token_storage_config!
    end
    assert_includes error.message, "DynamoDB table name is required"

    # Test shared storage without encryption
    config.token_storage_adapter = :redis
    config.token_storage_url = "redis://localhost:6379"
    config.token_encryption_key = nil
    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      config.validate_token_storage_config!
    end
    assert_includes error.message, "Token encryption key is required"
  end

  def test_version_constant
    # Test that version constant is defined and is a string
    assert_instance_of String, JDPIClient::VERSION
    assert_match(/\d+\.\d+\.\d+/, JDPIClient::VERSION)
  end

  def test_auth_client_class_exists
    # Test that auth client class is properly defined
    assert defined?(JDPIClient::Auth::Client)

    # Test auth client can be initialized
    auth_client = JDPIClient::Auth::Client.new(@config)
    assert_instance_of JDPIClient::Auth::Client, auth_client
  end
end