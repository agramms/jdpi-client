# Claude Code Integration Examples

This document provides practical examples for integrating jdpi-client with Claude Code assistance.

## 🔧 Complete Setup Example

```ruby
# config/initializers/jdpi_client.rb (Rails)
# or setup.rb (plain Ruby)

require 'jdpi_client'
require 'logger'

JDPIClient.configure do |config|
  # Single host configuration - environment auto-detected
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST') do
    case Rails.env.to_s
    when 'production'
      'api.mybank.prod.jdpi.pstijd'
    when 'staging'
      'api.mybank.staging.jdpi.pstijd'
    else
      'api.mybank.homl.jdpi.pstijd'
    end
  end

  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')
  config.timeout = ENV.fetch('JDPI_TIMEOUT', 10).to_i
  config.open_timeout = ENV.fetch('JDPI_OPEN_TIMEOUT', 3).to_i

  # Environment-specific logging
  config.logger = if Rails.env.production?
    Rails.logger
  else
    Logger.new($stdout, level: Logger::DEBUG)
  end
end
```

## 💰 PIX Payment Flow

### Complete Payment Creation
```ruby
class PixPaymentService
  include ActiveModel::Validations

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :pix_key, presence: true
  validates :description, length: { maximum: 140 }

  def initialize(amount:, pix_key:, description: nil, priority: 0)
    @amount = amount
    @pix_key = pix_key
    @description = description
    @priority = priority
  end

  def execute!
    return false unless valid?

    begin
      # Generate idempotency key for safe retries
      idempotency_key = generate_idempotency_key

      # Create payment order
      spi_client = JDPIClient::SPI::OP.new
      response = spi_client.create_order!(
        valor: (@amount * 100).to_i, # Convert to centavos
        chave: @pix_key,
        descricao: @description,
        prioridade_pagamento: @priority,
        finalidade: 1, # P2P payment
        dt_hr_requisicao_psp: Time.now.utc.iso8601,
        idempotency_key: idempotency_key
      )

      # Store transaction details
      transaction_id = response['id_req']
      log_transaction(transaction_id, idempotency_key)

      # Check status
      check_payment_status(transaction_id)

    rescue JDPIClient::Errors::Validation => e
      errors.add(:base, "Payment validation failed: #{e.message}")
      false
    rescue JDPIClient::Errors::RateLimited => e
      errors.add(:base, "Rate limited. Please try again later.")
      false
    rescue => e
      errors.add(:base, "Payment failed: #{e.message}")
      false
    end
  end

  private

  def generate_idempotency_key
    "pix_#{Time.now.to_i}_#{SecureRandom.hex(8)}"
  end

  def log_transaction(transaction_id, idempotency_key)
    Rails.logger.info "PIX Payment created: #{transaction_id}, key: #{idempotency_key}"
  end

  def check_payment_status(transaction_id)
    spi_client = JDPIClient::SPI::OP.new
    status_response = spi_client.consult_request(transaction_id)

    case status_response['status']
    when 'APPROVED'
      Rails.logger.info "Payment #{transaction_id} approved"
      true
    when 'REJECTED'
      errors.add(:base, "Payment rejected: #{status_response['reason']}")
      false
    else
      Rails.logger.info "Payment #{transaction_id} pending"
      true
    end
  end
end

# Usage
payment = PixPaymentService.new(
  amount: 25.50,
  pix_key: "user@bank.com",
  description: "Payment for services"
)

if payment.execute!
  puts "Payment successful!"
else
  puts "Payment failed: #{payment.errors.full_messages.join(', ')}"
end
```

