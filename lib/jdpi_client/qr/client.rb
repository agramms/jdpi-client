# frozen_string_literal: true

module JDPIClient
  module QR
    class Client
      def initialize(http = nil, config = JDPIClient.config, token_provider: nil)
        token_provider ||= JDPIClient::Auth::Client.new(config).to_proc
        @http = http || JDPIClient::HTTP.new(base: config.base_url, token_provider: token_provider,
                                             logger: config.logger, timeout: config.timeout, open_timeout: config.open_timeout)
      end

      def static_generate(payload, idempotency_key: nil)
        @http.post("/qrcode-api/jdpi/qrcode/api/v1/estatico/gerar", body: payload, idempotency_key: idempotency_key)
      end

      def dynamic_immediate_generate(payload, idempotency_key: nil)
        @http.post("/qrcode-api/jdpi/qrcode/api/v1/dinamico/gerar", body: payload, idempotency_key: idempotency_key)
      end

      def decode(payload)
        @http.post("/qrcode-api/jdpi/qrcode/api/v1/decodificar", body: payload)
      end

      def dynamic_immediate_update(id_documento, payload)
        @http.put("/qrcode-api/jdpi/qrcode/api/v1/dinamico/#{id_documento}", body: payload)
      end

      def cert_download
        @http.get("/certificado-api/jdpi/certificates/download")
      end

      def cobv_generate(payload, idempotency_key: nil)
        @http.post("/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/gerar", body: payload,
                                                                         idempotency_key: idempotency_key)
      end

      def cobv_update(id_documento, payload)
        @http.put("/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/#{id_documento}", body: payload)
      end

      def cobv_jws(payload)
        @http.post("/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/jws", body: payload)
      end
    end
  end
end
