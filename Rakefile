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

# Full test suite with coverage and linting
desc "Run full test suite (tests + coverage + linting)"
task :ci do
  Rake::Task[:test_coverage].invoke
  Rake::Task[:rubocop].invoke
  puts "\n✅ All checks completed successfully!"
end

# Default task
task default: %i[test rubocop]
