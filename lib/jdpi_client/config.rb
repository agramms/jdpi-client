# frozen_string_literal: true

module JDPIClient
  class Config
    attr_accessor :jdpi_client_host, :oauth_client_id, :oauth_secret,
                  :timeout, :open_timeout, :logger,
                  :token_storage_adapter, :token_storage_url, :token_storage_options,
                  :token_encryption_key, :token_scope_prefix, :warn_on_local_tokens

    def initialize
      @jdpi_client_host = "localhost"
      @timeout = 8
      @open_timeout = 2
      @logger = nil

      # Token storage configuration
      @token_storage_adapter = :memory
      @token_storage_url = nil
      @token_storage_options = {}
      @token_encryption_key = nil
      @token_scope_prefix = "default"
      @warn_on_local_tokens = true
    end

    def base_url
      protocol = production? ? "https" : "http"
      "#{protocol}://#{@jdpi_client_host}"
    end

    def production?
      @jdpi_client_host.to_s.include?("prod") || @jdpi_client_host.to_s.include?("production")
    end

    def environment
      production? ? "prod" : "homl"
    end

    # Token storage configuration helpers
    def shared_token_storage?
      [:redis, :dynamodb, :database].include?(@token_storage_adapter)
    end

    def token_encryption_enabled?
      !@token_encryption_key.nil? && !@token_encryption_key.empty?
    end

    def token_storage_key_prefix
      "jdpi_client:tokens:#{@token_scope_prefix}:#{environment}"
    end

    def validate_token_storage_config!
      if shared_token_storage? && !token_encryption_enabled?
        raise JDPIClient::Errors::ConfigurationError,
              "Token encryption key is required when using shared token storage"
      end

      if @token_storage_adapter == :redis && @token_storage_url.nil?
        raise JDPIClient::Errors::ConfigurationError,
              "Redis URL is required when using Redis token storage"
      end

      if @token_storage_adapter == :dynamodb && (@token_storage_options[:table_name]).nil?
        raise JDPIClient::Errors::ConfigurationError,
              "DynamoDB table name is required when using DynamoDB token storage"
      end
    end
  end
end
