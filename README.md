<div align="center">

**English** | [Português (BR)](./README.pt-BR.md)

</div>

---

# Expense Split API

A RESTful API for splitting expenses between friends, built with Swift and Vapor 4.

## ✨ Features

- 🔐 **JWT Authentication** - Secure token-based authentication
- 💰 **Expense Tracking** - Create and manage expenses with equal splitting
- 🔄 **Global Debt Compensation** - Automatic balance calculation across all activities
- 👥 **Multi-user Support** - Multiple users per activity
- 🌍 **Internationalization** - English and Portuguese (pt-BR) support
- 📚 **OpenAPI/Swagger** - Interactive API documentation
- 🐳 **Docker Support** - Easy local development
- ☁️ **Render.com Ready** - Free tier deployment configuration

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- PostgreSQL 16 (included in Docker Compose)

### Local Development

```bash
# Clone repository
git clone <your-repo-url>
cd ExpenseSplitAPI

# Start with Docker Compose
docker compose up -d

# API will be available at http://localhost:8080
# Swagger docs at http://localhost:8080/docs

# Check logs
docker compose logs -f app

# Stop services
docker compose down
```

### First Request

```bash
# Health check
curl http://localhost:8080/health

# Sign up
curl -X POST http://localhost:8080/api/v1/users/sign-up \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "password123"
  }'
```

## 📚 Documentation

- **Interactive API Docs**: http://localhost:8080/docs (Swagger UI)
- **OpenAPI Spec**: http://localhost:8080/openapi.json
- **Insomnia Collection**: [`.insomnia/ExpenseSplitAPI.yaml`](./.insomnia/ExpenseSplitAPI.yaml)

## 🏗️ Project Structure

```
ExpenseSplitAPI/
├── Sources/ExpenseSplitAPI/
│   ├── Controllers/          # Request handlers
│   │   ├── AuthController.swift
│   │   ├── ActivityController.swift
│   │   ├── ExpenseController.swift
│   │   ├── ParticipantController.swift
│   │   └── BalanceController.swift
│   ├── Models/               # Data models & DTOs
│   │   ├── User.swift
│   │   ├── Activity.swift
│   │   ├── Expense.swift
│   │   └── DTOs/
│   ├── Services/              # Business logic
│   │   ├── BalanceService.swift
│   │   ├── CompensationService.swift
│   │   └── LocalizedText.swift
│   ├── Middleware/           # Custom middleware
│   │   ├── UserAuthenticator.swift
│   │   └── LocalizationMiddleware.swift
│   ├── Migrations/           # Database migrations
│   └── Resources/            # Localization files
│       └── Localizable.xcstrings
├── .insomnia/                # Insomnia collection
├── Public/swagger/           # Swagger UI files
├── docker-compose.yml        # Local development
├── render.yaml               # Render.com deployment
└── Dockerfile                # Docker image
```

## 🔌 API Endpoints

### Authentication
- `POST /api/v1/users/sign-up` - Register new user
- `POST /api/v1/users/sign-in` - Authenticate and get JWT token
- `GET /api/v1/users/me` - Get current user profile (Protected)

### Activities
- `POST /api/v1/activities` - Create activity
- `GET /api/v1/users/:userId/activities` - List user's activities
- `GET /api/v1/activities/:activityId` - Get activity details
- `PUT /api/v1/activities/:activityId` - Update activity
- `DELETE /api/v1/activities/:activityId` - Delete activity

### Expenses
- `POST /api/v1/activities/:activityId/expenses` - Create expense
- `GET /api/v1/activities/:activityId/expenses` - List expenses
- `GET /api/v1/expenses/:expenseId` - Get expense details
- `PUT /api/v1/expenses/:expenseId` - Update expense
- `PUT /api/v1/expenses/:expenseId/payer` - Set/update payer
- `POST /api/v1/expenses/:expenseId/payments` - Mark payment
- `DELETE /api/v1/expenses/:expenseId` - Delete expense

### Participants
- `POST /api/v1/activities/:activityId/participants` - Add participants
- `GET /api/v1/activities/:activityId/participants` - List participants
- `DELETE /api/v1/activities/:activityId/participants/:userId` - Remove participant

### Balance
- `GET /api/v1/activities/:activityId/balance` - Activity balance
- `GET /api/v1/balance/between/:userId1/:userId2` - Balance between users
- `GET /api/v1/balance/users/:userId/global` - User global balance
- `GET /api/v1/balance/users/:userId/detailed` - Detailed balance

