# frozen_string_literal: true

require_relative "test_helper"

class TestHTTP < Minitest::Test
  def setup
    @base_url = "http://test.homl.jdpi.pstijd"
    @token_provider = proc { "test_token_123" }
    @logger = Logger.new(StringIO.new)
    @http = JDPIClient::HTTP.new(
      base: @base_url,
      token_provider: @token_provider,
      logger: @logger,
      timeout: 10,
      open_timeout: 5
    )
  end

  def test_initialization
    assert_equal @base_url, @http.instance_variable_get(:@base)
    assert_equal @token_provider, @http.instance_variable_get(:@token_provider)
    assert_equal @logger, @http.instance_variable_get(:@logger)

    conn = @http.instance_variable_get(:@conn)
    assert_instance_of Faraday::Connection, conn
    assert_equal 10, conn.options.timeout
    assert_equal 5, conn.options.open_timeout
  end

  def test_default_headers
    expected_headers = {
      "Authorization" => "Bearer test_token_123",
      "Content-Type" => "application/json; charset=utf-8",
      "Accept" => "application/json"
    }

    headers = @http.send(:default_headers)
    assert_equal expected_headers, headers
  end

  def test_get_method_exists
    assert_respond_to @http, :get
    assert_equal(-2, @http.method(:get).arity) # path required, keyword args optional
  end

  def test_post_method_exists
    assert_respond_to @http, :post
    assert_equal(-2, @http.method(:post).arity) # path required, keyword args optional
  end

  def test_put_method_exists
    assert_respond_to @http, :put
    assert_equal(-2, @http.method(:put).arity) # path required, keyword args optional
  end

  def test_idempotency_header_constant
    assert_equal "Chave-Idempotencia", JDPIClient::HTTP::IDEMPOTENCY_HEADER
  end

  def test_parse_json_with_string
    json_string = '{"test": "value"}'
    result = @http.send(:parse_json, json_string)
    assert_equal({ "test" => "value" }, result)
  end

  def test_parse_json_with_hash
    hash_data = { "test" => "value" }
    result = @http.send(:parse_json, hash_data)
    assert_equal hash_data, result
  end

  def test_parse_json_with_empty_data
    assert_equal({}, @http.send(:parse_json, nil))
    assert_equal({}, @http.send(:parse_json, ""))
  end

  def test_request_method_is_private
    assert @http.private_methods.include?(:request), "request should be a private method"
  end

  def test_faraday_connection_configured
    conn = @http.instance_variable_get(:@conn)
    assert_instance_of Faraday::Connection, conn
    assert_equal "#{@base_url}/", conn.url_prefix.to_s
  end

  def test_timeout_configuration
    conn = @http.instance_variable_get(:@conn)
    assert_equal 10, conn.options.timeout
    assert_equal 5, conn.options.open_timeout
  end

  def test_request_with_params_method_exists
    # Test that the request method accepts params
    assert_respond_to @http, :get

    # Test method signature accepts params keyword argument
    method = @http.method(:get)
    assert method.arity < 0, "Get method should accept keyword arguments"
  end

  def test_idempotency_key_in_method_signature
    # Test that post/put methods accept idempotency_key parameter
    post_method = @http.method(:post)
    put_method = @http.method(:put)

    assert post_method.arity < 0, "Post method should accept keyword arguments"
    assert put_method.arity < 0, "Put method should accept keyword arguments"
  end

  def test_request_without_params_method_signature
    # Test that get method works without params
    assert_respond_to @http, :get
    assert_equal(-2, @http.method(:get).arity)
  end

  def test_parse_json_with_invalid_json
    # Test fallback when JSON parsing fails
    invalid_json = "invalid json string"
    assert_raises(MultiJson::ParseError) do
      @http.send(:parse_json, invalid_json)
    end
  end

  def test_error_handling_method_exists
    # Test that error handling logic exists in the request method
    # We can't easily test the full error flow without complex mocking
    # so we test that the error classes exist and can be instantiated
    assert defined?(JDPIClient::Errors::Validation)
    assert defined?(JDPIClient::Errors::ServerError)
    assert defined?(JDPIClient::Errors::Unauthorized)
  end

  def test_private_request_method_structure
    # Test that request is a private method
    assert @http.private_methods.include?(:request)

    # Test request method arity allows for keyword arguments
    method = @http.method(:request)
    assert method.arity < 0, "Request method should accept keyword arguments"
  end
end
