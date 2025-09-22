# frozen_string_literal: true

require "monitor"

module JDPIClient
  module Auth
    class Client
      include MonitorMixin

      TOKEN_PATH = "/auth/jdpi/connect/token"

      def initialize(config = JDPIClient.config)
        super()
        @config = config
        @cached = nil
        @expires_at = Time.at(0)
      end

      # Returns a valid access token string.
      def token!
        synchronize do
          refresh! if Time.now >= @expires_at
          @cached
        end
      end

      def refresh!
        conn = Faraday.new(url: @config.base_url) do |f|
          f.request :url_encoded
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
        resp = conn.post(TOKEN_PATH, {
                           grant_type: "client_credentials",
                           client_id: @config.oauth_client_id,
                           client_secret: @config.oauth_secret
                         })
        data = MultiJson.load(resp.body)
        @cached = data["access_token"]
        ttl = data["expires_in"] || 300
        @expires_at = Time.now + ttl - 10
        @cached
      rescue Faraday::ClientError => e
        raise JDPIClient::Errors::Unauthorized, "Cannot obtain token: #{e.message}"
      end

      # Proc to inject into HTTP client
      def to_proc
        proc { token! }
      end
    end
  end
end
