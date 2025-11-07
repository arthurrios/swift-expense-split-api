# Expense Split API

A RESTful API for splitting expenses between friends, built with Swift and Vapor.

## Features

- 🔐 JWT Authentication
- 💰 Expense tracking and splitting
- 🔄 Global debt compensation across activities
- 👥 Multi-user support
- 🌍 Multiple environments (dev, test, production)
- 🐳 Docker support
- ☁️ Fly.io deployment ready

## Quick Start

### Prerequisites

- Swift 5.9+ (for local development)
- Docker & Docker Compose
- PostgreSQL 16

### Local Development

```bash
# Clone repository
git clone <your-repo-url>
cd ExpenseSplitAPI

# Copy environment file
cp .env.example .env.development

# Edit .env.development with your settings
nano .env.development

# Start with Docker Compose
docker-compose up -d

# API will be available at http://localhost:8080

# Check logs
docker-compose logs -f api-dev

# Stop services
docker-compose down
```

### Without Docker (macOS only)

```bash
# Install dependencies
brew install vapor postgresql

# Start PostgreSQL
brew services start postgresql

# Create database
createdb expense_split_dev

# Set environment variables
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_NAME=expense_split_dev
export DATABASE_USERNAME=your_username
export DATABASE_PASSWORD=your_password
export JWT_SECRET=your-secret-key
export ENVIRONMENT=development

# Build and run
swift build
swift run

# Or use Vapor CLI
vapor build
vapor run
```

### Running Tests

```bash
# With Swift
swift test

# With Docker
docker-compose exec api-dev swift test

# Run specific test
swift test --filter AuthTests

# With coverage
swift test --enable-code-coverage
```

## Documentation

- [Complete API Documentation](./API_DOCUMENTATION.md)
- [Part 1: Foundation & Models](./docs/PART1_FOUNDATION.md)
- [Part 2: DTOs & Configuration](./docs/PART2_CONFIGURATION.md)
- [Part 3: Controllers](./docs/PART3_CONTROLLERS.md)
- [Part 4: Balance & Compensation Logic](./docs/PART4_BALANCE.md)
- [Part 5: Docker Setup](./docs/PART5_DOCKER.md)
- [Part 6: Fly.io Deployment](./docs/PART6_DEPLOYMENT.md)
- [Part 7: Testing](./docs/PART7_TESTING.md)

## API Endpoints

### Base URLs

- **Production**: `https://expense-split-api-prod.fly.dev`
- **Test/Students**: `https://expense-split-api-test.fly.dev`
- **Local Development**: `http://localhost:8080`

### Quick Examples

#### Sign Up
```bash
curl -X POST http://localhost:8080/api/v1/users/sign-up \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123"
  }'
```

#### Sign In
```bash
curl -X POST http://localhost:8080/api/v1/users/sign-in \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

#### Create Activity
```bash
curl -X POST http://localhost:8080/api/v1/activity \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Weekend Trip",
    "activityDate": "2025-11-10T10:00:00Z"
  }'
```

#### Create Expense
```bash
curl -X POST http://localhost:8080/api/v1/expense/ACTIVITY_ID \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Restaurant Dinner",
    "amountInCents": 10000,
    "payerId": "PAYER_USER_ID",
    "participantsIds": ["USER_ID_1", "USER_ID_2"]
  }'
```

#### Get Global Balance (with compensation)
```bash
curl -X GET http://localhost:8080/api/v1/balance/user/YOUR_USER_ID \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

See [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) for complete endpoint reference.

## Project Structure

