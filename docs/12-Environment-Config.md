
# Environment & Configuration Management

This document covers comprehensive environment configuration for the jdpi-client gem.

## 🌍 Automatic Environment Detection

The jdpi-client gem automatically detects environment and protocol from the hostname:

- **Production**: Hostnames containing "prod" or "production" → Uses HTTPS
- **Homolog**: Any other hostname → Uses HTTP

```ruby
# Examples of automatic detection
config.jdpi_client_host = "api.mybank.prod.jdpi.pstijd"        # → HTTPS, production
config.jdpi_client_host = "api.mybank.production.jdpi.pstijd"  # → HTTPS, production
config.jdpi_client_host = "api.mybank.homl.jdpi.pstijd"        # → HTTP, homolog
config.jdpi_client_host = "localhost"                          # → HTTP, homolog
```

## 📋 Required Environment Variables

### Core Configuration
```env
# Required - JDPI API hostname
JDPI_CLIENT_HOST=api.mybank.homl.jdpi.pstijd

# Required - OAuth2 credentials (provided by JDPI)
JDPI_CLIENT_ID=your_oauth_client_id
JDPI_CLIENT_SECRET=your_oauth_client_secret
```

### Optional Configuration
```env
# Timeouts (defaults shown)
JDPI_TIMEOUT=8
JDPI_OPEN_TIMEOUT=2

# Token encryption (recommended for production)
JDPI_TOKEN_ENCRYPTION_KEY=your_32_character_encryption_key_here

# Logging
JDPI_LOG_LEVEL=info

# Storage backend URLs
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgresql://user:pass@host:5432/db
```

## 🔧 Configuration Examples

### Development Environment
```ruby
# config/environments/development.rb
JDPIClient.configure do |config|
  config.jdpi_client_host = 'api.test.homl.jdpi.pstijd'
  config.oauth_client_id = ENV['JDPI_CLIENT_ID'] || 'dev_client'
  config.oauth_secret = ENV['JDPI_CLIENT_SECRET'] || 'dev_secret'
  config.timeout = 15  # Longer for debugging
  config.logger = Logger.new($stdout, level: Logger::DEBUG)
  config.token_storage_adapter = :memory
end
```

### Production Environment
```ruby
# config/environments/production.rb
JDPIClient.configure do |config|
  config.jdpi_client_host = ENV.fetch('JDPI_CLIENT_HOST')
  config.oauth_client_id = ENV.fetch('JDPI_CLIENT_ID')
  config.oauth_secret = ENV.fetch('JDPI_CLIENT_SECRET')
  config.timeout = 8
  config.logger = Rails.logger
  config.logger.level = Logger::WARN

  # Encrypted Redis storage for production
  config.token_storage_adapter = :redis
  config.token_storage_url = ENV.fetch('REDIS_URL')
  config.token_encryption_enabled = true
  config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
end
```

### Testing Environment
```ruby
# config/environments/test.rb
JDPIClient.configure do |config|
  config.jdpi_client_host = 'api.test.homl.jdpi.pstijd'
  config.oauth_client_id = 'test_client'
  config.oauth_secret = 'test_secret'
  config.token_storage_adapter = :memory
  config.logger = Logger.new('/dev/null')  # Silent in tests
end
```

## 🗄️ Storage Backend Configuration

### Memory Storage (Default)
```ruby
config.token_storage_adapter = :memory
# ✅ Fast and simple
# ❌ Not shared between processes
# 👍 Best for: Single-server apps, development
```

### Redis Storage
```ruby
config.token_storage_adapter = :redis
config.token_storage_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0'
config.token_storage_options = {
  timeout: 5,
  reconnect_attempts: 3
}
# ✅ Distributed, high performance
# 👍 Best for: Production clusters
```

### Database Storage
```ruby
config.token_storage_adapter = :database
config.token_storage_url = ENV['DATABASE_URL']
config.token_storage_options = {
  table_name: 'jdpi_client_tokens'
}
# ✅ Persistent, transactional
# 👍 Best for: Apps with existing database
```

### DynamoDB Storage
```ruby
config.token_storage_adapter = :dynamodb
config.token_storage_options = {
  table_name: 'jdpi-tokens',
  region: ENV['AWS_REGION'] || 'us-east-1'
}
# ✅ Serverless, auto-scaling
# 👍 Best for: AWS serverless applications
```

## 🔒 Security Configuration

### Token Encryption
```ruby
# Generate encryption key
encryption_key = SecureRandom.hex(32)  # 64-character hex string

# Enable encryption
config.token_encryption_enabled = true
config.token_encryption_key = encryption_key
```

### Environment-Specific Security
```ruby
# Production security settings
if Rails.env.production?
  config.token_encryption_enabled = true
  config.token_encryption_key = ENV.fetch('JDPI_TOKEN_ENCRYPTION_KEY')
  config.logger.level = Logger::WARN  # Minimal logging
else
  config.logger.level = Logger::DEBUG  # Detailed logging
end
```

## 📊 Current Configuration Summary

- **Ruby Support**: 3.0, 3.1, 3.2, 3.3, 3.4
- **Test Coverage**: 75.65% line coverage, 53.07% branch coverage
- **CI/CD**: GitHub Actions with multi-version testing
- **Storage Backends**: Memory, Redis, Database, DynamoDB
- **Security**: Token encryption, environment detection, secure defaults

For complete environment variable reference, see the main [README Environment Variables section](../README.md#environment-variables-reference).
