# frozen_string_literal: true

require_relative "test_helper"

class TestHTTPRequestPaths < Minitest::Test
  def setup
    super  # Important: Call parent setup for WebMock stubs

    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @token_provider = proc { "test_token" }
  end

  def test_http_request_method_with_different_scenarios
    http = JDPIClient::HTTP.new(
      base: @config.base_url,
      token_provider: @token_provider
    )

    # Test that request method exists and has proper structure
    assert http.private_methods.include?(:request)

    # Test default_headers method
    headers = http.send(:default_headers)
    assert_equal "Bearer test_token", headers["Authorization"]
    assert_equal "application/json; charset=utf-8", headers["Content-Type"]
    assert_equal "application/json", headers["Accept"]

    # Test parse_json with different scenarios
    assert_equal({}, http.send(:parse_json, nil))
    assert_equal({}, http.send(:parse_json, ""))
    assert_equal({ "test" => "value" }, http.send(:parse_json, '{"test": "value"}'))
    assert_equal({ "existing" => "hash" }, http.send(:parse_json, { "existing" => "hash" }))

    # Test JSON parse error handling
    assert_raises(MultiJson::ParseError) do
      http.send(:parse_json, "invalid json {")
    end
  end

  def test_error_factory_comprehensive
    # Test all error status codes
    test_cases = [
      [400, JDPIClient::Errors::Validation, "Bad Request"],
      [401, JDPIClient::Errors::Unauthorized, "Unauthorized"],
      [403, JDPIClient::Errors::Forbidden, "Forbidden"],
      [404, JDPIClient::Errors::NotFound, "Not Found"],
      [429, JDPIClient::Errors::RateLimited, "Too Many Requests"],
      [500, JDPIClient::Errors::ServerError, "Server Error 500"],
      [502, JDPIClient::Errors::ServerError, "Server Error 502"],
      [503, JDPIClient::Errors::ServerError, "Server Error 503"],
      [418, JDPIClient::Errors::Error, "HTTP 418"]
    ]

    test_cases.each do |status, expected_class, expected_message|
      error = JDPIClient::Errors.from_response(status)
      assert_instance_of expected_class, error
      assert_equal expected_message, error.message
    end

    # Test validation error with custom message
    body = { "message" => "Custom validation message" }
    error = JDPIClient::Errors.from_response(400, body)
    assert_instance_of JDPIClient::Errors::Validation, error
    assert_equal "Custom validation message", error.message

    # Test validation error with nil body
    error = JDPIClient::Errors.from_response(400, nil)
    assert_equal "Bad Request", error.message

    # Test validation error with empty body
    error = JDPIClient::Errors.from_response(400, {})
    assert_equal "Bad Request", error.message
  end

  def test_config_all_edge_cases
    config = JDPIClient::Config.new

    # Test default values
    assert_equal "localhost", config.jdpi_client_host
    assert_equal 8, config.timeout
    assert_equal 2, config.open_timeout
    assert_nil config.logger

    # Test production detection edge cases
    prod_hosts = [
      "api.prod.example.com",
      "prod-api.example.com",
      "api.production.example.com",
      "production-api.example.com",
      "api.bank.prod.jdpi.pstijd",
      "my.production.host.com"
    ]

    prod_hosts.each do |host|
      config.jdpi_client_host = host
      assert config.production?, "#{host} should be detected as production"
      assert_equal "prod", config.environment
      assert config.base_url.start_with?("https://"), "Production should use HTTPS"
    end

    # Test non-production detection
    non_prod_hosts = [
      "api.homl.example.com",
      "api.test.example.com",
      "api.dev.example.com",
      "localhost",
      "127.0.0.1",
      "staging.example.com",
      "api.sandbox.example.com"
    ]

    non_prod_hosts.each do |host|
      config.jdpi_client_host = host
      refute config.production?, "#{host} should NOT be detected as production"
      assert_equal "homl", config.environment
      assert config.base_url.start_with?("http://"), "Non-production should use HTTP"
    end

    # Test nil and empty values
    config.jdpi_client_host = nil
    refute config.production?
    assert_equal "homl", config.environment
    assert_equal "http://", config.base_url

    config.jdpi_client_host = ""
    refute config.production?
    assert_equal "homl", config.environment
    assert_equal "http://", config.base_url
  end

  def test_auth_client_token_management
    auth_client = JDPIClient::Auth::Client.new(@config)

    # Test MonitorMixin inclusion
    assert auth_client.class.ancestors.include?(MonitorMixin)
    assert_respond_to auth_client, :synchronize

    # Test token expiration logic
    auth_client.instance_variable_set(:@expires_at, Time.now - 1)
    assert auth_client.instance_variable_get(:@expires_at) < Time.now

    # Test cached token when not expired
    storage = auth_client.instance_variable_get(:@storage)
    cache_key = auth_client.instance_variable_get(:@cache_key)
    token_data = {
      "access_token" => "valid_token",
      "expires_at" => Time.now.to_i + 3600,
      "token_type" => "Bearer"
    }
    storage.store(cache_key, token_data, 3600)

    token = auth_client.token!
    assert_equal "valid_token", token

    # Test to_proc method
    token_proc = auth_client.to_proc
    assert_instance_of Proc, token_proc
    assert_equal "valid_token", token_proc.call

    # Test expiration buffer logic
    expires_in = 3600
    buffer = 10
    auth_client.instance_variable_set(:@expires_at, Time.now + expires_in - buffer)
    expires_at = auth_client.instance_variable_get(:@expires_at)
    assert expires_at < Time.now + expires_in
  end

  def test_module_configuration_edge_cases
    original_config = JDPIClient.config.dup

    # Test configure block
    JDPIClient.configure do |config|
      assert_instance_of JDPIClient::Config, config
      config.jdpi_client_host = "configured.test.com"
      config.timeout = 25
      config.open_timeout = 15
    end

    config = JDPIClient.config
    assert_equal "configured.test.com", config.jdpi_client_host
    assert_equal 25, config.timeout
    assert_equal 15, config.open_timeout

    # Test that config persists
    same_config = JDPIClient.config
    assert_same config, same_config

    # Restore original for other tests
    JDPIClient.instance_variable_set(:@config, original_config)
  end

  def test_faraday_connection_configuration
    http = JDPIClient::HTTP.new(
      base: "http://test.example.com",
      token_provider: proc { "token" },
      timeout: 20,
      open_timeout: 10
    )

    conn = http.instance_variable_get(:@conn)
    assert_instance_of Faraday::Connection, conn
    assert_equal 20, conn.options.timeout
    assert_equal 10, conn.options.open_timeout
    assert_equal "http://test.example.com/", conn.url_prefix.to_s
  end
end