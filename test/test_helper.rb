# frozen_string_literal: true

# Coverage setup (Ruby 3.0+ only gem)
if ENV["COVERAGE"] == "true"
  require "simplecov"

  SimpleCov.start do
    # Configure coverage settings
    add_filter "/test/"
    add_filter "/vendor/"
    add_filter "/.bundle/"

    # Group coverage by type
    add_group "Library", "lib"
    add_group "Services", "lib/jdpi_client"
    add_group "Auth", "lib/jdpi_client/auth"
    add_group "SPI", "lib/jdpi_client/spi"
    add_group "DICT", "lib/jdpi_client/dict"
    add_group "QR", "lib/jdpi_client/qr"
    add_group "Token Storage", "lib/jdpi_client/token_storage"

    # Coverage thresholds (can be increased over time)
    minimum_coverage 85
    minimum_coverage_by_file 5

    # Output formats
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::SimpleFormatter
                                                       ])

    # Track files that should be covered even if not loaded during tests
    track_files "lib/**/*.rb"
  end

  puts "📊 Coverage tracking enabled for Ruby #{RUBY_VERSION}"
end

# Service integration configuration with mocking
module ServiceConfiguration
  extend self

  def integration_tests_enabled?
    true # Always enabled since we use mocks
  end

  def redis_available?
    true # Always available with mock_redis
  end

  def postgres_available?
    true # Always available with SQLite
  end

  def dynamodb_available?
    true # Always available with mocks
  end

  def test_adapter
    return :memory if ENV["SKIP_INTEGRATION"] == "true"

    case ENV["TEST_ADAPTER"]
    when "memory" then :memory
    when "redis" then :redis
    when "postgres", "postgresql", "database" then :database
    when "dynamodb" then :dynamodb
    when "all" then :all
    else
      :memory # Default to memory for fast tests
    end
  end

  def create_test_config(adapter_type = nil)
    adapter_type ||= test_adapter

    config = JDPIClient::Config.new
    config.jdpi_client_host = "localhost"
    config.oauth_client_id = "test_client"
    config.oauth_secret = "test_secret"
    config.timeout = 5
    config.open_timeout = 2

    case adapter_type
    when :redis
      config.token_storage_adapter = :redis
      config.token_storage_url = "redis://localhost:6379/0"
      config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    when :database
      config.token_storage_adapter = :database
      config.token_storage_url = "sqlite3:///:memory:"
      config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    when :dynamodb
      config.token_storage_adapter = :dynamodb
      config.token_storage_options = {
        table_name: "jdpi_test_tokens",
        region: "us-east-1"
      }
      config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    else # :memory
      config.token_storage_adapter = :memory
      config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    end

    config
  end

  def create_database_config(database_url = nil)
    config = JDPIClient::Config.new
    config.jdpi_client_host = "localhost"
    config.oauth_client_id = "test_client"
    config.oauth_secret = "test_secret"
    config.timeout = 5
    config.open_timeout = 2
    config.token_storage_adapter = :database
    config.token_storage_url = database_url || "sqlite3:///:memory:"
    config.token_encryption_key = JDPIClient::TokenStorage::Encryption.generate_key
    config
  end

  def skip_unless_service_available(service_name)
    case service_name
    when :redis
      skip "Redis not available in test environment" unless redis_available?
    when :postgres, :postgresql, :database
      skip "PostgreSQL not available in test environment" unless postgres_available?
    when :dynamodb
      skip "DynamoDB not available in test environment" unless dynamodb_available?
    when :integration
      skip "Integration tests disabled" unless integration_tests_enabled?
    end
  end

  def cleanup_test_data!
    # Cleanup is handled by the individual test teardown methods
    # since we're using mocked services that reset automatically
  end
end

require "minitest/autorun"
require "minitest/pride"
require "webmock/minitest"
require_relative "../lib/jdpi_client"

# Configure WebMock to allow localhost connections but mock external requests
WebMock.disable_net_connect!(allow_localhost: true)

# Set up common HTTP stubs
def setup_common_http_stubs
  # Stub OAuth token requests - any body/headers allowed
  stub_request(:post, "http://api.test.homl.jdpi.pstijd/auth/jdpi/connect/token")
    .to_return(
      status: 200,
      body: {
        access_token: "mocked_access_token_123",
        token_type: "Bearer",
        expires_in: 3600,
        scope: "read write"
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

  # Stub any other common API endpoints
  stub_request(:get, /.*\/api\/.*/)
    .to_return(status: 200, body: '{"status": "success"}', headers: { 'Content-Type' => 'application/json' })

  stub_request(:post, /.*\/api\/.*/)
    .to_return(status: 200, body: '{"status": "success"}', headers: { 'Content-Type' => 'application/json' })

  stub_request(:put, /.*\/api\/.*/)
    .to_return(status: 200, body: '{"status": "success"}', headers: { 'Content-Type' => 'application/json' })

  stub_request(:delete, /.*\/api\/.*/)
    .to_return(status: 200, body: '{"status": "success"}', headers: { 'Content-Type' => 'application/json' })
end

class Minitest::Test
  include ServiceConfiguration

  def setup
    # Reset configuration for each test to ensure isolation
    JDPIClient.instance_variable_set(:@config, nil)

    # Set up test configuration based on environment
    @test_config = create_test_config
    JDPIClient.instance_variable_set(:@config, @test_config)

    # Set up HTTP stubs for external requests
    setup_common_http_stubs

    # Clean up any existing test data (handled by individual test teardown)
  end

  def teardown
    # Clean up any test artifacts (handled by individual test teardown)
    JDPIClient.instance_variable_set(:@config, nil)
    # Reset WebMock stubs
    WebMock.reset!
  end

  # Helper method to create storage instance for testing
  def create_storage(adapter_type = nil)
    config = create_test_config(adapter_type)
    JDPIClient::TokenStorage::Factory.create(config)
  end

  # Helper method to skip tests based on service availability
  def skip_unless_available(service)
    skip_unless_service_available(service)
  end
end

# Helper methods for testing
module TestHelpers
  def mock_successful_response(data = {})
    {
      "status" => "success",
      "data" => data,
      "timestamp" => Time.now.utc.iso8601
    }
  end

  def mock_error_response(message = "Test error", code = 400)
    {
      "error" => {
        "message" => message,
        "code" => code
      }
    }
  end

  def with_temp_config(**options)
    original_config = JDPIClient.config.dup

    JDPIClient.configure do |config|
      options.each { |key, value| config.send("#{key}=", value) }
    end

    yield
  ensure
    # Restore original configuration
    JDPIClient.instance_variable_set(:@config, original_config)
  end
end

# Include helper methods in test classes
Minitest::Test.include TestHelpers
