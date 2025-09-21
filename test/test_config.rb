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
end