## 🌍 Internationalization

The API supports multiple languages via `Accept-Language` header or `lang` query parameter:

```bash
# Portuguese (default in test environment)
curl -H "Accept-Language: pt-BR" http://localhost:8080/api/v1/users/sign-in

# English
curl -H "Accept-Language: en" http://localhost:8080/api/v1/users/sign-in

# Or use query parameter
curl "http://localhost:8080/api/v1/users/sign-in?lang=en"
```

Supported languages:
- 🇺🇸 English (en)
- 🇧🇷 Portuguese (pt-BR)

## 🧪 Testing

### Using Insomnia

1. Import the collection from `.insomnia/ExpenseSplitAPI.yaml`
2. Configure environment variable `baseURL` to `http://localhost:8080/api/v1`
3. Start with **Sign In** request (uses seed data: `alice@example.com` / `12121212`)
4. Token is automatically saved and used in protected requests

### Seed Data

When `SEED_DATABASE=true`, the following test users are created:

| Email | Password | Name |
|-------|----------|------|
| `alice@example.com` | `12121212` | Alice Johnson |
| `bob@example.com` | `12121212` | Bob Smith |
| `charlie@example.com` | `12121212` | Charlie Brown |
| `diana@example.com` | `12121212` | Diana Prince |

## ⚙️ Environment Variables

### Required

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_HOST` | PostgreSQL host | `localhost` |
| `DATABASE_PORT` | PostgreSQL port | `5432` |
| `DATABASE_NAME` | Database name | `expense_split_dev` |
| `DATABASE_USERNAME` | Database user | `vapor` |
| `DATABASE_PASSWORD` | Database password | `password` |
| `JWT_SECRET` | JWT signing secret (min 32 chars) | - |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment name | `development` |
| `SERVER_PORT` | Server port | `8080` |
| `DEFAULT_LOCALE` | Default locale | `en` (prod), `pt-BR` (test) |
| `SEED_DATABASE` | Enable database seeding | `false` |

## 🐳 Docker Commands

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f app

# Stop services
docker compose down

# Reset database (removes all data)
docker compose down -v
docker compose up -d

# Rebuild after code changes
docker compose build app
docker compose up -d
```

## ☁️ Deployment

### Render.com (Free Tier)

1. Push code to GitHub
2. Go to [Render.com](https://render.com) and create new Blueprint
3. Connect your repository
4. Render will automatically detect `render.yaml` and deploy both environments

**Environments:**
- **Production**: `https://expense-split-api-prod.onrender.com`
- **Test/Students**: `https://expense-split-api-test.onrender.com`

See [render.yaml](./render.yaml) for configuration.

## 🔒 Security

- ✅ JWT token-based authentication
- ✅ Password hashing with Bcrypt
- ✅ Input validation on all endpoints
- ✅ Localized error messages
- ✅ CORS support
- ✅ SQL injection protection (via Fluent ORM)

## 📊 Database Schema

```
users
├── activities (many-to-many via activity_participants)
├── expenses (as payer)
└── expense_participants (as debtor)

activities
├── participants (many-to-many via activity_participants)
└── expenses

expenses
├── payer (optional, can be set later)
├── participants (many-to-many via expense_participants)
└── payments (via expense_payments)
```

## 🛠️ Development

### Running Locally (without Docker)

```bash
# Install Swift 6.1+
# Install PostgreSQL

# Create database
createdb expense_split_dev

# Set environment variables
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_NAME=expense_split_dev
export DATABASE_USERNAME=your_username
export DATABASE_PASSWORD=your_password
export JWT_SECRET=your-secret-key-min-32-chars
export ENVIRONMENT=development

# Build and run
swift build
swift run
```

### Running Tests

```bash
swift test
```

## 📝 License

MIT License - see [LICENSE](./LICENSE) file for details

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

- 📖 **API Documentation**: http://localhost:8080/docs
- 🐛 **Issues**: Create an issue on GitHub
- 💬 **Questions**: Check the documentation or open a discussion

## 🙏 Acknowledgments

- Built with [Vapor](https://vapor.codes) - Server-side Swift framework
- Database: [PostgreSQL](https://www.postgresql.org)
- API Documentation: [Swagger UI](https://swagger.io/tools/swagger-ui/)
- Deployment: [Render.com](https://render.com)

---

<div align="center">

**Made with ❤️ using Swift & Vapor**

[English](./README.md) | [Português (BR)](./README.pt-BR.md)

</div>
