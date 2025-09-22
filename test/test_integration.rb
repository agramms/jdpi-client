# frozen_string_literal: true

require_relative "test_helper"

class TestIntegration < Minitest::Test
  def setup
    super # Important: Call parent setup for WebMock stubs

    JDPIClient.configure do |config|
      config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
      config.oauth_client_id = "test_client"
      config.oauth_secret = "test_secret"
      config.timeout = 10
      config.open_timeout = 3
    end
  end

  def test_all_service_clients_can_be_instantiated
    # Test that all service clients can be created without errors
    auth_client = JDPIClient::Auth::Client.new
    assert_instance_of JDPIClient::Auth::Client, auth_client

    spi_op = JDPIClient::SPI::OP.new
    assert_instance_of JDPIClient::SPI::OP, spi_op

    spi_od = JDPIClient::SPI::OD.new
    assert_instance_of JDPIClient::SPI::OD, spi_od

    dict_keys = JDPIClient::DICT::Keys.new
    assert_instance_of JDPIClient::DICT::Keys, dict_keys

    dict_claims = JDPIClient::DICT::Claims.new
    assert_instance_of JDPIClient::DICT::Claims, dict_claims

    dict_infractions = JDPIClient::DICT::Infractions.new
    assert_instance_of JDPIClient::DICT::Infractions, dict_infractions

    dict_med = JDPIClient::DICT::MED.new
    assert_instance_of JDPIClient::DICT::MED, dict_med

    qr_client = JDPIClient::QR::Client.new
    assert_instance_of JDPIClient::QR::Client, qr_client

    participants = JDPIClient::Participants.new
    assert_instance_of JDPIClient::Participants, participants
  end

  def test_service_clients_use_configured_settings
    # Verify that service clients pick up the global configuration
    spi_op = JDPIClient::SPI::OP.new
    http_client = spi_op.instance_variable_get(:@http)

    # Check that the HTTP client was configured with our settings
    conn = http_client.instance_variable_get(:@conn)
    assert_equal 10, conn.options.timeout
    assert_equal 3, conn.options.open_timeout
  end

  def test_service_clients_with_custom_token_provider
    custom_token_provider = proc { "custom_auth_token" }

    # Test that services accept custom token providers
    spi_op = JDPIClient::SPI::OP.new(nil, JDPIClient.config, token_provider: custom_token_provider)
    http_client = spi_op.instance_variable_get(:@http)
    token_provider = http_client.instance_variable_get(:@token_provider)

    assert_equal "custom_auth_token", token_provider.call
  end

  def test_environment_specific_configuration
    # Test production environment
    with_temp_config(jdpi_client_host: "api.bank.prod.jdpi.pstijd") do
      config = JDPIClient.config
      assert config.production?
      assert_equal "prod", config.environment
      assert config.base_url.start_with?("https://")

      # Test that services use production config
      spi_op = JDPIClient::SPI::OP.new
      http_client = spi_op.instance_variable_get(:@http)
      base_url = http_client.instance_variable_get(:@base)
      assert base_url.start_with?("https://")
    end

    # Test homolog environment
    with_temp_config(jdpi_client_host: "api.bank.homl.jdpi.pstijd") do
      config = JDPIClient.config
      refute config.production?
      assert_equal "homl", config.environment
      assert config.base_url.start_with?("http://")

      # Test that services use homolog config
      spi_op = JDPIClient::SPI::OP.new
      http_client = spi_op.instance_variable_get(:@http)
      base_url = http_client.instance_variable_get(:@base)
      assert base_url.start_with?("http://")
    end
  end

  def test_auth_client_integration_with_services
    # Test that auth client can be shared across services
    auth_client = JDPIClient::Auth::Client.new
    token_provider = auth_client.to_proc

    spi_op = JDPIClient::SPI::OP.new(nil, JDPIClient.config, token_provider: token_provider)
    qr_client = JDPIClient::QR::Client.new(nil, JDPIClient.config, token_provider: token_provider)

    # Both should use the same token provider
    spi_http = spi_op.instance_variable_get(:@http)
    qr_http = qr_client.instance_variable_get(:@http)

    spi_token_provider = spi_http.instance_variable_get(:@token_provider)
    qr_token_provider = qr_http.instance_variable_get(:@token_provider)

    assert_equal token_provider, spi_token_provider
    assert_equal token_provider, qr_token_provider
  end

  def test_error_handling_integration
    # Test that error classes are properly loaded and can be used
    validation_error = JDPIClient::Errors::Validation.new("Test validation error")
    assert_instance_of JDPIClient::Errors::Validation, validation_error
    assert_equal "Test validation error", validation_error.message

    # Test error factory method
    server_error = JDPIClient::Errors.from_response(500)
    assert_instance_of JDPIClient::Errors::ServerError, server_error

    unauthorized_error = JDPIClient::Errors.from_response(401)
    assert_instance_of JDPIClient::Errors::Unauthorized, unauthorized_error
  end

  def test_module_configuration_persistence
    # Test that configuration persists across multiple service instantiations
    original_host = JDPIClient.config.jdpi_client_host

    JDPIClient.configure do |config|
      config.jdpi_client_host = "persistent.test.host.com"
      config.timeout = 20
    end

    # Create multiple services and verify they all use the same config
    services = [
      JDPIClient::SPI::OP.new,
      JDPIClient::DICT::Keys.new,
      JDPIClient::QR::Client.new
    ]

    services.each do |service|
      http_client = service.instance_variable_get(:@http)
      base_url = http_client.instance_variable_get(:@base)
      assert_includes base_url, "persistent.test.host.com"

      conn = http_client.instance_variable_get(:@conn)
      assert_equal 20, conn.options.timeout
    end

    # Restore original config
    JDPIClient.configure do |config|
      config.jdpi_client_host = original_host
    end
  end
end
