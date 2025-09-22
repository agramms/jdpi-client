# frozen_string_literal: true

module JDPIClient
  class HTTP
    IDEMPOTENCY_HEADER = "Chave-Idempotencia"

    def initialize(base:, token_provider:, logger: nil, timeout: 8, open_timeout: 2)
      @base = base
      @token_provider = token_provider
      @logger = logger

      @conn = Faraday.new(url: @base) do |f|
        f.request :retry, max: 2, interval: 0.2, interval_randomness: 0.2, backoff_factor: 2,
                          methods: %i[get post put patch delete],
                          exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
        f.response :raise_error # convert 4xx/5xx to exceptions; we catch below
        f.adapter Faraday.default_adapter
      end
      @conn.options.timeout = timeout
      @conn.options.open_timeout = open_timeout
    end

    def get(path, params: {}, headers: {})
      request(:get, path, params: params, headers: headers)
    end

    def post(path, body: {}, headers: {}, idempotency_key: nil)
      request(:post, path, body: body, headers: headers, idempotency_key: idempotency_key)
    end

    def put(path, body: {}, headers: {}, idempotency_key: nil)
      request(:put, path, body: body, headers: headers, idempotency_key: idempotency_key)
    end

    private

    def request(method, path, params: {}, body: nil, headers: {}, idempotency_key: nil)
      hdrs = default_headers.merge(headers)
      hdrs[IDEMPOTENCY_HEADER] = idempotency_key if idempotency_key

      resp = @conn.send(method) do |req|
        req.url(path, params) unless params.nil? || params.empty?
        req.headers.update(hdrs)
        req.body = MultiJson.dump(body) if body
      end

      parse_json(resp.body)
    rescue Faraday::ClientError => e
      status = e.response&.dig(:status) || 500
      body = begin
        parse_json(e.response&.dig(:body))
      rescue StandardError
        nil
      end
      raise JDPIClient::Errors.from_response(status, body)
    end

    def default_headers
      {
        "Authorization" => "Bearer #{@token_provider.call}",
        "Content-Type" => "application/json; charset=utf-8",
        "Accept" => "application/json"
      }
    end

    def parse_json(raw)
      return {} if raw.nil? || raw.empty?

      if raw.is_a?(String)
        MultiJson.load(raw)
      else
        raw
      end
    end
  end
end
