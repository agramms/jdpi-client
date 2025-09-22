# frozen_string_literal: true

require_relative "test_helper"

class TestDICTMED < Minitest::Test
  def test_class_exists
    assert defined?(JDPIClient::DICT::MED)
  end

  def test_initialization
    dict_med = JDPIClient::DICT::MED.new
    assert_instance_of JDPIClient::DICT::MED, dict_med
  end

  def test_has_http_client
    dict_med = JDPIClient::DICT::MED.new
    http_client = dict_med.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_dependencies
    config = JDPIClient::Config.new
    config.jdpi_client_host = "test.example.com"
    config.oauth_client_id = "test_id"
    config.oauth_secret = "test_secret"

    dict_med = JDPIClient::DICT::MED.new(nil, config)
    assert_instance_of JDPIClient::DICT::MED, dict_med

    http_client = dict_med.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end
end
