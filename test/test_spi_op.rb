# frozen_string_literal: true

require_relative "test_helper"

class TestSPIOP < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"

    @token_provider = proc { "test_token_123" }
  end

  def test_initialization_with_default_http
    spi_op = JDPIClient::SPI::OP.new
    http_client = spi_op.instance_variable_get(:@http)

    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    spi_op = JDPIClient::SPI::OP.new(nil, @config)
    http_client = spi_op.instance_variable_get(:@http)

    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_token_provider
    custom_token_provider = proc { "custom_token" }
    spi_op = JDPIClient::SPI::OP.new(nil, @config, token_provider: custom_token_provider)
    http_client = spi_op.instance_variable_get(:@http)

    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_create_order_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :create_order!

    # Test method accepts required parameters
    assert spi_op.method(:create_order!).arity == -2 # 1 required, keyword optional
  end

  def test_consult_request_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :consult_request

    # Test method accepts one parameter
    assert_equal 1, spi_op.method(:consult_request).arity
  end

  def test_account_statement_pi_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :account_statement_pi

    # Test method accepts optional parameter
    assert_equal(-1, spi_op.method(:account_statement_pi).arity)
  end

  def test_account_statement_tx_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :account_statement_tx

    # Test method accepts optional parameter
    assert_equal(-1, spi_op.method(:account_statement_tx).arity)
  end

  def test_posting_detail_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :posting_detail

    # Test method accepts one parameter
    assert_equal 1, spi_op.method(:posting_detail).arity
  end

  def test_credit_status_payment_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :credit_status_payment

    # Test method accepts one parameter
    assert_equal 1, spi_op.method(:credit_status_payment).arity
  end

  def test_posting_spi_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :posting_spi

    # Test method accepts one parameter
    assert_equal 1, spi_op.method(:posting_spi).arity
  end

  def test_remuneration_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :remuneration

    # Test method accepts one parameter
    assert_equal 1, spi_op.method(:remuneration).arity
  end

  def test_balance_pi_jdpi_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :balance_pi_jdpi

    # Test method accepts no parameters
    assert_equal 0, spi_op.method(:balance_pi_jdpi).arity
  end

  def test_balance_pi_spi_method_signature
    spi_op = JDPIClient::SPI::OP.new
    assert_respond_to spi_op, :balance_pi_spi

    # Test method accepts no parameters
    assert_equal 0, spi_op.method(:balance_pi_spi).arity
  end

  def test_uses_provided_http_client
    mock_http = Object.new # Simple object instead of mock
    spi_op = JDPIClient::SPI::OP.new(mock_http, @config, token_provider: @token_provider)

    # Each method should use the provided HTTP client
    http_client = spi_op.instance_variable_get(:@http)
    assert_same mock_http, http_client
  end

  def test_api_methods_exist
    # Test that the API methods exist and have expected behavior
    spi_op = JDPIClient::SPI::OP.new

    assert_respond_to spi_op, :create_order!
    assert_respond_to spi_op, :account_statement_pi
    assert_respond_to spi_op, :account_statement_tx
    assert_respond_to spi_op, :consult_request
    assert_respond_to spi_op, :posting_detail
    assert_respond_to spi_op, :credit_status_payment
    assert_respond_to spi_op, :posting_spi
    assert_respond_to spi_op, :remuneration
    assert_respond_to spi_op, :balance_pi_jdpi
    assert_respond_to spi_op, :balance_pi_spi
  end
end