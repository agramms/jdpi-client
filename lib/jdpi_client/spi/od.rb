# frozen_string_literal: true
module JDPIClient
  module SPI
    class OD
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create_order!(payload, idempotency_key: nil)
        @http.post("/spi-api/jdpi/spi/api/v2/od", body: payload, idempotency_key: idempotency_key)
      end

      def consult_request(id_req)
        @http.get("/spi-api/jdpi/spi/api/v2/od/#{id_req}")
      end

      def reasons
        @http.get("/spi-api/jdpi/spi/api/v2/od/motivos")
      end

      def credit_status_refund(end_to_end_id)
        @http.get("/spi-api/jdpi/spi/api/v2/credito-devolucao/#{end_to_end_id}")
      end
    end
  end
end