```
ExpenseSplitAPI/
├── Package.swift                 # Swift package configuration
├── Dockerfile                    # Docker image definition
├── docker-compose.yml            # Development environment
├── docker-compose.test.yml       # Test/student environment
├── fly.toml                      # Production deployment config
├── fly-test.toml                 # Test deployment config
├── README.md                     # This file
├── API_DOCUMENTATION.md          # Complete API docs
│
├── Sources/
│   ├── App/
│   │   ├── configure.swift       # App configuration
│   │   ├── routes.swift          # Route definitions
│   │   │
│   │   ├── Models/               # Data models
│   │   │   ├── User.swift
│   │   │   ├── Activity.swift
│   │   │   ├── Expense.swift
│   │   │   ├── UserToken.swift
│   │   │   └── DTOs/             # Data Transfer Objects
│   │   │       ├── UserDTOs.swift
│   │   │       ├── ActivityDTOs.swift
│   │   │       ├── ExpenseDTOs.swift
│   │   │       └── BalanceDTOs.swift
│   │   │
│   │   ├── Controllers/          # Request handlers
│   │   │   ├── AuthController.swift
│   │   │   ├── ActivityController.swift
│   │   │   ├── ExpenseController.swift
│   │   │   ├── BalanceController.swift
│   │   │   └── ParticipantController.swift
│   │   │
│   │   ├── Services/             # Business logic
│   │   │   ├── BalanceService.swift
│   │   │   └── CompensationService.swift
│   │   │
│   │   ├── Migrations/           # Database migrations
│   │   │   ├── CreateUser.swift
│   │   │   ├── CreateActivity.swift
│   │   │   ├── CreateExpense.swift
│   │   │   └── ...
│   │   │
│   │   └── Middleware/           # Custom middleware
│   │       └── UserAuthenticator.swift
│   │
│   └── Run/
│       └── main.swift            # Entry point
│
├── Tests/
│   └── AppTests/                 # Test suite
│       ├── AuthTests.swift
│       ├── ActivityTests.swift
│       ├── ExpenseTests.swift
│       └── BalanceTests.swift
│
└── Public/                       # Static files (if any)
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_HOST` | PostgreSQL host | `localhost` or `postgres-dev` |
| `DATABASE_PORT` | PostgreSQL port | `5432` |
| `DATABASE_NAME` | Database name | `expense_split_dev` |
| `DATABASE_USERNAME` | Database user | `vapor` |
| `DATABASE_PASSWORD` | Database password | `password` |
| `JWT_SECRET` | Secret for JWT signing (min 32 chars) | `your-super-secret-key` |
| `ENVIRONMENT` | Environment name | `development`, `testing`, `production` |
| `SERVER_PORT` | Server port | `8080` |

### Environment Files

- `.env.development` - Local development
- `.env.testing` - Test environment
- `.env.production` - Production (set in Fly.io secrets)
- `.env.example` - Template (commit this to git)

**Never commit actual .env files to git!**

## Database Management

### Migrations

```bash
# Migrations run automatically in dev/test on startup
# For production, run manually:

# Via Fly.io
flyctl ssh console --app expense-split-api-prod
./App migrate --env production

# Via Docker
docker exec -it expense-split-api-prod ./App migrate --env production
```

### Database Backup

```bash
# Backup development database
docker exec expense-split-postgres-dev pg_dump -U vapor expense_split_dev > backup.sql

# Restore database
cat backup.sql | docker exec -i expense-split-postgres-dev psql -U vapor -d expense_split_dev

# Backup production database (Fly.io)
flyctl postgres connect --app expense-split-db-prod
pg_dump expense_split_api_prod > backup_prod.sql
```

### Reset Test Database

```bash
# Stop and remove volumes
docker-compose -f docker-compose.test.yml down -v

# Restart (will recreate database)
docker-compose -f docker-compose.test.yml up -d
```

## Deployment

### Fly.io (Recommended)

#### First Time Setup

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login

# Create production app
flyctl apps create expense-split-api-prod

# Create test app
flyctl apps create expense-split-api-test

# Create databases
flyctl postgres create --name expense-split-db-prod --region gru
flyctl postgres create --name expense-split-db-test --region gru

# Attach databases
flyctl postgres attach expense-split-db-prod --app expense-split-api-prod
flyctl postgres attach expense-split-db-test --app expense-split-api-test

# Set secrets
flyctl secrets set \
  JWT_SECRET="your-production-secret" \
  --app expense-split-api-prod

flyctl secrets set \
  JWT_SECRET="test-secret" \
  --app expense-split-api-test
```

#### Deploy

```bash
# Deploy production
flyctl deploy --config fly.toml --app expense-split-api-prod

# Deploy test/student environment
flyctl deploy --config fly-test.toml --app expense-split-api-test

# View logs
flyctl logs --app expense-split-api-prod

# Check status
flyctl status --app expense-split-api-prod
```

### Docker (Self-Hosted)

```bash
# Build image
docker build -t expense-split-api:latest .

# Run with environment variables
docker run -d \
  --name expense-split-api \
  -p 8080:8080 \
  -e DATABASE_HOST=your_db_host \
  -e DATABASE_PORT=5432 \
  -e DATABASE_NAME=expense_split_prod \
  -e DATABASE_USERNAME=vapor \
  -e DATABASE_PASSWORD=secure_password \
  -e JWT_SECRET=your-jwt-secret \
  -e ENVIRONMENT=production \
  expense-split-api:latest
