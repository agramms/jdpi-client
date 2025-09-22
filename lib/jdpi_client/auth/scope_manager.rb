# frozen_string_literal: true

require "digest"

module JDPIClient
  module Auth
    # Manages OAuth scopes and generates scope-aware cache keys
    # Ensures tokens are only reused when scopes match exactly
    class ScopeManager
      # Default scopes for JDPI operations
      DEFAULT_SCOPES = {
        dict: %w[dict_api],
        spi: %w[spi_api],
        qr: %w[qrcode_api],
        auth: %w[auth_apim]
      }.freeze

      # Scope combinations for different service groups
      SCOPE_COMBINATIONS = {
        minimal: %w[auth_apim],
        dict: %w[auth_apim dict_api],
        spi: %w[auth_apim spi_api],
        qr: %w[auth_apim qrcode_api],
        qrcode: %w[auth_apim qrcode_api],
        full_access: %w[auth_apim dict_api spi_api qrcode_api]
      }.freeze

      class << self
        # Normalize and sort scopes for consistent cache keys
        # @param scopes [String, Array<String>] OAuth scopes
        # @return [String] Normalized scope string
        def normalize_scopes(scopes)
          scope_array = case scopes
                        when String
                          scopes.split(/[\s,]+/).reject(&:empty?)
                        when Array
                          scopes.flatten.compact
                        when nil
                          ["auth_apim"] # Default scope
                        else
                          [scopes.to_s]
                        end

          # Remove duplicates, sort for consistency
          scope_array.uniq.sort.join(" ")
        end

        # Generate a cache key for the given client_id and scopes
        # @param client_id [String] OAuth client ID
        # @param scopes [String, Array<String>] OAuth scopes
        # @param config [JDPIClient::Config] Configuration object
        # @return [String] Cache key for token storage
        def cache_key(client_id, scopes, config)
          normalized_scopes = normalize_scopes(scopes)
          scope_hash = scope_fingerprint(normalized_scopes)

          "#{config.token_storage_key_prefix}:#{client_id}:#{scope_hash}"
        end

        # Generate a unique fingerprint for a set of scopes
        # @param scopes [String] Normalized scope string
        # @return [String] Short hash representing the scopes
        def scope_fingerprint(scopes)
          Digest::SHA256.hexdigest(scopes)[0..15] # 16 character hash
        end

        # Validate that requested scopes are allowed
        # @param scopes [String, Array<String>] Requested scopes
        # @param allowed_scopes [Array<String>] Allowed scopes for the client
        # @return [Boolean] True if all scopes are allowed
        def scopes_allowed?(scopes, allowed_scopes = nil)
          return true if allowed_scopes.nil? # No restrictions

          normalized_scopes = normalize_scopes(scopes).split(" ")
          allowed_set = Set.new(allowed_scopes)

          normalized_scopes.all? { |scope| allowed_set.include?(scope) }
        end

        # Get the default scopes for a service type
        # @param service_type [Symbol] Service type (:dict, :spi, :qr, etc.)
        # @param operation [Symbol] Operation type (ignored - JDPI uses service-level scopes)
        # @return [Array<String>] Default scopes for the service
        def default_scopes_for(service_type, operation = nil)
          base_scopes = ["auth_apim"]

          case service_type
          when :dict
            base_scopes += %w[dict_api]
          when :spi
            base_scopes += %w[spi_api]
          when :qr, :qrcode
            base_scopes += %w[qrcode_api]
          end

          base_scopes.uniq
        end

        # Get predefined scope combination
        # @param combination [Symbol] Predefined combination name
        # @return [Array<String>] Scopes for the combination
        def scope_combination(combination)
          SCOPE_COMBINATIONS[combination] || SCOPE_COMBINATIONS[:minimal]
        end

        # Determine if scopes are compatible for token reuse
        # @param token_scopes [String] Scopes from stored token
        # @param requested_scopes [String] Scopes being requested
        # @return [Boolean] True if token can be reused
        def scopes_compatible?(token_scopes, requested_scopes)
          token_set = Set.new(normalize_scopes(token_scopes).split(" "))
          requested_set = Set.new(normalize_scopes(requested_scopes).split(" "))

          # Token can be reused if it has all requested scopes
          requested_set.subset?(token_set)
        end

        # Parse scopes from OAuth response
        # @param oauth_response [Hash] OAuth token response
        # @return [String] Normalized scopes from response
        def parse_scopes_from_response(oauth_response)
          scope_value = oauth_response["scope"] || oauth_response[:scope]
          normalize_scopes(scope_value || "auth_apim")
        end

        # Generate scope parameter for OAuth request
        # @param scopes [String, Array<String>] Requested scopes
        # @return [String] Scope parameter for OAuth request
        def scope_parameter(scopes)
          normalize_scopes(scopes)
        end

        # Get human-readable description of scopes
        # @param scopes [String, Array<String>] Scopes to describe
        # @return [Hash] Description of scope capabilities
        def describe_scopes(scopes)
          normalized = normalize_scopes(scopes).split(" ")
          capabilities = {
            auth_apim: false,
            dict_api: false,
            spi_api: false,
            qrcode_api: false
          }

          normalized.each do |scope|
            case scope
            when "auth_apim"
              capabilities[:auth_apim] = true
            when "dict_api"
              capabilities[:dict_api] = true
            when "spi_api"
              capabilities[:spi_api] = true
            when "qrcode_api"
              capabilities[:qrcode_api] = true
            end
          end

          # Convert to human-readable format
          {
            authentication: capabilities[:auth_apim],
            dict_operations: capabilities[:dict_api],
            spi_operations: capabilities[:spi_api],
            qr_operations: capabilities[:qrcode_api],
            total_scopes: normalized.size,
            scope_fingerprint: scope_fingerprint(normalize_scopes(scopes))
          }
        end

        # Validate scope format
        # @param scope [String] Individual scope to validate
        # @return [Boolean] True if scope format is valid
        def valid_scope_format?(scope)
          # JDPI scopes are simple service names
          %w[auth_apim dict_api spi_api qrcode_api].include?(scope)
        end

        # Validate all scopes in a collection
        # @param scopes [String, Array<String>] Scopes to validate
        # @return [Array<String>] Invalid scopes found
        def invalid_scopes(scopes)
          normalized = normalize_scopes(scopes).split(" ")
          normalized.reject { |scope| valid_scope_format?(scope) }
        end
      end
    end
  end
end