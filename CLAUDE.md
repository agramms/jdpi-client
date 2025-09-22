# Claude Code Configuration for jdpi-client

This file contains Claude Code specific instructions and patterns for working with the jdpi-client gem.

## 🚀 Quick Setup for Claude

When configuring this gem in Claude Code, use these environment-aware patterns:

```ruby
# Basic configuration - Claude will auto-detect environment
JDPIClient.configure do |c|
  c.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST', 'api.mybank.homl.jdpi.pstijd')
  c.oauth_client_id = ENV['JDPI_CLIENT_ID']
  c.oauth_secret = ENV['JDPI_CLIENT_SECRET']
  c.timeout = 8
  c.logger = Logger.new($stdout) if Rails.env.development?
end
```

## 🌍 Environment Detection Logic

The gem automatically detects environment and protocol from the hostname:

- **Production**: Contains "prod" or "production" → Uses HTTPS
- **Homolog**: Any other hostname → Uses HTTP

```ruby
# Examples:
"api.mybank.prod.jdpi.pstijd"        # → https://api.mybank.prod.jdpi.pstijd
"api.mybank.production.jdpi.pstijd"  # → https://api.mybank.production.jdpi.pstijd
"api.mybank.homl.jdpi.pstijd"        # → http://api.mybank.homl.jdpi.pstijd
"localhost"                          # → http://localhost
```

## 📋 Common Usage Patterns

### Authentication & Token Management
```ruby
# Token is automatically managed - just use it
auth_client = JDPIClient::Auth::Client.new
token = auth_client.token!  # Thread-safe, auto-refreshes

# Or use as proc for HTTP clients
token_provider = auth_client.to_proc
```

### PIX Payment Operations
```ruby
# SPI OP - Create payment order
spi_op = JDPIClient::SPI::OP.new
response = spi_op.create_order!(
  valor: 1050,  # R$ 10.50 in centavos
  chave: "user@bank.com",
  prioridade_pagamento: 0,
  finalidade: 1,
  dt_hr_requisicao_psp: Time.now.utc.iso8601,
  idempotency_key: SecureRandom.uuid
)
```

### DICT Operations
```ruby
# Key management
dict_keys = JDPIClient::DICT::Keys.new
dict_keys.create_key!(tipo: "EMAIL", chave: "user@bank.com")

# Claims and portability
dict_claims = JDPIClient::DICT::Claims.new
dict_claims.create_claim!(chave: "user@bank.com", tipo_reivindicacao: "OWNERSHIP")
```

### QR Code Generation
```ruby
# Generate payment QR code
qr_client = JDPIClient::QR::Client.new
qr_response = qr_client.create_qr!(
  valor: 2500,  # R$ 25.00
  descricao: "Payment for services"
)
```

## 🧪 Testing with Claude

### Running Tests
```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby test/test_config.rb

# Run with linting
bundle exec rake  # Runs both test and rubocop
```

### Test Structure
```ruby
# test/test_helper.rb sets up the test environment
require_relative "test_helper"

class TestMyFeature < Minitest::Test
  def setup
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "api.test.homl.jdpi.pstijd"
  end

  def test_environment_detection
    assert_equal "homl", @config.environment
    refute @config.production?
  end
end
```

## 🔧 Development Commands

### For Claude Code Sessions
```bash
# Install dependencies
bundle install

# Run linter
bundle exec rubocop

# Run tests
bundle exec rake test

# Run tests with coverage
COVERAGE=true bundle exec rake test

# Run full CI suite (tests + coverage + linting)
bundle exec rake ci

# Build gem
gem build jdpi_client.gemspec

# Install locally for testing
gem install jdpi_client-*.gem --local
```

## 🚨 Error Handling Patterns

```ruby
begin
  response = spi_op.create_order!(payment_data)
rescue JDPIClient::Errors::Validation => e
  # Handle validation errors (400)
  logger.error "Validation failed: #{e.message}"
rescue JDPIClient::Errors::Unauthorized => e
  # Handle auth errors (401) - maybe refresh token
  logger.error "Auth failed: #{e.message}"
rescue JDPIClient::Errors::RateLimited => e
  # Handle rate limiting (429)
  sleep 1
  retry
rescue JDPIClient::Errors::ServerError => e
  # Handle server errors (5xx)
  logger.error "Server error: #{e.message}"
end
```

## 📖 Documentation References

- `/docs/` - Complete JDPI API documentation
- `README.md` - Basic usage and installation
- `test/` - Test examples and patterns
- `.github/workflows/ci.yml` - CI/CD pipeline

## 🔍 Debugging Tips

1. **Enable logging** to see HTTP requests/responses
2. **Check environment detection** with `config.environment` and `config.production?`
3. **Verify base URL** with `config.base_url`
4. **Test token generation** independently with auth client
5. **Use idempotency keys** for payment operations to avoid duplicates

## 📝 Notes for Claude

- This gem follows Ruby conventions with frozen string literals
- All HTTP operations include retry logic and proper error handling
- Thread-safe token management with MonitorMixin
- Comprehensive test coverage with minitest
- CI/CD pipeline tests multiple Ruby versions (3.0-3.4)
- Current test coverage: 75.65% line coverage, 53.07% branch coverage
- Test suite: 330 runs, 1869 assertions across all supported Ruby versions