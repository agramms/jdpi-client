# Development Workflow for Claude Code

This guide outlines the complete development workflow when working on the jdpi-client gem with Claude Code assistance.

## 🚀 Initial Setup

### 1. Clone and Setup
```bash
git clone <repository-url>
cd jdpi-client
bundle install
```

### 2. Environment Configuration
```bash
# Create .env file (not committed)
cat > .env << EOF
JDPI_CLIENT_HOST=api.mybank.homl.jdpi.pstijd
JDPI_CLIENT_ID=your_client_id
JDPI_CLIENT_SECRET=your_client_secret
EOF

# Load in development
# gem 'dotenv-rails' # Add to Gemfile if using Rails
```

### 3. Verify Setup
```bash
# Run tests to ensure everything works
bundle exec rake test

# Check linting
bundle exec rubocop

# Build gem to verify structure
gem build jdpi_client.gemspec
```

## 🧪 Test-Driven Development

### Test Structure
```
test/
├── test_helper.rb          # Common test setup
├── test_config.rb          # Configuration tests
├── test_auth_client.rb     # Authentication tests
├── services/               # Service-specific tests
│   ├── test_pix_payment_service.rb
│   └── test_qr_code_service.rb
└── integration/            # Integration tests
    └── test_end_to_end.rb
```

### Writing New Tests
```ruby
# test/test_new_feature.rb
require_relative "test_helper"

class TestNewFeature < Minitest::Test
  def setup
    # Setup test environment
    @config = JDPIClient::Config.new
    @config.jdpi_client_host = "test.homl.jdpi.pstijd"
  end

  def test_feature_behavior
    # Arrange - Set up test data
    # Act - Execute the feature
    # Assert - Verify results
  end

  def test_error_handling
    # Test error scenarios
  end
end
```

### Running Tests
```bash
# All tests
bundle exec rake test

# Specific test file
bundle exec ruby test/test_config.rb

# Specific test method
bundle exec ruby test/test_config.rb -n test_production_detection

# With verbose output
bundle exec rake test TESTOPTS="-v"

# Generate coverage report (Ruby 3.0+)
bundle exec rake test_coverage
# OR
COVERAGE=true bundle exec rake test

# View coverage report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

## 🔧 Development Commands

### Code Quality
```bash
# Lint check
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Check specific files
bundle exec rubocop lib/jdpi_client/config.rb

# Generate configuration
bundle exec rubocop --generate-config
```

### Documentation
```bash
# Generate YARD documentation
yard doc

# Serve documentation locally
yard server

# Check documentation coverage
yard stats --list-undoc
```

### Gem Management
```bash
# Build gem
gem build jdpi_client.gemspec

# Install locally
gem install jdpi_client-*.gem --local

# Uninstall
gem uninstall jdpi_client

# Push to RubyGems (when ready)
gem push jdpi_client-*.gem
```

## 🐛 Debugging Workflow

### 1. Enable Debug Logging
```ruby
JDPIClient.configure do |c|
  c.logger = Logger.new($stdout, level: Logger::DEBUG)
end
```

### 2. Test Individual Components
```ruby
# Test configuration
config = JDPIClient::Config.new
config.jdpi_client_host = "test.homl.jdpi.pstijd"
puts config.base_url
puts config.environment

# Test authentication
auth = JDPIClient::Auth::Client.new(config)
token = auth.token!
puts "Token: #{token}"

# Test HTTP client
http = JDPIClient::HTTP.new(
  base: config.base_url,
  token_provider: auth.to_proc,
  logger: config.logger
)
```

### 3. Mock External Services
```ruby
# In tests, mock HTTP responses
class TestWithMocks < Minitest::Test
  def setup
    @mock_response = {
      "access_token" => "test_token",
      "expires_in" => 3600
    }
  end

  def test_with_mock
    stub_request(:post, "http://test.homl.jdpi.pstijd/auth/jdpi/connect/token")
      .to_return(
        status: 200,
        body: JSON.generate(@mock_response),
        headers: { 'Content-Type' => 'application/json' }
      )

    # Your test code here
  end
end
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow
The gem includes a complete CI/CD pipeline that runs on:
- Push to main/master
- Pull requests
- Multiple Ruby versions (3.0-3.3)

### Local CI Simulation
```bash
# Simulate CI environment
RAILS_ENV=test bundle exec rake

# Test multiple Ruby versions (if using rbenv)
for version in 3.0.6 3.1.4 3.2.2 3.3.0; do
  rbenv local $version
  bundle install
  bundle exec rake test
done
```

### Pre-commit Hooks
```bash
# Install pre-commit hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Run linter
bundle exec rubocop

# Run tests
bundle exec rake test

echo "All checks passed!"
EOF

chmod +x .git/hooks/pre-commit
```

## 📦 Release Process

### Version Management
```ruby
# lib/jdpi_client/version.rb
module JDPIClient
  VERSION = "0.1.0"
end
```

### Release Steps
1. **Update version** in `lib/jdpi_client/version.rb`
2. **Update CHANGELOG.md** with new features/fixes
3. **Run full test suite**: `bundle exec rake`
4. **Build gem**: `gem build jdpi_client.gemspec`
5. **Test gem locally**: `gem install jdpi_client-*.gem --local`
6. **Commit changes**: `git commit -am "Release v0.1.0"`
7. **Tag release**: `git tag v0.1.0`
8. **Push**: `git push && git push --tags`

### Automated Release (if using GitHub Actions)
```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: [ 'v*' ]
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.2'
        bundler-cache: true
    - name: Build gem
      run: gem build jdpi_client.gemspec
    - name: Publish to RubyGems
      run: gem push jdpi_client-*.gem
      env:
        GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_AUTH_TOKEN }}
```

## 🚨 Troubleshooting Common Issues

### Authentication Failures
```bash
# Check token manually
ruby -e "
require './lib/jdpi_client'
JDPIClient.configure { |c| c.jdpi_client_host = 'your-host' }
puts JDPIClient::Auth::Client.new.token!
"
```

### Network Issues
```bash
# Test connectivity
curl -v http://your-host/auth/jdpi/connect/token

# Check SSL/TLS
openssl s_client -connect your-prod-host:443
```

### Dependency Conflicts
```bash
# Check bundle issues
bundle check
bundle update
bundle clean

# Reset bundle
rm -rf .bundle vendor/bundle Gemfile.lock
bundle install
```

This workflow ensures consistent, reliable development with Claude Code assistance.