# Docker Development Environment

This document provides comprehensive information about the Docker-based development environment for the jdpi-client Ruby gem.

## 🎯 Overview

The jdpi-client project includes a complete Docker development environment designed specifically for Ruby gem development. This environment provides:

- **Zero-config setup** with `docker-compose up`
- **Multi-Ruby version testing** (Ruby 3.0-3.4)
- **Complete storage backend testing** (Redis, PostgreSQL, DynamoDB Local)
- **JDPI mock server** for realistic API testing
- **VS Code devcontainer** support with pre-configured extensions
- **Hot reloading** and debugging capabilities

## 📁 Docker Structure

```
├── .devcontainer/
│   ├── devcontainer.json          # VS Code dev container configuration
│   └── Dockerfile.dev             # Development container definition
├── docker/
│   ├── ruby/                      # Ruby version-specific containers
│   │   ├── Dockerfile.ruby30      # Ruby 3.0 container
│   │   ├── Dockerfile.ruby31      # Ruby 3.1 container
│   │   ├── Dockerfile.ruby32      # Ruby 3.2 container
│   │   ├── Dockerfile.ruby33      # Ruby 3.3 container
│   │   └── Dockerfile.ruby34      # Ruby 3.4 container
│   ├── services/
│   │   └── jdpi-mock/             # JDPI API mock server
│   └── postgres/
│       └── init.sql               # PostgreSQL initialization
├── docker-compose.yml             # Main services definition
├── docker-compose.dev.yml         # Development overrides
├── docker-compose.test.yml        # Testing configuration
└── scripts/
    ├── setup-dev.sh               # Development setup script
    └── test-matrix.sh              # Multi-Ruby testing script
```

## 🚀 Getting Started

### Option 1: VS Code Dev Container (Recommended)

