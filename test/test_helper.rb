# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/jdpi_client"

class Minitest::Test
  def setup
    JDPIClient.config.instance_variable_set(:@jdpi_client_host, "localhost")
    JDPIClient.config.instance_variable_set(:@oauth_client_id, "test_client")
    JDPIClient.config.instance_variable_set(:@oauth_secret, "test_secret")
  end
end