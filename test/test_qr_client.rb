# frozen_string_literal: true

require_relative "test_helper"

class TestQRClient < Minitest::Test
  def test_class_exists
    assert defined?(JDPIClient::QR::Client)
  end

  def test_initialization
    qr_client = JDPIClient::QR::Client.new
    assert_instance_of JDPIClient::QR::Client, qr_client
  end

  def test_has_http_client
    qr_client = JDPIClient::QR::Client.new
    http_client = qr_client.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    config = JDPIClient::Config.new
    config.jdpi_client_host = "custom.host.com"

    qr_client = JDPIClient::QR::Client.new(nil, config)
    assert_instance_of JDPIClient::QR::Client, qr_client
  end
end