### Account Statement Analysis
```ruby
class AccountStatementAnalyzer
  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @spi_client = JDPIClient::SPI::OP.new
  end

  def generate_report
    # Get PI account statement
    pi_statement = @spi_client.account_statement_pi(
      data_inicio: @start_date.strftime('%Y-%m-%d'),
      data_fim: @end_date.strftime('%Y-%m-%d')
    )

    # Get transactional account statement
    tx_statement = @spi_client.account_statement_tx(
      data_inicio: @start_date.strftime('%Y-%m-%d'),
      data_fim: @end_date.strftime('%Y-%m-%d')
    )

    {
      period: "#{@start_date} to #{@end_date}",
      pi_transactions: analyze_transactions(pi_statement['transacoes']),
      tx_transactions: analyze_transactions(tx_statement['transacoes']),
      summary: generate_summary(pi_statement, tx_statement)
    }
  end

  private

  def analyze_transactions(transactions)
    return [] unless transactions

    transactions.map do |tx|
      {
        end_to_end_id: tx['end_to_end_id'],
        amount: tx['valor'],
        type: tx['tipo'],
        timestamp: DateTime.parse(tx['dt_hr_transacao']),
        status: tx['status']
      }
    end
  end

  def generate_summary(pi_statement, tx_statement)
    {
      total_pi_volume: calculate_volume(pi_statement['transacoes']),
      total_tx_volume: calculate_volume(tx_statement['transacoes']),
      transaction_count: (pi_statement['transacoes']&.size || 0) + (tx_statement['transacoes']&.size || 0)
    }
  end

  def calculate_volume(transactions)
    return 0 unless transactions
    transactions.sum { |tx| tx['valor'] || 0 }
  end
end
```

## 🔑 DICT Key Management

### Comprehensive Key Lifecycle
```ruby
class PixKeyManager
  VALID_KEY_TYPES = %w[CPF CNPJ EMAIL PHONE RANDOM].freeze

  def initialize
    @dict_keys = JDPIClient::DICT::Keys.new
    @dict_claims = JDPIClient::DICT::Claims.new
  end

  def register_key(type:, key_value:, account_info:)
    validate_key_format!(type, key_value)

    begin
      response = @dict_keys.create_key!(
        tipo: type,
        chave: key_value,
        conta: account_info,
        dt_hr_requisicao_psp: Time.now.utc.iso8601
      )

      Rails.logger.info "PIX key registered: #{key_value} (#{type})"
      response

    rescue JDPIClient::Errors::Validation => e
      handle_registration_error(e, key_value)
    end
  end

  def claim_key(key_value:, claim_type: 'OWNERSHIP')
    begin
      response = @dict_claims.create_claim!(
        chave: key_value,
        tipo_reivindicacao: claim_type,
        dt_hr_requisicao_psp: Time.now.utc.iso8601
      )

      claim_id = response['id_reivindicacao']
      Rails.logger.info "PIX key claim initiated: #{claim_id} for #{key_value}"

      # Monitor claim status
      monitor_claim_status(claim_id)

    rescue => e
      Rails.logger.error "Claim failed for #{key_value}: #{e.message}"
      raise
    end
  end

  def transfer_key_ownership(key_value:, new_participant:)
    # Initiate ownership transfer
    response = @dict_claims.create_claim!(
      chave: key_value,
      tipo_reivindicacao: 'PORTABILITY',
      participante_doador: current_participant_code,
      participante_reivindicador: new_participant,
      dt_hr_requisicao_psp: Time.now.utc.iso8601
    )

    claim_id = response['id_reivindicacao']
    Rails.logger.info "Key transfer initiated: #{claim_id}"

    # Set up monitoring for completion
    PixKeyTransferJob.perform_later(claim_id, key_value)
    claim_id
  end

  private

  def validate_key_format!(type, key_value)
    case type
    when 'EMAIL'
      raise ArgumentError, "Invalid email format" unless key_value =~ URI::MailTo::EMAIL_REGEXP
    when 'PHONE'
      raise ArgumentError, "Invalid phone format" unless key_value =~ /^\+\d{13}$/
    when 'CPF', 'CNPJ'
      raise ArgumentError, "Invalid document format" unless valid_document?(key_value)
    end
  end

  def valid_document?(document)
    # Implement CPF/CNPJ validation logic
    document =~ /^\d{11}$/ || document =~ /^\d{14}$/
  end

  def handle_registration_error(error, key_value)
    if error.message.include?('already exists')
      Rails.logger.warn "Key already exists: #{key_value}"
      # Maybe initiate claim process
      false
    else
      Rails.logger.error "Registration failed: #{error.message}"
      raise error
    end
  end

  def monitor_claim_status(claim_id)
    # This would typically be handled by a background job
    ClaimMonitorJob.perform_later(claim_id)
  end

  def current_participant_code
    ENV.fetch('JDPI_PARTICIPANT_CODE')
  end
end
```

