# frozen_string_literal: true

require_relative "test_helper"

class TestJDPIClient < Minitest::Test
  def teardown
    # Reset the module state after each test
    JDPIClient.instance_variable_set(:@config, nil)
  end

  def test_module_exists
    assert defined?(JDPIClient)
    assert_kind_of Module, JDPIClient
  end

  def test_configure_yields_config
    yielded_config = nil

    JDPIClient.configure do |config|
      yielded_config = config
    end

    assert_instance_of JDPIClient::Config, yielded_config
    assert_equal JDPIClient.config, yielded_config
  end

  def test_configure_allows_setting_values
    JDPIClient.configure do |config|
      config.jdpi_client_host = "custom.host.com"
      config.oauth_client_id = "custom_client"
      config.oauth_secret = "custom_secret"
      config.timeout = 15
    end

    config = JDPIClient.config
    assert_equal "custom.host.com", config.jdpi_client_host
    assert_equal "custom_client", config.oauth_client_id
    assert_equal "custom_secret", config.oauth_secret
    assert_equal 15, config.timeout
  end

  def test_config_returns_same_instance
    config1 = JDPIClient.config
    config2 = JDPIClient.config

    assert_same config1, config2
  end

  def test_config_creates_new_instance_when_needed
    # Reset to ensure clean state
    JDPIClient.instance_variable_set(:@config, nil)
    assert_nil JDPIClient.instance_variable_get(:@config)

    config = JDPIClient.config
    assert_instance_of JDPIClient::Config, config
    assert_equal config, JDPIClient.instance_variable_get(:@config)
  end

  def test_configure_and_config_work_together
    JDPIClient.configure do |config|
      config.jdpi_client_host = "test.example.com"
    end

    retrieved_config = JDPIClient.config
    assert_equal "test.example.com", retrieved_config.jdpi_client_host
  end

  def test_multiple_configure_calls_use_same_config
    JDPIClient.configure do |config|
      config.jdpi_client_host = "first.com"
    end

    JDPIClient.configure do |config|
      config.oauth_client_id = "test_client"
    end

    config = JDPIClient.config
    assert_equal "first.com", config.jdpi_client_host
    assert_equal "test_client", config.oauth_client_id
  end

  def test_module_has_version_constant
    assert defined?(JDPIClient::VERSION)
    assert_instance_of String, JDPIClient::VERSION
    assert_match(/\A\d+\.\d+\.\d+\z/, JDPIClient::VERSION)
  end

  def test_required_classes_are_loaded
    assert defined?(JDPIClient::Config)
    assert defined?(JDPIClient::HTTP)
    assert defined?(JDPIClient::Auth::Client)
    assert defined?(JDPIClient::SPI::OP)
    assert defined?(JDPIClient::SPI::OD)
    assert defined?(JDPIClient::DICT::Keys)
    assert defined?(JDPIClient::DICT::Claims)
    assert defined?(JDPIClient::DICT::Infractions)
    assert defined?(JDPIClient::DICT::MED)
    assert defined?(JDPIClient::QR::Client)
    assert defined?(JDPIClient::Participants)
    assert defined?(JDPIClient::Errors)
  end

  def test_error_classes_are_available
    assert defined?(JDPIClient::Errors::Error)
    assert defined?(JDPIClient::Errors::ConfigurationError)
    assert defined?(JDPIClient::Errors::Unauthorized)
    assert defined?(JDPIClient::Errors::Forbidden)
    assert defined?(JDPIClient::Errors::NotFound)
    assert defined?(JDPIClient::Errors::RateLimited)
    assert defined?(JDPIClient::Errors::ServerError)
    assert defined?(JDPIClient::Errors::Validation)
  end

  def test_service_classes_can_be_instantiated
    JDPIClient.configure do |config|
      config.jdpi_client_host = "test.example.com"
      config.oauth_client_id = "test"
      config.oauth_secret = "secret"
    end

    assert_instance_of JDPIClient::Auth::Client, JDPIClient::Auth::Client.new
    assert_instance_of JDPIClient::SPI::OP, JDPIClient::SPI::OP.new
    assert_instance_of JDPIClient::SPI::OD, JDPIClient::SPI::OD.new
    assert_instance_of JDPIClient::QR::Client, JDPIClient::QR::Client.new
    assert_instance_of JDPIClient::Participants, JDPIClient::Participants.new
  end
end