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

  def test_initialization_with_token_provider
    token_provider = proc { "qr_test_token" }
    qr_client = JDPIClient::QR::Client.new(nil, JDPIClient::Config.new, token_provider: token_provider)

    http_client = qr_client.instance_variable_get(:@http)
    http_token_provider = http_client.instance_variable_get(:@token_provider)

    assert_equal "qr_test_token", http_token_provider.call
  end

  def test_initialization_with_custom_http_client
    custom_http = Object.new
    qr_client = JDPIClient::QR::Client.new(custom_http)

    http_client = qr_client.instance_variable_get(:@http)
    assert_same custom_http, http_client
  end

  def test_all_qr_methods_exist
    qr_client = JDPIClient::QR::Client.new

    # Test that all QR-specific methods exist
    assert_respond_to qr_client, :static_generate
    assert_respond_to qr_client, :dynamic_immediate_generate
    assert_respond_to qr_client, :decode
    assert_respond_to qr_client, :dynamic_immediate_update
    assert_respond_to qr_client, :cert_download
    assert_respond_to qr_client, :cobv_generate
    assert_respond_to qr_client, :cobv_update
    assert_respond_to qr_client, :cobv_jws
  end

  def test_method_signatures
    qr_client = JDPIClient::QR::Client.new

    # Test method arities (methods with keyword arguments have negative arity)
    assert_equal(-2, qr_client.method(:static_generate).arity)
    assert_equal(-2, qr_client.method(:dynamic_immediate_generate).arity)
    assert_equal(1, qr_client.method(:decode).arity)
    assert_equal(2, qr_client.method(:dynamic_immediate_update).arity)
    assert_equal(0, qr_client.method(:cert_download).arity)
    assert_equal(-2, qr_client.method(:cobv_generate).arity)
    assert_equal(2, qr_client.method(:cobv_update).arity)
    assert_equal(1, qr_client.method(:cobv_jws).arity)
  end
end