## 🔍 QR Code Generation & Management

```ruby
class QRCodeService
  def initialize
    @qr_client = JDPIClient::QR::Client.new
  end

  def generate_payment_qr(amount:, description: nil, expires_in: 30.minutes)
    begin
      response = @qr_client.create_qr!(
        valor: (amount * 100).to_i, # Convert to centavos
        descricao: description,
        validade: expires_in.to_i,
        tipo_cobranca: 'IMMEDIATE',
        permite_alteracao_valor: false
      )

      {
        qr_code: response['qr_code'],
        transaction_id: response['txid'],
        expires_at: Time.now + expires_in,
        pix_copy_paste: response['pix_copia_cola']
      }

    rescue => e
      Rails.logger.error "QR Code generation failed: #{e.message}"
      raise
    end
  end

  def generate_dynamic_qr(merchant_info:, allows_amount_change: true)
    response = @qr_client.create_dynamic_qr!(
      info_adicional: merchant_info,
      permite_alteracao_valor: allows_amount_change,
      validade: 24.hours.to_i # 24 hour validity
    )

    {
      qr_code: response['qr_code'],
      location: response['location'],
      merchant_info: merchant_info
    }
  end
end
```

## 🧪 Testing Patterns

### Service Testing with Mocks
```ruby
# test/services/test_pix_payment_service.rb
require_relative '../test_helper'

class TestPixPaymentService < Minitest::Test
  def setup
    @service = PixPaymentService.new(
      amount: 25.50,
      pix_key: "test@example.com",
      description: "Test payment"
    )

    # Mock SPI client
    @mock_spi = Minitest::Mock.new
    JDPIClient::SPI::OP.stub(:new, @mock_spi) do
      # Tests go here
    end
  end

  def test_successful_payment
    expected_response = {
      'id_req' => 'test_123',
      'status' => 'APPROVED'
    }

    @mock_spi.expect(:create_order!, expected_response, [Hash])
    @mock_spi.expect(:consult_request, expected_response, ['test_123'])

    JDPIClient::SPI::OP.stub(:new, @mock_spi) do
      assert @service.execute!
    end

    @mock_spi.verify
  end

  def test_validation_error_handling
    error = JDPIClient::Errors::Validation.new("Invalid amount")
    @mock_spi.expect(:create_order!, proc { raise error }, [Hash])

    JDPIClient::SPI::OP.stub(:new, @mock_spi) do
      refute @service.execute!
      assert_includes @service.errors.full_messages.join, "validation failed"
    end
  end
end
```

## 📊 Performance Monitoring Example

```ruby
class JDPIMetricsCollector
  def initialize
    @metrics = []
  end

  def track_request(operation, &block)
    start_time = Time.now

    begin
      result = block.call
      duration = Time.now - start_time

      log_success_metric(operation, duration)
      result

    rescue => e
      duration = Time.now - start_time
      log_error_metric(operation, duration, e)
      raise e
    end
  end

  private

  def log_success_metric(operation, duration)
    Rails.logger.info "JDPI Operation Success", {
      operation: operation,
      duration_ms: (duration * 1000).round(2),
      status: 'success',
      timestamp: Time.now.utc.iso8601
    }
  end

  def log_error_metric(operation, duration, error)
    Rails.logger.error "JDPI Operation Failed", {
      operation: operation,
      duration_ms: (duration * 1000).round(2),
      error_class: error.class.name,
      error_message: error.message,
      status: 'error',
      timestamp: Time.now.utc.iso8601
    }
  end
end

# Usage with existing services
metrics = JDPIMetricsCollector.new

# Track payment operations
payment_result = metrics.track_request('spi.create_order') do
  spi_client.create_order!(payment_data)
end

# Track DICT operations
key_result = metrics.track_request('dict.register_key') do
  dict_client.create_key!(key_data)
end
```

