# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "multi_json"

require_relative "jdpi_client/version"
require_relative "jdpi_client/config"
require_relative "jdpi_client/errors"
require_relative "jdpi_client/http"

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
    def configure
      yield config
    end

    def config
      @config ||= JDPIClient::Config.new
    end
  end
end
