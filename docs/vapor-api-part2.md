# Part 2 - DTOs and Configuration

## Table of Contents
1. [DTOs (Data Transfer Objects)](#1-dtos-data-transfer-objects)
2. [Configure.swift](#2-configureswift)
3. [Routes.swift](#3-routesswift)
4. [Main Entry Point](#4-main-entry-point)

---

## 1. DTOs (Data Transfer Objects)

### File: `Sources/App/Models/DTOs/UserDTOs.swift`

```swift
import Vapor

// MARK: - Sign Up
struct SignUpRequest: Content {
    let name: String
    let email: String
    let password: String
    
    func validate() throws {
        guard name.count >= 2 else {
            throw Abort(.badRequest, reason: "Name must be at least 2 characters long")
        }
        
        guard email.contains("@") && email.contains(".") else {
            throw Abort(.badRequest, reason: "Invalid email format")
        }
        
        guard password.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters long")
        }
    }
}

struct SignUpResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let token: String
}

// MARK: - Sign In
struct SignInRequest: Content {
    let email: String
    let password: String
    
    func validate() throws {
        guard email.count > 0 else {
            throw Abort(.badRequest, reason: "Email is required")
        }
        
        guard password.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters long")
        }
    }
}

struct SignInResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let token: String
}

// MARK: - User Profile
struct UserProfileResponse: Content {
    let id: UUID
    let name: String
    let email: String
    let createdAt: Date?
    
    init(from user: User) {
        self.id = user.id!
        self.name = user.name
        self.email = user.email
        self.createdAt = user.createdAt
    }
}
```

### File: `Sources/App/Models/DTOs/ActivityDTOs.swift`

```swift
import Vapor

// MARK: - Create Activity
struct CreateActivityRequest: Content {
    let title: String
    let activityDate: Date
    
    func validate() throws {
        guard title.count >= 3 else {
            throw Abort(.badRequest, reason: "Activity title must be at least 3 characters long")
        }
    }
}

struct CreateActivityResponse: Content {
    let id: UUID
    let name: String
    let activityDate: Date
    let createdAt: Date?
}

// MARK: - Update Activity
struct UpdateActivityRequest: Content {
    let newTitle: String?
    let newActivityDate: Date?
    
    func validate() throws {
        if let title = newTitle, title.count < 3 {
            throw Abort(.badRequest, reason: "Activity title must be at least 3 characters long")
        }
    }
}

// MARK: - List Activities
struct ActivityListItem: Content {
    let id: UUID
    let name: String
    let totalAmountInCents: Int
    let activityDate: Date
    let participantsAmount: Int
    let expensesAmount: Int
}

struct ActivityListResponse: Content {
    let activities: [ActivityListItem]
}

// MARK: - Activity Summary
struct ActivitySummaryResponse: Content {
    let amountPaidInCents: Int
    let amountPendentInCents: Int
    let totalExpensesAmount: Int
    let activitiesCount: Int
    let expensesCount: Int
    let participantsCount: Int
}

// MARK: - Activity Detail
struct ActivityDetailResponse: Content {
    let id: UUID
    let name: String
    let activityDate: Date
    let participants: [ParticipantInfo]
    let expenses: [ExpenseInfo]
    let totalAmountInCents: Int
    
    struct ParticipantInfo: Content {
        let id: UUID
        let name: String
        let email: String
    }
    
    struct ExpenseInfo: Content {
        let id: UUID
        let name: String
        let amountInCents: Int
        let payerName: String
        let payerId: UUID
        let participantsCount: Int
    }
}
```

### File: `Sources/App/Models/DTOs/ExpenseDTOs.swift`

```swift
import Vapor

// MARK: - Create Expense
struct CreateExpenseRequest: Content {
    let title: String
    let amountInCents: Int
    let payerId: UUID
    let participantsIds: [UUID]
    
    func validate() throws {
        guard title.count >= 3 else {
            throw Abort(.badRequest, reason: "Expense title must be at least 3 characters long")
        }
        
        guard amountInCents > 0 else {
            throw Abort(.badRequest, reason: "Amount must be greater than 0")
        }
        
        guard !participantsIds.isEmpty else {
            throw Abort(.badRequest, reason: "At least one participant is required")
        }
        
        guard Set(participantsIds).count == participantsIds.count else {
            throw Abort(.badRequest, reason: "Duplicate participants are not allowed")
        }
    }
}

struct CreateExpenseResponse: Content {
    let id: UUID
    let name: String
    let amountInCents: Int
    let payerId: UUID
    let activityId: UUID
    let participants: [ParticipantDebt]
    
    struct ParticipantDebt: Content {
        let userId: UUID
        let userName: String
        let amountOwedInCents: Int
    }
}

// MARK: - List Expenses
struct ExpenseListItem: Content {
    let id: UUID
    let name: String
    let totalAmountInCents: Int
    let createdAt: Date?
    let payer: PayerInfo
    let participants: [ParticipantInfo]
    
    struct PayerInfo: Content {
        let userId: UUID
        let name: String
    }
    
    struct ParticipantInfo: Content {
        let userId: UUID
        let name: String
        let amountOwedInCents: Int
        let alreadyPaid: Bool
    }
}

struct ExpenseListResponse: Content {
    let expenses: [ExpenseListItem]
}

// MARK: - Mark Payment
struct MarkPaymentRequest: Content {
    let debtorId: UUID
    let paymentDate: Date?
    
    func validate() throws {
        // paymentDate is optional, defaults to now
    }
}

struct MarkPaymentResponse: Content {
    let success: Bool
    let message: String
    let expense: ExpensePaymentDetail
    
    struct ExpensePaymentDetail: Content {
        let id: UUID
        let name: String
        let amountInCents: Int
        let participants: [ParticipantPaymentStatus]
    }
    
    struct ParticipantPaymentStatus: Content {
        let userId: UUID
        let name: String
        let amountOwedInCents: Int
        let amountPaidInCents: Int
        let isPaidInFull: Bool
    }
}
```

### File: `Sources/App/Models/DTOs/BalanceDTOs.swift`

```swift
import Vapor

// MARK: - Activity Balance (without global compensation)
struct ActivityBalanceResponse: Content {
    let activityId: UUID
    let activityName: String
    let transfers: [Transfer]
    
    struct Transfer: Content {
        let from: UserInfo
        let to: UserInfo
        let amountInCents: Int
    }
    
    struct UserInfo: Content {
        let userId: UUID
        let name: String
    }
}

// MARK: - Balance Between Two Users (global compensation)
struct BalanceBetweenUsersResponse: Content {
    let netBalance: NetBalance?
    let details: [ActivityDetail]
    
    struct NetBalance: Content {
        let debtor: UserInfo
        let creditor: UserInfo
        let amountInCents: Int
    }
    
    struct ActivityDetail: Content {
        let activityName: String
        let activityId: UUID
        let fromUser: String
        let toUser: String
        let amountInCents: Int
    }
    
    struct UserInfo: Content {
        let userId: UUID
        let name: String
    }
}

// MARK: - User Global Balance (all compensations)
struct UserGlobalBalanceResponse: Content {
    let globalNetBalanceInCents: Int
    let compensatedDebts: [CompensatedDebt]
    let compensatedCredits: [CompensatedCredit]
    
    struct CompensatedDebt: Content {
        let creditorName: String
        let creditorId: UUID
        let netAmountInCents: Int
        let activitiesCount: Int
        let activities: [ActivityBreakdown]
    }
    
    struct CompensatedCredit: Content {
        let debtorName: String
        let debtorId: UUID
        let netAmountInCents: Int
        let activitiesCount: Int
        let activities: [ActivityBreakdown]
    }
    
    struct ActivityBreakdown: Content {
        let activityName: String
        let activityId: UUID
        let amountInCents: Int
    }
}

// MARK: - Detailed Balance (without compensation)
struct DetailedBalanceResponse: Content {
    let totalOwedToUserInCents: Int
    let totalUserOwesInCents: Int
    let debts: [DebtDetail]
    let credits: [CreditDetail]
    
    struct DebtDetail: Content {
        let creditorName: String
        let creditorId: UUID
        let amountInCents: Int
        let activityName: String
        let activityId: UUID
        let expenseName: String
        let expenseId: UUID
    }
    
    struct CreditDetail: Content {
        let debtorName: String
        let debtorId: UUID
        let amountInCents: Int
        let activityName: String
        let activityId: UUID
        let expenseName: String
        let expenseId: UUID
    }
}

// MARK: - Participants List
struct ParticipantsListResponse: Content {
    let participants: [ParticipantItem]
    
    struct ParticipantItem: Content {
        let id: UUID
        let name: String
        let email: String
        let relatedActivitiesAmount: Int
    }
}
```

---

## 2. Configure.swift

### File: `Sources/App/configure.swift`

```swift
import Vapor
import Fluent
import FluentPostgresDriver
import JWT

public func configure(_ app: Application) async throws {
    // MARK: - Environment Detection
    let environment = Environment.get("ENVIRONMENT") ?? "development"
    app.logger.info("Running in \(environment) environment")
    
    // MARK: - Server Configuration
    let port = Environment.get("SERVER_PORT").flatMap(Int.init) ?? 8080
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port
    
    // MARK: - Database Configuration
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
    
    // MARK: - JWT Configuration
    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        app.logger.critical("JWT_SECRET environment variable not set!")
        throw Abort(.internalServerError, reason: "JWT secret missing")
    }
    
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // MARK: - Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateActivity())
    app.migrations.add(CreateActivityParticipants())
    app.migrations.add(CreateExpense())
    app.migrations.add(CreateExpenseParticipants())
    app.migrations.add(CreateExpensePayments())
    
    // MARK: - Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // CORS Configuration
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // MARK: - Register Routes
    try routes(app)
    
    // MARK: - Run Migrations
    if environment != "production" {
        try await app.autoMigrate()
        app.logger.info("Migrations completed successfully")
    } else {
        app.logger.warning("Skipping auto-migration in production. Run migrations manually.")
    }
    
    app.logger.info("Application configured successfully on port \(port)")
}
```

---

## 3. Routes.swift

### File: `Sources/App/routes.swift`

```swift
import Vapor

func routes(_ app: Application) throws {
    // MARK: - Health Check
    app.get("health") { req async -> HTTPStatus in
        return .ok
    }
    
    app.get { req async -> String in
        return "Expense Split API - Version 1.0"
    }
    
    // MARK: - API v1 Routes
    let api = app.grouped("api", "v1")
    
    // MARK: - Auth Routes (Public)
    let authController = AuthController()
    let authRoutes = api.grouped("users")
    authRoutes.post("sign-up", use: authController.signUp)
    authRoutes.post("sign-in", use: authController.signIn)
    
    // MARK: - Protected Routes (Require Authentication)
    let protected = api.grouped(UserToken.authenticator(), User.guardMiddleware())
    
    // User Profile
    protected.get("users", "me", use: authController.getProfile)
    
    // Activities
    let activityController = ActivityController()
    protected.post("activity", use: activityController.create)
    protected.put("activity", ":activityId", use: activityController.update)
    protected.get("activity", ":userId", use: activityController.list)
    protected.get("activity", "detail", ":activityId", use: activityController.detail)
    
    // Activity Summary
    protected.get("activity", "summary", ":userId", use: activityController.summary)
    
    // Expenses
    let expenseController = ExpenseController()
    protected.post("expense", ":activityId", use: expenseController.create)
    protected.get("expenses", ":activityId", use: expenseController.list)
    protected.post("expense", ":expenseId", "payment", use: expenseController.markPayment)
    
    // Participants
    let participantController = ParticipantController()
    protected.get("participants", ":userId", use: participantController.list)
    
    // Balance
    let balanceController = BalanceController()
    protected.get("activity", ":activityId", "balance", use: balanceController.activityBalance)
    protected.get("balance", "between", ":userId1", ":userId2", use: balanceController.balanceBetweenUsers)
    protected.get("balance", "user", ":userId", use: balanceController.userGlobalBalance)
    protected.get("user", ":userId", "balance", "detailed", use: balanceController.detailedBalance)
    
    app.logger.info("Routes registered successfully")
}
```

---

## 4. Main Entry Point

### File: `Sources/Run/main.swift`

```swift
import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }

do {
    try await configure(app)
    try app.run()
} catch {
    app.logger.critical("Failed to start application: \(error)")
    throw error
}
```

---

## Summary

This part covered:

1. ✅ **All DTOs** - Request/Response objects for:
   - User authentication (sign up, sign in)
   - Activities (create, update, list, summary)
   - Expenses (create, list, mark payment)
   - Balance calculations (activity, between users, global)
   - Participants listing

2. ✅ **Configure.swift** - Complete application setup:
   - Environment detection
   - Database configuration
   - JWT authentication setup
   - Migrations registration
   - CORS middleware
   - Auto-migration for dev/test environments

3. ✅ **Routes.swift** - All API endpoints:
   - Public routes (health check, sign up, sign in)
   - Protected routes (everything else)
   - RESTful organization

4. ✅ **Main entry point** - Application bootstrap

**Next up: Part 3 - Controllers Implementation**

This will include the complete implementation of:
- AuthController
- ActivityController
- ExpenseController
- ParticipantController
