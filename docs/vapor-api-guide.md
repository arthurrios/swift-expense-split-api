# Complete Guide - Expense Split API with Vapor (Swift)

## Table of Contents
1. [Introduction and Architecture](#1-introduction-and-architecture)
2. [Initial Setup](#2-initial-setup)
3. [Project Structure](#3-project-structure)
4. [Database Configuration](#4-database-configuration)
5. [Implementing Models](#5-implementing-models)
6. [Migrations](#6-migrations)
7. [Controllers and Routes](#7-controllers-and-routes)
8. [JWT Authentication](#8-jwt-authentication)
9. [Compensation Logic](#9-compensation-logic)
10. [Environments (Prod and Test)](#10-environments-prod-and-test)
11. [Docker Setup](#11-docker-setup)
12. [Deploying to Fly.io](#12-deploying-to-flyio)
13. [Testing](#13-testing)

---

## 1. Introduction and Architecture

### What We're Building
A complete REST API for splitting expenses between friends, featuring:
- JWT Authentication
- Multiple environments (production and students)
- Global debt compensation system
- Deployment via Docker and Fly.io

### Technology Stack
- **Backend**: Swift + Vapor 4
- **Database**: PostgreSQL
- **Cache/Sessions**: Redis (optional)
- **Deployment**: Docker + Fly.io
- **Testing**: XCTest

### Environment Architecture

```
┌─────────────────────────────────────────┐
│         Fly.io (Production)             │
│  ┌───────────────────────────────────┐  │
│  │   Vapor API (Production)          │  │
│  │   - ENV: production               │  │
│  │   - DB: postgres-prod             │  │
│  │   - Access: Only you              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Fly.io (Students/Test)             │
│  ┌───────────────────────────────────┐  │
│  │   Vapor API (Testing)             │  │
│  │   - ENV: testing                  │  │
│  │   - DB: postgres-test             │  │
│  │   - Access: Public for students   │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│      Docker Local (Development)         │
│  ┌───────────────────────────────────┐  │
│  │   Vapor API (Development)         │  │
│  │   - ENV: development              │  │
│  │   - DB: postgres-dev (Docker)     │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## 2. Initial Setup

### Option A: With macOS (Recommended for development)

```bash
# Install Homebrew (if you don't have it)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Swift and Vapor
brew install vapor

# Verify installation
vapor --version
swift --version
```

### Option B: Without macOS (Docker Only)

```bash
# Only Docker needed
# Install Docker Desktop
# https://www.docker.com/products/docker-desktop

# Verify installation
docker --version
docker-compose --version
```

### Create the Project

```bash
# With Vapor Toolbox (macOS)
vapor new ExpenseSplitAPI --no-fluent

# Or without Vapor Toolbox (any OS)
mkdir ExpenseSplitAPI
cd ExpenseSplitAPI

# Initialize Package.swift manually (see below)
```

### Package.swift Structure

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExpenseSplitAPI",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // Vapor Framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        
        // Fluent (ORM)
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.7.2"),
        
        // JWT
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWT", package: "jwt"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        )
    ]
)
```

---

## 3. Project Structure

```
ExpenseSplitAPI/
├── Package.swift
├── Dockerfile
├── docker-compose.yml
├── fly.toml (production)
├── fly-test.toml (students)
├── .env.development
├── .env.testing
├── .env.production
├── .dockerignore
├── .gitignore
├── README.md
│
├── Sources/
│   ├── App/
│   │   ├── configure.swift
│   │   ├── routes.swift
│   │   │
│   │   ├── Models/
│   │   │   ├── User.swift
│   │   │   ├── Activity.swift
│   │   │   ├── Expense.swift
│   │   │   ├── UserToken.swift
│   │   │   └── DTOs/
│   │   │       ├── UserDTOs.swift
│   │   │       ├── ActivityDTOs.swift
│   │   │       ├── ExpenseDTOs.swift
│   │   │       └── BalanceDTOs.swift
│   │   │
│   │   ├── Migrations/
│   │   │   ├── CreateUser.swift
│   │   │   ├── CreateActivity.swift
│   │   │   ├── CreateExpense.swift
│   │   │   ├── CreateActivityParticipants.swift
│   │   │   ├── CreateExpenseParticipants.swift
│   │   │   ├── CreateExpensePayments.swift
│   │   │   └── CreateUserToken.swift
│   │   │
│   │   ├── Controllers/
│   │   │   ├── AuthController.swift
│   │   │   ├── ActivityController.swift
│   │   │   ├── ExpenseController.swift
│   │   │   ├── BalanceController.swift
│   │   │   └── ParticipantController.swift
│   │   │
│   │   ├── Services/
│   │   │   ├── BalanceService.swift
│   │   │   └── CompensationService.swift
│   │   │
│   │   └── Middleware/
│   │       ├── UserAuthenticator.swift
│   │       └── EnvironmentMiddleware.swift
│   │
│   └── Run/
│       └── main.swift
│
└── Tests/
    └── AppTests/
        ├── AuthTests.swift
        ├── ActivityTests.swift
        ├── ExpenseTests.swift
        └── BalanceTests.swift
```

---

## 4. Database Configuration

### File: `.env.development`
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=expense_split_dev
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=password
JWT_SECRET=your-super-secret-jwt-key-dev-change-in-production
ENVIRONMENT=development
SERVER_PORT=8080
```

### File: `.env.testing`
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=expense_split_test
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=password
JWT_SECRET=your-super-secret-jwt-key-test
ENVIRONMENT=testing
SERVER_PORT=8081
```

### File: `.env.production`
```env
# This will be set in Fly.io secrets, not committed to git
DATABASE_HOST=your-prod-db-host
DATABASE_PORT=5432
DATABASE_NAME=expense_split_prod
DATABASE_USERNAME=vapor_prod
DATABASE_PASSWORD=super-secure-production-password
JWT_SECRET=your-super-secret-jwt-key-prod
ENVIRONMENT=production
SERVER_PORT=8080
```

### File: `.gitignore`
```
.DS_Store
.build/
.swiftpm/
*.xcodeproj
*.xcworkspace
.env*
!.env.example
DerivedData/
.vscode/
xcuserdata/
```

### File: `.env.example`
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=expense_split_dev
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=password
JWT_SECRET=change-this-secret
ENVIRONMENT=development
SERVER_PORT=8080
```

---

## 5. Implementing Models

### File: `Sources/App/Models/User.swift`

```swift
import Vapor
import Fluent
import JWT

final class User: Model, Content {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Children(for: \.$user)
    var tokens: [UserToken]
    
    @Siblings(through: ActivityParticipant.self, from: \.$user, to: \.$activity)
    var activities: [Activity]
    
    @Siblings(through: ExpenseParticipant.self, from: \.$user, to: \.$expense)
    var expenses: [Expense]
    
    init() {}
    
    init(id: UUID? = nil, name: String, email: String, passwordHash: String) {
        self.id = id
        self.name = name
        self.email = email
        self.passwordHash = passwordHash
    }
}

// MARK: - ModelAuthenticatable
extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$passwordHash
    
    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

// MARK: - JWT Payload
struct UserPayload: JWTPayload {
    var userId: UUID
    var email: String
    var exp: ExpirationClaim
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}
```

### File: `Sources/App/Models/UserToken.swift`

```swift
import Vapor
import Fluent

final class UserToken: Model, Content {
    static let schema = "user_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "value")
    var value: String
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "expires_at", on: .none)
    var expiresAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, value: String, userID: UUID, expiresAt: Date? = nil) {
        self.id = id
        self.value = value
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}

extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user
    
    var isValid: Bool {
        guard let expiresAt = expiresAt else {
            return true
        }
        return expiresAt > Date()
    }
}
```

### File: `Sources/App/Models/Activity.swift`

```swift
import Vapor
import Fluent

final class Activity: Model, Content {
    static let schema = "activities"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "activity_date")
    var activityDate: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Siblings(through: ActivityParticipant.self, from: \.$activity, to: \.$user)
    var participants: [User]
    
    @Children(for: \.$activity)
    var expenses: [Expense]
    
    init() {}
    
    init(id: UUID? = nil, name: String, activityDate: Date) {
        self.id = id
        self.name = name
        self.activityDate = activityDate
    }
}

// Pivot table for Activity-User many-to-many relationship
final class ActivityParticipant: Model {
    static let schema = "activity_participants"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "activity_id")
    var activity: Activity
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "joined_at", on: .create)
    var joinedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, activityID: UUID, userID: UUID) {
        self.id = id
        self.$activity.id = activityID
        self.$user.id = userID
    }
}
```

### File: `Sources/App/Models/Expense.swift`

```swift
import Vapor
import Fluent

final class Expense: Model, Content {
    static let schema = "expenses"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "amount_in_cents")
    var amountInCents: Int
    
    @Parent(key: "payer_id")
    var payer: User
    
    @Parent(key: "activity_id")
    var activity: Activity
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @Siblings(through: ExpenseParticipant.self, from: \.$expense, to: \.$user)
    var participants: [User]
    
    @Children(for: \.$expense)
    var payments: [ExpensePayment]
    
    init() {}
    
    init(id: UUID? = nil, name: String, amountInCents: Int, payerID: UUID, activityID: UUID) {
        self.id = id
        self.name = name
        self.amountInCents = amountInCents
        self.$payer.id = payerID
        self.$activity.id = activityID
    }
}

// Pivot table for Expense-User many-to-many relationship (debtors)
final class ExpenseParticipant: Model {
    static let schema = "expense_participants"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "expense_id")
    var expense: Expense
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "amount_owed_in_cents")
    var amountOwedInCents: Int
    
    @Timestamp(key: "added_at", on: .create)
    var addedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, expenseID: UUID, userID: UUID, amountOwedInCents: Int) {
        self.id = id
        self.$expense.id = expenseID
        self.$user.id = userID
        self.amountOwedInCents = amountOwedInCents
    }
}

// Track payments made by debtors
final class ExpensePayment: Model, Content {
    static let schema = "expense_payments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "expense_id")
    var expense: Expense
    
    @Parent(key: "debtor_id")
    var debtor: User
    
    @Field(key: "amount_paid_in_cents")
    var amountPaidInCents: Int
    
    @Timestamp(key: "paid_at", on: .create)
    var paidAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, expenseID: UUID, debtorID: UUID, amountPaidInCents: Int) {
        self.id = id
        self.$expense.id = expenseID
        self.$debtor.id = debtorID
        self.amountPaidInCents = amountPaidInCents
    }
}
```

---

## 6. Migrations

### File: `Sources/App/Migrations/CreateUser.swift`

```swift
import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateUserToken.swift`

```swift
import Fluent

struct CreateUserToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_tokens")
            .id()
            .field("value", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("expires_at", .datetime)
            .unique(on: "value")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("user_tokens").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateActivity.swift`

```swift
import Fluent

struct CreateActivity: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("activities")
            .id()
            .field("name", .string, .required)
            .field("activity_date", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("activities").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateActivityParticipants.swift`

```swift
import Fluent

struct CreateActivityParticipants: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("activity_participants")
            .id()
            .field("activity_id", .uuid, .required, .references("activities", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("joined_at", .datetime)
            .unique(on: "activity_id", "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("activity_participants").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateExpense.swift`

```swift
import Fluent

struct CreateExpense: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("expenses")
            .id()
            .field("name", .string, .required)
            .field("amount_in_cents", .int, .required)
            .field("payer_id", .uuid, .required, .references("users", "id"))
            .field("activity_id", .uuid, .required, .references("activities", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("expenses").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateExpenseParticipants.swift`

```swift
import Fluent

struct CreateExpenseParticipants: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("expense_participants")
            .id()
            .field("expense_id", .uuid, .required, .references("expenses", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("amount_owed_in_cents", .int, .required)
            .field("added_at", .datetime)
            .unique(on: "expense_id", "user_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("expense_participants").delete()
    }
}
```

### File: `Sources/App/Migrations/CreateExpensePayments.swift`

```swift
import Fluent

struct CreateExpensePayments: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("expense_payments")
            .id()
            .field("expense_id", .uuid, .required, .references("expenses", "id", onDelete: .cascade))
            .field("debtor_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("amount_paid_in_cents", .int, .required)
            .field("paid_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("expense_payments").delete()
    }
}
```

---

This is Part 1 of the complete guide. Would you like me to continue with:
- Part 2: DTOs, Controllers, and Routes
- Part 3: Services (Balance and Compensation Logic)
- Part 4: Docker and Deployment Configuration
- Part 5: Testing Setup

Let me know which part you'd like next!