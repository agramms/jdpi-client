# frozen_string_literal: true

module JDPIClient
  module DICT
    class Infractions
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create(payload, idempotency_key:)
        @http.post("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/incluir", body: payload,
                                                                                          idempotency_key: idempotency_key)
      end

      def list_pending
        @http.get("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/listar/pendentes")
      end

      def consult(params = {})
        @http.post("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/consultar", body: params)
      end

      def cancel(params = {})
        @http.post("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/cancelar", body: params)
      end

      def analyze(params = {})
        @http.post("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/analisar", body: params)
      end

      def list(params = {})
        @http.post("/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/listar", body: params)
      end
    end
  end
end
