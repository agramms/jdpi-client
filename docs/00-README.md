# JDPI Integration Documentation

This directory contains comprehensive documentation for JDPI (Java Development Platform Integration) services, organized for Ruby developers using the jdpi-client gem.

**Last Updated**: January 2024 | **Version**: 0.2.0

## 📚 Documentation Structure

This documentation is organized into focused modules for different aspects of JDPI integration:

### Core Configuration
- **[12-Environment-Config.md](12-Environment-Config.md)** - Environment setup and configuration management
- **[14-Development-Workflow.md](14-Development-Workflow.md)** - Complete development workflow and CI/CD

### API Services
- **[01-Connectivity-and-Auth.md](01-Connectivity-and-Auth.md)** - Authentication and connectivity
- **[09-Payment-Settlement-SPI.md](09-Payment-Settlement-SPI.md)** - PIX payment operations (SPI OP/OD)
- **[04-DICT-Keys.md](04-DICT-Keys.md)** - PIX key management
- **[05-DICT-Portability-and-Claims.md](05-DICT-Portability-and-Claims.md)** - Key claims and transfers
- **[08-Payment-Initiation-QR.md](08-Payment-Initiation-QR.md)** - QR code generation
- **[11-Participants-Management.md](11-Participants-Management.md)** - Participant information

### Implementation Guides
- **[13-Claude-Examples.md](13-Claude-Examples.md)** - Practical Ruby code examples
- **[15-Troubleshooting.md](15-Troubleshooting.md)** - Common issues and solutions
- **[03-PIX-Rules-and-Terminology.md](03-PIX-Rules-and-Terminology.md)** - PIX system rules

## 🚀 Quick Start

The jdpi-client gem automatically handles environment detection and base URL construction:

```ruby
# Simple configuration - environment auto-detected
JDPIClient.configure do |config|
  config.jdpi_client_host = "api.mybank.homl.jdpi.pstijd"  # HTTP, homolog
  config.jdpi_client_host = "api.mybank.prod.jdpi.pstijd" # HTTPS, production
  config.oauth_client_id = ENV['JDPI_CLIENT_ID']
  config.oauth_secret = ENV['JDPI_CLIENT_SECRET']
end
```

## 🌍 Environment & URL Construction

**Environment Detection**:
- Contains "prod" or "production" → HTTPS + production settings
- Any other hostname → HTTP + homolog settings

**Base URL Template**: `{protocol}://{hostname}`
- **Production**: `https://api.bank.prod.jdpi.pstijd`
- **Homolog**: `http://api.bank.homl.jdpi.pstijd`

**Service Endpoints**:
- **Auth**: `/auth/jdpi/connect/token`
- **SPI OP/OD**: `/spi/api/v1/op`, `/spi/api/v1/od`
- **DICT**: `/dict/api/v2/key`, `/dict/api/v2/claims`
- **QR Code**: `/qr/api/v1/qr`
- **Participants**: `/participants/api/v1/participants`

## 📊 Current Status

- **Ruby Support**: 3.0, 3.1, 3.2, 3.3, 3.4
- **Test Coverage**: 75.65% line coverage, 53.07% branch coverage
- **Test Suite**: 330 runs, 1869 assertions
- **CI/CD**: GitHub Actions with multi-version matrix testing

## 🔧 Integration Features

- **Automatic OAuth2 Management**: Token caching and refresh
- **Multi-Backend Storage**: Memory, Redis, Database, DynamoDB
- **Environment Detection**: Automatic protocol and environment selection
- **Error Handling**: Structured exceptions with retry logic
- **Security**: Token encryption and secure credential management
- **Testing**: Comprehensive mocking and test helpers

For complete setup and usage instructions, see the main [README](../README.md).
