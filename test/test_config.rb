# frozen_string_literal: true

require_relative "test_helper"

class TestConfig < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
  end

  def test_default_configuration
    assert_equal "localhost", @config.jdpi_client_host
    assert_equal 8, @config.timeout
    assert_equal 2, @config.open_timeout
  end

  def test_production_detection
    @config.jdpi_client_host = "api.mybank.prod.jdpi.pstijd"
    assert @config.production?
    assert_equal "prod", @config.environment

    @config.jdpi_client_host = "api.mybank.production.jdpi.pstijd"
    assert @config.production?
    assert_equal "prod", @config.environment
  end

  def test_homolog_detection
    @config.jdpi_client_host = "api.mybank.homl.jdpi.pstijd"
    refute @config.production?
    assert_equal "homl", @config.environment

    @config.jdpi_client_host = "localhost"
    refute @config.production?
    assert_equal "homl", @config.environment
  end

  def test_base_url_generation
    @config.jdpi_client_host = "api.mybank.homl.jdpi.pstijd"
    assert_equal "http://api.mybank.homl.jdpi.pstijd", @config.base_url

    @config.jdpi_client_host = "api.mybank.prod.jdpi.pstijd"
    assert_equal "https://api.mybank.prod.jdpi.pstijd", @config.base_url
  end

  def test_configuration_attributes_are_accessible
    # Test all attributes can be read and written
    @config.jdpi_client_host = "test.host.com"
    @config.oauth_client_id = "test_client_id"
    @config.oauth_secret = "test_secret"
    @config.timeout = 15
    @config.open_timeout = 5
    @config.logger = Logger.new(StringIO.new)

    assert_equal "test.host.com", @config.jdpi_client_host
    assert_equal "test_client_id", @config.oauth_client_id
    assert_equal "test_secret", @config.oauth_secret
    assert_equal 15, @config.timeout
    assert_equal 5, @config.open_timeout
    assert_instance_of Logger, @config.logger
  end

  def test_production_detection_edge_cases
    # Test various production hostname patterns
    production_hosts = [
      "api.bank.prod.jdpi.pstijd",
      "api.bank.production.jdpi.pstijd",
      "prod.api.bank.jdpi.pstijd",
      "production.api.bank.jdpi.pstijd"
    ]

    production_hosts.each do |host|
      @config.jdpi_client_host = host
      assert @config.production?, "#{host} should be detected as production"
      assert_equal "prod", @config.environment
      assert @config.base_url.start_with?("https://")
    end
  end

  def test_homolog_detection_edge_cases
    # Test various non-production hostname patterns
    homolog_hosts = [
      "api.bank.homl.jdpi.pstijd",
      "api.bank.dev.jdpi.pstijd",
      "api.bank.test.jdpi.pstijd",
      "localhost",
      "127.0.0.1",
      "api.bank.staging.jdpi.pstijd"
    ]

    homolog_hosts.each do |host|
      @config.jdpi_client_host = host
      refute @config.production?, "#{host} should NOT be detected as production"
      assert_equal "homl", @config.environment
      assert @config.base_url.start_with?("http://")
    end
  end

  def test_nil_host_handling
    @config.jdpi_client_host = nil
    refute @config.production?
    assert_equal "homl", @config.environment
  end

  def test_empty_string_host_handling
    @config.jdpi_client_host = ""
    refute @config.production?
    assert_equal "homl", @config.environment
    assert_equal "http://", @config.base_url
  end

  def test_case_sensitive_production_detection
    # Test lowercase variations work
    @config.jdpi_client_host = "api.bank.prod.jdpi.pstijd"
    assert @config.production?

    @config.jdpi_client_host = "api.bank.production.jdpi.pstijd"
    assert @config.production?

    # Test uppercase variations don't work (case sensitive)
    @config.jdpi_client_host = "API.BANK.PROD.JDPI.PSTIJD"
    refute @config.production?
  end

  def test_base_url_format
    # Test that base_url returns proper URL format
    @config.jdpi_client_host = "api.test.com"
    base_url = @config.base_url
    assert base_url.match?(/^https?:\/\/.+/), "Base URL should be a valid URL format"
  end

  def test_config_attribute_assignment
    # Test that all attributes can be assigned and retrieved
    test_values = {
      jdpi_client_host: "new.host.com",
      oauth_client_id: "new_client",
      oauth_secret: "new_secret",
      timeout: 20,
      open_timeout: 10
    }

    test_values.each do |attr, value|
      @config.send("#{attr}=", value)
      assert_equal value, @config.send(attr)
    end
  end
end
