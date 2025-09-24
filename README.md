# jdpi_client

[![CI](https://github.com/agramms/jdpi-client/workflows/CI/badge.svg)](https://github.com/agramms/jdpi-client/actions)
[![Test Coverage](https://img.shields.io/badge/coverage-75.65%25-brightgreen.svg)](https://github.com/agramms/jdpi-client/actions)
[![Ruby Version](https://img.shields.io/badge/ruby-3.0%20%7C%203.1%20%7C%203.2%20%7C%203.3%20%7C%203.4-red.svg)](https://github.com/agramms/jdpi-client)
[![Gem Version](https://img.shields.io/badge/gem-0.1.0-blue.svg)](https://github.com/agramms/jdpi-client)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Code Style](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![Maintainability](https://img.shields.io/badge/maintainability-A-brightgreen.svg)](https://github.com/agramms/jdpi-client)

A lightweight Ruby client for **JDPI** microservices (Auth, DICT, QR, SPI OP/OD, Participants). No Rails dependency.
All service base URLs are fully configurable by environment.

## 📋 Prerequisites

Before installing jdpi_client, ensure you have:

- **Ruby 3.0 or higher** (tested on Ruby 3.0, 3.1, 3.2, 3.3, and 3.4)
- **Bundler 2.0+** for dependency management
- **System dependencies** (for advanced token storage):
  - `libpq-dev` (for PostgreSQL storage backend)
  - `libsqlite3-dev` (for SQLite storage backend)

### Verify Prerequisites

```bash
ruby --version    # Should be 3.0+
bundle --version  # Should be 2.0+
```

### Install System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y libpq-dev libsqlite3-dev
```

**macOS (Homebrew):**
```bash
brew install postgresql sqlite3
```

## Installation

### From Source (Development)

Add this line to your application's Gemfile:

```ruby
gem 'jdpi_client', git: 'https://github.com/agramms/jdpi-client.git'
```

Then execute:

```bash
bundle install
```

### Local Development Install

Clone and install from source:

```bash
git clone https://github.com/agramms/jdpi-client.git
cd jdpi-client
bundle install
gem build jdpi_client.gemspec
gem install jdpi_client-0.1.0.gem
```

### Docker Development Setup

**🐳 Complete containerized development environment with one-command setup!**

We provide a comprehensive Docker development environment with:
- All Ruby versions (3.0-3.4) for matrix testing
- Complete storage backend testing (Redis, PostgreSQL, DynamoDB Local)
- JDPI mock server for realistic API testing
- VS Code devcontainer support
- Hot reloading and debugging capabilities

#### Quick Start (Recommended)

```bash
git clone https://github.com/agramms/jdpi-client.git
cd jdpi-client

# Option 1: VS Code with Dev Container (Recommended)
# 1. Open in VS Code
# 2. Click "Reopen in Container" when prompted
# 3. Environment will be automatically set up!

# Option 2: Command Line Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
docker-compose exec jdpi-dev bash
```

#### Available Docker Commands

```bash
# Development environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Run test suite
docker-compose -f docker-compose.yml -f docker-compose.test.yml up jdpi-test

# Matrix testing across all Ruby versions (3.0-3.4)
./scripts/test-matrix.sh

# Individual Ruby version testing
docker-compose --profile matrix-test up ruby30  # Test Ruby 3.0
docker-compose --profile matrix-test up ruby31  # Test Ruby 3.1
# ... and so on for ruby32, ruby33, ruby34
```

#### Services Available

| Service | Port | Purpose |
|---------|------|---------|
| **jdpi-dev** | - | Main development container (Ruby 3.2) |
| **redis** | 6379 | Token storage testing |
| **postgres** | 5432 | Database storage testing |
| **dynamodb** | 8000 | DynamoDB Local for AWS testing |
| **jdpi-mock** | 3000 | Mock JDPI server for API testing |

#### VS Code DevContainer Features

- **Pre-configured environment** with Ruby LSP, debugger, and extensions
- **Integrated testing** with test runner integration
- **Port forwarding** for all services
- **Hot reloading** for code changes
- **Debugging support** with breakpoints and variable inspection

#### Manual Setup

If you prefer manual Docker setup:

```bash
# 1. Start all services
docker-compose up -d

# 2. Run setup script
docker-compose exec jdpi-dev scripts/setup-dev.sh

# 3. Verify setup
docker-compose exec jdpi-dev bundle exec rake test
```

## 🚀 Quick Setup Checklist

Follow these steps to get jdpi_client up and running:

### 1. Environment Setup
- [ ] **Install prerequisites** (Ruby 3.0+, Bundler 2.0+, system dependencies)
- [ ] **Install the gem** using one of the methods above
- [ ] **Create environment file** (`.env` for local development)

### 2. Basic Configuration
Create a configuration file or add to your application initializer:

```ruby
# config/initializers/jdpi_client.rb (Rails)
# or create a separate configuration file

require 'jdpi_client'

JDPIClient.configure do |config|
  # Required settings
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

  # Optional settings
  config.timeout = 10
  config.logger = Logger.new($stdout) # Enable logging
end
```

### 3. Environment Variables Setup
Create your `.env` file or set these environment variables:

```bash
# Required
JDPI_CLIENT_HOST=api.yourbank.homl.jdpi.pstijd
JDPI_CLIENT_ID=your_oauth_client_id
JDPI_CLIENT_SECRET=your_oauth_secret

# Optional (for advanced features)
JDPI_TOKEN_ENCRYPTION_KEY=your_32_character_encryption_key_here
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgresql://user:password@localhost:5432/your_app
```

### 4. Verify Installation
Test your setup with this simple script:

```ruby
require 'jdpi_client'

# Test configuration
puts "✅ Gem loaded successfully"
puts "🌍 Environment: #{JDPIClient.config&.environment || 'not configured'}"
puts "🔗 Host: #{JDPIClient.config&.jdpi_client_host || 'not configured'}"

# Test authentication (requires valid credentials)
begin
  auth_client = JDPIClient::Auth::Client.new
  token = auth_client.token!
  puts "🔑 Authentication: SUCCESS"
rescue => e
  puts "❌ Authentication failed: #{e.message}"
end
```

### 5. First API Call
Try your first JDPI API call:

```ruby
# Get participants list (simple read operation)
begin
  participants = JDPIClient::Participants.new
  result = participants.list
  puts "📋 Participants API: SUCCESS (#{result.size} participants)"
rescue => e
  puts "❌ API call failed: #{e.message}"
end
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

![Tests](https://img.shields.io/badge/tests-330%20runs%2C%201869%20assertions-success)
![Test Status](https://img.shields.io/badge/test_status-passing-brightgreen)
![Line Coverage](https://img.shields.io/badge/line_coverage-75.65%25-brightgreen)
![Branch Coverage](https://img.shields.io/badge/branch_coverage-53.07%25-yellow)
![Ruby Support](https://img.shields.io/badge/ruby-3.0%20%7C%203.1%20%7C%203.2%20%7C%203.3%20%7C%203.4-ruby)

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
- 🧪 **High test coverage** (75.65%) with comprehensive test suite

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

## 🔧 Environment Variables Reference

This section lists all environment variables that jdpi_client recognizes:

### Required Variables

| Variable | Description | Example | Notes |
|----------|-------------|---------|-------|
| `JDPI_CLIENT_HOST` | JDPI API hostname | `api.mybank.homl.jdpi.pstijd` | Auto-detects environment and protocol |
| `JDPI_CLIENT_ID` | OAuth2 client ID | `your_client_id` | Provided by JDPI |
| `JDPI_CLIENT_SECRET` | OAuth2 client secret | `your_client_secret` | Keep secure! |

### Optional Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `JDPI_TIMEOUT` | Request timeout (seconds) | `8` | `10` |
| `JDPI_OPEN_TIMEOUT` | Connection timeout (seconds) | `2` | `3` |
| `JDPI_LOG_LEVEL` | Logging level | `info` | `debug`, `warn`, `error` |
| `JDPI_TOKEN_ENCRYPTION_KEY` | Token encryption key (32+ chars) | `nil` | Generated with `SecureRandom.hex(32)` |

### Storage Backend Variables

#### Redis Storage
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379/0` | `redis://user:pass@host:port/db` |
| `JDPI_REDIS_TIMEOUT` | Redis operation timeout | `5` | `10` |
| `JDPI_REDIS_RECONNECT_ATTEMPTS` | Reconnection attempts | `3` | `5` |

#### Database Storage
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_URL` | Database connection URL | `nil` | `postgresql://user:pass@host/db` |
| `JDPI_DB_TABLE_NAME` | Token storage table name | `jdpi_client_tokens` | `my_tokens` |

#### DynamoDB Storage
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `AWS_REGION` | AWS region | `us-east-1` | `us-west-2` |
| `AWS_ACCESS_KEY_ID` | AWS access key | `nil` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `nil` | IAM user secret |
| `JDPI_DYNAMODB_TABLE` | DynamoDB table name | `jdpi-tokens` | `my-jdpi-tokens` |
| `DYNAMODB_ENDPOINT` | DynamoDB endpoint (for local) | `nil` | `http://localhost:8000` |

### Development & Testing Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RAILS_ENV` / `RACK_ENV` | Application environment | `nil` | `development`, `production` |
| `DEBUG` | Enable debug logging | `false` | `true` |
| `COVERAGE` | Enable test coverage | `false` | `true` |
| `TEST_ADAPTER` | Test storage adapter | `memory` | `redis`, `database`, `dynamodb` |

### Example .env Files

**Development (.env.development):**
```bash
JDPI_CLIENT_HOST=api.test.homl.jdpi.pstijd
JDPI_CLIENT_ID=test_client_id
JDPI_CLIENT_SECRET=test_client_secret
JDPI_TIMEOUT=10
DEBUG=true
```

**Production (.env.production):**
```bash
JDPI_CLIENT_HOST=api.mybank.prod.jdpi.pstijd
JDPI_CLIENT_ID=prod_client_id
JDPI_CLIENT_SECRET=super_secure_secret
JDPI_TOKEN_ENCRYPTION_KEY=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
REDIS_URL=redis://cache.production.com:6379/1
JDPI_TIMEOUT=8
JDPI_OPEN_TIMEOUT=3
```

**Testing (.env.test):**
```bash
JDPI_CLIENT_HOST=api.test.homl.jdpi.pstijd
JDPI_CLIENT_ID=test_client
JDPI_CLIENT_SECRET=test_secret
TEST_ADAPTER=memory
COVERAGE=true
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

## 📚 API Reference

This section provides detailed information about JDPI APIs and their request/response formats.

### Complete API Documentation

For comprehensive API documentation, see the `/docs` directory:
- **[JDPI API Overview](docs/01-JDPI-Overview.md)** - Introduction to JDPI architecture
- **[Authentication](docs/02-Authentication.md)** - OAuth2 flow and token management
- **[SPI Operations](docs/03-SPI-Operations.md)** - PIX payment APIs (OP/OD)
- **[DICT Services](docs/04-DICT-Services.md)** - PIX key management
- **[QR Code Generation](docs/05-QR-Generation.md)** - QR code creation and validation
- **[Participants API](docs/06-Participants.md)** - Participant information

### Authentication API

**Endpoint**: `/auth/jdpi/connect/token`

**Request Format**:
```json
POST /auth/jdpi/connect/token
Content-Type: application/x-www-form-urlencoded

client_id=YOUR_CLIENT_ID&
client_secret=YOUR_CLIENT_SECRET&
grant_type=client_credentials&
scope=auth_apim spi_api dict_api
```

**Response Format**:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "auth_apim spi_api dict_api"
}
```

**Ruby Example**:
```ruby
auth_client = JDPIClient::Auth::Client.new
token = auth_client.token!
# Token is automatically cached and refreshed
```

### SPI OP (Outbound Payments) API

#### Create Payment Order

**Endpoint**: `/spi/api/v1/op`

**Request Format**:
```json
POST /spi/api/v1/op
Authorization: Bearer {token}
Content-Type: application/json

{
  "valor": 1050,
  "chave": "user@bank.com",
  "descricao": "Payment description",
  "prioridade_pagamento": 0,
  "finalidade": 1,
  "dt_hr_requisicao_psp": "2024-01-15T10:30:00Z",
  "idempotency_key": "unique-request-id-123"
}
```

**Response Format**:
```json
{
  "id_req": "12345678-1234-1234-1234-123456789012",
  "status": "ACSP",
  "dt_hr_resposta": "2024-01-15T10:30:01Z",
  "valor": 1050,
  "chave": "user@bank.com"
}
```

**Ruby Example**:
```ruby
spi_client = JDPIClient::SPI::OP.new
response = spi_client.create_order!(
  valor: 1050,  # R$ 10.50 in centavos
  chave: "user@bank.com",
  descricao: "Coffee payment",
  prioridade_pagamento: 0,
  finalidade: 1,
  dt_hr_requisicao_psp: Time.now.utc.iso8601,
  idempotency_key: SecureRandom.uuid
)
puts response['id_req']  # Payment ID
```

#### Query Payment Status

**Endpoint**: `/spi/api/v1/op/{id_req}`

**Request Format**:
```http
GET /spi/api/v1/op/12345678-1234-1234-1234-123456789012
Authorization: Bearer {token}
```

**Response Format**:
```json
{
  "id_req": "12345678-1234-1234-1234-123456789012",
  "status": "ACCC",
  "dt_hr_resposta": "2024-01-15T10:30:01Z",
  "valor": 1050,
  "chave": "user@bank.com",
  "end_to_end_id": "E12345678202401151030123456789012"
}
```

### DICT (PIX Key Management) API

#### Register PIX Key

**Endpoint**: `/dict/api/v2/key`

**Request Format**:
```json
POST /dict/api/v2/key
Authorization: Bearer {token}
Content-Type: application/json

{
  "tipo": "EMAIL",
  "chave": "user@bank.com",
  "conta": {
    "ispb": "12345678",
    "agencia": "0001",
    "conta": "12345678",
    "tipo_conta": "CACC"
  }
}
```

**Response Format**:
```json
{
  "chave": "user@bank.com",
  "tipo": "EMAIL",
  "status": "OWNED",
  "dt_criacao": "2024-01-15T10:30:00Z"
}
```

**Ruby Example**:
```ruby
dict_client = JDPIClient::DICT::Keys.new
response = dict_client.create_key!(
  tipo: "EMAIL",
  chave: "user@bank.com",
  conta: {
    ispb: "12345678",
    agencia: "0001",
    conta: "12345678",
    tipo_conta: "CACC"
  }
)
```

#### Query PIX Key

**Endpoint**: `/dict/api/v2/key/{key_value}`

**Request Format**:
```http
GET /dict/api/v2/key/user@bank.com
Authorization: Bearer {token}
```

**Response Format**:
```json
{
  "chave": "user@bank.com",
  "tipo": "EMAIL",
  "conta": {
    "ispb": "12345678",
    "nome": "Bank Name",
    "agencia": "0001",
    "conta": "12345678",
    "tipo_conta": "CACC"
  },
  "status": "OWNED"
}
```

### QR Code API

#### Generate QR Code

**Endpoint**: `/qr/api/v1/qr`

**Request Format**:
```json
POST /qr/api/v1/qr
Authorization: Bearer {token}
Content-Type: application/json

{
  "valor": 2500,
  "descricao": "Payment for services",
  "chave": "merchant@bank.com"
}
```

**Response Format**:
```json
{
  "qr_code": "iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAYAAAB5fY51...",
  "pix_copia_cola": "00020126580014br.gov.bcb.pix013639c02...",
  "txid": "12345678901234567890123456789012"
}
```

**Ruby Example**:
```ruby
qr_client = JDPIClient::QR::Client.new
response = qr_client.create_qr!(
  valor: 2500,  # R$ 25.00
  descricao: "Coffee and pastry",
  chave: "merchant@bank.com"
)

puts "QR Code: #{response['qr_code']}"
puts "PIX Copy/Paste: #{response['pix_copia_cola']}"
```

### Common Response Codes

| HTTP Status | Description | Action |
|-------------|-------------|--------|
| 200 | Success | Request completed successfully |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Check request format and parameters |
| 401 | Unauthorized | Refresh authentication token |
| 403 | Forbidden | Check permissions and scope |
| 404 | Not Found | Resource doesn't exist |
| 429 | Rate Limited | Implement backoff/retry logic |
| 500 | Internal Error | Retry with exponential backoff |
| 502/503 | Service Unavailable | Check JDPI service status |

### Request/Response Headers

**Common Request Headers**:
```http
Authorization: Bearer {access_token}
Content-Type: application/json
Accept: application/json
X-Idempotency-Key: {unique-request-id}  # For payment operations
```

**Common Response Headers**:
```http
Content-Type: application/json
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
X-Request-ID: 12345678-1234-1234-1234-123456789012
```

### Error Response Format

All JDPI APIs return structured error responses:

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "The request format is invalid",
    "details": [
      {
        "field": "valor",
        "message": "Value must be greater than 0"
      }
    ]
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "path": "/spi/api/v1/op"
}
```

### Webhooks & Notifications

JDPI can send webhooks for payment status updates:

**Webhook Payload Format**:
```json
{
  "event_type": "payment.status_changed",
  "id_req": "12345678-1234-1234-1234-123456789012",
  "status": "ACCC",
  "timestamp": "2024-01-15T10:30:01Z",
  "end_to_end_id": "E12345678202401151030123456789012"
}
```

**Webhook Signature Verification**:
```ruby
# Verify webhook authenticity
def verify_webhook(payload, signature, secret)
  expected_signature = OpenSSL::HMAC.hexdigest('sha256', secret, payload)
  Rack::Utils.secure_compare(signature, expected_signature)
end
```

### Testing & Sandbox

**Homolog Environment**:
- Base URL: `http://api.bank.homl.jdpi.pstijd`
- Use test credentials provided by JDPI
- Safe for testing without real money

**Test PIX Keys**:
- Email: `test@example.com`
- Phone: `+5511999999999`
- CPF: `12345678901` (test CPF)
- Random Key: `123e4567-e89b-12d3-a456-426614174000`

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

## 🔒 Security Considerations

Security is critical when working with PIX payments. Follow these best practices:

### 1. Credential Management

**✅ DO:**
- Store credentials in environment variables, never in code
- Use encrypted storage for production credentials
- Rotate OAuth secrets regularly
- Use different credentials for each environment

**❌ DON'T:**
- Commit credentials to version control
- Log or print sensitive information
- Share credentials across environments
- Store credentials in plain text files

```ruby
# ✅ Good - Environment variables
config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

# ❌ Bad - Hard-coded credentials
config.oauth_secret = 'my-secret-key'  # Never do this!
```

### 2. Token Security

**Enable token encryption in production:**

```ruby
config.token_encryption_enabled = true
config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')

# Generate a secure encryption key:
# ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

**Token storage recommendations:**
- Use Redis/Database/DynamoDB in production (not memory)
- Enable encryption for all stored tokens
- Set appropriate token TTL values
- Monitor token usage patterns

### 3. Network Security

**HTTPS/TLS Configuration:**
- Always use HTTPS in production (auto-detected for `prod` hostnames)
- Validate SSL certificates
- Use TLS 1.2 or higher
- Configure proper timeout values

```ruby
config.timeout = 8         # Request timeout
config.open_timeout = 3    # Connection timeout
```

**Firewall and Access:**
- Whitelist JDPI IP addresses
- Restrict outbound connections to JDPI endpoints only
- Use VPN or private networks when possible
- Monitor network traffic for anomalies

### 4. Logging Security

**Safe logging practices:**

```ruby
# ✅ Good - Structured logging without sensitive data
logger.info "PIX payment initiated", {
  order_id: order_id,
  amount_cents: amount,
  timestamp: Time.now.utc.iso8601
}

# ❌ Bad - Logging sensitive information
logger.info "Token: #{token}"  # Never log tokens!
logger.info "Request: #{request_body.inspect}"  # May contain secrets
```

**Configure logging levels:**

```ruby
# Production - minimal logging
config.logger.level = Logger::WARN

# Development - detailed logging
config.logger.level = Logger::DEBUG if Rails.env.development?
```

### 5. Application Security

**Input validation:**
- Validate all payment parameters
- Sanitize user inputs
- Use strong typing where possible
- Implement request size limits

**Error handling:**
- Never expose internal errors to users
- Log security events (failed authentication, etc.)
- Implement rate limiting
- Use structured error responses

```ruby
begin
  response = spi_client.create_order!(payment_data)
rescue JDPIClient::Errors::Unauthorized => e
  # ✅ Good - Log security event, return generic error
  security_logger.warn "Authentication failed for client #{client_id}"
  render json: { error: 'Authentication failed' }, status: :unauthorized

  # ❌ Bad - Expose detailed error information
  render json: { error: e.message }, status: :unauthorized
end
```

### 6. Production Deployment

**Environment separation:**
- Use completely separate credentials for each environment
- Never use production credentials in development/testing
- Implement proper CI/CD security practices
- Use infrastructure as code for consistent deployments

**Secret management:**
- Use dedicated secret management services (AWS Secrets Manager, Azure Key Vault, etc.)
- Implement secret rotation procedures
- Monitor secret access and usage
- Use service accounts with minimal permissions

**Example secure production configuration:**

```ruby
# config/initializers/jdpi_client.rb
JDPIClient.configure do |config|
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')

  # Security settings
  config.timeout = 8
  config.open_timeout = 3
  config.logger = Rails.logger
  config.logger.level = Logger::WARN  # Minimal production logging

  # Encrypted token storage
  config.token_storage_adapter = :redis
  config.token_storage_url = ENV.fetch('REDIS_URL')
  config.token_encryption_enabled = true
  config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
  config.token_storage_key_prefix = "#{Rails.env}:jdpi"
end
```

### 7. Monitoring & Alerting

**Set up monitoring for:**
- Failed authentication attempts
- Unusual payment patterns
- Token refresh failures
- Network connectivity issues
- Performance degradation

**Security alerts:**
- Multiple authentication failures
- Unexpected geographic access
- Token encryption/decryption failures
- Suspicious payment amounts or patterns

### 8. Compliance & Auditing

**PIX Compliance:**
- Follow Central Bank of Brazil regulations
- Implement proper audit logs
- Maintain transaction records
- Follow data protection requirements (LGPD)

**Audit logging:**
- Log all payment operations with timestamps
- Track user actions and changes
- Maintain immutable audit trails
- Regular compliance reviews

## ⚡ Performance & Rate Limiting

Understanding JDPI's performance characteristics and rate limits is crucial for production applications.

### JDPI Rate Limits

**Standard Rate Limits:**
- **Authentication**: 10 requests/minute per client
- **PIX Payments (SPI OP)**: 100 requests/minute per participant
- **PIX Queries (SPI OD)**: 200 requests/minute per participant
- **DICT Operations**: 50 requests/minute per participant
- **QR Generation**: 300 requests/minute per participant

**Rate Limit Headers:**
JDPI returns these headers with rate limit information:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1640995200
```

### Performance Characteristics

**Expected Response Times:**
- **Token Requests**: < 200ms
- **PIX Payments**: < 500ms
- **Balance Queries**: < 300ms
- **DICT Lookups**: < 400ms
- **QR Generation**: < 100ms

**Best Practices for Performance:**

1. **Token Caching** (automatically handled by jdpi_client):
```ruby
# Tokens are cached automatically with intelligent refresh
auth_client = JDPIClient::Auth::Client.new
token = auth_client.token!  # Cached for subsequent requests
```

2. **Connection Reuse**:
```ruby
# Configure reasonable timeouts
config.timeout = 8         # Request timeout
config.open_timeout = 3    # Connection timeout
```

3. **Request Batching** (where supported):
```ruby
# Batch DICT lookups when possible
dict_client = JDPIClient::DICT::Keys.new
keys = ["user1@bank.com", "user2@bank.com", "user3@bank.com"]
# Process in batches to respect rate limits
```

### Rate Limiting Strategies

**1. Exponential Backoff:**

```ruby
def make_request_with_backoff(retries = 3, delay = 1)
  begin
    spi_client.create_order!(payment_data)
  rescue JDPIClient::Errors::RateLimited => e
    if retries > 0
      sleep(delay)
      make_request_with_backoff(retries - 1, delay * 2)
    else
      raise e
    end
  end
end
```

**2. Rate Limit Monitoring:**

```ruby
# Check rate limit status before making requests
def check_rate_limits(response)
  remaining = response.headers['X-RateLimit-Remaining'].to_i
  reset_time = response.headers['X-RateLimit-Reset'].to_i

  if remaining < 10
    wait_time = reset_time - Time.now.to_i
    puts "⚠️  Rate limit low (#{remaining} remaining), resets in #{wait_time}s"
  end
end
```

**3. Request Queue Management:**

```ruby
class JDPIRequestQueue
  def initialize(requests_per_minute: 90)  # Stay under 100/min limit
    @requests_per_minute = requests_per_minute
    @request_times = []
  end

  def throttled_request(&block)
    wait_if_needed
    result = block.call
    @request_times << Time.now
    result
  end

  private

  def wait_if_needed
    now = Time.now
    @request_times.reject! { |time| time < now - 60 }  # Keep last minute

    if @request_times.size >= @requests_per_minute
      sleep_time = 60 - (now - @request_times.first)
      sleep(sleep_time) if sleep_time > 0
    end
  end
end

# Usage
queue = JDPIRequestQueue.new(requests_per_minute: 90)
queue.throttled_request { spi_client.create_order!(payment_data) }
```

### High-Volume Applications

**Connection Pooling:**
For high-volume applications, consider implementing connection pooling:

```ruby
require 'connection_pool'

JDPI_POOL = ConnectionPool.new(size: 25, timeout: 5) do
  JDPIClient::SPI::OP.new
end

# Use pooled connections
JDPI_POOL.with do |spi_client|
  spi_client.create_order!(payment_data)
end
```

**Distributed Rate Limiting:**
For multiple application instances, use Redis for distributed rate limiting:

```ruby
class DistributedRateLimit
  def initialize(redis, limit:, window:)
    @redis = redis
    @limit = limit
    @window = window
  end

  def allow_request?(key)
    current_time = Time.now.to_i
    window_start = current_time - @window

    pipe = @redis.pipelined do
      @redis.zremrangebyscore(key, 0, window_start)
      @redis.zcard(key)
      @redis.zadd(key, current_time, current_time)
      @redis.expire(key, @window)
    end

    current_requests = pipe[1]
    current_requests < @limit
  end
end

# Usage
rate_limiter = DistributedRateLimit.new(
  Redis.current,
  limit: 90,
  window: 60
)

if rate_limiter.allow_request?("jdpi:spi:#{institution_id}")
  spi_client.create_order!(payment_data)
else
  # Handle rate limit exceeded
  raise "Rate limit exceeded"
end
```

### Performance Monitoring

**Key Metrics to Track:**
- Request latency percentiles (P50, P95, P99)
- Rate limit utilization
- Token refresh frequency
- Connection pool utilization
- Error rates by endpoint

**Example Monitoring:**

```ruby
class JDPIMetrics
  def self.track_request(endpoint, &block)
    start_time = Time.now
    begin
      result = block.call
      duration = Time.now - start_time

      # Log successful request
      Rails.logger.info "JDPI Request", {
        endpoint: endpoint,
        duration_ms: (duration * 1000).round(2),
        status: 'success'
      }

      result
    rescue => e
      duration = Time.now - start_time

      # Log failed request
      Rails.logger.warn "JDPI Request Failed", {
        endpoint: endpoint,
        duration_ms: (duration * 1000).round(2),
        error: e.class.name,
        status: 'error'
      }

      raise e
    end
  end
end

# Usage
JDPIMetrics.track_request('spi.create_order') do
  spi_client.create_order!(payment_data)
end
```

### Optimization Tips

1. **Cache DICT Lookups**: PIX keys don't change frequently
2. **Batch Operations**: Group related requests when possible
3. **Use Connection Pooling**: For multi-threaded applications
4. **Implement Circuit Breakers**: Prevent cascade failures
5. **Monitor Performance**: Track latency and error rates
6. **Optimize Payload Size**: Send only required fields
7. **Use Compression**: Enable gzip compression for large requests

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

### 🚀 CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment. Understanding the CI/CD pipeline helps contributors write code that passes all checks.

#### GitHub Actions Workflow

The CI pipeline is defined in `.github/workflows/ci.yml` and includes:

1. **Multi-Version Testing**:
   - Tests across Ruby 3.0, 3.1, 3.2, 3.3, and 3.4
   - Ensures compatibility across all supported Ruby versions
   - Uses matrix strategy for parallel execution

2. **Code Quality Checks**:
   - **RuboCop**: Linting and style checking
   - **Test Coverage**: Minimum 70% line coverage required
   - **Security**: Dependency vulnerability scanning

3. **Test Execution**:
   - Runs complete test suite (330+ tests, 1800+ assertions)
   - Uses mocked HTTP responses for reliable testing
   - Includes integration tests for all storage backends

4. **Gem Building**:
   - Validates gem can be built successfully
   - Checks gemspec structure and dependencies

#### CI Commands

**Local CI Simulation**:
```bash
# Run the same checks as CI
bundle exec rake ci

# Individual steps:
bundle exec rubocop          # Style checking
bundle exec rake test        # Run test suite
COVERAGE=true bundle exec rake test  # With coverage
gem build jdpi_client.gemspec       # Build gem
```

**Pre-commit Checks**:
```bash
# Recommended before committing
bundle exec rubocop -a      # Auto-fix style issues
bundle exec rake test       # Ensure tests pass
git add . && git commit     # Git hooks will clean commit messages
```

#### CI Environment Variables

The CI environment uses these variables:

| Variable | Purpose | Value in CI |
|----------|---------|-------------|
| `CI` | Indicates CI environment | `"true"` |
| `COVERAGE` | Enable coverage reporting | `"true"` |
| `TEST_ADAPTER` | Default storage adapter for tests | `"memory"` |
| `RUBY_VERSION` | Matrix variable for Ruby version | `"3.0"`, `"3.1"`, etc. |

#### Branch Protection

The `master` branch is protected with these rules:
- **Required status checks**: All CI jobs must pass
- **Up-to-date branches**: Must be current with master
- **Linear history**: No merge commits allowed (use squash/rebase)

#### Coverage Reporting

Coverage is automatically calculated and reported:

- **Coverage threshold**: 70% minimum line coverage
- **Per-file threshold**: 25% minimum per file
- **Branch coverage**: Tracked but not enforced
- **HTML reports**: Generated in `coverage/` directory
- **CI comments**: Coverage percentage posted on PRs

#### Automated Checks

The CI pipeline automatically:

1. **Installs system dependencies** (libpq-dev, libsqlite3-dev)
2. **Sets up Ruby** with bundler caching
3. **Installs gems** with `bundle install`
4. **Runs RuboCop** with zero-tolerance for violations
5. **Executes tests** with coverage reporting
6. **Builds the gem** and validates structure
7. **Reports results** via GitHub status checks

#### Debugging CI Failures

**Common CI failure scenarios**:

1. **RuboCop violations**:
   ```bash
   # Fix locally
   bundle exec rubocop -a
   git add . && git commit --amend --no-edit
   ```

2. **Test failures**:
   ```bash
   # Run specific test
   bundle exec ruby test/test_failing_file.rb

   # Run with verbose output
   bundle exec rake test TESTOPTS="-v"
   ```

3. **Coverage drops**:
   ```bash
   # Check coverage locally
   COVERAGE=true bundle exec rake test
   open coverage/index.html  # View detailed report
   ```

4. **Gem build failures**:
   ```bash
   # Test gem build
   gem build jdpi_client.gemspec
   gem spec jdpi_client-*.gem --ruby
   ```

#### Performance Optimization

CI runs are optimized for speed:

- **Bundler caching**: Dependencies cached between runs
- **Parallel execution**: Multiple Ruby versions tested simultaneously
- **Minimal system setup**: Only installs required dependencies
- **Efficient test structure**: Fast unit tests with mocked external calls

#### Contributing Workflow

For contributors, the recommended workflow is:

1. **Fork and clone** the repository
2. **Create a feature branch** (`git checkout -b feature/your-feature`)
3. **Make changes** following code style guidelines
4. **Run local CI checks** (`bundle exec rake ci`)
5. **Commit changes** (git hooks clean commit messages)
6. **Push and create PR** - CI runs automatically
7. **Address CI feedback** if any checks fail
8. **Merge after approval** and passing CI

#### Security Scanning

The CI pipeline includes security checks:

- **Bundler audit**: Scans for known vulnerabilities in dependencies
- **Code analysis**: Static analysis for potential security issues
- **Dependency updates**: Dependabot creates PRs for security updates

**Running security checks locally**:
```bash
# Install bundler-audit
gem install bundler-audit

# Check for vulnerabilities
bundle audit check --update

# Update vulnerable dependencies
bundle update
```

#### Release Process

When ready to release (maintainers only):

1. **Update version** in `jdpi_client.gemspec`
2. **Update CHANGELOG.md** with release notes
3. **Create release PR** with version bump
4. **Merge after CI passes** and approval
5. **Tag release** (`git tag v0.2.0 && git push --tags`)
6. **Publish gem** (when RubyGems integration is ready)

#### Monitoring CI Health

CI pipeline health is monitored through:

- **GitHub Actions dashboard**: View recent runs and success rates
- **Branch protection status**: Ensures quality gates are maintained
- **Coverage trends**: Track coverage changes over time
- **Performance metrics**: Monitor CI execution time and resource usage

#### Coverage Features

- Current coverage: **75.65%** (minimum threshold enforced at 70%)
- Per-file minimum: **25%**
- Branch coverage: **53.07%**
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

## 🔧 Troubleshooting

This section covers common issues and their solutions. For more detailed troubleshooting, see the [complete troubleshooting guide](docs/15-Troubleshooting.md).

### Installation Issues

#### Problem: "command not found: bundle"
**Solution**: Install Bundler:
```bash
gem install bundler
```

#### Problem: "libpq-dev not found" during bundle install
**Solution**: Install system dependencies:
```bash
# Ubuntu/Debian
sudo apt-get install -y libpq-dev libsqlite3-dev

# macOS
brew install postgresql sqlite3
```

#### Problem: Ruby version errors
**Solution**: Ensure Ruby 3.0+ is installed:
```bash
ruby --version  # Should show 3.0+
rbenv install 3.2.0  # If using rbenv
rbenv global 3.2.0
```

### Configuration Issues

#### Problem: "JDPI_CLIENT_HOST is missing" error
**Solution**: Set required environment variables:
```bash
export JDPI_CLIENT_HOST=api.yourbank.homl.jdpi.pstijd
export JDPI_CLIENT_ID=your_client_id
export JDPI_CLIENT_SECRET=your_client_secret
```

#### Problem: Environment auto-detection not working
**Solution**: Check hostname patterns:
```ruby
# Production hostnames should contain "prod" or "production"
config.jdpi_client_host = "api.bank.prod.jdpi.pstijd"  # → HTTPS

# Other hostnames are treated as homolog
config.jdpi_client_host = "api.bank.homl.jdpi.pstijd"  # → HTTP
```

#### Problem: SSL certificate verification errors
**Solution**:
1. Check network connectivity
2. Verify firewall settings
3. For development/testing only, you can disable SSL verification:
```ruby
# ⚠️  DEVELOPMENT/TESTING ONLY - NEVER in production!
config.verify_ssl = false  # If this option exists
```

### Authentication Issues

#### Problem: "Authentication failed" or 401 errors
**Solution**: Verify credentials and configuration:

1. **Check credentials**:
```ruby
# Test configuration
puts "Host: #{JDPIClient.config.jdpi_client_host}"
puts "Client ID: #{JDPIClient.config.oauth_client_id}"
puts "Secret set: #{!JDPIClient.config.oauth_secret.nil?}"
```

2. **Test authentication directly**:
```ruby
auth_client = JDPIClient::Auth::Client.new
begin
  token = auth_client.token!
  puts "✅ Authentication successful"
  puts "Token expires: #{auth_client.token_info[:expires_at]}"
rescue => e
  puts "❌ Authentication failed: #{e.message}"
end
```

3. **Check token storage**:
```ruby
# Clear cached tokens to force refresh
auth_client.refresh!
```

#### Problem: Token refresh failures
**Solution**:
- Verify credentials haven't expired
- Check network connectivity to JDPI
- Clear token storage and retry
- Contact JDPI support if issue persists

### API Request Issues

#### Problem: Rate limiting errors (429)
**Solution**: Implement proper rate limiting:
```ruby
begin
  response = spi_client.create_order!(payment_data)
rescue JDPIClient::Errors::RateLimited => e
  sleep(60)  # Wait for rate limit reset
  retry
end
```

#### Problem: Request validation errors (400)
**Solution**: Check request format:
```ruby
# Enable debug logging to see request details
JDPIClient.config.logger.level = Logger::DEBUG

# Common validation issues:
payment_data = {
  valor: 1050,                    # Amount in centavos (required)
  chave: "user@bank.com",         # Valid PIX key (required)
  dt_hr_requisicao_psp: Time.now.utc.iso8601,  # ISO8601 format (required)
  idempotency_key: SecureRandom.uuid            # Unique key (recommended)
}
```

#### Problem: Connection timeouts
**Solution**: Adjust timeout settings:
```ruby
JDPIClient.configure do |config|
  config.timeout = 15        # Increase request timeout
  config.open_timeout = 5    # Increase connection timeout
end
```

### Storage Backend Issues

#### Problem: Redis connection errors
**Solution**: Verify Redis configuration:
```bash
# Test Redis connectivity
redis-cli -u $REDIS_URL ping
```

```ruby
# Test Redis from Ruby
require 'redis'
redis = Redis.new(url: ENV['REDIS_URL'])
redis.ping  # Should return "PONG"
```

#### Problem: Database connection errors
**Solution**: Verify database setup:
```ruby
# Test database connectivity
require 'active_record'
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
ActiveRecord::Base.connection.execute("SELECT 1")
```

#### Problem: DynamoDB access errors
**Solution**: Verify AWS configuration:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Test DynamoDB access
aws dynamodb list-tables --region us-east-1
```

### Performance Issues

#### Problem: Slow response times
**Solution**:
1. Check network latency to JDPI endpoints
2. Enable connection pooling for multi-threaded apps
3. Monitor token caching effectiveness
4. Verify rate limiting isn't being triggered

#### Problem: High memory usage
**Solution**:
1. Ensure proper connection cleanup
2. Monitor token storage size
3. Use connection pooling instead of creating new clients
4. Review application architecture for memory leaks

### Development & Testing Issues

#### Problem: Tests failing with authentication errors
**Solution**: Use test stubs and mocks:
```ruby
# In test_helper.rb or spec_helper.rb
require 'webmock/minitest'  # or webmock/rspec

# Stub OAuth requests
stub_request(:post, %r{.*/auth/jdpi/connect/token})
  .to_return(
    status: 200,
    body: {
      access_token: "test_token",
      token_type: "Bearer",
      expires_in: 3600
    }.to_json,
    headers: { "Content-Type" => "application/json" }
  )
```

#### Problem: Coverage tests failing
**Solution**: Run tests with coverage enabled:
```bash
COVERAGE=true bundle exec rake test
```

#### Problem: RuboCop style errors
**Solution**: Auto-fix style issues:
```bash
bundle exec rubocop -a  # Auto-fix issues
bundle exec rubocop     # Check remaining issues
```

### Debugging Tips

#### Enable detailed logging:
```ruby
JDPIClient.configure do |config|
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::DEBUG
end
```

#### Inspect configuration:
```ruby
config = JDPIClient.config
puts "Environment: #{config.environment}"
puts "Base URL: #{config.base_url}"
puts "Timeout: #{config.timeout}s"
puts "Token storage: #{config.token_storage_adapter}"
```

#### Monitor token usage:
```ruby
auth_client = JDPIClient::Auth::Client.new
info = auth_client.token_info

puts "Token cached: #{info[:cached]}"
puts "Storage type: #{info[:storage_type]}"
puts "Expires at: #{info[:expires_at]}"
puts "Time until expiry: #{info[:expires_at] - Time.now} seconds" if info[:expires_at]
```

### Getting Help

If you're still experiencing issues:

1. **Check the logs** for detailed error messages
2. **Review the FAQ section** for common questions
3. **Search existing issues** on GitHub
4. **Create a minimal reproduction case**
5. **Open a GitHub issue** with:
   - Ruby version
   - Gem version
   - Configuration (sanitized)
   - Full error message and stack trace
   - Steps to reproduce

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
   Badge: `[![codecov](https://codecov.io/gh/agramms/jdpi-client/branch/main/graph/badge.svg)](https://codecov.io/gh/agramms/jdpi-client)`

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
- **Coverage**: Shows current 75.65% test coverage
- **Ruby Support**: Indicates Ruby 3.0+ compatibility
- **License**: MIT license badge
- **Code Style**: RuboCop compliance

## ❓ Frequently Asked Questions (FAQ)

### General Questions

**Q: What is JDPI and how does it relate to PIX?**
A: JDPI (Java Development Platform Integration) is the platform that facilitates PIX payments in Brazil. PIX is the instant payment system created by the Central Bank of Brazil. This gem provides a Ruby client to interact with JDPI services for PIX operations.

**Q: Do I need to be a bank to use this gem?**
A: Not necessarily. You need to be a PIX participant, which includes banks, payment institutions, and other authorized financial entities. You must obtain credentials from the Central Bank of Brazil.

**Q: Is this gem production-ready?**
A: Yes, the gem is designed for production use with comprehensive error handling, token management, rate limiting, and security features. It has 75.65% test coverage and supports Ruby 3.0+.

### Installation & Setup

**Q: Why do I get "gem not found" when trying to install?**
A: This gem is currently available from source. Use the Git installation method shown in the Installation section. Publishing to RubyGems is planned for future releases.

**Q: What Ruby versions are supported?**
A: Ruby 3.0 and higher are supported. The gem is tested on Ruby 3.0, 3.1, 3.2, 3.3, and 3.4.

**Q: Do I need Rails to use this gem?**
A: No, this gem has no Rails dependency and works with any Ruby application (Sinatra, plain Ruby scripts, etc.).

### Configuration

**Q: How do I know if my configuration is correct?**
A: Use the verification script from the Quick Setup Checklist section. It will test your configuration and authentication.

**Q: What's the difference between production and homolog environments?**
A: The gem auto-detects environments based on hostname:
- Hostnames containing "prod" or "production" use HTTPS and production settings
- All other hostnames use HTTP and are treated as homolog/testing environments

**Q: Should I enable token encryption?**
A: Yes, for production environments. Token encryption protects sensitive OAuth tokens when stored in Redis, databases, or other storage backends.

### Authentication & Tokens

**Q: How often do tokens expire?**
A: OAuth tokens typically expire after 1 hour. The gem automatically handles token refresh, so you don't need to manage this manually.

**Q: Can I share tokens between application instances?**
A: Yes, use Redis, Database, or DynamoDB token storage adapters for sharing tokens across multiple application instances or servers.

**Q: Why am I getting authentication errors?**
A: Common causes:
1. Invalid client credentials
2. Incorrect hostname/environment
3. Network connectivity issues
4. Expired credentials (contact JDPI support)

### PIX Operations

**Q: What's the difference between SPI OP and SPI OD?**
A: - **SPI OP**: Outbound payments (initiating PIX payments)
- **SPI OD**: Inbound operations (refunds, disputes, queries)

**Q: How do I handle PIX key validation?**
A: Use the DICT services to validate PIX keys before creating payments:
```ruby
dict_client = JDPIClient::DICT::Keys.new
key_info = dict_client.consult_key("user@bank.com")
```

**Q: What is idempotency and why is it important?**
A: Idempotency ensures that duplicate requests don't create multiple payments. Always provide a unique `idempotency_key` for payment operations:
```ruby
response = spi_client.create_order!(
  # ... payment data ...
  idempotency_key: SecureRandom.uuid
)
```

### Error Handling

**Q: How do I handle rate limiting?**
A: The gem provides `JDPIClient::Errors::RateLimited` exceptions. Implement exponential backoff and monitor rate limit headers (see Performance section).

**Q: What should I do when payments fail?**
A: Always implement proper error handling for different scenarios:
- Validation errors (400): Fix the request data
- Authentication errors (401): Check credentials/tokens
- Rate limiting (429): Implement backoff/retry logic
- Server errors (5xx): Log and retry with exponential backoff

**Q: How do I debug API calls?**
A: Enable debug logging:
```ruby
config.logger = Logger.new($stdout)
config.logger.level = Logger::DEBUG
```

### Performance & Scaling

**Q: How many requests per second can I make?**
A: JDPI has rate limits (typically 100 requests/minute for PIX payments). See the Performance & Rate Limiting section for details and optimization strategies.

**Q: Can this gem handle high-volume applications?**
A: Yes, with proper configuration:
- Use connection pooling for multi-threaded applications
- Implement distributed rate limiting with Redis
- Use appropriate token storage backends
- Monitor performance metrics

**Q: Should I use connection pooling?**
A: For multi-threaded applications or high-volume scenarios, yes. Use the `connection_pool` gem as shown in the Performance section.

### Security

**Q: How should I store credentials securely?**
A: - Use environment variables, never hard-code credentials
- Enable token encryption in production
- Use dedicated secret management services
- Rotate credentials regularly

**Q: What should I log and what shouldn't I log?**
A: **Log**: Request metadata, response status, timing, error messages
**Never log**: OAuth tokens, client secrets, sensitive payment data, PIX keys

**Q: Is it safe to use in production?**
A: Yes, when following security best practices:
- Use HTTPS in production
- Enable token encryption
- Implement proper error handling
- Monitor for security events
- Follow the Security Considerations section

### Troubleshooting

**Q: Tests are failing with authentication errors**
A: Ensure your test environment uses mock/stub HTTP requests. The gem includes comprehensive test helpers for this purpose.

**Q: I'm getting SSL certificate errors**
A: This usually indicates:
1. Network connectivity issues
2. Firewall blocking HTTPS traffic
3. Invalid/expired certificates (rare with JDPI)

**Q: Token storage isn't working**
A: Verify:
1. Storage backend is properly configured and accessible
2. Required gems are installed (redis, pg, aws-sdk-dynamodb)
3. Network connectivity to storage services
4. Proper credentials/permissions

**Q: Performance is slower than expected**
A: Check:
1. Network latency to JDPI endpoints
2. Token caching is working (should see cached token reuse)
3. Connection pooling configuration
4. Rate limiting isn't being triggered
5. Database/Redis performance if using those storage backends

### Migration & Updates

**Q: How do I upgrade to a new version?**
A: Update the gem reference in your Gemfile and run `bundle update jdpi_client`. Check the CHANGELOG for breaking changes.

**Q: Can I migrate from another PIX client?**
A: Yes, but you'll need to:
1. Update configuration format
2. Adjust API call patterns
3. Update error handling
4. Test thoroughly in homolog environment

**Q: How do I contribute to this project?**
A: See the Contributing section for guidelines on submitting issues, feature requests, and pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Check the [troubleshooting guide](docs/15-Troubleshooting.md)
- Review existing [documentation](docs/)
- Open an issue on GitHub
