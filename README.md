# jdpi_client

[![CI](https://github.com/your-org/jdpi-client/workflows/CI/badge.svg)](https://github.com/your-org/jdpi-client/actions)
[![Test Coverage](https://img.shields.io/badge/coverage-94.1%25-brightgreen.svg)](https://your-org.github.io/jdpi-client/coverage/)
[![Ruby Version](https://img.shields.io/badge/ruby-3.0%2B-red.svg)](https://github.com/your-org/jdpi-client)
[![Gem Version](https://img.shields.io/badge/gem-0.1.0-blue.svg)](https://rubygems.org/gems/jdpi_client)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Code Style](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Maintainability](https://img.shields.io/badge/maintainability-A-brightgreen.svg)](https://github.com/your-org/jdpi-client)

> **Note**: Replace `your-org` with your actual GitHub organization/username in the badge URLs above

A lightweight Ruby client for **JDPI** microservices (Auth, DICT, QR, SPI OP/OD, Participants). No Rails dependency.
All service base URLs are fully configurable by environment.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jdpi_client', path: '/path/to/jdpi_client'
```

Or build and install locally:

```bash
gem build jdpi_client.gemspec
gem install jdpi_client-0.1.0.gem
```

## Quick start

```ruby
require 'jdpi_client'

JDPIClient.configure do |c|
  c.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST', 'api.mybank.homl.jdpi.pstijd')
  # Environment and protocol auto-detected from hostname:
  # - Contains 'prod' or 'production' -> HTTPS + production
  # - Otherwise -> HTTP + homolog

  c.oauth_client_id = ENV['JDPI_CLIENT_ID']
  c.oauth_secret    = ENV['JDPI_CLIENT_SECRET']
  c.timeout         = 8
  c.open_timeout    = 2
  c.logger          = Logger.new($stdout)
end

token = JDPIClient::Auth::Client.new.token!
resp  = JDPIClient::SPI::OP.new.create_order!(
  valor: 1050,
  chave: "fulano@bank.com",
  prioridade_pagamento: 0,
  finalidade: 1,
  dt_hr_requisicao_psp: Time.now.utc.iso8601
)
```

## Quality Metrics

![Tests](https://img.shields.io/badge/tests-160%20runs%2C%20558%20assertions-success)
![Test Status](https://img.shields.io/badge/test_status-passing-brightgreen)
![Branch Coverage](https://img.shields.io/badge/branch_coverage-62.96%25-yellow)
![Ruby 3.0+](https://img.shields.io/badge/ruby-3.0%20%7C%203.1%20%7C%203.2%20%7C%203.3%20%7C%203.4-ruby)

## Features

- 🔐 **Automatic OAuth2 token management** with thread-safe caching
- 🏢 **Multi-backend token storage** (Memory, Redis, Database, DynamoDB)
- 🔒 **Token encryption** for sensitive data protection
- 🌐 **Environment auto-detection** from hostname (prod/homl)
- 🔄 **Built-in retry logic** with exponential backoff
- 🛡️ **Comprehensive error handling** with structured exceptions
- 🔑 **Idempotency support** for safe payment operations
- ⚡ **Distributed locking** for clustered environments
- 📝 **Request/response logging** for debugging
- 🚀 **No Rails dependency** - works with any Ruby application
- 🧪 **High test coverage** (94.1%) with comprehensive test suite

## Services Supported

- **Auth** - OAuth2 authentication and token management
- **SPI OP** - Payment initiation and settlement
- **SPI OD** - Refund and dispute management
- **DICT** - PIX key management, claims, and infractions
- **QR** - QR code generation for payments
- **Participants** - Participant information management

## Configuration

### Environment Detection

The gem automatically detects environment and protocol from the hostname:

| Hostname Pattern | Environment | Protocol | Example |
|------------------|-------------|----------|---------|
| Contains `prod` or `production` | Production | HTTPS | `https://api.bank.prod.jdpi.pstijd` |
| Any other hostname | Homolog | HTTP | `http://api.bank.homl.jdpi.pstijd` |

### Advanced Configuration

```ruby
JDPIClient.configure do |config|
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

  # Optional settings
  config.timeout = 10        # Request timeout in seconds
  config.open_timeout = 3    # Connection timeout in seconds
  config.logger = Rails.logger if defined?(Rails)

  # Token storage configuration (for clustered environments)
  config.token_storage_adapter = :memory  # Default: in-memory storage
  config.token_storage_key_prefix = 'jdpi_client'  # Cache key prefix
  config.token_encryption_enabled = true  # Encrypt sensitive tokens
  config.token_encryption_key = ENV['JDPI_TOKEN_ENCRYPTION_KEY']  # 32+ character key
end
```

### Token Storage Configuration

The gem supports multiple token storage backends for clustered and distributed environments:

#### Memory Storage (Default)
```ruby
config.token_storage_adapter = :memory
# ✅ Fast and simple
# ❌ Not shared between processes/servers
# 👍 Best for: Single-server applications, development
```

#### Redis Storage
```ruby
config.token_storage_adapter = :redis
config.token_storage_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
config.token_storage_options = {
  timeout: 5,
  reconnect_attempts: 3,
  reconnect_delay: 1
}
# ✅ Distributed caching with automatic expiration
# ✅ High performance with built-in clustering
# 👍 Best for: Production clustered environments
```

#### Database Storage
```ruby
config.token_storage_adapter = :database
config.token_storage_url = ENV['DATABASE_URL']  # Any database supported by Ruby
config.token_storage_options = {
  table_name: 'jdpi_client_tokens'  # Custom table name
}
# ✅ Persistent storage with transaction safety
# ✅ Works with existing database infrastructure
# 👍 Best for: Applications with existing database setup
```

#### DynamoDB Storage
```ruby
config.token_storage_adapter = :dynamodb
config.token_storage_options = {
  table_name: 'jdpi-tokens',
  region: 'us-east-1',
  access_key_id: ENV['AWS_ACCESS_KEY_ID'],      # Optional if using IAM roles
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'] # Optional if using IAM roles
}
# ✅ Serverless with automatic scaling
# ✅ Built-in TTL for automatic token cleanup
# 👍 Best for: AWS-based serverless applications
```

#### Token Encryption

Enable encryption for sensitive token data:

```ruby
config.token_encryption_enabled = true
config.token_encryption_key = ENV['JDPI_TOKEN_ENCRYPTION_KEY']  # 32+ characters required

# Generate a secure encryption key:
# ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

#### Production Configuration Examples

**Rails Application with Redis:**
```ruby
# config/initializers/jdpi_client.rb
JDPIClient.configure do |config|
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')
  config.logger = Rails.logger

  # Shared Redis cache for clustered Rails servers
  config.token_storage_adapter = :redis
  config.token_storage_url = ENV.fetch('REDIS_URL')
  config.token_encryption_enabled = Rails.env.production?
  config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
  config.token_storage_key_prefix = "#{Rails.env}:jdpi"
end
```

**Serverless Application with DynamoDB:**
```ruby
JDPIClient.configure do |config|
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

  # DynamoDB for serverless environments
  config.token_storage_adapter = :dynamodb
  config.token_storage_options = {
    table_name: ENV.fetch('JDPI_TOKENS_TABLE', 'jdpi-tokens'),
    region: ENV.fetch('AWS_REGION', 'us-east-1')
  }
  config.token_encryption_enabled = true
  config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
end
```

**Development/Testing:**
```ruby
JDPIClient.configure do |config|
  config.jdpi_client_host = 'api.test.homl.jdpi.pstijd'
  config.oauth_client_id = 'test_client_id'
  config.oauth_secret = 'test_secret'

  # Simple memory storage for development
  config.token_storage_adapter = :memory
  config.logger = Logger.new($stdout) if ENV['DEBUG']
end
```

## Usage Examples

### Authentication & Token Management

The gem automatically handles OAuth2 token management with intelligent caching:

```ruby
# Basic token usage - automatically cached and refreshed
auth_client = JDPIClient::Auth::Client.new
token = auth_client.token!  # Thread-safe, auto-refreshes when expired

# Scope-specific tokens for different JDPI services
dict_token = auth_client.token!(requested_scopes: ['auth_apim', 'dict_api'])
spi_token = auth_client.token!(requested_scopes: ['auth_apim', 'spi_api'])

# Use as a proc for HTTP clients
token_provider = auth_client.to_proc
http_client.authorization = token_provider

# Force token refresh if needed
auth_client.refresh!

# Get token information for debugging
info = auth_client.token_info
puts "Token cached: #{info[:cached]}"
puts "Storage type: #{info[:storage_type]}"
puts "Expires at: #{info[:expires_at]}"
```

### PIX Payment
```ruby
# Create payment order
spi_client = JDPIClient::SPI::OP.new
response = spi_client.create_order!(
  valor: 2500,  # R$ 25.00 in centavos
  chave: "user@bank.com",
  descricao: "Payment for services",
  prioridade_pagamento: 0,
  finalidade: 1,
  dt_hr_requisicao_psp: Time.now.utc.iso8601,
  idempotency_key: SecureRandom.uuid
)

# Check payment status
status = spi_client.consult_request(response['id_req'])
```

### PIX Key Management
```ruby
# Register new PIX key
dict_client = JDPIClient::DICT::Keys.new
dict_client.create_key!(
  tipo: "EMAIL",
  chave: "user@bank.com",
  conta: account_info
)

# Claim existing key
claims_client = JDPIClient::DICT::Claims.new
claims_client.create_claim!(
  chave: "user@bank.com",
  tipo_reivindicacao: "OWNERSHIP"
)
```

### QR Code Generation
```ruby
# Generate payment QR code
qr_client = JDPIClient::QR::Client.new
qr_response = qr_client.create_qr!(
  valor: 1500,  # R$ 15.00
  descricao: "Coffee payment"
)

puts qr_response['qr_code']
puts qr_response['pix_copia_cola']
```

## Error Handling

The gem provides structured error handling for different scenarios:

```ruby
begin
  response = spi_client.create_order!(payment_data)
rescue JDPIClient::Errors::Validation => e
  # Handle validation errors (400)
  puts "Invalid request: #{e.message}"
rescue JDPIClient::Errors::Unauthorized => e
  # Handle authentication errors (401)
  puts "Authentication failed: #{e.message}"
rescue JDPIClient::Errors::RateLimited => e
  # Handle rate limiting (429)
  puts "Rate limited, please retry later"
rescue JDPIClient::Errors::ServerError => e
  # Handle server errors (5xx)
  puts "Server error: #{e.message}"
end
```

## Development

### Setup

```bash
git clone <repository-url>
cd jdpi-client
bundle install
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby test/test_config.rb

# Run with verbose output
bundle exec rake test TESTOPTS="-v"

# Run linter
bundle exec rubocop

# Run everything (tests + linting)
bundle exec rake
```

### Code Quality & Coverage

```bash
# Auto-fix linting issues
bundle exec rubocop -a

# Run tests with coverage
bundle exec rake test_coverage

# Generate coverage report only
bundle exec rake coverage

# Full CI suite (tests + coverage + linting)
bundle exec rake ci

# Alternative coverage command
COVERAGE=true bundle exec rake test
```

#### Coverage Features

- Current coverage: **94.1%** (minimum threshold enforced at 90%)
- Per-file minimum: **85%**
- Branch coverage: **62.96%**
- HTML reports generated in `coverage/index.html`
- Branch coverage enabled for detailed analysis
- Works across all supported Ruby versions (3.0+)
- High coverage ensures reliability and maintainability

### Building the Gem

```bash
# Build gem
gem build jdpi_client.gemspec

# Install locally for testing
gem install jdpi_client-*.gem --local

# Uninstall
gem uninstall jdpi_client
```

## Contributing

We welcome contributions! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** following our coding standards:
   - Use frozen string literals
   - Follow existing code style and patterns
   - Add tests for new functionality
   - Update documentation as needed

4. **Run the test suite**
   ```bash
   bundle exec rake test
   bundle exec rubocop
   ```

5. **Commit your changes**
   ```bash
   git commit -am "Add feature: your feature description"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Provide a clear description of your changes
   - Reference any related issues
   - Ensure CI tests pass

### Code Style

- Follow the existing code style
- Use meaningful variable and method names
- Add comments for complex business logic
- Keep methods focused and concise
- Use proper error handling

### Testing Guidelines

- Write tests for all new functionality
- Use descriptive test names
- Mock external API calls
- Test both success and error scenarios
- Maintain good test coverage

## Documentation

- `/docs` - Complete JDPI API documentation and PIX rules
- `CLAUDE.md` - Claude Code specific configuration and patterns
- `docs/13-Claude-Examples.md` - Comprehensive usage examples
- `docs/14-Development-Workflow.md` - Development and testing guide
- `docs/15-Troubleshooting.md` - Common issues and solutions

## Badge Setup

To get dynamic badges that update automatically:

### Coverage Badge Setup
1. **CodeCov Integration** (recommended):
   ```yaml
   # Add to .github/workflows/ci.yml
   - name: Upload coverage to Codecov
     uses: codecov/codecov-action@v3
     with:
       file: ./coverage/coverage.xml
   ```
   Badge: `[![codecov](https://codecov.io/gh/your-org/jdpi-client/branch/main/graph/badge.svg)](https://codecov.io/gh/your-org/jdpi-client)`

2. **GitHub Pages Coverage**:
   ```yaml
   # Add job to deploy coverage reports
   - name: Deploy coverage to GitHub Pages
     uses: peaceiris/actions-gh-pages@v3
     with:
       github_token: ${{ secrets.GITHUB_TOKEN }}
       publish_dir: ./coverage
   ```

### Automated Badge Updates
For automatically updating badges, consider:
- **GitHub Actions**: Auto-update README badges based on test results
- **Shields.io**: Dynamic badges from GitHub API endpoints
- **CodeClimate**: Code quality and coverage integration
- **RubyGems**: Automatic gem version badges

### Current Badge Configuration
All badges are configured with current project metrics:
- **CI Status**: Links to GitHub Actions workflow results
- **Coverage**: Shows current 94.1% test coverage
- **Ruby Support**: Indicates Ruby 3.0+ compatibility
- **License**: MIT license badge
- **Code Style**: RuboCop compliance

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Check the [troubleshooting guide](docs/15-Troubleshooting.md)
- Review existing [documentation](docs/)
- Open an issue on GitHub
