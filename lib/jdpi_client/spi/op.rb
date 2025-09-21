# frozen_string_literal: true
module JDPIClient
  module SPI
    class OP
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create_order!(payload, idempotency_key: nil)
        @http.post("/spi-api/jdpi/spi/api/v2/op", body: payload, idempotency_key: idempotency_key)
      end

      def consult_request(id_req)
        @http.get("/spi-api/jdpi/spi/api/v2/op/#{id_req}")
      end

      def account_statement_pi(payload = {})
        @http.post("/spi-api/jdpi/spi/api/v2/conta-pi/extrato", body: payload)
      end

      def account_statement_tx(payload = {})
        @http.post("/spi-api/jdpi/spi/api/v2/conta-transacional/extrato", body: payload)
      end

      def posting_detail(end_to_end_id)
        @http.get("/spi-api/jdpi/spi/api/v2/conta-transacional/#{end_to_end_id}")
      end

      def credit_status_payment(end_to_end_id)
        @http.get("/spi-api/jdpi/spi/api/v2/credito-pagamento/#{end_to_end_id}")
      end

      def posting_spi(end_to_end_id)
        @http.get("/spi-api/jdpi/spi/api/v2/lancamento/#{end_to_end_id}")
      end

      def remuneration(date_str)
        @http.get("/spi-api/jdpi/spi/api/v2/remuneracao-conta-pi/#{date_str}")
      end

      def balance_pi_jdpi
        @http.get("/spi-api/jdpi/spi/api/v2/saldo/conta-pi/jdpi")
      end

      def balance_pi_spi
        @http.get("/spi-api/jdpi/spi/api/v2/saldo/conta-pi/spi")
      end
    end
  end
end
