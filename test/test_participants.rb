# frozen_string_literal: true

require_relative "test_helper"

class TestParticipants < Minitest::Test
  def test_class_exists
    assert defined?(JDPIClient::Participants)
  end

  def test_initialization
    participants = JDPIClient::Participants.new
    assert_instance_of JDPIClient::Participants, participants
  end

  def test_has_http_client
    participants = JDPIClient::Participants.new
    http_client = participants.instance_variable_get(:@http)
    assert_instance_of JDPIClient::HTTP, http_client
  end

  def test_initialization_with_custom_config
    config = JDPIClient::Config.new
    config.jdpi_client_host = "custom.host.com"

    participants = JDPIClient::Participants.new(nil, config)
    assert_instance_of JDPIClient::Participants, participants
  end
end