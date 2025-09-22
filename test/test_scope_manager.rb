# frozen_string_literal: true

require_relative "test_helper"

class TestScopeManager < Minitest::Test
  def test_normalize_scopes_with_string
    scopes = "dict:read spi:write auth:token"
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth:token dict:read spi:write", normalized
  end

  def test_normalize_scopes_with_array
    scopes = ["spi:write", "dict:read", "auth:token"]
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth:token dict:read spi:write", normalized
  end

  def test_normalize_scopes_with_nil
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(nil)
    assert_equal "auth:token", normalized
  end

  def test_normalize_scopes_removes_duplicates
    scopes = "auth:token dict:read auth:token spi:write dict:read"
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth:token dict:read spi:write", normalized
  end

  def test_scope_fingerprint
    scopes = "auth:token dict:read spi:write"
    fingerprint = JDPIClient::Auth::ScopeManager.scope_fingerprint(scopes)
    assert_equal 16, fingerprint.length
    assert fingerprint.match?(/\A[a-f0-9]{16}\z/)
  end

  def test_cache_key_generation
    config = JDPIClient::Config.new
    config.token_scope_prefix = "test_prefix"
    config.jdpi_client_host = "localhost" # homl environment

    cache_key = JDPIClient::Auth::ScopeManager.cache_key("client123", "auth:token dict:read", config)
    expected_pattern = /\Ajdpi_client:tokens:test_prefix:homl:client123:[a-f0-9]{16}\z/
    assert cache_key.match?(expected_pattern)
  end

  def test_scopes_allowed_with_no_restrictions
    scopes = ["auth:token", "dict:read", "spi:write"]
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, nil)
  end

  def test_scopes_allowed_with_restrictions
    scopes = ["auth:token", "dict:read"]
    allowed = ["auth:token", "dict:read", "dict:write", "spi:read"]
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, allowed)
  end

  def test_scopes_not_allowed_with_restrictions
    scopes = ["auth:token", "dict:read", "spi:payment"]
    allowed = ["auth:token", "dict:read", "dict:write"]
    refute JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, allowed)
  end

  def test_default_scopes_for_dict_read
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:dict, :read)
    expected = ["auth:token", "dict:read"]
    assert_equal expected, scopes
  end

  def test_default_scopes_for_dict_write
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:dict, :write)
    expected = ["auth:token", "dict:read", "dict:write"]
    assert_equal expected, scopes
  end

  def test_default_scopes_for_spi_payment
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:spi, :payment)
    expected = ["auth:token", "spi:read", "spi:write", "spi:payment"]
    assert_equal expected, scopes
  end

  def test_scope_combinations
    minimal = JDPIClient::Auth::ScopeManager.scope_combination(:minimal)
    assert_equal ["auth:token"], minimal

    full = JDPIClient::Auth::ScopeManager.scope_combination(:full_access)
    assert_includes full, "auth:token"
    assert_includes full, "dict:read"
    assert_includes full, "spi:payment"
  end

  def test_scopes_compatible_for_reuse
    token_scopes = "auth:token dict:read dict:write spi:read"
    requested_scopes = "auth:token dict:read"

    assert JDPIClient::Auth::ScopeManager.scopes_compatible?(token_scopes, requested_scopes)
  end

  def test_scopes_not_compatible_for_reuse
    token_scopes = "auth:token dict:read"
    requested_scopes = "auth:token dict:read spi:write"

    refute JDPIClient::Auth::ScopeManager.scopes_compatible?(token_scopes, requested_scopes)
  end

  def test_parse_scopes_from_oauth_response
    oauth_response = { "scope" => "auth:token dict:read spi:write" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth:token dict:read spi:write", scopes
  end

  def test_parse_scopes_from_oauth_response_with_symbol_key
    oauth_response = { scope: "dict:write spi:payment auth:token" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth:token dict:write spi:payment", scopes
  end

  def test_parse_scopes_from_oauth_response_without_scope
    oauth_response = { "access_token" => "token123" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth:token", scopes
  end

  def test_scope_parameter_formatting
    scopes = ["dict:write", "auth:token", "spi:read"]
    parameter = JDPIClient::Auth::ScopeManager.scope_parameter(scopes)
    assert_equal "auth:token dict:write spi:read", parameter
  end

  def test_describe_scopes
    scopes = "auth:token dict:read dict:write spi:payment"
    description = JDPIClient::Auth::ScopeManager.describe_scopes(scopes)

    assert description[:authentication]
    assert_includes description[:dict_operations], "read"
    assert_includes description[:dict_operations], "write"
    assert_includes description[:spi_operations], "payment"
    assert_equal 4, description[:total_scopes]
    assert_equal 16, description[:scope_fingerprint].length
  end

  def test_valid_scope_format
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("auth:token")
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("dict:read")
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("spi_service:write_permission")

    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("invalid_scope")
    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("too:many:colons")
    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("InvalidCase:Token")
  end

  def test_invalid_scopes_detection
    scopes = "auth:token invalid_scope dict:read TooManyColons:are:here"
    invalid = JDPIClient::Auth::ScopeManager.invalid_scopes(scopes)

    assert_includes invalid, "invalid_scope"
    assert_includes invalid, "TooManyColons:are:here"
    refute_includes invalid, "auth:token"
    refute_includes invalid, "dict:read"
  end
end