## 🔄 Rate Limiting Implementation

```ruby
class JDPIRateLimitManager
  def initialize(redis: Redis.current)
    @redis = redis
  end

  def with_rate_limit(operation:, limit: 90, window: 60, &block)
    key = "jdpi:rate_limit:#{operation}:#{Time.now.to_i / window}"

    current_requests = @redis.incr(key)
    @redis.expire(key, window) if current_requests == 1

    if current_requests > limit
      wait_time = window - (Time.now.to_i % window)
      raise JDPIClient::Errors::RateLimited.new(
        "Rate limit exceeded. Retry in #{wait_time} seconds"
      )
    end

    block.call
  end
end

# Usage
rate_limiter = JDPIRateLimitManager.new

rate_limiter.with_rate_limit(operation: 'spi_payments', limit: 90) do
  spi_client.create_order!(payment_data)
end
```

## 🔧 Environment-Specific Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.after_initialize do
    JDPIClient.configure do |jdpi_config|
      jdpi_config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
      jdpi_config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
      jdpi_config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

      # Production-specific settings
      jdpi_config.timeout = 8
      jdpi_config.open_timeout = 3
      jdpi_config.logger = Rails.logger
      jdpi_config.logger.level = Logger::WARN  # Minimal logging

      # Encrypted token storage with Redis
      jdpi_config.token_storage_adapter = :redis
      jdpi_config.token_storage_url = ENV.fetch('REDIS_URL')
      jdpi_config.token_encryption_enabled = true
      jdpi_config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
      jdpi_config.token_storage_key_prefix = "production:jdpi"
    end
  end
end

# config/environments/development.rb
Rails.application.configure do
  config.after_initialize do
    JDPIClient.configure do |jdpi_config|
      jdpi_config.jdpi_client_host = 'api.test.homl.jdpi.pstijd'
      jdpi_config.oauth_client_id = ENV['JDPI_CLIENT_ID'] || 'dev_client'
      jdpi_config.oauth_secret = ENV['JDPI_CLIENT_SECRET'] || 'dev_secret'

      # Development-specific settings
      jdpi_config.timeout = 15  # Longer timeout for debugging
      jdpi_config.logger = Logger.new($stdout)
      jdpi_config.logger.level = Logger::DEBUG  # Verbose logging

      # Simple memory storage for development
      jdpi_config.token_storage_adapter = :memory
    end
  end
end
```

## 🧪 Testing Best Practices

### Integration Test Setup
```ruby
# test/integration/test_pix_integration.rb
require_relative '../test_helper'

class TestPixIntegration < Minitest::Test
  def setup
    # Use test configuration
    @config = ServiceConfiguration.create_test_config(:memory)
    JDPIClient.instance_variable_set(:@config, @config)

    # Set up HTTP stubs
    setup_common_http_stubs
  end

  def test_complete_payment_flow
    # Test the full payment flow
    auth_client = JDPIClient::Auth::Client.new
    token = auth_client.token!
    assert token

    spi_client = JDPIClient::SPI::OP.new
    response = spi_client.create_order!(
      valor: 1000,
      chave: "test@example.com",
      dt_hr_requisicao_psp: Time.now.utc.iso8601,
      idempotency_key: SecureRandom.uuid
    )

    assert response['id_req']
    assert_equal 'ACSP', response['status']
  end

  def test_error_handling
    # Test error scenarios
    spi_client = JDPIClient::SPI::OP.new

    assert_raises JDPIClient::Errors::Validation do
      spi_client.create_order!(valor: -100)  # Invalid amount
    end
  end
end
```

## 📈 Current Metrics & Coverage

- **Test Coverage**: 75.65% line coverage, 53.07% branch coverage
- **Test Suite**: 330 runs, 1869 assertions
- **Ruby Support**: 3.0, 3.1, 3.2, 3.3, 3.4
- **CI/CD**: GitHub Actions with multi-version matrix testing
- **Performance**: Sub-500ms response times for most operations

This comprehensive documentation provides Claude with practical, copy-paste examples for common JDPI integration scenarios, updated with current metrics and best practices.