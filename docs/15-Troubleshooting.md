# Troubleshooting Guide

This guide helps diagnose and resolve common issues when using the jdpi-client gem.

## 🔍 Quick Diagnostics

### Check Configuration
```ruby
# Verify current configuration
config = JDPIClient.config
puts "Host: #{config.jdpi_client_host}"
puts "Base URL: #{config.base_url}"
puts "Environment: #{config.environment}"
puts "Production?: #{config.production?}"
puts "Timeout: #{config.timeout}s"
```

### Test Connectivity
```ruby
# Basic connectivity test
require 'net/http'
uri = URI(JDPIClient.config.base_url)
response = Net::HTTP.get_response(uri)
puts "Status: #{response.code}"
```

## 🚨 Common Error Scenarios

### 1. Authentication Errors (401 Unauthorized)

**Symptoms:**
- `JDPIClient::Errors::Unauthorized: Cannot obtain token`
- HTTP 401 responses

**Causes & Solutions:**

```ruby
# Check credentials
puts "Client ID: #{JDPIClient.config.oauth_client_id}"
puts "Secret set: #{!JDPIClient.config.oauth_secret.nil?}"

# Test token request manually
auth_client = JDPIClient::Auth::Client.new
begin
  token = auth_client.token!
  puts "Token obtained: #{token[0..20]}..."
rescue => e
  puts "Auth failed: #{e.message}"
end
```

**Common fixes:**
- Verify `JDPI_CLIENT_ID` and `JDPI_CLIENT_SECRET` environment variables
- Check if credentials are valid for the target environment
- Ensure client is registered in the JDPI system

### 2. Network/Timeout Errors

**Symptoms:**
- `Faraday::TimeoutError`
- `Faraday::ConnectionFailed`
- Slow responses

**Debugging:**
```ruby
# Increase timeouts temporarily
JDPIClient.configure do |c|
  c.timeout = 30
  c.open_timeout = 10
  c.logger = Logger.new($stdout, level: Logger::DEBUG)
end

# Test with curl
system("curl -v -m 10 #{JDPIClient.config.base_url}/health")
```

**Solutions:**
- Check network connectivity to JDPI endpoints
- Adjust timeout values based on network conditions
- Verify firewall/proxy settings
- Check if using correct environment URLs

### 3. Environment Detection Issues

**Symptoms:**
- Wrong protocol (HTTP vs HTTPS)
- Incorrect environment detection

**Debug environment detection:**
```ruby
hosts_to_test = [
  "api.mybank.homl.jdpi.pstijd",
  "api.mybank.prod.jdpi.pstijd",
  "api.mybank.production.jdpi.pstijd",
  "localhost"
]

hosts_to_test.each do |host|
  config = JDPIClient::Config.new
  config.jdpi_client_host = host
  puts "#{host} -> #{config.base_url} (#{config.environment})"
end
```

**Expected output:**
```
api.mybank.homl.jdpi.pstijd -> http://api.mybank.homl.jdpi.pstijd (homl)
api.mybank.prod.jdpi.pstijd -> https://api.mybank.prod.jdpi.pstijd (prod)
api.mybank.production.jdpi.pstijd -> https://api.mybank.production.jdpi.pstijd (prod)
localhost -> http://localhost (homl)
```

### 4. SSL/TLS Certificate Issues (Production)

**Symptoms:**
- `OpenSSL::SSL::SSLError`
- Certificate verification failures

**Debug SSL:**
```bash
# Check certificate
openssl s_client -connect your-prod-host:443 -servername your-prod-host

# Test with curl
curl -vvv https://your-prod-host/auth/jdpi/connect/token
```

**Solutions:**
- Ensure system has up-to-date CA certificates
- Check if using correct production hostname
- Verify certificate chain is complete

### 5. Rate Limiting (429 Too Many Requests)

**Symptoms:**
- `JDPIClient::Errors::RateLimited`
- HTTP 429 responses

**Handling rate limits:**
```ruby
def make_request_with_backoff(max_retries: 3)
  retries = 0
  begin
    yield
  rescue JDPIClient::Errors::RateLimited => e
    retries += 1
    if retries <= max_retries
      sleep_time = 2 ** retries # Exponential backoff
      puts "Rate limited, waiting #{sleep_time}s before retry #{retries}/#{max_retries}"
      sleep(sleep_time)
      retry
    else
      raise e
    end
  end
end

# Usage
make_request_with_backoff do
  spi_client.create_order!(payment_data)
end
```

### 6. JSON Parsing Errors

**Symptoms:**
- `MultiJson::ParseError`
- Unexpected response format

