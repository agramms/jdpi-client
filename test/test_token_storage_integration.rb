require 'test_helper'
require 'logger'

class TestTokenStorageIntegration < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.token_encryption_key = 'test_encryption_key_32_characters_long'
    @config.warn_on_local_tokens = false
  end

  def test_memory_storage_full_workflow
    # Test memory storage with all functionality
    @config.token_storage_adapter = :memory
    storage = JDPIClient::TokenStorage::Memory.new(@config)

    token_data = {
      'access_token' => 'test_token_12345',
      'token_type' => 'Bearer',
      'expires_in' => 3600,
      'scope' => 'auth:token dict:read'
    }

    # Test storage operations
    storage.store('test_key', token_data, 3600)
    assert storage.exists?('test_key')

    retrieved = storage.retrieve('test_key')
    assert_equal token_data, retrieved

    # Test deletion
    storage.delete('test_key')
    refute storage.exists?('test_key')
    assert_nil storage.retrieve('test_key')

    # Test clear all
    storage.store('key1', token_data, 3600)
    storage.store('key2', token_data, 3600)
    storage.clear_all
    refute storage.exists?('key1')
    refute storage.exists?('key2')

    # Test health check
    assert storage.healthy?
  end

  def test_encryption_full_workflow
    # Test all encryption methods
    encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    assert_instance_of String, encryption_key
    assert_equal 44, encryption_key.length  # Base64 encoded 32 bytes = 44 chars

    # Test key validation
    assert JDPIClient::TokenStorage::Encryption.valid_key?(encryption_key)
    refute JDPIClient::TokenStorage::Encryption.valid_key?('short')
    refute JDPIClient::TokenStorage::Encryption.valid_key?(nil)

    # Test encryption/decryption
    data = {
      'access_token' => 'test_token',
      'scope' => 'auth:token',
      'expires_at' => Time.now.utc.iso8601
    }

    encrypted = JDPIClient::TokenStorage::Encryption.encrypt(data, encryption_key)
    assert encrypted[:encrypted]
    assert_equal 1, encrypted[:version]
    assert encrypted[:data]

    decrypted = JDPIClient::TokenStorage::Encryption.decrypt(encrypted, encryption_key)
    assert_equal data, decrypted
  end

  def test_scope_manager_full_workflow
    # Test all scope manager functionality
    scopes = ['auth:token', 'dict:read', 'spi:write']

    # Test normalization (returns string, not array)
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal 'auth:token dict:read spi:write', normalized

    # Test with duplicates and different formats
    mixed_scopes = ['auth:token', 'dict:read dict:write', 'auth:token']
    normalized_mixed = JDPIClient::Auth::ScopeManager.normalize_scopes(mixed_scopes)
    assert_equal 'auth:token dict:read dict:write', normalized_mixed

    # Test fingerprint generation
    fingerprint = JDPIClient::Auth::ScopeManager.scope_fingerprint(normalized)
    assert_instance_of String, fingerprint
    assert_equal 16, fingerprint.length

    # Test cache key generation
    cache_key = JDPIClient::Auth::ScopeManager.cache_key('client123', scopes, @config)
    assert_includes cache_key, 'jdpi_client:tokens'
    assert_includes cache_key, 'client123'

    # Test scope compatibility
    assert JDPIClient::Auth::ScopeManager.scopes_compatible?(scopes, scopes)
    assert JDPIClient::Auth::ScopeManager.scopes_compatible?(scopes, ['auth:token'])
    refute JDPIClient::Auth::ScopeManager.scopes_compatible?(['auth:token'], scopes)
  end

  def test_config_validation
    # Test configuration validation
    @config.token_storage_adapter = :redis
    @config.token_storage_url = nil

    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      @config.validate_token_storage_config!
    end
    assert_includes error.message, 'Redis URL is required'

    # Test DynamoDB validation
    @config.token_storage_adapter = :dynamodb
    @config.token_storage_options = {}

    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      @config.validate_token_storage_config!
    end
    assert_includes error.message, 'DynamoDB table name is required'

    # Test encryption requirement for shared storage
    @config.token_storage_adapter = :redis
    @config.token_storage_url = 'redis://localhost:6379'
    @config.token_encryption_key = nil

    error = assert_raises(JDPIClient::Errors::ConfigurationError) do
      @config.validate_token_storage_config!
    end
    assert_includes error.message, 'Token encryption key is required'
  end

  def test_factory_adapter_discovery
    # Test factory methods
    available_adapters = JDPIClient::TokenStorage::Factory.available_adapters
    assert_includes available_adapters, :memory

    # Test adapter availability checking
    assert JDPIClient::TokenStorage::Factory.adapter_available?(:memory)

    # Test adapter info
    adapter_info = JDPIClient::TokenStorage::Factory.adapter_info
    assert adapter_info.key?(:memory)
    assert_equal 'In-memory storage (not shared across instances)', adapter_info[:memory][:description]
  end

  def test_warning_system
    # Test warning system for local tokens
    @config.warn_on_local_tokens = true
    log_output = StringIO.new
    logger = Logger.new(log_output)
    @config.logger = logger

    storage = JDPIClient::TokenStorage::Memory.new(@config)
    storage.store('test_key', {'access_token' => 'test'}, 3600)

    log_content = log_output.string
    assert_includes log_content, 'WARN'
    assert_includes log_content, 'in-memory storage'
  end

  def test_config_helpers
    # Test configuration helper methods
    @config.token_storage_adapter = :memory
    refute @config.shared_token_storage?

    @config.token_storage_adapter = :redis
    assert @config.shared_token_storage?

    @config.token_encryption_key = nil
    refute @config.token_encryption_enabled?

    @config.token_encryption_key = 'test_key'
    assert @config.token_encryption_enabled?

    # Test key prefix generation
    prefix = @config.token_storage_key_prefix
    assert_includes prefix, 'jdpi_client:tokens'
    assert_includes prefix, @config.environment
  end

  def test_error_handling
    # Test various error conditions
    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.encrypt({'test' => 'data'}, nil)
    end

    # Test with invalid encrypted data
    invalid_encrypted = {
      encrypted: true,
      version: 1,
      data: 'invalid_base64_data'
    }

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.decrypt(invalid_encrypted, 'test_key')
    end
  end
end