# frozen_string_literal: true
module JDPIClient
  module Errors
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class Unauthorized < Error; end
    class Forbidden < Error; end
    class NotFound < Error; end
    class RateLimited < Error; end
    class ServerError < Error; end
    class Validation < Error; end

    def self.from_response(status, body=nil)
      case status
      when 400 then Validation.new(body && body["message"] || "Bad Request")
      when 401 then Unauthorized.new("Unauthorized")
      when 403 then Forbidden.new("Forbidden")
      when 404 then NotFound.new("Not Found")
      when 429 then RateLimited.new("Too Many Requests")
      when 500..599 then ServerError.new("Server Error #{status}")
      else
        Error.new("HTTP #{status}")
      end
    end
  end
end