```

## For Students

Students should use the **test environment**:

**Test API Base URL**: `https://expense-split-api-test.fly.dev`

### Getting Started

1. **Import Postman Collection**: Download `Expense_Split_API.postman_collection.json`
2. **Set Base URL**: In Postman, set `base_url` variable to the test URL
3. **Sign Up**: Create your account
4. **Start Testing**: The token will be saved automatically

### Important Notes for Students

- ✅ Test database is completely separate from production
- ✅ Feel free to create/delete data
- ✅ Database may be reset periodically
- ❌ Do NOT use real personal information
- ❌ Do NOT store sensitive data

### Example Workflow

```bash
# 1. Sign up
POST https://expense-split-api-test.fly.dev/api/v1/users/sign-up
{
  "name": "Student Name",
  "email": "student@example.com",
  "password": "password123"
}

# 2. Create activity
POST https://expense-split-api-test.fly.dev/api/v1/activity
Authorization: Bearer <your_token>
{
  "title": "Class Project",
  "activityDate": "2025-11-10T10:00:00Z"
}

# 3. Add expense
POST https://expense-split-api-test.fly.dev/api/v1/expense/{activityId}
Authorization: Bearer <your_token>
{
  "title": "Team Lunch",
  "amountInCents": 5000,
  "payerId": "{your_user_id}",
  "participantsIds": ["{user_id_1}", "{user_id_2}"]
}
```

## Testing the API

### Manual Testing with curl

See examples in the [Quick Examples](#quick-examples) section above.

### Automated Testing

```bash
# Run all tests
swift test

# Run specific test class
swift test --filter AuthTests

# Run specific test method
swift test --filter AuthTests.testSignUpSuccess

# With verbose output
swift test --verbose
```

### Using Postman

1. Import `Expense_Split_API.postman_collection.json`
2. Set environment variables:
   - `base_url`: Your API URL
   - `token`: Auto-saved after login
3. Run requests in order (Auth → Activities → Expenses → Balance)

## Monitoring

### Health Check

```bash
curl http://localhost:8080/health
# Should return: 200 OK
```

### Logs

```bash
# Local Docker
docker-compose logs -f api-dev

# Fly.io Production
flyctl logs --app expense-split-api-prod

# Fly.io Test
flyctl logs --app expense-split-api-test
```

### Metrics

```bash
# Check running containers
docker ps

# Check resource usage
docker stats

# Fly.io status
flyctl status --app expense-split-api-prod
```

## Troubleshooting

### Database Connection Issues

```bash
# Check database is running
docker ps | grep postgres

# Check database logs
docker logs expense-split-postgres-dev

# Test connection
docker exec -it expense-split-postgres-dev psql -U vapor -d expense_split_dev -c "SELECT 1"
```

### Build Issues

```bash
# Clean build
swift package clean
swift build

# With Docker
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Authentication Issues

- Verify JWT_SECRET is set correctly
- Check token expiration (30 days by default)
- Ensure Authorization header format: `Bearer <token>`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`swift test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for linting
- Write tests for new features
- Update documentation

## Security

### Reporting Vulnerabilities

Please report security vulnerabilities to: your-email@example.com

### Best Practices

- ✅ Use strong JWT secrets (min 32 characters)
- ✅ Use HTTPS in production
- ✅ Keep dependencies updated
- ✅ Use environment variables for secrets
- ✅ Implement rate limiting (TODO)
- ❌ Never commit secrets to git
- ❌ Never expose production database

## Performance

### Optimization Tips

- Database indexes are created automatically by migrations
- JWT tokens are cached in memory
- Use pagination for large result sets (TODO)
- Enable connection pooling (configured by default)

### Scaling

```bash
# Vertical scaling (Fly.io)
flyctl scale vm shared-cpu-2x --memory 1024 --app expense-split-api-prod

# Horizontal scaling (Fly.io)
flyctl scale count 2 --app expense-split-api-prod
```

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Support

For issues and questions:
- 📖 Check the [documentation](./API_DOCUMENTATION.md)
- 🐛 Create an issue on GitHub
- 💬 Contact: your-email@example.com

## Acknowledgments

- Built with [Vapor](https://vapor.codes)
- Deployed on [Fly.io](https://fly.io)
- Database: [PostgreSQL](https://www.postgresql.org)

---

**Happy Coding! 🚀**