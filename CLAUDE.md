# Claude Code Configuration for jdpi-client

This file contains Claude Code specific instructions and patterns for working with the jdpi-client gem.

## 🏗️ Development Environment

This project uses a **development-focused DevContainer** approach:

- **DevContainer**: Rich development environment with Redis, PostgreSQL, DynamoDB Local, and JDPI Mock Server
- **CI Testing**: Clean, fast tests using only memory/mocks (no infrastructure dependencies)
- **Separation**: Clear distinction between development tooling and CI execution

### Development vs CI Philosophy

```
Development Container = Rich services + debugging tools + full integration testing
CI Environment       = Pure memory + mocks + fast execution + no external dependencies
```

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

### Test Environments

**CI Testing (Automatic)**:
- Uses memory adapters and mocks exclusively
- No external services required
- Fast execution (< 30 seconds)
- Automatically activated in CI environments

**Development Testing (In DevContainer)**:
- Optional real service integration
- Rich debugging capabilities
- Full service stack available

### Running Tests

```bash
# Default: Fast tests with mocks (works everywhere)
bundle exec rake test

# Development: Test with real Redis
TEST_ADAPTER=redis bundle exec rake test

# Development: Test with real PostgreSQL
TEST_ADAPTER=database bundle exec rake test

# Development: Test with all services
TEST_ADAPTER=all bundle exec rake test

# Specific test file
bundle exec ruby test/test_config.rb

# With linting
bundle exec rake  # Runs both test and rubocop

# With coverage
COVERAGE=true bundle exec rake test
```

### Test Structure & Safety

The test suite automatically detects CI environments and ensures clean execution:

```ruby
# test/test_helper.rb automatically handles environment detection
require_relative "test_helper"

class TestMyFeature < Minitest::Test
  def setup
    # Automatically gets clean config in CI, rich config in development
    @config = create_test_config
  end

  def test_environment_detection
    assert_equal "homl", @config.environment
    refute @config.production?

    # This test works in both CI and development environments
    # CI: Uses memory adapter
    # Dev: Can use real services if TEST_ADAPTER is set
  end
end
```

### CI Safety Features

- **Automatic Environment Detection**: Detects CI vs development environments
- **Service URL Cleaning**: Removes external service URLs in CI automatically
- **Forced Memory Adapters**: Always uses in-memory storage in CI regardless of configuration
- **Fast Execution**: No service dependencies or network calls in CI

## 🔧 Development Commands

### DevContainer Environment

**Setup**: Open in VS Code DevContainer for full development environment

```bash
# Install dependencies (automatic on container start)
bundle install

# Development testing (uses rich services)
TEST_ADAPTER=all bundle exec rake test

# Fast testing (uses mocks, same as CI)
bundle exec rake test

# Code quality
bundle exec rubocop

# Documentation
bundle exec yard doc

# Build gem
gem build jdpi_client.gemspec
```

### CI/Production Commands
```bash
# These commands work in any environment (CI, local, etc.)

# Fast tests (memory only)
bundle exec rake test

# With coverage
COVERAGE=true bundle exec rake test

# Full quality check
bundle exec rake ci

# Install locally
gem install jdpi_client-*.gem --local
```

### Environment-Specific Usage

```bash
# Development container features:
# - Redis at redis://redis:6379/0
# - PostgreSQL at postgresql://postgres:password@postgres:5432/jdpi_client_development
# - DynamoDB Local at http://dynamodb:8000
# - JDPI Mock at http://jdpi-mock:3000

# Use these for development testing:
TEST_ADAPTER=redis bundle exec rake test     # Test Redis integration
TEST_ADAPTER=database bundle exec rake test  # Test PostgreSQL integration
TEST_ADAPTER=dynamodb bundle exec rake test  # Test DynamoDB integration
TEST_ADAPTER=all bundle exec rake test       # Test all integrations
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

### Environment-Aware Debugging

1. **Development Container**:
   - Full logging enabled automatically
   - Rich debugging tools (pry, pry-byebug)
   - Service health checks available
   - Integration testing with real services

2. **CI Environment**:
   - Clean, minimal logging
   - Fast execution with mocks
   - No external dependencies

### Debugging Steps

1. **Check environment**: Use `CIEnvironment.ci?` to see which mode you're in
2. **Verify configuration**: `config.environment` and `config.production?`
3. **Check base URL**: `config.base_url`
4. **Test token generation**: Use auth client independently
5. **Service integration**: In dev container, check service health endpoints
6. **Use idempotency keys**: For payment operations to avoid duplicates

### Development Container Debugging

```bash
# Check service health
curl http://redis:6379         # Redis
pg_isready -h postgres         # PostgreSQL
curl http://dynamodb:8000/     # DynamoDB Local
curl http://jdpi-mock:3000/health # JDPI Mock

# Test with different adapters
TEST_ADAPTER=memory bundle exec ruby test/test_config.rb     # Fast
TEST_ADAPTER=redis bundle exec ruby test/test_config.rb     # Redis integration
TEST_ADAPTER=all bundle exec ruby test/test_config.rb       # Full integration
```

## 📝 Notes for Claude

### Architecture & Conventions
- Ruby conventions with frozen string literals
- Thread-safe token management with MonitorMixin
- Comprehensive test coverage with minitest
- CI/CD pipeline tests multiple Ruby versions (3.0-3.4)
- Current test coverage: 75.65% line coverage, 53.07% branch coverage
- Test suite: 330 runs, 1869 assertions across all supported Ruby versions

### Development Philosophy
- **DevContainer**: Rich development experience with full service stack
- **CI Testing**: Pure memory/mocks, no infrastructure dependencies
- **Automatic Environment Detection**: Tests adapt to CI vs development environments
- **Service Safety**: Impossible for CI tests to accidentally use external services

### Test Execution Summary
```
CI Environment:      Memory adapters, WebMock, SQLite in-memory, ~30 seconds
Development (Fast):  Memory adapters, WebMock, SQLite in-memory, ~30 seconds
Development (Full):  Real services, integration testing, ~2-5 minutes
```

### Key Benefits
✅ **Fast CI**: No service dependencies, pure mocks
✅ **Rich Development**: Full service integration available
✅ **Safety**: Automatic environment detection prevents accidents
✅ **Flexibility**: Choose appropriate testing level for the task