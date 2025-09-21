# frozen_string_literal: true

require_relative "test_helper"
require "faraday"

class TestAuthClient < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
    @config.oauth_client_id = "test_client"
    @config.oauth_secret = "test_secret"
    @auth_client = JDPIClient::Auth::Client.new(@config)
  end

  def test_token_caching
    # Mock successful token response
    stub_token_request(access_token: "test_token", expires_in: 3600)

    token1 = @auth_client.token!
    token2 = @auth_client.token!

    assert_equal "test_token", token1
    assert_equal "test_token", token2
  end

  def test_token_refresh_when_expired
    # Mock first token request
    stub_token_request(access_token: "old_token", expires_in: -1)

    old_token = @auth_client.token!
    assert_equal "old_token", old_token

    # Mock second token request
    stub_token_request(access_token: "new_token", expires_in: 3600)

    new_token = @auth_client.token!
    assert_equal "new_token", new_token
  end

  def test_to_proc
    stub_token_request(access_token: "proc_token", expires_in: 3600)

    token_proc = @auth_client.to_proc
    assert_instance_of Proc, token_proc
    assert_equal "proc_token", token_proc.call
  end

  private

  def stub_token_request(access_token:, expires_in:)
    response_body = {
      "access_token" => access_token,
      "expires_in" => expires_in,
      "token_type" => "Bearer"
    }

    # Create a stub connection that returns our mock response
    conn = Minitest::Mock.new
    response = Minitest::Mock.new
    response.expect(:body, MultiJson.dump(response_body))

    conn.expect(:post, response, ["/auth/jdpi/connect/token", Hash])

    # Replace the real connection with our mock
    Faraday.stub(:new, conn) do
      @auth_client.refresh!
    end
  end
end