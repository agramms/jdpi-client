# frozen_string_literal: true

require_relative "test_helper"

class TestErrors < Minitest::Test
  def test_error_inheritance
    assert JDPIClient::Errors::Error < StandardError
    assert JDPIClient::Errors::ConfigurationError < JDPIClient::Errors::Error
    assert JDPIClient::Errors::Unauthorized < JDPIClient::Errors::Error
    assert JDPIClient::Errors::Forbidden < JDPIClient::Errors::Error
    assert JDPIClient::Errors::NotFound < JDPIClient::Errors::Error
    assert JDPIClient::Errors::RateLimited < JDPIClient::Errors::Error
    assert JDPIClient::Errors::ServerError < JDPIClient::Errors::Error
    assert JDPIClient::Errors::Validation < JDPIClient::Errors::Error
  end

  def test_from_response_400_with_message
    body = { "message" => "Invalid parameters" }
    error = JDPIClient::Errors.from_response(400, body)

    assert_instance_of JDPIClient::Errors::Validation, error
    assert_equal "Invalid parameters", error.message
  end

  def test_from_response_400_without_message
    error = JDPIClient::Errors.from_response(400, nil)

    assert_instance_of JDPIClient::Errors::Validation, error
    assert_equal "Bad Request", error.message
  end

  def test_from_response_400_with_empty_body
    error = JDPIClient::Errors.from_response(400, {})

    assert_instance_of JDPIClient::Errors::Validation, error
    assert_equal "Bad Request", error.message
  end

  def test_from_response_401
    error = JDPIClient::Errors.from_response(401)

    assert_instance_of JDPIClient::Errors::Unauthorized, error
    assert_equal "Unauthorized", error.message
  end

  def test_from_response_403
    error = JDPIClient::Errors.from_response(403)

    assert_instance_of JDPIClient::Errors::Forbidden, error
    assert_equal "Forbidden", error.message
  end

  def test_from_response_404
    error = JDPIClient::Errors.from_response(404)

    assert_instance_of JDPIClient::Errors::NotFound, error
    assert_equal "Not Found", error.message
  end

  def test_from_response_429
    error = JDPIClient::Errors.from_response(429)

    assert_instance_of JDPIClient::Errors::RateLimited, error
    assert_equal "Too Many Requests", error.message
  end

  def test_from_response_500
    error = JDPIClient::Errors.from_response(500)

    assert_instance_of JDPIClient::Errors::ServerError, error
    assert_equal "Server Error 500", error.message
  end

  def test_from_response_502
    error = JDPIClient::Errors.from_response(502)

    assert_instance_of JDPIClient::Errors::ServerError, error
    assert_equal "Server Error 502", error.message
  end

  def test_from_response_503
    error = JDPIClient::Errors.from_response(503)

    assert_instance_of JDPIClient::Errors::ServerError, error
    assert_equal "Server Error 503", error.message
  end

  def test_from_response_unknown_status
    error = JDPIClient::Errors.from_response(418)

    assert_instance_of JDPIClient::Errors::Error, error
    assert_equal "HTTP 418", error.message
  end

  def test_from_response_with_body_parsing
    body = { "message" => "Custom error message", "code" => "INVALID_KEY" }
    error = JDPIClient::Errors.from_response(400, body)

    assert_instance_of JDPIClient::Errors::Validation, error
    assert_equal "Custom error message", error.message
  end

  def test_error_messages_are_strings
    [400, 401, 403, 404, 429, 500, 418].each do |status|
      error = JDPIClient::Errors.from_response(status)
      assert_instance_of String, error.message
      assert !error.message.empty?, "Error message should not be empty for status #{status}"
    end
  end

  def test_error_can_be_raised_and_rescued
    assert_raises(JDPIClient::Errors::Validation) do
      raise JDPIClient::Errors.from_response(400)
    end

    assert_raises(JDPIClient::Errors::Error) do
      raise JDPIClient::Errors.from_response(418)
    end

    # Test rescuing by parent class
    begin
      raise JDPIClient::Errors.from_response(401)
    rescue JDPIClient::Errors::Error => e
      assert_instance_of JDPIClient::Errors::Unauthorized, e
    end
  end

  def test_error_classes_can_be_instantiated_directly
    error = JDPIClient::Errors::ConfigurationError.new("Missing config")
    assert_equal "Missing config", error.message

    error = JDPIClient::Errors::Unauthorized.new
    assert_instance_of String, error.message
  end
end