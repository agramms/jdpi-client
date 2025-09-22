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

    # Coverage thresholds (can be increased over time)
    minimum_coverage 72
    minimum_coverage_by_file 60

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

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/jdpi_client"

class Minitest::Test
  def setup
    # Reset configuration for each test to ensure isolation
    JDPIClient.instance_variable_set(:@config, nil)

    # Set up test configuration
    JDPIClient.configure do |config|
      config.jdpi_client_host = "localhost"
      config.oauth_client_id = "test_client"
      config.oauth_secret = "test_secret"
      config.timeout = 5
      config.open_timeout = 2
    end
  end

  def teardown
    # Clean up any test artifacts
    JDPIClient.instance_variable_set(:@config, nil)
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
