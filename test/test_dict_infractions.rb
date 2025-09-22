# frozen_string_literal: true

require_relative "test_helper"

class TestDICTInfractions < Minitest::Test
  def test_class_exists
    assert defined?(JDPIClient::DICT::Infractions)
  end

  def test_initialization
    dict_infractions = JDPIClient::DICT::Infractions.new
    assert_instance_of JDPIClient::DICT::Infractions, dict_infractions
  end

  def test_has_http_client
    dict_infractions = JDPIClient::DICT::Infractions.new
    http_client = dict_infractions.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_all_parameters
    mock_http = Object.new
    config = JDPIClient::Config.new
    config.jdpi_client_host = "test.host.com"
    token_provider = proc { "test_token" }

    dict_infractions = JDPIClient::DICT::Infractions.new(mock_http, config, token_provider: token_provider)

    assert_same mock_http, dict_infractions.instance_variable_get(:@http)
  end
end
