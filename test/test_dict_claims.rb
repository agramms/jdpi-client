# frozen_string_literal: true

require_relative "test_helper"

class TestDICTClaims < Minitest::Test
  def test_class_exists
    assert defined?(JDPIClient::DICT::Claims)
  end

  def test_initialization
    dict_claims = JDPIClient::DICT::Claims.new
    assert_instance_of JDPIClient::DICT::Claims, dict_claims
  end

  def test_has_http_client
    dict_claims = JDPIClient::DICT::Claims.new
    http_client = dict_claims.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    config = JDPIClient::Config.new
    config.jdpi_client_host = "custom.host.com"
    config.oauth_client_id = "test"
    config.oauth_secret = "secret"

    dict_claims = JDPIClient::DICT::Claims.new(nil, config)
    assert_instance_of JDPIClient::DICT::Claims, dict_claims
  end

  def test_initialization_with_custom_http_and_token_provider
    mock_http = Object.new
    token_provider = proc { "custom_token" }
    config = JDPIClient::Config.new

    dict_claims = JDPIClient::DICT::Claims.new(mock_http, config, token_provider: token_provider)

    assert_same mock_http, dict_claims.instance_variable_get(:@http)
  end
end
