# frozen_string_literal: true

require_relative "test_helper"

class TestSPIOD < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"
  end

  def test_class_exists
    assert defined?(JDPIClient::SPI::OD)
  end

  def test_initialization
    od_client = JDPIClient::SPI::OD.new
    assert_instance_of JDPIClient::SPI::OD, od_client
  end

  def test_has_http_client
    od_client = JDPIClient::SPI::OD.new
    http_client = od_client.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    od_client = JDPIClient::SPI::OD.new(nil, @config)
    assert_instance_of JDPIClient::SPI::OD, od_client
  end

  def test_initialization_with_custom_token_provider
    token_provider = proc { "custom_token" }
    od_client = JDPIClient::SPI::OD.new(nil, @config, token_provider: token_provider)

    http_client = od_client.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_all_api_methods_exist
    od_client = JDPIClient::SPI::OD.new

    assert_respond_to od_client, :create_order!
    assert_respond_to od_client, :consult_request
    assert_respond_to od_client, :reasons
    assert_respond_to od_client, :credit_status_refund
  end

  def test_method_signatures
    od_client = JDPIClient::SPI::OD.new

    # create_order! should accept payload and optional idempotency_key
    assert_equal(-2, od_client.method(:create_order!).arity)

    # consult_request should accept one parameter
    assert_equal(1, od_client.method(:consult_request).arity)

    # reasons should accept no parameters
    assert_equal(0, od_client.method(:reasons).arity)

    # credit_status_refund should accept one parameter
    assert_equal(1, od_client.method(:credit_status_refund).arity)
  end

  def test_uses_provided_http_client
    mock_http = Object.new
    od_client = JDPIClient::SPI::OD.new(mock_http, @config, token_provider: proc { "token" })

    http_client = od_client.instance_variable_get(:@http)
    assert_same mock_http, http_client
  end
end