# frozen_string_literal: true

module JDPIClient
  module DICT
    class Claims
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def create(payload, idempotency_key:)
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/incluir", body: payload,
                                                                                      idempotency_key: idempotency_key)
      end

      def list_pending
        @http.get("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/listar/pendentes")
      end

      def confirm(id)
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/#{id}/confirmar", body: {})
      end

      def cancel(id)
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/#{id}/cancelar", body: {})
      end

      def conclude(id)
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/#{id}/concluir", body: {})
      end

      def list(params = {})
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/listar", body: params)
      end

      def get(params = {})
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao", body: params)
      end

      def list_paged(params = {})
        @http.post("/chave-reivindicacao-api/jdpi/dict/api/v1/reivindicacao/listar/paginacao", body: params)
      end
    end
  end
end
