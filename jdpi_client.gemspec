# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "jdpi_client"
  spec.version       = "0.1.0"
  spec.authors       = ["JDPI Development Team"]
  spec.email         = ["dev@jdpi.com"]
  spec.summary       = "Ruby client for JDPI microservices (DICT, QR, SPI OP/OD, Auth, Participants)"
  spec.description   = "A lightweight, Faraday-based client for JDPI with idempotency, retry, and structured errors."
  spec.license       = "MIT"
  spec.files         = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md", "docs/**/*"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.0.0"

  # Core dependencies
  spec.add_dependency "base64", ">= 0.1.0"
  spec.add_dependency "faraday", ">= 2.9", "< 3.0"
  spec.add_dependency "faraday-retry", ">= 2.2", "< 3.0"
  spec.add_dependency "multi_json", ">= 1.15", "< 2.0"

  # Development dependencies
  spec.add_development_dependency "minitest", ">= 5.0"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rubocop", ">= 1.0"
  spec.add_development_dependency "simplecov", ">= 0.22"

  # Mocking dependencies for tests
  spec.add_development_dependency "mock_redis", ">= 0.17"
  spec.add_development_dependency "webmock", ">= 3.0"

  # Optional dependencies for token storage backends (dev/test only)
  spec.add_development_dependency "activerecord", ">= 6.0"
  spec.add_development_dependency "aws-sdk-dynamodb", "~> 1.150"
  spec.add_development_dependency "aws-sdk-core", "~> 3.190"
  spec.add_development_dependency "pg", ">= 1.0"
  spec.add_development_dependency "redis", ">= 4.0"
  spec.add_development_dependency "sqlite3", ">= 1.4"

  # Optional dependencies for token storage backends
  # Note: These are optional and only required when using specific storage adapters
  spec.metadata["rubygems_mfa_required"] = "true"
end
