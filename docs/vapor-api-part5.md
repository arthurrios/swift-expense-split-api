# Part 5 - Docker Configuration

## Table of Contents
1. [Dockerfile](#1-dockerfile)
2. [Docker Compose](#2-docker-compose)
3. [Docker Ignore](#3-docker-ignore)
4. [Development Workflow](#4-development-workflow)

---

## 1. Dockerfile

This Dockerfile uses multi-stage builds for optimal image size and build caching.

### File: `Dockerfile`

```dockerfile
# ================================
# Build Stage
# ================================
FROM swift:5.9-jammy as build

# Install OS dependencies
RUN apt-get update -y \
    && apt-get install -y \
    libsqlite3-dev \
    libpq-dev \
    && rm -r /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# Copy Package files first for better caching
COPY ./Package.* ./

# Fetch dependencies
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Build with optimizations
RUN swift build -c release \
    --static-swift-stdlib \
    -Xlinker -s

# ================================
# Run Stage
# ================================
FROM ubuntu:jammy

# Install runtime dependencies
RUN apt-get update -y \
    && apt-get install -y \
    ca-certificates \
    libpq5 \
    libsqlite3-0 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app

# Copy built executable and resources from build stage
COPY --from=build --chown=vapor:vapor /build/.build/release /app

# Ensure the directory is owned by the vapor user
RUN chown -R vapor:vapor /app

# Switch to the new user
USER vapor:vapor

# Expose port
EXPOSE 8080

# Set environment to production by default (can be overridden)
ENV ENVIRONMENT=production

# Start the Vapor service
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
```

---

## 2. Docker Compose

Three different compose configurations for different environments.

### File: `docker-compose.yml` (Development)

```yaml
version: '3.8'

services:
  # PostgreSQL Database for Development
  postgres-dev:
    image: postgres:16-alpine
    container_name: expense-split-postgres-dev
    environment:
      POSTGRES_USER: vapor
      POSTGRES_PASSWORD: password
      POSTGRES_DB: expense_split_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    networks:
      - expense-split-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vapor"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Vapor API - Development
  api-dev:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: expense-split-api-dev
    depends_on:
      postgres-dev:
        condition: service_healthy
    environment:
      DATABASE_HOST: postgres-dev
      DATABASE_PORT: 5432
      DATABASE_NAME: expense_split_dev
      DATABASE_USERNAME: vapor
      DATABASE_PASSWORD: password
      JWT_SECRET: dev-jwt-secret-change-in-production
      ENVIRONMENT: development
      SERVER_PORT: 8080
    ports:
      - "8080:8080"
    volumes:
      # Mount source code for live reloading (optional, for development)
      - ./Sources:/app/Sources:ro
      - ./Public:/app/Public:ro
    networks:
      - expense-split-network
    restart: unless-stopped

volumes:
  postgres_dev_data:
    driver: local

networks:
  expense-split-network:
    driver: bridge
```

### File: `docker-compose.test.yml` (Testing/Students)

```yaml
version: '3.8'

services:
  # PostgreSQL Database for Testing
  postgres-test:
    image: postgres:16-alpine
    container_name: expense-split-postgres-test
    environment:
      POSTGRES_USER: vapor
      POSTGRES_PASSWORD: password
      POSTGRES_DB: expense_split_test
    ports:
      - "5433:5432"
    volumes:
      - postgres_test_data:/var/lib/postgresql/data
    networks:
      - expense-split-test-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vapor"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Vapor API - Testing (for students)
  api-test:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: expense-split-api-test
    depends_on:
      postgres-test:
        condition: service_healthy
    environment:
      DATABASE_HOST: postgres-test
      DATABASE_PORT: 5432
      DATABASE_NAME: expense_split_test
      DATABASE_USERNAME: vapor
      DATABASE_PASSWORD: password
      JWT_SECRET: test-jwt-secret-for-students
      ENVIRONMENT: testing
      SERVER_PORT: 8080
    ports:
      - "8081:8080"
    networks:
      - expense-split-test-network
    restart: unless-stopped
    # Add labels for identification
    labels:
      - "environment=testing"
      - "access=students"

volumes:
  postgres_test_data:
    driver: local

networks:
  expense-split-test-network:
    driver: bridge
```

### File: `docker-compose.prod.yml` (Production - Template)

```yaml
version: '3.8'

services:
  # PostgreSQL Database for Production
  # NOTE: In production with Fly.io, you'll use their managed Postgres
  # This is just a template for self-hosted production
  postgres-prod:
    image: postgres:16-alpine
    container_name: expense-split-postgres-prod
    environment:
      POSTGRES_USER: ${DATABASE_USERNAME}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
      POSTGRES_DB: ${DATABASE_NAME}
    ports:
      - "5432:5432"
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
    networks:
      - expense-split-prod-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DATABASE_USERNAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: always

  # Vapor API - Production
  api-prod:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: expense-split-api-prod
    depends_on:
      postgres-prod:
        condition: service_healthy
    environment:
      DATABASE_HOST: postgres-prod
      DATABASE_PORT: 5432
      DATABASE_NAME: ${DATABASE_NAME}
      DATABASE_USERNAME: ${DATABASE_USERNAME}
      DATABASE_PASSWORD: ${DATABASE_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      ENVIRONMENT: production
      SERVER_PORT: 8080
    ports:
      - "8080:8080"
    networks:
      - expense-split-prod-network
    restart: always
    # Security: Run as non-root user (already configured in Dockerfile)
    labels:
      - "environment=production"
      - "access=restricted"

volumes:
  postgres_prod_data:
    driver: local

networks:
  expense-split-prod-network:
    driver: bridge
```

---

## 3. Docker Ignore

### File: `.dockerignore`

```
# Swift build artifacts
.build/
.swiftpm/
*.xcodeproj
*.xcworkspace
DerivedData/

# Environment files (will be set via docker-compose)
.env*

# Git
.git/
.gitignore

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# macOS
.DS_Store

# Documentation
README.md
docs/

# Tests (optional - remove if you want to run tests in container)
Tests/

# Docker files themselves
Dockerfile
docker-compose*.yml
.dockerignore

# Logs
*.log

# Database
*.db
*.sqlite

# Temporary files
tmp/
temp/
```

---

## 4. Development Workflow

### Starting Development Environment

```bash
# Start development environment
docker-compose up -d

# View logs
docker-compose logs -f api-dev

# Stop environment
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Starting Test/Student Environment

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# View logs
docker-compose -f docker-compose.test.yml logs -f api-test

# Stop environment
docker-compose -f docker-compose.test.yml down
```

### Building Without Compose (Manual)

```bash
# Build the image
docker build -t expense-split-api:latest .

# Run with environment variables
docker run -d \
  --name expense-split-api \
  -p 8080:8080 \
  -e DATABASE_HOST=host.docker.internal \
  -e DATABASE_PORT=5432 \
  -e DATABASE_NAME=expense_split_dev \
  -e DATABASE_USERNAME=vapor \
  -e DATABASE_PASSWORD=password \
  -e JWT_SECRET=your-secret-key \
  -e ENVIRONMENT=development \
  expense-split-api:latest
```

### Running on Apple Silicon (M1/M2/M3)

```bash
# Build for ARM64
docker build --platform linux/arm64 -t expense-split-api:latest .

# Or build for both ARM64 and AMD64 (multi-platform)
docker buildx build --platform linux/amd64,linux/arm64 -t expense-split-api:latest .
```

### Accessing the Containers

```bash
# Access API container bash
docker exec -it expense-split-api-dev bash

# Access database
docker exec -it expense-split-postgres-dev psql -U vapor -d expense_split_dev

# Check database tables
docker exec -it expense-split-postgres-dev psql -U vapor -d expense_split_dev -c "\dt"
```

### Database Management

```bash
# Backup development database
docker exec expense-split-postgres-dev pg_dump -U vapor expense_split_dev > backup.sql

# Restore database
cat backup.sql | docker exec -i expense-split-postgres-dev psql -U vapor -d expense_split_dev

# Reset test database (for students)
docker-compose -f docker-compose.test.yml down -v
docker-compose -f docker-compose.test.yml up -d
```

### Running Both Environments Simultaneously

```bash
# Start development (port 8080)
docker-compose up -d

# Start test/student (port 8081)
docker-compose -f docker-compose.test.yml up -d

# Now you have:
# - Dev API: http://localhost:8080
# - Test API: http://localhost:8081 (for students)

# Stop both
docker-compose down
docker-compose -f docker-compose.test.yml down
```

### Troubleshooting

```bash
# Check container status
docker ps -a

# Check container logs
docker logs expense-split-api-dev

# Check container resource usage
docker stats

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d

# Remove all stopped containers and images
docker system prune -a
```

### Environment-Specific Commands

```bash
# Development: Auto-migrate on startup (configured in configure.swift)
docker-compose up -d

# Testing: Auto-migrate on startup
docker-compose -f docker-compose.test.yml up -d

# Production: Manual migration (for safety)
# SSH into production server, then:
docker exec -it expense-split-api-prod vapor-cli migrate --env production
```

---

## Summary

This part covered:

1. ✅ **Dockerfile**:
   - Multi-stage build for smaller images
   - Swift 5.9 base image
   - Optimized for production
   - Runs as non-root user for security

2. ✅ **Docker Compose Files**:
   - **Development** (port 8080) - Your main development environment
   - **Testing** (port 8081) - For students, separate database
   - **Production** (template) - Reference for self-hosted deployments

3. ✅ **Docker Ignore**:
   - Excludes unnecessary files from image
   - Reduces build time and image size

4. ✅ **Complete Workflow**:
   - Commands for all scenarios
   - Database management
   - Troubleshooting tips
   - Multi-environment setup

**Key Points:**
- Development and test can run simultaneously
- Test environment (port 8081) is isolated for students
- Production uses environment variables for security
- Auto-migration in dev/test, manual in production

**Next up: Part 6 - Fly.io Deployment Configuration**

This will cover:
- fly.toml configuration
- Secrets management
- Deploying to production and test environments
- Managed Postgres setup