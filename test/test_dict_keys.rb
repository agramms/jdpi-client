# frozen_string_literal: true

require_relative "test_helper"

class TestDICTKeys < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"
  end

  def test_class_exists
    assert defined?(JDPIClient::DICT::Keys)
  end

  def test_initialization
    dict_keys = JDPIClient::DICT::Keys.new
    assert_instance_of JDPIClient::DICT::Keys, dict_keys
  end

  def test_has_http_client
    dict_keys = JDPIClient::DICT::Keys.new
    http_client = dict_keys.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    dict_keys = JDPIClient::DICT::Keys.new(nil, @config)
    assert_instance_of JDPIClient::DICT::Keys, dict_keys
  end

  def test_initialization_with_token_provider
    token_provider = proc { "test_token" }
    dict_keys = JDPIClient::DICT::Keys.new(nil, @config, token_provider: token_provider)

    http_client = dict_keys.instance_variable_get(:@http)
    http_token_provider = http_client.instance_variable_get(:@token_provider)

    assert_equal "test_token", http_token_provider.call
  end

  def test_initialization_creates_auth_client_when_no_token_provider
    # This should trigger the creation of a default auth client
    dict_keys = JDPIClient::DICT::Keys.new(nil, @config)

    http_client = dict_keys.instance_variable_get(:@http)
    token_provider = http_client.instance_variable_get(:@token_provider)

    assert_instance_of Proc, token_provider
  end

  def test_uses_provided_http_client
    mock_http = Object.new
    dict_keys = JDPIClient::DICT::Keys.new(mock_http, @config, token_provider: proc { "token" })

    http_client = dict_keys.instance_variable_get(:@http)
    assert_same mock_http, http_client
  end

  def test_all_methods_exist
    dict_keys = JDPIClient::DICT::Keys.new(nil, @config)

    # Test that all expected methods exist
    assert_respond_to dict_keys, :create
    assert_respond_to dict_keys, :update
    assert_respond_to dict_keys, :delete
    assert_respond_to dict_keys, :list_by_customer
    assert_respond_to dict_keys, :get
    assert_respond_to dict_keys, :stats
  end

  def test_method_signatures
    dict_keys = JDPIClient::DICT::Keys.new(nil, @config)

    # Test create method signature (payload + keyword arg)
    assert_equal(2, dict_keys.method(:create).arity)

    # Test update method signature (chave, payload + keyword arg)
    assert_equal(3, dict_keys.method(:update).arity)

    # Test delete method signature (chave + keyword arg)
    assert_equal(2, dict_keys.method(:delete).arity)

    # Test other methods (positional args only)
    assert_equal(1, dict_keys.method(:list_by_customer).arity)
    assert_equal(1, dict_keys.method(:get).arity)
    assert_equal(1, dict_keys.method(:stats).arity)
  end
end
