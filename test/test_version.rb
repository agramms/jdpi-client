# frozen_string_literal: true

require_relative "test_helper"

class TestVersion < Minitest::Test
  def test_version_constant_exists
    assert defined?(JDPIClient::VERSION)
  end

  def test_version_is_string
    assert_instance_of String, JDPIClient::VERSION
  end

  def test_version_format
    # Version should follow semantic versioning pattern
    assert_match(/\A\d+\.\d+\.\d+\z/, JDPIClient::VERSION)
  end

  def test_version_not_empty
    refute_empty JDPIClient::VERSION
  end
end
