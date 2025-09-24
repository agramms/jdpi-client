#!/bin/bash
set -e

# JDPI Client Development Environment Setup Script
# This script sets up the complete development environment with full service stack
#
# NOTE: This is for DEVELOPMENT only. Tests run cleanly in CI without any services.

echo "🚀 Setting up JDPI Client development environment..."
echo "   This includes Redis, PostgreSQL, DynamoDB Local, and JDPI Mock Server"
echo "   Tests will run cleanly in CI without any of these services"

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

# Check if we're running inside Docker
if [ -f /.dockerenv ]; then
    print_status "Running inside Docker development container"
    IN_DOCKER=true
else
    print_status "Running on host machine"
    IN_DOCKER=false
fi

# Environment detection
if [ "${DEV_CONTAINER}" = "true" ] || [ "${DEVELOPMENT_MODE}" = "true" ]; then
    print_status "Development container environment detected"
    print_status "Services will be configured for rich development experience"
else
    print_warning "Not in development container - some features may not be available"
fi

# Navigate to workspace directory
cd /workspace 2>/dev/null || cd "$(dirname "$0")/.."

print_status "Working directory: $(pwd)"

# Install Ruby dependencies
print_status "Installing Ruby dependencies..."
if command -v bundle >/dev/null 2>&1; then
    bundle install
    print_success "Bundle install completed"
else
    print_error "Bundle command not found!"
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p coverage
mkdir -p logs
mkdir -p tmp
print_success "Directories created"

# Wait for services to be ready (if in Docker)
if [ "$IN_DOCKER" = true ]; then
    print_status "Waiting for services to be ready..."

    # Wait for Redis
    print_status "Waiting for Redis..."
    timeout 30 bash -c 'until redis-cli -h redis ping 2>/dev/null; do sleep 1; done' || {
        print_warning "Redis not available, some tests may fail"
    }

    # Wait for PostgreSQL
    print_status "Waiting for PostgreSQL..."
    timeout 30 bash -c 'until pg_isready -h postgres -p 5432 2>/dev/null; do sleep 1; done' || {
        print_warning "PostgreSQL not available, some tests may fail"
    }

    # Wait for DynamoDB Local
    print_status "Waiting for DynamoDB Local..."
    timeout 30 bash -c 'until curl -s http://dynamodb:8000/ >/dev/null 2>&1; do sleep 1; done' || {
        print_warning "DynamoDB Local not available, some tests may fail"
    }

    # Wait for JDPI Mock Server
    print_status "Waiting for JDPI Mock Server..."
    timeout 30 bash -c 'until curl -s http://jdpi-mock:3000/health >/dev/null 2>&1; do sleep 1; done' || {
        print_warning "JDPI Mock Server not available, some tests may use fallback mocks"
    }

    print_success "Services are ready!"
fi

# Create DynamoDB tables if needed
if [ "$IN_DOCKER" = true ]; then
    print_status "Setting up DynamoDB tables..."

    # Create DynamoDB table for token storage testing
    aws dynamodb create-table \
        --endpoint-url http://dynamodb:8000 \
        --table-name jdpi-tokens \
        --attribute-definitions AttributeName=key,AttributeType=S \
        --key-schema AttributeName=key,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region us-east-1 \
        2>/dev/null || print_warning "DynamoDB table already exists or could not be created"
fi

# Run initial tests to verify setup
print_status "Running initial test to verify setup..."
if bundle exec ruby -e "require_relative 'lib/jdpi_client'; puts 'JDPI Client loaded successfully'"; then
    print_success "JDPI Client library loads correctly"
else
    print_error "Failed to load JDPI Client library"
    exit 1
fi

# Check if test suite can run
print_status "Verifying test environment..."
if bundle exec ruby test/test_config.rb >/dev/null 2>&1; then
    print_success "Test environment is working"
else
    print_warning "Test environment may have issues, but continuing..."
fi

# Create cache directories for better performance
if [ "$IN_DOCKER" = true ]; then
    print_status "Setting up cache directories..."
    mkdir -p .bundle-cache .gem-cache
    print_success "Cache directories created"
fi

# Print environment information
echo ""
print_success "🎉 Development environment setup complete!"
echo ""
print_status "Environment Information:"
echo "  Ruby Version: $(ruby --version)"
echo "  Bundler Version: $(bundle --version)"
echo "  Working Directory: $(pwd)"

if [ "$IN_DOCKER" = true ]; then
    echo "  Redis: ${REDIS_URL:-redis://redis:6379/0}"
    echo "  PostgreSQL: ${DATABASE_URL:-postgresql://postgres:password@postgres:5432/jdpi_client_development}"
    echo "  DynamoDB: ${DYNAMODB_ENDPOINT:-http://dynamodb:8000}"
    echo "  JDPI Mock: ${JDPI_CLIENT_HOST:-jdpi-mock:3000}"
fi

echo ""
print_status "Available development commands:"
echo "  bundle exec rake test              - Run all tests (uses mocks/memory)"
echo "  bundle exec rubocop                - Check code style"
echo "  bundle exec rake                   - Run tests + linting"
echo "  COVERAGE=true bundle exec rake test - Run with coverage"
echo "  bundle exec gem build jdpi_client.gemspec - Build gem"
echo "  bundle exec yard doc               - Generate documentation"

if [ "${DEV_CONTAINER}" = "true" ]; then
    echo ""
    print_status "Development environment features:"
    echo "  - Redis available at: ${REDIS_URL}"
    echo "  - PostgreSQL available at: ${DATABASE_URL}"
    echo "  - DynamoDB Local at: ${DYNAMODB_ENDPOINT}"
    echo "  - JDPI Mock Server at: http://${JDPI_CLIENT_HOST}"
    echo "  - Use TEST_ADAPTER=redis|database|dynamodb|all to test with real services"
fi

if [ "$IN_DOCKER" = false ]; then
    echo ""
    print_status "Docker commands:"
    echo "  docker-compose up jdpi-dev         - Start development environment"
    echo "  docker-compose --profile matrix-test up - Run matrix tests"
fi

echo ""
print_success "🚀 Development environment ready!"
print_status "Note: Tests run cleanly in CI without any services - this rich environment is for development only."