# frozen_string_literal: true
module JDPIClient
  module DICT
    class Keys
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create(payload, idempotency_key:)
        @http.post("/chave-gestao-api/jdpi/dict/api/v1/incluir", body: payload, idempotency_key: idempotency_key)
      end

      def update(chave, payload, idempotency_key:)
        @http.put("/chave-gestao-api/jdpi/dict/api/v1/#{chave}", body: payload, idempotency_key: idempotency_key)
      end

      def delete(chave, idempotency_key:)
        @http.post("/chave-gestao-api/jdpi/dict/api/v1/#{chave}/excluir", body: {}, idempotency_key: idempotency_key)
      end

      def list_by_customer(payload)
        @http.post("/chave-gestao-api/jdpi/dict/api/v1/listar/chave", body: payload)
      end

      def get(chave)
        @http.get("/chave-gestao-api/jdpi/dict/api/v1/#{chave}")
      end

      def stats(cpf_cnpj)
        @http.get("/chave-gestao-api/jdpi/dict/api/v1/estatisticas/#{cpf_cnpj}")
      end
    end
  end
end
