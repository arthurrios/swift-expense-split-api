# Part 6 - Fly.io Deployment Configuration

## Table of Contents
1. [Fly.io Setup](#1-flyio-setup)
2. [Production Configuration](#2-production-configuration)
3. [Test/Student Configuration](#3-teststudent-configuration)
4. [Database Setup](#4-database-setup)
5. [Deployment Process](#5-deployment-process)
6. [Monitoring and Management](#6-monitoring-and-management)

---

## 1. Fly.io Setup

### Install Fly CLI

```bash
# macOS/Linux
curl -L https://fly.io/install.sh | sh

# Add to PATH (if not automatically added)
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Verify installation
flyctl version

# Login to Fly.io
flyctl auth login

# Or signup if you don't have an account
flyctl auth signup
```

### Initialize Fly.io Apps

```bash
# Create production app (DO NOT run fly launch, we'll create manually)
flyctl apps create expense-split-api-prod

# Create test/student app
flyctl apps create expense-split-api-test

# List your apps
flyctl apps list
```

---

## 2. Production Configuration

### File: `fly.toml` (Production)

```toml
# fly.toml app configuration file
# https://fly.io/docs/reference/configuration/

app = "expense-split-api-prod"
primary_region = "gru"  # São Paulo (closest to Brasília)
kill_signal = "SIGTERM"
kill_timeout = "5s"

[experimental]
  auto_rollback = true

[build]
  dockerfile = "Dockerfile"

[env]
  ENVIRONMENT = "production"
  SERVER_PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false  # Keep always running for production
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

  # Health checks
  [http_service.concurrency]
    type = "connections"
    hard_limit = 250
    soft_limit = 200

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/health"

# Resource allocation for production
[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512

# Autoscaling for production
[metrics]
  port = 9091
  path = "/metrics"

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 250
    soft_limit = 200

  [[services.tcp_checks]]
    grace_period = "10s"
    interval = "30s"
    restart_limit = 0
    timeout = "5s"

  [[services.http_checks]]
    interval = "30s"
    grace_period = "10s"
    method = "GET"
    path = "/health"
    protocol = "http"
    restart_limit = 0
    timeout = "5s"
```

---

## 3. Test/Student Configuration

### File: `fly-test.toml` (Students)

```toml
# fly.toml app configuration file for test/student environment
# https://fly.io/docs/reference/configuration/

app = "expense-split-api-test"
primary_region = "gru"  # São Paulo
kill_signal = "SIGTERM"
kill_timeout = "5s"

[experimental]
  auto_rollback = true

[build]
  dockerfile = "Dockerfile"

[env]
  ENVIRONMENT = "testing"
  SERVER_PORT = "8080"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true  # Allow sleeping when idle to save costs
  auto_start_machines = true
  min_machines_running = 0  # Can scale to 0 when not in use
  processes = ["app"]

  # Health checks
  [http_service.concurrency]
    type = "connections"
    hard_limit = 100
    soft_limit = 80

  [[http_service.checks]]
    grace_period = "10s"
    interval = "30s"
    method = "GET"
    timeout = "5s"
    path = "/health"

# Smaller resources for test environment
[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 256

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 100
    soft_limit = 80

  [[services.tcp_checks]]
    grace_period = "10s"
    interval = "30s"
    restart_limit = 0
    timeout = "5s"

  [[services.http_checks]]
    interval = "30s"
    grace_period = "10s"
    method = "GET"
    path = "/health"
    protocol = "http"
    restart_limit = 0
    timeout = "5s"
```

---

## 4. Database Setup

### Create Production Database

```bash
# Create Postgres cluster for production
flyctl postgres create \
  --name expense-split-db-prod \
  --region gru \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --volume-size 10

# Attach to production app
flyctl postgres attach expense-split-db-prod \
  --app expense-split-api-prod

# This automatically sets DATABASE_URL secret
# Verify secrets
flyctl secrets list --app expense-split-api-prod
```

### Create Test/Student Database

```bash
# Create Postgres cluster for test environment
flyctl postgres create \
  --name expense-split-db-test \
  --region gru \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --volume-size 5

# Attach to test app
flyctl postgres attach expense-split-db-test \
  --app expense-split-api-test

# Verify secrets
flyctl secrets list --app expense-split-api-test
```

### Set Additional Secrets

Fly.io's `postgres attach` sets `DATABASE_URL`, but we need individual components.

```bash
# Production secrets
flyctl secrets set \
  DATABASE_HOST="expense-split-db-prod.internal" \
  DATABASE_PORT="5432" \
  DATABASE_NAME="expense_split_api_prod" \
  DATABASE_USERNAME="postgres" \
  DATABASE_PASSWORD="your-strong-password-here" \
  JWT_SECRET="your-production-jwt-secret-min-32-chars" \
  --app expense-split-api-prod

# Test secrets
flyctl secrets set \
  DATABASE_HOST="expense-split-db-test.internal" \
  DATABASE_PORT="5432" \
  DATABASE_NAME="expense_split_api_test" \
  DATABASE_USERNAME="postgres" \
  DATABASE_PASSWORD="test-password-here" \
  JWT_SECRET="test-jwt-secret-for-students" \
  --app expense-split-api-test
```

### Alternative: Parse DATABASE_URL

If you prefer to use the auto-generated `DATABASE_URL`, modify `configure.swift`:

```swift
// In configure.swift, add this before the database configuration

if let databaseURL = Environment.get("DATABASE_URL") {
    app.logger.info("Using DATABASE_URL for configuration")
    try app.databases.use(.postgres(url: databaseURL), as: .psql)
} else {
    // Fall back to individual environment variables
    guard let databaseHost = Environment.get("DATABASE_HOST"),
          let databaseName = Environment.get("DATABASE_NAME"),
          let databaseUsername = Environment.get("DATABASE_USERNAME"),
          let databasePassword = Environment.get("DATABASE_PASSWORD") else {
        app.logger.critical("Database environment variables not set!")
        throw Abort(.internalServerError, reason: "Database configuration missing")
    }
    
    let databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432
    
    app.databases.use(.postgres(
        hostname: databaseHost,
        port: databasePort,
        username: databaseUsername,
        password: databasePassword,
        database: databaseName
    ), as: .psql)
}
```

---

## 5. Deployment Process

### First Time Deployment

#### Deploy Production

```bash
# Deploy production
flyctl deploy \
  --config fly.toml \
  --app expense-split-api-prod

# Watch deployment
flyctl logs --app expense-split-api-prod

# Run migrations (if auto-migrate is disabled in production)
flyctl ssh console --app expense-split-api-prod
# Inside container:
# ./App migrate --env production

# Verify deployment
flyctl status --app expense-split-api-prod

# Open in browser
flyctl open --app expense-split-api-prod
```

#### Deploy Test/Student Environment

```bash
# Deploy test
flyctl deploy \
  --config fly-test.toml \
  --app expense-split-api-test

# Watch deployment
flyctl logs --app expense-split-api-test

# Verify deployment
flyctl status --app expense-split-api-test

# Open in browser
flyctl open --app expense-split-api-test
```

### Subsequent Deployments

```bash
# Production
flyctl deploy --config fly.toml --app expense-split-api-prod

# Test
flyctl deploy --config fly-test.toml --app expense-split-api-test
```

### CI/CD with GitHub Actions (Optional)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Fly.io

on:
  push:
    branches:
      - main  # Production
      - test  # Test environment

jobs:
  deploy:
    name: Deploy to Fly.io
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: superfly/flyctl-actions/setup-flyctl@master
      
      - name: Deploy Production
        if: github.ref == 'refs/heads/main'
        run: flyctl deploy --remote-only --config fly.toml --app expense-split-api-prod
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
      
      - name: Deploy Test
        if: github.ref == 'refs/heads/test'
        run: flyctl deploy --remote-only --config fly-test.toml --app expense-split-api-test
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

---

## 6. Monitoring and Management

### Viewing Logs

```bash
# Production logs (live)
flyctl logs --app expense-split-api-prod

# Test logs (live)
flyctl logs --app expense-split-api-test

# Historical logs
flyctl logs --app expense-split-api-prod --all
```

### Scaling

```bash
# Scale production vertically
flyctl scale vm shared-cpu-2x --memory 1024 --app expense-split-api-prod

# Scale production horizontally (multiple instances)
flyctl scale count 2 --app expense-split-api-prod

# Scale test (minimal)
flyctl scale vm shared-cpu-1x --memory 256 --app expense-split-api-test
flyctl scale count 1 --app expense-split-api-test
```

### SSH Access

```bash
# SSH into production
flyctl ssh console --app expense-split-api-prod

# SSH into test
flyctl ssh console --app expense-split-api-test

# Run commands remotely
flyctl ssh console --app expense-split-api-prod -C "ls -la"
```

### Database Access

```bash
# Connect to production database
flyctl postgres connect --app expense-split-db-prod

# Connect to test database
flyctl postgres connect --app expense-split-db-test

# Create database backup
flyctl ssh console --app expense-split-db-prod
# Inside:
pg_dump -U postgres expense_split_api_prod > backup.sql

# Or use Fly's proxy
flyctl proxy 5432 --app expense-split-db-prod
# Then connect with local client:
psql -h localhost -p 5432 -U postgres -d expense_split_api_prod
```

### Health Checks

```bash
# Check production health
curl https://expense-split-api-prod.fly.dev/health

# Check test health
curl https://expense-split-api-test.fly.dev/health

# Detailed status
flyctl status --app expense-split-api-prod
flyctl status --app expense-split-api-test
```

### Restart Applications

```bash
# Restart production
flyctl apps restart expense-split-api-prod

# Restart test
flyctl apps restart expense-split-api-test
```

### Cost Management

```bash
# View current usage
flyctl dashboard

# Stop test app when not needed (to save costs)
flyctl scale count 0 --app expense-split-api-test

# Start test app again
flyctl scale count 1 --app expense-split-api-test
```

### Giving Students Access

Students should use the test environment URL:

```
Production (ONLY YOU):
https://expense-split-api-prod.fly.dev

Test/Students (PUBLIC):
https://expense-split-api-test.fly.dev
```

Share the test URL with students. The test database is completely separate from production.

### Reset Test Database (For New Semester)

```bash
# Option 1: Delete and recreate database
flyctl postgres detach expense-split-db-test --app expense-split-api-test
flyctl postgres destroy expense-split-db-test
# Then follow "Create Test/Student Database" steps again

# Option 2: Connect and drop/recreate schema
flyctl postgres connect --app expense-split-db-test
# Inside:
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
\q

# Then restart API to run migrations
flyctl apps restart expense-split-api-test
```

---

## Summary

This part covered:

1. ✅ **Fly.io Setup**:
   - CLI installation and authentication
   - App creation for both environments

2. ✅ **Configuration Files**:
   - Production config with always-on instances
   - Test config with auto-sleep to save costs
   - Regional deployment (São Paulo for Brazil)

3. ✅ **Database Management**:
   - Managed Postgres for both environments
   - Secrets configuration
   - Database connection methods

4. ✅ **Deployment**:
   - Manual deployment commands
   - CI/CD setup with GitHub Actions
   - Migration handling

5. ✅ **Monitoring**:
   - Logs, scaling, SSH access
   - Health checks and status monitoring
   - Cost management strategies

**Key Points:**
- Production: `https://expense-split-api-prod.fly.dev` (only you)
- Test: `https://expense-split-api-test.fly.dev` (students)
- Test environment can auto-sleep to save costs
- Databases are completely isolated
- Easy to reset test data between semesters

**Next up: Part 7 - Testing and Documentation**

This will cover:
- Writing unit tests
- Integration tests
- API documentation
- Postman/Thunder Client collections
- README and usage guides