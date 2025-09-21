# frozen_string_literal: true
module JDPIClient
  class Participants
    def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
      token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
      @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                           logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
    end

    def list(payload = {})
      @http.post("/auth/jdpi/spi/api/v1/gestao-psps/listar", body: payload)
    end

    def consult(payload = {})
      @http.post("/auth/jdpi/spi/api/v1/gestao-psps/consultar", body: payload)
    end
  end
end
