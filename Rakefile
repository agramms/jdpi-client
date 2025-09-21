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

# Test task with coverage (Ruby 3.0+)
desc "Run tests with coverage (Ruby 3.0+)"
task :test_coverage do
  if RUBY_VERSION >= "3.0.0"
    puts "🧪 Running tests with coverage for Ruby #{RUBY_VERSION}"
    ENV["COVERAGE"] = "true"
    Rake::Task[:test].invoke
  else
    puts "⚠️  Coverage requires Ruby 3.0+, current: #{RUBY_VERSION}"
    puts "   Running tests without coverage..."
    Rake::Task[:test].invoke
  end
end

# RuboCop linting
RuboCop::RakeTask.new

# Coverage report task
desc "Generate coverage report (Ruby 3.0+)"
task :coverage do
  if RUBY_VERSION >= "3.0.0"
    Rake::Task[:test_coverage].invoke
    puts "\n📊 Coverage report generated in coverage/index.html"
  else
    puts "⚠️  Coverage requires Ruby 3.0+, current: #{RUBY_VERSION}"
  end
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
task :install => :build do
  gem_file = Dir["jdpi_client-*.gem"].last
  system("gem install #{gem_file} --local")
end

# Full test suite with coverage and linting
desc "Run full test suite (tests + coverage + linting)"
task :ci do
  if RUBY_VERSION >= "3.0.0"
    Rake::Task[:test_coverage].invoke
  else
    Rake::Task[:test].invoke
  end
  Rake::Task[:rubocop].invoke
  puts "\n✅ All checks completed successfully!"
end

# Default task
task default: [:test, :rubocop]