**Debug response format:**
```ruby
# Enable detailed logging to see raw responses
JDPIClient.configure do |c|
  c.logger = Logger.new($stdout, level: Logger::DEBUG)
end

# Check response manually
http = JDPIClient::HTTP.new(
  base: JDPIClient.config.base_url,
  token_provider: proc { "test_token" },
  logger: Logger.new($stdout)
)

begin
  response = http.get("/some/endpoint")
rescue => e
  puts "Error: #{e.message}"
  puts "Response body: #{e.response&.body}" if e.respond_to?(:response)
end
```

## 🛠️ Development Issues

### 1. Test Failures

**Mock-related failures:**
```ruby
# Ensure mocks are properly setup
def test_with_proper_mocking
  mock_client = Minitest::Mock.new
  expected_response = { "status" => "success" }

  mock_client.expect(:create_order!, expected_response, [Hash])

  JDPIClient::SPI::OP.stub(:new, mock_client) do
    # Your test code
    result = service.execute!
    assert result
  end

  mock_client.verify # This will fail if expectations aren't met
end
```

**Test environment isolation:**
```ruby
# In test_helper.rb, ensure clean state
class Minitest::Test
  def setup
    # Reset configuration for each test
    JDPIClient.instance_variable_set(:@config, nil)
    JDPIClient.configure do |c|
      c.jdpi_client_host = "test.homl.jdpi.pstijd"
      c.oauth_client_id = "test_client"
      c.oauth_secret = "test_secret"
    end
  end
end
```

### 2. Dependency Conflicts

**Bundler issues:**
```bash
# Check for conflicts
bundle check
bundle outdated

# Clean install
rm -rf .bundle vendor/bundle Gemfile.lock
bundle install

# Update specific gems
bundle update faraday
```

**Version compatibility:**
```ruby
# Check current versions
puts "Faraday: #{Faraday::VERSION}"
puts "Ruby: #{RUBY_VERSION}"
puts "MultiJson: #{MultiJson::VERSION if defined?(MultiJson::VERSION)}"
```

### 3. Memory/Performance Issues

**Monitor memory usage:**
```ruby
require 'objspace'

# Before operations
before = ObjectSpace.count_objects

# Your operations here
1000.times do
  JDPIClient::Auth::Client.new.token!
end

# After operations
after = ObjectSpace.count_objects
puts "Objects created: #{after[:TOTAL] - before[:TOTAL]}"
```

**Profile performance:**
```ruby
require 'benchmark'

result = Benchmark.measure do
  # Your code here
end

puts "Time: #{result.real}s"
```

## 📊 Debugging Tools

### 1. Enable Detailed Logging
```ruby
# Maximum verbosity
JDPIClient.configure do |c|
  c.logger = Logger.new($stdout, level: Logger::DEBUG)
end

# Custom logger with request/response details
class DetailedLogger < Logger
  def info(message)
    super("[#{Time.now}] #{message}")
  end
end
```

### 2. HTTP Request Inspector
```ruby
# Add to HTTP client for debugging
class DebugHTTP < JDPIClient::HTTP
  private

  def request(method, path, **options)
    puts ">>> #{method.upcase} #{@base}#{path}"
    puts ">>> Headers: #{default_headers.merge(options[:headers] || {})}"
    puts ">>> Body: #{options[:body]}" if options[:body]

    result = super

    puts "<<< Response: #{result}"
    result
  rescue => e
    puts "<<< Error: #{e.class}: #{e.message}"
    raise
  end
end
```

### 3. Network Traffic Analysis
```bash
# Monitor HTTP traffic (macOS)
sudo tcpdump -i any -A -s 0 'port 80 or port 443'

# Use Charles Proxy or similar tools for detailed inspection
```

## 🔧 Configuration Validation

### Environment-specific Validation
```ruby
class ConfigValidator
  def self.validate!
    config = JDPIClient.config

    errors = []
    errors << "Missing oauth_client_id" if config.oauth_client_id.nil?
    errors << "Missing oauth_secret" if config.oauth_secret.nil?
    errors << "Invalid timeout" if config.timeout <= 0

    # Environment-specific checks
    if config.production?
      errors << "Production must use HTTPS" unless config.base_url.start_with?('https://')
      errors << "Production credentials too short" if config.oauth_secret&.length < 20
    end

    raise "Configuration errors: #{errors.join(', ')}" if errors.any?

    puts "✅ Configuration valid"
  end
end

# Run validation
ConfigValidator.validate!
```

## 📞 Getting Help

1. **Check logs** with debug level enabled
2. **Review test cases** for similar scenarios
3. **Verify configuration** matches environment
4. **Test individual components** in isolation
5. **Check JDPI service status** and documentation
6. **Review network connectivity** and firewall settings

Remember: Most issues are configuration-related. Start with basic connectivity and authentication before debugging complex business logic.