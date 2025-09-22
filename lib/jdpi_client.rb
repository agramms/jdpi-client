# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "multi_json"

require_relative "jdpi_client/version"
require_relative "jdpi_client/config"
require_relative "jdpi_client/errors"
require_relative "jdpi_client/http"
require_relative "jdpi_client/token_storage"

# Services
require_relative "jdpi_client/auth/client"
require_relative "jdpi_client/dict/keys"
require_relative "jdpi_client/dict/claims"
require_relative "jdpi_client/dict/infractions"
require_relative "jdpi_client/dict/med"
require_relative "jdpi_client/qr/client"
require_relative "jdpi_client/spi/op"
require_relative "jdpi_client/spi/od"
require_relative "jdpi_client/participants"

module JDPIClient
  class << self
    # Configure the JDPI client
    # @yield [config] Configuration block
    def configure
      yield config
    end

    # Get the current configuration
    # @return [JDPIClient::Config] Current configuration
    def config
      @config ||= JDPIClient::Config.new
    end

    # Get available token storage adapters
    # @return [Hash] Information about available adapters
    def available_storage_adapters
      TokenStorage::Factory.adapter_info
    end

    # Check if a storage adapter is available
    # @param adapter [Symbol] Adapter name
    # @return [Boolean] True if adapter is available
    def storage_adapter_available?(adapter)
      TokenStorage::Factory.adapter_available?(adapter)
    end

    # Generate a secure encryption key for token storage
    # @return [String] Secure encryption key
    def generate_encryption_key
      TokenStorage::Encryption.generate_key
    end

    # Validate an encryption key
    # @param key [String] Encryption key to validate
    # @return [Boolean] True if key is secure
    def valid_encryption_key?(key)
      TokenStorage::Encryption.valid_encryption_key?(key)
    end
  end
end
