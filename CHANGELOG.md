# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2024-01-15

### Added
- **Enhanced README Documentation**: Comprehensive setup guides, troubleshooting, and API examples
- **Security Considerations**: Production security best practices and token encryption
- **Performance & Rate Limiting**: JDPI-specific optimization strategies
- **Environment Variables Reference**: Complete documentation of all configuration variables
- **FAQ Section**: 30+ questions covering common integration scenarios
- **API Reference**: Detailed request/response examples for all JDPI endpoints
- **CI/CD Documentation**: Complete GitHub Actions pipeline information
- **Prerequisites Section**: Ruby version requirements and system dependencies
- **Quick Setup Checklist**: Step-by-step guide for new users
- **Troubleshooting Guide**: Common issues and solutions with code examples

### Changed
- **Updated Test Metrics**: Reflects current 75.65% line coverage, 53.07% branch coverage
- **Ruby Version Support**: Updated to show Ruby 3.0-3.4 compatibility
- **Test Suite Information**: Updated to reflect 330 runs, 1869 assertions
- **Coverage Thresholds**: Adjusted to 70% line coverage, 25% per-file minimum
- **Badge Information**: Updated all README badges with current metrics

### Fixed
- **Installation Instructions**: Removed outdated local path references
- **Git Commit Message Cleanup**: Added hooks to remove Claude co-authorship automatically
- **AWS SDK Deprecation Warnings**: Suppressed Net::HTTPResponse warnings in CI
- **SimpleCov Configuration**: Aligned threshold settings across configuration files
- **GitHub Actions Permissions**: Fixed PR comment permissions for coverage reporting
- **Gem Validation**: Improved CI gem building and validation process

### Security
- **Token Encryption**: Enhanced documentation for production token security
- **Credential Management**: Best practices for environment variable security
- **Network Security**: HTTPS/TLS configuration guidelines
- **Logging Security**: Safe practices for production logging

### Documentation
- **Production Deployment**: Comprehensive production configuration examples
- **Development Workflow**: Complete contributor guidelines and CI information
- **Testing Framework**: Enhanced test setup and execution documentation
- **Error Handling**: Structured error handling patterns and examples

## [0.1.0] - 2024-01-01

### Added
- **Initial Release**: Complete JDPI client implementation
- **Authentication**: OAuth2 token management with automatic refresh
- **DICT Services**: PIX key management, claims, infractions, and MED operations
- **QR Code Generation**: PIX QR code creation and validation
- **SPI Operations**: Payment initiation (OP) and settlement queries (OD)
- **Participants Management**: JDPI participant information APIs
- **Multi-Backend Token Storage**: Support for Memory, Redis, Database, and DynamoDB
- **Token Encryption**: Secure token storage with configurable encryption
- **Environment Auto-Detection**: Automatic protocol and environment detection
- **Comprehensive Error Handling**: Structured exceptions for all API scenarios
- **Thread-Safe Design**: Concurrent request handling with proper locking
- **Retry Logic**: Built-in exponential backoff for failed requests
- **Test Coverage**: 75.65% test coverage with comprehensive test suite
- **Ruby 3.0+ Support**: Compatible with Ruby 3.0, 3.1, 3.2, 3.3, and 3.4
- **CI/CD Pipeline**: GitHub Actions workflow with multi-version testing
- **Documentation**: Complete API documentation and usage examples
