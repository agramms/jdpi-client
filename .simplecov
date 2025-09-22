# frozen_string_literal: true

# SimpleCov configuration for jdpi-client (Ruby 3.0+ gem)
SimpleCov.configure do
  # Coverage output directory
  coverage_dir "coverage"

  # Files to exclude from coverage
  add_filter do |source_file|
    # Exclude test files
    source_file.filename.include?("/test/") ||
      # Exclude vendor and bundle directories
      source_file.filename.include?("/vendor/") ||
      source_file.filename.include?("/.bundle/") ||
      # Exclude generated files
      source_file.filename.include?("/tmp/") ||
      # Exclude version file (simple constant)
      source_file.filename.end_with?("/version.rb")
  end

  # Group files by functionality
  add_group "Configuration", ["lib/jdpi_client/config.rb"]
  add_group "HTTP Client", ["lib/jdpi_client/http.rb"]
  add_group "Error Handling", ["lib/jdpi_client/errors.rb"]
  add_group "Authentication", ["lib/jdpi_client/auth"]
  add_group "SPI Services", ["lib/jdpi_client/spi"]
  add_group "DICT Services", ["lib/jdpi_client/dict"]
  add_group "QR Services", ["lib/jdpi_client/qr"]
  add_group "Core", ["lib/jdpi_client.rb"]

  # Set coverage thresholds (can be increased over time)
  minimum_coverage 70
  minimum_coverage_by_file 30
  # refuse_coverage_drop  # Disabled to allow threshold adjustments

  # Configure output formats
  if ENV["CI"] == "true"
    # CI environment - use simple formatter
    formatter SimpleCov::Formatter::SimpleFormatter
  else
    # Local development - use HTML formatter for detailed view
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::HTMLFormatter,
                                                         SimpleCov::Formatter::SimpleFormatter
                                                       ])
  end

  # Track all Ruby files in lib directory
  track_files "lib/**/*.rb"

  # Enable branch coverage (Ruby 3.0+ supports this)
  enable_coverage :branch

  # Merge results from multiple test runs
  merge_timeout 3600

  # Project name for reports
  project_name "JDPI Client"

  puts "📊 SimpleCov configured for Ruby #{RUBY_VERSION}"
  puts "   Coverage threshold: #{minimum_coverage}%"
  puts "   Output directory: #{coverage_dir}"
end
