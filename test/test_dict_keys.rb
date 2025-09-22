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
end