1. **Prerequisites:**
   - [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - [VS Code](https://code.visualstudio.com/)
   - [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Setup:**
   ```bash
   git clone https://github.com/agramms/jdpi-client.git
   cd jdpi-client
   code .
   ```

3. **Launch:**
   - VS Code will detect the devcontainer configuration
   - Click "Reopen in Container" when prompted
   - Wait for the environment to build and start
   - All dependencies will be automatically installed

### Option 2: Command Line Development

```bash
# Clone the repository
git clone https://github.com/agramms/jdpi-client.git
cd jdpi-client

# Start development environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Access the development container
docker-compose exec jdpi-dev bash

# Inside the container, run setup
scripts/setup-dev.sh
```

## 🐳 Docker Services

### Core Services

#### jdpi-dev (Development Container)
- **Base:** Ruby 3.2-slim with development tools
- **Purpose:** Main development environment
- **Features:**
  - Ruby LSP and debugging tools
  - Bundle cache for faster dependency installation
  - Source code volume mount with hot reloading
  - Pre-installed development gems (solargraph, rubocop, debug)

#### redis
- **Image:** redis:7-alpine
- **Port:** 6379
- **Purpose:** Token storage backend testing
- **Features:**
  - Persistent data volume
  - Health checks
  - Development logging enabled

#### postgres
- **Image:** postgres:15-alpine
- **Port:** 5432
- **Purpose:** Database storage backend testing
- **Features:**
  - Pre-configured databases (development, test)
  - Automatic table creation for token storage
  - Development logging enabled

#### dynamodb
- **Image:** amazon/dynamodb-local:latest
- **Port:** 8000
- **Purpose:** AWS DynamoDB simulation for testing
- **Features:**
  - In-memory storage for fast tests
  - Shared database mode
  - Automatic table creation

#### jdpi-mock
- **Image:** Custom Node.js application
- **Port:** 3000
- **Purpose:** Mock JDPI API server
- **Features:**
  - Complete JDPI API simulation
  - Configurable responses for different scenarios
  - Request logging and debugging
  - Health check endpoint

### Matrix Testing Services

#### ruby30, ruby31, ruby32, ruby33, ruby34
- **Purpose:** Multi-Ruby version testing
- **Features:**
  - Separate bundle caches for each version
  - Version-specific gem compatibility
  - Isolated test environments
  - CI/CD pipeline simulation

## 🛠️ Development Commands

### Basic Development

```bash
# Start development environment
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Access development container
docker-compose exec jdpi-dev bash

# Run tests
docker-compose exec jdpi-dev bundle exec rake test

# Run linting
docker-compose exec jdpi-dev bundle exec rubocop

# Run tests with coverage
docker-compose exec jdpi-dev bash -c "COVERAGE=true bundle exec rake test"
```

### Testing Commands

```bash
# Run test suite in isolated environment
docker-compose -f docker-compose.yml -f docker-compose.test.yml up jdpi-test

# Matrix testing across all Ruby versions
./scripts/test-matrix.sh

# Test specific Ruby version
docker-compose --profile matrix-test up ruby30
docker-compose --profile matrix-test up ruby31
# ... etc
```

### Service Management

```bash
# Start only specific services
docker-compose up redis postgres  # Only storage services
docker-compose up jdpi-mock       # Only mock server

# View logs
docker-compose logs jdpi-dev      # Development container logs
docker-compose logs jdpi-mock     # Mock server logs
docker-compose logs -f redis      # Follow Redis logs

# Restart services
docker-compose restart redis      # Restart Redis
docker-compose restart jdpi-mock  # Restart mock server

# Clean shutdown
docker-compose down --volumes --remove-orphans
```

## 🔧 Configuration

### Environment Variables

The development environment supports these environment variables:

```bash
# Development Container
DEBUG=true                    # Enable debug logging
VERBOSE=true                 # Verbose output
LOG_LEVEL=debug              # Set log level
COVERAGE=true                # Enable test coverage

# Service URLs (automatically configured)
REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgresql://postgres:password@postgres:5432/jdpi_client_development
DYNAMODB_ENDPOINT=http://dynamodb:8000
JDPI_CLIENT_HOST=jdpi-mock:3000
```

### Volume Mounts

The development environment uses several volumes for performance and persistence:

- **Source code:** `.:/workspace:cached` - Hot reloading
- **Bundle cache:** `bundle-cache:/usr/local/bundle` - Faster dependency installation
- **Gem cache:** `gem-cache:/usr/local/lib/ruby/gems` - Gem caching
- **Redis data:** `redis-data:/data` - Persistent Redis storage
- **PostgreSQL data:** `postgres-data:/var/lib/postgresql/data` - Persistent database

### Port Forwarding

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| jdpi-mock | 3000 | 3000 | JDPI API mock server |
| redis | 6379 | 6379 | Redis service |
| postgres | 5432 | 5432 | PostgreSQL database |
| dynamodb | 8000 | 8000 | DynamoDB Local |
| ruby-debug | 1234 | 1234 | Ruby debugger (development) |

## 🧪 Testing

### Test Structure

The Docker environment supports multiple testing scenarios:

1. **Unit Tests:** Fast, isolated tests using mocked services
2. **Integration Tests:** Tests using real storage backends (Redis, PostgreSQL, DynamoDB)
3. **Matrix Tests:** Cross-Ruby version compatibility testing
4. **End-to-End Tests:** Full workflow testing with JDPI mock server

### Test Configuration

Each Ruby version container uses different Redis databases to avoid conflicts:

- Ruby 3.0: `redis://redis:6379/1`
- Ruby 3.1: `redis://redis:6379/2`
- Ruby 3.2: `redis://redis:6379/3`
- Ruby 3.3: `redis://redis:6379/4`
- Ruby 3.4: `redis://redis:6379/5`

### Coverage Reporting

Test coverage is collected and reported for each Ruby version:

```bash
# Generate coverage report
COVERAGE=true docker-compose exec jdpi-dev bundle exec rake test

# View coverage report
docker-compose exec jdpi-dev open coverage/index.html
```

## 🐛 Debugging

### VS Code Debugging

The devcontainer includes pre-configured debugging support:

1. **Set breakpoints** in VS Code
2. **Run debug configuration** from VS Code's Run panel
3. **Use integrated terminal** for interactive debugging

### Manual Debugging

```bash
# Access development container
docker-compose exec jdpi-dev bash

# Run Ruby debugger
bundle exec ruby -rdebug your_script.rb

# Run tests with debugging
bundle exec ruby test/specific_test.rb -n test_method_name
```

### Service Debugging

```bash
# Check service health
docker-compose exec jdpi-dev curl http://redis:6379/  # Redis health
docker-compose exec jdpi-dev curl http://jdpi-mock:3000/health  # Mock server health
docker-compose exec jdpi-dev pg_isready -h postgres -p 5432  # PostgreSQL health

# Access service logs
docker-compose logs redis
docker-compose logs postgres
docker-compose logs jdpi-mock
```

## 🚨 Troubleshooting

### Common Issues

#### Services Not Starting

```bash
# Check Docker Desktop is running
docker version

# Check for port conflicts
docker-compose ps
netstat -tulpn | grep :6379  # Check if Redis port is in use

# Restart Docker Desktop and try again
docker-compose down --volumes
docker-compose up -d
```

#### Permission Issues

```bash
# Fix file permissions (macOS/Linux)
sudo chown -R $USER:$USER .

# Reset Docker volumes
docker-compose down --volumes
docker volume prune -f
docker-compose up -d
```

#### Bundle Install Failures

```bash
# Clear bundle cache
docker-compose exec jdpi-dev rm -rf .bundle
docker-compose exec jdpi-dev bundle clean --force

# Rebuild development container
docker-compose build jdpi-dev --no-cache
```

#### Database Connection Issues

```bash
# Check PostgreSQL is ready
docker-compose exec postgres pg_isready

# Recreate database
docker-compose exec postgres psql -U postgres -c "DROP DATABASE IF EXISTS jdpi_client_development;"
docker-compose exec postgres psql -U postgres -c "CREATE DATABASE jdpi_client_development;"
```

### Performance Optimization

#### macOS Performance

For better performance on macOS:

```yaml
# Add to docker-compose.override.yml
version: '3.8'
services:
  jdpi-dev:
    volumes:
      - .:/workspace:delegated  # Use delegated consistency
```

#### Memory Usage

```bash
# Check Docker resource usage
docker stats

# Limit container memory if needed
docker-compose exec jdpi-dev bash -c "ulimit -v 1048576"  # 1GB limit
```

## 📚 Additional Resources

- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/remote/containers)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Ruby Docker Images](https://hub.docker.com/_/ruby)
- [PostgreSQL Docker Images](https://hub.docker.com/_/postgres)
- [Redis Docker Images](https://hub.docker.com/_/redis)
- [DynamoDB Local Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)

## 🤝 Contributing

When contributing to the Docker environment:

1. **Test changes** across all Ruby versions
2. **Update documentation** for any new features
3. **Ensure compatibility** with both VS Code and command-line workflows
4. **Verify CI/CD integration** remains functional

---

**Need help?** Check the [main README](README.md) or open an issue on GitHub.