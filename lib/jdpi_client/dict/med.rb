# frozen_string_literal: true
module JDPIClient
  module DICT
    class MED
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create(payload, idempotency_key:)
        @http.post("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/incluir", body: payload, idempotency_key: idempotency_key)
      end

      def list_pending
        @http.get("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/listar/pendentes")
      end

      def consult(params = {})
        @http.post("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/consultar", body: params)
      end

      def cancel(params = {})
        @http.post("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/cancelar", body: params)
      end

      def analyze(params = {})
        @http.post("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/analisar", body: params)
      end

      def list(params = {})
        @http.post("/chave-devolucao-api/jdpi/dict/api/v1/devolucao/listar", body: params)
      end
    end
  end
end
