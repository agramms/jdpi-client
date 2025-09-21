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
end