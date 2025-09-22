# frozen_string_literal: true

require "rake/testtask"
require "rubocop/rake_task"

# Standard test task
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb", "test/**/test_*.rb"]
  t.verbose = true
end

# Test task with coverage
desc "Run tests with coverage"
task :test_coverage do
  puts "🧪 Running tests with coverage for Ruby #{RUBY_VERSION}"
  ENV["COVERAGE"] = "true"
  Rake::Task[:test].invoke
end

# Unit tests (fast, memory storage only)
desc "Run unit tests (fast, memory storage only)"
task :test_unit do
  puts "🚀 Running unit tests (memory storage only)"
  ENV["TEST_ADAPTER"] = "memory"
  ENV["SKIP_INTEGRATION"] = "true"
  Rake::Task[:test].invoke
end

# Integration tests (with real services)
desc "Run integration tests (with Redis, PostgreSQL, DynamoDB)"
task :test_integration do
  puts "🔗 Running integration tests with real services"
  ENV["TEST_ADAPTER"] = "all"
  ENV["RUN_INTEGRATION"] = "true"
  Rake::Task[:test].invoke
end

# Full test suite
desc "Run full test suite (unit + integration + coverage)"
task :test_full do
  puts "🎯 Running complete test suite"
  ENV["COVERAGE"] = "true"
  ENV["RUN_INTEGRATION"] = "true"
  Rake::Task[:test].invoke
end

# RuboCop linting
RuboCop::RakeTask.new

# Coverage report task
desc "Generate coverage report"
task :coverage do
  Rake::Task[:test_coverage].invoke
  puts "\n📊 Coverage report generated in coverage/index.html"
end

# Clean task
desc "Clean generated files"
task :clean do
  rm_rf "coverage"
  rm_rf "pkg"
  rm_rf "doc"
  rm_rf ".yardoc"
  puts "🧹 Cleaned generated files"
end

# Build gem
desc "Build gem"
task :build do
  system("gem build jdpi_client.gemspec")
end

# Install gem locally
desc "Install gem locally"
task install: :build do
  gem_file = Dir["jdpi_client-*.gem"].last
  system("gem install #{gem_file} --local")
end

# Service management tasks
namespace :services do
  desc "Set up test services (Redis, PostgreSQL, DynamoDB)"
  task :setup do
    puts "🔧 Setting up test services..."

    # Test Redis connection
    begin
      require "redis"
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      redis.ping
      puts "✅ Redis connection verified"
    rescue StandardError => e
      puts "❌ Redis setup failed: #{e.message}"
    end

    # Test PostgreSQL connection
    begin
      require "pg"
      conn = PG.connect(ENV.fetch("DATABASE_URL", "postgresql://jdpi_user:jdpi_password@localhost:5432/jdpi_test"))
      conn.exec("SELECT 1")
      conn.close
      puts "✅ PostgreSQL connection verified"
    rescue StandardError => e
      puts "❌ PostgreSQL setup failed: #{e.message}"
    end

    # Test DynamoDB connection
    begin
      require "aws-sdk-dynamodb"
      dynamodb = Aws::DynamoDB::Client.new(
        endpoint: ENV.fetch("DYNAMODB_ENDPOINT", "http://localhost:8000"),
        region: "us-east-1",
        access_key_id: "fakekey",
        secret_access_key: "fakesecret"
      )
      dynamodb.list_tables
      puts "✅ DynamoDB Local connection verified"
    rescue StandardError => e
      puts "❌ DynamoDB setup failed: #{e.message}"
    end

    puts "🚀 Service setup complete!"
  end

  desc "Reset all test data in services"
  task :reset do
    puts "🔄 Resetting test data..."

    # Clear Redis
    begin
      require "redis"
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      redis.flushdb
      puts "✅ Redis data cleared"
    rescue StandardError => e
      puts "❌ Redis reset failed: #{e.message}"
    end

    # Clear PostgreSQL test data
    begin
      require "pg"
      conn = PG.connect(ENV.fetch("DATABASE_URL", "postgresql://jdpi_user:jdpi_password@localhost:5432/jdpi_test"))
      conn.exec("DELETE FROM jdpi_client_tokens WHERE token_key LIKE 'test_%'")
      conn.close
      puts "✅ PostgreSQL test data cleared"
    rescue StandardError => e
      puts "❌ PostgreSQL reset failed: #{e.message}"
    end

    puts "🧹 Reset complete!"
  end

  desc "Check service health"
  task :health do
    puts "🔍 Checking service health..."

    services = [
      ["Redis", lambda {
        require "redis"
        Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping
      }],
      ["PostgreSQL", lambda {
        require "pg"
        conn = PG.connect(ENV.fetch("DATABASE_URL", "postgresql://jdpi_user:jdpi_password@localhost:5432/jdpi_test"))
        result = conn.exec("SELECT 1").values.first.first == "1"
        conn.close
        result
      }],
      ["DynamoDB", lambda {
        require "aws-sdk-dynamodb"
        Aws::DynamoDB::Client.new(
          endpoint: ENV.fetch("DYNAMODB_ENDPOINT", "http://localhost:8000"),
          region: "us-east-1",
          access_key_id: "fakekey",
          secret_access_key: "fakesecret"
        ).list_tables
        true
      }]
    ]

    services.each do |name, check|
      check.call
      puts "✅ #{name} is healthy"
    rescue StandardError => e
      puts "❌ #{name} is unhealthy: #{e.message}"
    end
  end
end

# Full test suite with coverage and linting
desc "Run full test suite (tests + coverage + linting)"
task :ci do
  Rake::Task[:test_coverage].invoke
  Rake::Task[:rubocop].invoke
  puts "\n✅ All checks completed successfully!"
end

# Default task
task default: %i[test rubocop]
