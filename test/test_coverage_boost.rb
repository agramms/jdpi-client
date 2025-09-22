require 'test_helper'

class TestCoverageBoost < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"
    @config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
  end

  # Test service constructors - these are often uncovered by tests
  def test_all_service_constructors_with_default_config
    # Test DICT services
    JDPIClient::DICT::Keys.new
    JDPIClient::DICT::Claims.new
    JDPIClient::DICT::Infractions.new
    JDPIClient::DICT::MED.new

    # Test QR service
    JDPIClient::QR::Client.new

    # Test SPI services
    JDPIClient::SPI::OP.new
    JDPIClient::SPI::OD.new

    # Test Participants service
    JDPIClient::Participants.new
  end

  def test_all_service_constructors_with_explicit_config
    # Test DICT services with explicit config
    JDPIClient::DICT::Keys.new(nil, @config)
    JDPIClient::DICT::Claims.new(nil, @config)
    JDPIClient::DICT::Infractions.new(nil, @config)
    JDPIClient::DICT::MED.new(nil, @config)

    # Test QR service with explicit config
    JDPIClient::QR::Client.new(nil, @config)

    # Test SPI services with explicit config
    JDPIClient::SPI::OP.new(nil, @config)
    JDPIClient::SPI::OD.new(nil, @config)

    # Test Participants service with explicit config
    JDPIClient::Participants.new(nil, @config)
  end

  def test_all_service_constructors_with_custom_token_provider
    token_provider = -> { "custom_token" }

    # Test DICT services with custom token provider
    JDPIClient::DICT::Keys.new(nil, @config, token_provider: token_provider)
    JDPIClient::DICT::Claims.new(nil, @config, token_provider: token_provider)
    JDPIClient::DICT::Infractions.new(nil, @config, token_provider: token_provider)
    JDPIClient::DICT::MED.new(nil, @config, token_provider: token_provider)

    # Test QR service with custom token provider
    JDPIClient::QR::Client.new(nil, @config, token_provider: token_provider)

    # Test SPI services with custom token provider
    JDPIClient::SPI::OP.new(nil, @config, token_provider: token_provider)
    JDPIClient::SPI::OD.new(nil, @config, token_provider: token_provider)

    # Test Participants service with custom token provider
    JDPIClient::Participants.new(nil, @config, token_provider: token_provider)
  end

  # Exercise all HTTP client parsing scenarios
  def test_http_parse_json_all_scenarios
    token_provider = -> { "test_token" }
    http = JDPIClient::HTTP.new(
      base: "http://localhost:1234",
      token_provider: token_provider
    )

    # Test all parse_json scenarios (this is a private method so access it through send)
    assert_equal({}, http.send(:parse_json, nil))
    assert_equal({}, http.send(:parse_json, ""))
    assert_equal({"test" => "value"}, http.send(:parse_json, '{"test": "value"}'))
    assert_equal({"hash" => "data"}, http.send(:parse_json, {"hash" => "data"}))

    # Test default headers
    headers = http.send(:default_headers)
    assert_equal "Bearer test_token", headers["Authorization"]
    assert_equal "application/json; charset=utf-8", headers["Content-Type"]
    assert_equal "application/json", headers["Accept"]
  end

  # Test all auth client private methods
  def test_auth_client_internal_methods
    auth_client = JDPIClient::Auth::Client.new(@config)

    # Test token_valid? with various scenarios
    valid_token_data = {
      access_token: "test_token",
      expires_at: (Time.now + 3600).utc.iso8601
    }
    assert auth_client.send(:token_valid?, valid_token_data)

    # Test with expired token
    expired_token_data = {
      access_token: "test_token",
      expires_at: (Time.now - 3600).utc.iso8601
    }
    refute auth_client.send(:token_valid?, expired_token_data)

    # Test with missing access_token
    invalid_token_data = {
      expires_at: (Time.now + 3600).utc.iso8601
    }
    refute auth_client.send(:token_valid?, invalid_token_data)

    # Test with nil
    refute auth_client.send(:token_valid?, nil)

    # Test with non-hash
    refute auth_client.send(:token_valid?, "not_a_hash")

    # Test with invalid expires_at
    invalid_expires_data = {
      access_token: "test_token",
      expires_at: "invalid_date"
    }
    refute auth_client.send(:token_valid?, invalid_expires_data)
  end

  # Test all config helper methods
  def test_config_all_helpers
    config = JDPIClient::Config.new

    # Test base_url with various host configurations
    test_hosts = [
      ["api.prod.jdpi.pstijd", "https://api.prod.jdpi.pstijd"],
      ["localhost", "http://localhost"],
      ["127.0.0.1", "http://127.0.0.1"],
      ["api.homl.jdpi.pstijd", "http://api.homl.jdpi.pstijd"],
      ["custom.domain.com", "http://custom.domain.com"]
    ]

    test_hosts.each do |host, expected_url|
      config.jdpi_client_host = host
      assert_equal expected_url, config.base_url
    end

    # Test production? with various patterns
    production_hosts = [
      "api.production.jdpi.pstijd",
      "prod.api.jdpi.pstijd",
      "api.prod.jdpi.pstijd",
      "production-api.jdpi.pstijd",
      "api.production-env.jdpi.pstijd"
    ]

    production_hosts.each do |host|
      config.jdpi_client_host = host
      assert config.production?, "#{host} should be detected as production"
      assert_equal "prod", config.environment
    end

    # Test environment detection for non-production
    non_production_hosts = [
      "api.homl.jdpi.pstijd",
      "localhost",
      "127.0.0.1",
      "api.staging.jdpi.pstijd",
      "dev.api.jdpi.pstijd",
      "test.api.jdpi.pstijd"
    ]

    non_production_hosts.each do |host|
      config.jdpi_client_host = host
      refute config.production?, "#{host} should not be detected as production"
      assert_equal "homl", config.environment
    end

    # Test token_encryption_enabled?
    refute config.token_encryption_enabled?
    config.token_encryption_key = "test_key"
    assert config.token_encryption_enabled?
    config.token_encryption_key = ""
    refute config.token_encryption_enabled?
    config.token_encryption_key = nil
    refute config.token_encryption_enabled?

    # Test shared_token_storage?
    config.token_storage_adapter = :memory
    refute config.shared_token_storage?

    [:redis, :dynamodb, :database].each do |adapter|
      config.token_storage_adapter = adapter
      assert config.shared_token_storage?
    end
  end

  # Test all scope manager edge cases
  def test_scope_manager_all_edge_cases
    # Test normalize_scopes with various inputs
    test_cases = [
      [nil, "auth:token"], # Default scope for nil
      ["", ""],
      ["   ", ""],
      ["scope1", "scope1"],
      ["  scope1  ", "scope1"],
      ["scope1 scope2", "scope1 scope2"],
      ["  scope1   scope2  ", "scope1 scope2"],
      [["scope1"], "scope1"],
      [["scope1", "scope2"], "scope1 scope2"],
      [["  scope1  ", "  scope2  "], "scope1 scope2"]
    ]

    test_cases.each do |input, expected|
      result = JDPIClient::Auth::ScopeManager.normalize_scopes(input)
      assert_equal expected, result, "Failed for input: #{input.inspect}"
    end

    # Test parse_scopes_from_response with various inputs
    response_cases = [
      [nil, "auth:token"],
      [{}, "auth:token"],
      [{"scope" => "custom:scope"}, "custom:scope"],
      [{"scope" => "  custom:scope  "}, "custom:scope"],
      [{"scope" => ""}, "auth:token"],
      [{"other_key" => "value"}, "auth:token"]
    ]

    response_cases.each do |response, expected|
      result = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(response)
      assert_equal expected, result, "Failed for response: #{response.inspect}"
    end

    # Test scope_parameter
    assert_equal "scope1", JDPIClient::Auth::ScopeManager.scope_parameter("scope1")
    assert_equal "scope1 scope2", JDPIClient::Auth::ScopeManager.scope_parameter(["scope1", "scope2"])

    # Test scope_fingerprint uniqueness and consistency
    fingerprint1 = JDPIClient::Auth::ScopeManager.scope_fingerprint("scope1")
    fingerprint2 = JDPIClient::Auth::ScopeManager.scope_fingerprint("scope2")
    fingerprint3 = JDPIClient::Auth::ScopeManager.scope_fingerprint("scope1") # Same as fingerprint1

    assert_equal 16, fingerprint1.length
    assert_equal 16, fingerprint2.length
    assert_equal fingerprint1, fingerprint3
    refute_equal fingerprint1, fingerprint2

    # Test cache_key generation
    cache_key1 = JDPIClient::Auth::ScopeManager.cache_key("client1", "scope1", @config)
    cache_key2 = JDPIClient::Auth::ScopeManager.cache_key("client2", "scope1", @config)
    cache_key3 = JDPIClient::Auth::ScopeManager.cache_key("client1", "scope2", @config)

    refute_equal cache_key1, cache_key2 # Different clients
    refute_equal cache_key1, cache_key3 # Different scopes

    # Same inputs should produce same cache key
    cache_key4 = JDPIClient::Auth::ScopeManager.cache_key("client1", "scope1", @config)
    assert_equal cache_key1, cache_key4
  end

  # Test encryption with edge cases
  def test_encryption_all_edge_cases
    # Test generate_key produces different keys
    keys = 10.times.map { JDPIClient::TokenStorage::Encryption.generate_key }
    assert_equal 10, keys.uniq.length, "All generated keys should be unique"

    # Test all keys are valid format
    keys.each do |key|
      assert_equal 44, key.length, "Key should be 44 characters (Base64 32 bytes)"
      assert_match(/\A[A-Za-z0-9+\/]+=*\z/, key, "Key should be valid Base64")
    end

    # Test encryption/decryption with various data types
    test_data = [
      {"simple" => "string"},
      {"number" => 42},
      {"boolean" => true},
      {"array" => [1, 2, 3]},
      {"nested" => {"deep" => {"value" => "test"}}},
      {"complex" => {"mixed" => [{"nested" => true}, "string", 123]}}
    ]

    key = keys.first

    test_data.each do |data|
      encrypted = JDPIClient::TokenStorage::Encryption.encrypt(data, key)
      assert_instance_of Hash, encrypted
      assert encrypted.key?(:encrypted)
      assert encrypted.key?(:ciphertext)

      decrypted = JDPIClient::TokenStorage::Encryption.decrypt(encrypted, key)
      assert_equal data, decrypted
    end

    # Test error conditions
    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.encrypt({}, nil)
    end

    assert_raises(JDPIClient::Errors::ConfigurationError) do
      JDPIClient::TokenStorage::Encryption.encrypt({}, "")
    end

    # Test decrypt with wrong key
    encrypted = JDPIClient::TokenStorage::Encryption.encrypt({"test" => "data"}, keys[0])
    assert_raises(JDPIClient::Errors::Error) do
      JDPIClient::TokenStorage::Encryption.decrypt(encrypted, keys[1])
    end

    # Test decrypt with invalid data
    assert_raises(JDPIClient::Errors::Error) do
      JDPIClient::TokenStorage::Encryption.decrypt("invalid_encrypted_data", keys[0])
    end
  end

  # Test factory with all adapter types
  def test_factory_comprehensive
    factory = JDPIClient::TokenStorage::Factory

    # Test adapter_available? for all known adapters
    adapters = [:memory, :redis, :dynamodb, :database, :unknown_adapter]
    results = {}

    adapters.each do |adapter|
      results[adapter] = factory.adapter_available?(adapter)
      assert [true, false].include?(results[adapter]), "adapter_available? should return boolean"
    end

    # Unknown adapter should always be false
    refute results[:unknown_adapter]

    # Memory should always be available
    assert results[:memory]

    # Test create with memory adapter (guaranteed to work)
    config = @config.dup
    config.token_storage_adapter = :memory
    storage = factory.create(config)
    assert_instance_of JDPIClient::TokenStorage::Memory, storage

    # Test create with other adapters if available
    [:redis, :dynamodb, :database].each do |adapter|
      next unless results[adapter]

      config.token_storage_adapter = adapter
      storage = factory.create(config)
      assert storage.class.name.downcase.include?(adapter.to_s)
    end
  end

  # Test memory storage comprehensive functionality
  def test_memory_storage_comprehensive
    storage = JDPIClient::TokenStorage::Memory.new(@config)

    # Test basic operations
    assert_equal 0, storage.stats[:total_tokens]
    refute storage.exists?("nonexistent")
    assert_nil storage.retrieve("nonexistent")

    # Test store and retrieve
    token_data = {"access_token" => "test123", "scope" => "auth:token"}
    storage.store("test_key", token_data, 3600)

    assert storage.exists?("test_key")
    assert_equal token_data, storage.retrieve("test_key")
    assert_equal 1, storage.stats[:total_tokens]

    # Test update existing token
    updated_data = {"access_token" => "updated456", "scope" => "auth:token"}
    storage.store("test_key", updated_data, 3600)

    assert_equal updated_data, storage.retrieve("test_key")
    assert_equal 1, storage.stats[:total_tokens] # Should still be 1

    # Test delete
    storage.delete("test_key")
    refute storage.exists?("test_key")
    assert_nil storage.retrieve("test_key")
    assert_equal 0, storage.stats[:total_tokens]

    # Test expiration handling
    storage.store("short_lived", token_data, -1) # Already expired
    refute storage.exists?("short_lived"), "Expired token should not exist"

    storage.store("about_to_expire", token_data, 1)
    assert storage.exists?("about_to_expire")
    sleep(1.1)
    refute storage.exists?("about_to_expire"), "Expired token should be cleaned up"

    # Test cleanup method directly
    storage.store("expired1", token_data, -10)
    storage.store("expired2", token_data, -5)
    storage.store("valid", token_data, 3600)

    assert storage.exists?("valid")
    storage.send(:cleanup_expired_tokens)
    assert storage.exists?("valid")
    assert_equal 1, storage.stats[:total_tokens]
  end

  # Test that all error classes have proper inheritance
  def test_error_class_hierarchy
    base_error = JDPIClient::Errors::Error.new("base")
    assert_kind_of StandardError, base_error

    # Test all specific error types inherit from base error
    error_classes = [
      JDPIClient::Errors::ConfigurationError,
      JDPIClient::Errors::Unauthorized,
      JDPIClient::Errors::Forbidden,
      JDPIClient::Errors::NotFound,
      JDPIClient::Errors::RateLimited,
      JDPIClient::Errors::ServerError,
      JDPIClient::Errors::Validation
    ]

    error_classes.each do |error_class|
      error = error_class.new("test message")
      assert_instance_of JDPIClient::Errors::Error, error
      assert_kind_of StandardError, error
      assert_equal "test message", error.message
    end

    # Test error factory with comprehensive status codes
    status_to_error = {
      400 => JDPIClient::Errors::Validation,
      401 => JDPIClient::Errors::Unauthorized,
      403 => JDPIClient::Errors::Forbidden,
      404 => JDPIClient::Errors::NotFound,
      422 => JDPIClient::Errors::Validation,
      429 => JDPIClient::Errors::RateLimited,
      500 => JDPIClient::Errors::ServerError,
      502 => JDPIClient::Errors::ServerError,
      503 => JDPIClient::Errors::ServerError,
      418 => JDPIClient::Errors::Error, # I'm a teapot - should fall back to base error
      999 => JDPIClient::Errors::Error  # Unknown status code
    }

    status_to_error.each do |status, expected_class|
      error = JDPIClient::Errors.from_response(status, {"message" => "test"})
      assert_instance_of expected_class, error
    end

    # Test with different body formats
    error1 = JDPIClient::Errors.from_response(400, nil)
    assert_instance_of JDPIClient::Errors::Validation, error1

    error2 = JDPIClient::Errors.from_response(400, {})
    assert_instance_of JDPIClient::Errors::Validation, error2

    error3 = JDPIClient::Errors.from_response(400, {"error" => "custom message"})
    assert_instance_of JDPIClient::Errors::Validation, error3
    assert_includes error3.message, "custom message"
  end

  # Test main module configuration
  def test_main_module_configuration
    # Test that we can get config
    config = JDPIClient.config
    assert_instance_of JDPIClient::Config, config

    # Test configuration with block
    JDPIClient.configure do |c|
      c.jdpi_client_host = "configured.test.example.com"
      c.oauth_client_id = "configured_client"
      c.oauth_secret = "configured_secret"
      c.timeout = 99
    end

    configured_config = JDPIClient.config
    assert_equal "configured.test.example.com", configured_config.jdpi_client_host
    assert_equal "configured_client", configured_config.oauth_client_id
    assert_equal "configured_secret", configured_config.oauth_secret
    assert_equal 99, configured_config.timeout

    # Test version constant
    assert defined?(JDPIClient::VERSION)
    assert_instance_of String, JDPIClient::VERSION
    assert_match(/\A\d+\.\d+\.\d+/, JDPIClient::VERSION)
  end
end