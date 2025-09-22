# frozen_string_literal: true

module JDPIClient
  class Config
    attr_accessor :jdpi_client_host, :oauth_client_id, :oauth_secret,
                  :timeout, :open_timeout, :logger

    def initialize
      @jdpi_client_host = "localhost"
      @timeout = 8
      @open_timeout = 2
      @logger = nil
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
  end
end
