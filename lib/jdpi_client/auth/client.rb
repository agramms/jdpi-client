# frozen_string_literal: true

require "monitor"
require_relative "scope_manager"
require_relative "../token_storage/factory"

module JDPIClient
  module Auth
    class Client
      include MonitorMixin

      TOKEN_PATH = "/auth/jdpi/connect/token"
      DEFAULT_SCOPES = "auth_apim"

      attr_reader :config, :storage, :scopes

      def initialize(config = JDPIClient.config, scopes: nil)
        super()
        @config = config
        @scopes = ScopeManager.normalize_scopes(scopes || DEFAULT_SCOPES)
        @storage = TokenStorage::Factory.create(@config)
        @cache_key = ScopeManager.cache_key(@config.oauth_client_id, @scopes, @config)

        # Legacy in-memory fallback for compatibility
        @cached = nil
        @expires_at = Time.at(0)

        log_storage_configuration
      end

      # Returns a valid access token string with scope-aware caching
      # @param requested_scopes [String, Array<String>] Optional scopes to request
      # @return [String] Valid access token
      def token!(requested_scopes: nil)
        effective_scopes = requested_scopes ? ScopeManager.normalize_scopes(requested_scopes) : @scopes
        cache_key = ScopeManager.cache_key(@config.oauth_client_id, effective_scopes, @config)

        synchronize do
          # Try to get token from distributed storage
          if @storage.exists?(cache_key)
            token_data = @storage.retrieve(cache_key)
            if token_data && token_valid?(token_data)
              log_token_reuse(cache_key)
              return token_data[:access_token]
            end
          end

          # Need to refresh token
          refresh_token!(effective_scopes, cache_key)
        end
      end

      # Force refresh of the access token
      # @param scopes [String] OAuth scopes to request
      # @param cache_key [String] Cache key for storing the token
      # @return [String] New access token
      def refresh_token!(scopes = @scopes, cache_key = @cache_key)
        # Use distributed locking if supported by storage adapter
        if @storage.respond_to?(:with_lock)
          @storage.with_lock(cache_key) do
            perform_token_refresh(scopes, cache_key)
          end
        else
          perform_token_refresh(scopes, cache_key)
        end
      end

      # Legacy refresh method for backward compatibility
      def refresh!
        refresh_token!(@scopes, @cache_key)
      end

      # Proc to inject into HTTP client
      # @param scopes [String, Array<String>] Optional scopes
      # @return [Proc] Token provider proc
      def to_proc(scopes: nil)
        if scopes
          proc { token!(requested_scopes: scopes) }
        else
          proc { token! }
        end
      end

      # Get token information for debugging
      # @return [Hash] Token metadata
      def token_info
        token_data = @storage.retrieve(@cache_key)
        return { cached: false, storage_type: @storage.class.name } unless token_data

        {
          cached: true,
          storage_type: @storage.class.name,
          scopes: token_data[:scope],
          expires_at: token_data[:expires_at],
          client_id: token_data[:client_id],
          cache_key: @cache_key,
          encryption_enabled: @config.token_encryption_enabled?
        }
      end

      # Clear cached token (useful for testing)
      def clear_token!
        @storage.delete(@cache_key)
        @cached = nil
        @expires_at = Time.at(0)
      end

      # Get storage statistics
      # @return [Hash] Storage statistics
      def storage_stats
        if @storage.respond_to?(:stats)
          @storage.stats
        else
          { storage_type: @storage.class.name, stats_not_available: true }
        end
      end

      private

      # Perform the actual token refresh
      # @param scopes [String] OAuth scopes
      # @param cache_key [String] Cache key
      # @return [String] New access token
      def perform_token_refresh(scopes, cache_key)
        # Check if another process already refreshed the token
        if @storage.exists?(cache_key)
          token_data = @storage.retrieve(cache_key)
          return token_data[:access_token] if token_data && token_valid?(token_data)
        end

        log_token_refresh
        execute_oauth_request(scopes, cache_key)
      rescue Faraday::ClientError => e
        handle_oauth_error(e)
      end

      # Execute OAuth request and store the token
      # @param scopes [String] OAuth scopes
      # @param cache_key [String] Cache key
      # @return [String] New access token
      def execute_oauth_request(scopes, cache_key)
        oauth_response = make_oauth_request(scopes)
        token_data = build_token_data(oauth_response)
        store_token(cache_key, token_data)
        update_legacy_cache(token_data)

        token_data[:access_token]
      end

      # Make the OAuth request
      # @param scopes [String] OAuth scopes
      # @return [Hash] OAuth response
      def make_oauth_request(scopes)
        conn = create_oauth_connection
        oauth_params = build_oauth_params(scopes)
        resp = conn.post(TOKEN_PATH, oauth_params)
        MultiJson.load(resp.body)
      end

      # Build token data structure from OAuth response
      # @param oauth_response [Hash] OAuth response
      # @return [Hash] Token data for storage
      def build_token_data(oauth_response)
        access_token = oauth_response["access_token"]
        expires_in = oauth_response["expires_in"] || 300
        response_scopes = ScopeManager.parse_scopes_from_response(oauth_response)

        {
          access_token: access_token,
          scope: response_scopes,
          expires_at: (Time.now + expires_in - 10).utc.iso8601,
          client_id: @config.oauth_client_id,
          created_at: Time.now.utc.iso8601
        }
      end

      # Store token in distributed cache
      # @param cache_key [String] Cache key
      # @param token_data [Hash] Token data
      def store_token(cache_key, token_data)
        expires_in = Time.parse(token_data[:expires_at]) - Time.now
        ttl = expires_in.to_i
        @storage.store(cache_key, token_data, ttl)
      end

      # Update legacy cache for backward compatibility
      # @param token_data [Hash] Token data
      def update_legacy_cache(token_data)
        @cached = token_data[:access_token]
        @expires_at = Time.parse(token_data[:expires_at])
      end

      # Create Faraday connection for OAuth requests
      # @return [Faraday::Connection] OAuth connection
      def create_oauth_connection
        Faraday.new(url: @config.base_url) do |f|
          f.request :url_encoded
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
      end

      # Build OAuth request parameters
      # @param scopes [String] OAuth scopes
      # @return [Hash] OAuth parameters
      def build_oauth_params(scopes)
        params = {
          grant_type: "client_credentials",
          client_id: @config.oauth_client_id,
          client_secret: @config.oauth_secret
        }

        # Add scope parameter if not default
        params[:scope] = ScopeManager.scope_parameter(scopes) if scopes != DEFAULT_SCOPES

        params
      end

      # Check if token data is valid and not expired
      # @param token_data [Hash] Token data from storage
      # @return [Boolean] True if token is valid
      def token_valid?(token_data)
        return false unless token_data.is_a?(Hash)
        return false unless token_data[:access_token]
        return false unless token_data[:expires_at]

        expires_at = begin
          Time.parse(token_data[:expires_at])
        rescue StandardError
          nil
        end
        return false unless expires_at

        Time.now < expires_at
      end

      # Handle OAuth errors
      # @param error [Faraday::ClientError] OAuth error
      def handle_oauth_error(error)
        error_message = "Cannot obtain token: #{error.message}"

        @config.logger&.error("JDPI OAuth Error: #{error_message}")

        case error.response[:status]
        when 401
          raise JDPIClient::Errors::Unauthorized, error_message
        when 403
          raise JDPIClient::Errors::Forbidden, error_message
        when 429
          raise JDPIClient::Errors::RateLimited, error_message
        else
          raise JDPIClient::Errors::ServerError, error_message
        end
      end

      # Log storage configuration information
      def log_storage_configuration
        return unless @config.logger

        adapter_type = @storage.class.name.split("::").last
        if @config.shared_token_storage?
          @config.logger.info(
            "JDPI Token Storage: Using #{adapter_type} for shared token caching. " \
            "Encryption: #{@config.token_encryption_enabled? ? 'enabled' : 'disabled'}"
          )
        elsif @config.warn_on_local_tokens
          @config.logger.warn(
            "JDPI Token Storage: Using #{adapter_type} (local only). " \
            "Consider configuring shared storage for clustered environments."
          )
        end
      end

      # Log token refresh activity
      def log_token_refresh
        return unless @config.logger

        @config.logger.info(
          "JDPI Token Refresh: Creating new token for client_id=#{@config.oauth_client_id}, " \
          "scopes=#{@scopes}, cache_key=#{@cache_key[0..20]}..."
        )
      end

      # Log token reuse activity
      # @param cache_key [String] Cache key used
      def log_token_reuse(cache_key)
        return unless @config.logger
        return unless @config.logger.level <= Logger::DEBUG

        @config.logger.debug(
          "JDPI Token Reuse: Using cached token for cache_key=#{cache_key[0..20]}..."
        )
      end
    end
  end
end
