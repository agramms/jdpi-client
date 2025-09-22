# frozen_string_literal: true

require_relative "test_helper"

class TestScopeManager < Minitest::Test
  def test_normalize_scopes_with_string
    scopes = "dict_api spi_api auth_apim"
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth_apim dict_api spi_api", normalized
  end

  def test_normalize_scopes_with_array
    scopes = ["spi_api", "dict_api", "auth_apim"]
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth_apim dict_api spi_api", normalized
  end

  def test_normalize_scopes_with_nil
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(nil)
    assert_equal "auth_apim", normalized
  end

  def test_normalize_scopes_removes_duplicates
    scopes = "auth_apim dict_api auth_apim spi_api dict_api"
    normalized = JDPIClient::Auth::ScopeManager.normalize_scopes(scopes)
    assert_equal "auth_apim dict_api spi_api", normalized
  end

  def test_scope_fingerprint
    scopes = "auth_apim dict_api spi_api"
    fingerprint = JDPIClient::Auth::ScopeManager.scope_fingerprint(scopes)
    assert_equal 16, fingerprint.length
    assert fingerprint.match?(/\A[a-f0-9]{16}\z/)
  end

  def test_cache_key_generation
    config = JDPIClient::Config.new
    config.token_scope_prefix = "test_prefix"
    config.jdpi_client_host = "localhost" # homl environment

    cache_key = JDPIClient::Auth::ScopeManager.cache_key("client123", "auth_apim dict_api", config)
    expected_pattern = /\Ajdpi_client:tokens:test_prefix:homl:client123:[a-f0-9]{16}\z/
    assert cache_key.match?(expected_pattern)
  end

  def test_scopes_allowed_with_no_restrictions
    scopes = ["auth_apim", "dict_api", "spi_api"]
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, nil)
  end

  def test_scopes_allowed_with_restrictions
    scopes = ["auth_apim", "dict_api"]
    allowed = ["auth_apim", "dict_api", "spi_api", "qrcode_api"]
    assert JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, allowed)
  end

  def test_scopes_not_allowed_with_restrictions
    scopes = ["auth_apim", "dict_api", "spi_api"]
    allowed = ["auth_apim", "dict_api"]
    refute JDPIClient::Auth::ScopeManager.scopes_allowed?(scopes, allowed)
  end

  def test_default_scopes_for_dict_read
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:dict, :read)
    expected = ["auth_apim", "dict_api"]
    assert_equal expected, scopes
  end

  def test_default_scopes_for_dict_write
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:dict, :write)
    expected = ["auth_apim", "dict_api"]
    assert_equal expected, scopes
  end

  def test_default_scopes_for_spi_payment
    scopes = JDPIClient::Auth::ScopeManager.default_scopes_for(:spi, :payment)
    expected = ["auth_apim", "spi_api"]
    assert_equal expected, scopes
  end

  def test_scope_combinations
    minimal = JDPIClient::Auth::ScopeManager.scope_combination(:minimal)
    assert_equal ["auth_apim"], minimal

    full = JDPIClient::Auth::ScopeManager.scope_combination(:full_access)
    assert_includes full, "auth_apim"
    assert_includes full, "dict_api"
    assert_includes full, "spi_api"
  end

  def test_scopes_compatible_for_reuse
    token_scopes = "auth_apim dict_api spi_api qrcode_api"
    requested_scopes = "auth_apim dict_api"

    assert JDPIClient::Auth::ScopeManager.scopes_compatible?(token_scopes, requested_scopes)
  end

  def test_scopes_not_compatible_for_reuse
    token_scopes = "auth_apim dict_api"
    requested_scopes = "auth_apim dict_api spi_api"

    refute JDPIClient::Auth::ScopeManager.scopes_compatible?(token_scopes, requested_scopes)
  end

  def test_parse_scopes_from_oauth_response
    oauth_response = { "scope" => "auth_apim dict_api spi_api" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth_apim dict_api spi_api", scopes
  end

  def test_parse_scopes_from_oauth_response_with_symbol_key
    oauth_response = { scope: "dict_api spi_api auth_apim" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth_apim dict_api spi_api", scopes
  end

  def test_parse_scopes_from_oauth_response_without_scope
    oauth_response = { "access_token" => "token123" }
    scopes = JDPIClient::Auth::ScopeManager.parse_scopes_from_response(oauth_response)
    assert_equal "auth_apim", scopes
  end

  def test_scope_parameter_formatting
    scopes = ["dict_api", "auth_apim", "spi_api"]
    parameter = JDPIClient::Auth::ScopeManager.scope_parameter(scopes)
    assert_equal "auth_apim dict_api spi_api", parameter
  end

  def test_describe_scopes
    scopes = "auth_apim dict_api spi_api qrcode_api"
    description = JDPIClient::Auth::ScopeManager.describe_scopes(scopes)

    assert description[:authentication]
    assert description[:dict_operations]
    assert description[:spi_operations]
    assert description[:qr_operations]
    assert_equal 4, description[:total_scopes]
    assert_equal 16, description[:scope_fingerprint].length
  end

  def test_valid_scope_format
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("auth_apim")
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("dict_api")
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("spi_api")
    assert JDPIClient::Auth::ScopeManager.valid_scope_format?("qrcode_api")

    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("invalid_scope")
    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("too:many:colons")
    refute JDPIClient::Auth::ScopeManager.valid_scope_format?("InvalidCase:Token")
  end

  def test_invalid_scopes_detection
    scopes = "auth_apim invalid_scope dict_api TooManyColons:are:here"
    invalid = JDPIClient::Auth::ScopeManager.invalid_scopes(scopes)

    assert_includes invalid, "invalid_scope"
    assert_includes invalid, "TooManyColons:are:here"
    refute_includes invalid, "auth_apim"
    refute_includes invalid, "dict_api"
  end
end