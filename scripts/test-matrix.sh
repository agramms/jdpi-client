#!/bin/bash
set -e

# JDPI Client Matrix Testing Script
# This script runs the test suite across all supported Ruby versions

echo "🧪 Running JDPI Client test matrix across all Ruby versions..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Navigate to project root
cd "$(dirname "$0")/.."

# Ruby versions to test
RUBY_VERSIONS=("30" "31" "32" "33" "34")
FAILED_VERSIONS=()
PASSED_VERSIONS=()

print_status "Starting matrix test for Ruby versions: ${RUBY_VERSIONS[*]}"

# Ensure services are running
print_status "Starting required services..."
docker-compose up -d redis postgres dynamodb jdpi-mock

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Function to run tests for a specific Ruby version
run_tests_for_version() {
    local version=$1
    local service_name="ruby${version}"

    print_status "Testing Ruby 3.${version#3}..."

    # Build the container if needed
    print_status "Building Ruby ${version} container..."
    if ! docker-compose build ${service_name}; then
        print_error "Failed to build Ruby ${version} container"
        return 1
    fi

    # Run bundle install
    print_status "Installing dependencies for Ruby ${version}..."
    if ! docker-compose run --rm ${service_name} bundle install; then
        print_error "Failed to install dependencies for Ruby ${version}"
        return 1
    fi

    # Run the tests
    print_status "Running tests for Ruby ${version}..."
    if docker-compose run --rm ${service_name} bundle exec rake test; then
        print_success "✅ Ruby ${version} tests passed!"
        return 0
    else
        print_error "❌ Ruby ${version} tests failed!"
        return 1
    fi
}

# Run tests for each Ruby version
for version in "${RUBY_VERSIONS[@]}"; do
    echo ""
    print_status "========================================"
    print_status "Testing Ruby 3.${version#3}"
    print_status "========================================"

    if run_tests_for_version $version; then
        PASSED_VERSIONS+=("3.${version#3}")
    else
        FAILED_VERSIONS+=("3.${version#3}")
    fi

    echo ""
done

# Cleanup
print_status "Cleaning up test containers..."
docker-compose down --volumes --remove-orphans

# Print summary
echo ""
print_status "========================================"
print_status "Matrix Test Summary"
print_status "========================================"

if [ ${#PASSED_VERSIONS[@]} -gt 0 ]; then
    print_success "✅ Passed versions: ${PASSED_VERSIONS[*]}"
fi

if [ ${#FAILED_VERSIONS[@]} -gt 0 ]; then
    print_error "❌ Failed versions: ${FAILED_VERSIONS[*]}"
fi

echo ""
print_status "Total versions tested: ${#RUBY_VERSIONS[@]}"
print_success "Passed: ${#PASSED_VERSIONS[@]}"
print_error "Failed: ${#FAILED_VERSIONS[@]}"

# Exit with appropriate code
if [ ${#FAILED_VERSIONS[@]} -eq 0 ]; then
    print_success "🎉 All Ruby versions passed the test suite!"
    exit 0
else
    print_error "💥 Some Ruby versions failed. Check the output above for details."
    exit 1
fi