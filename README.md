# jdpi_client

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

## Features

- 🔐 **Automatic OAuth2 token management** with thread-safe caching
- 🌐 **Environment auto-detection** from hostname (prod/homl)
- 🔄 **Built-in retry logic** with exponential backoff
- 🛡️ **Comprehensive error handling** with structured exceptions
- 🔑 **Idempotency support** for safe payment operations
- 📝 **Request/response logging** for debugging
- ⚡ **No Rails dependency** - works with any Ruby application

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
end
```

## Usage Examples

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

### Code Quality

```bash
# Auto-fix linting issues
bundle exec rubocop -a

# Check test coverage
COVERAGE=true bundle exec rake test
```

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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Check the [troubleshooting guide](docs/15-Troubleshooting.md)
- Review existing [documentation](docs/)
- Open an issue on GitHub
