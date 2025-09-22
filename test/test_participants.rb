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

  def test_initialization_with_token_provider
    token_provider = proc { "participants_token" }
    participants = JDPIClient::Participants.new(nil, JDPIClient::Config.new, token_provider: token_provider)

    http_client = participants.instance_variable_get(:@http)
    http_token_provider = http_client.instance_variable_get(:@token_provider)

    assert_equal "participants_token", http_token_provider.call
  end

  def test_initialization_with_custom_http_client
    custom_http = Object.new
    participants = JDPIClient::Participants.new(custom_http)

    http_client = participants.instance_variable_get(:@http)
    assert_same custom_http, http_client
  end

  def test_all_participant_methods_exist
    participants = JDPIClient::Participants.new

    # Test that all participant methods exist
    assert_respond_to participants, :list
    assert_respond_to participants, :consult
  end

  def test_method_signatures
    participants = JDPIClient::Participants.new

    # Test method arities
    assert_equal(-1, participants.method(:list).arity)
    assert_equal(-1, participants.method(:consult).arity)
  end
end
