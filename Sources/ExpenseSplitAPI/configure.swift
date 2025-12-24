import Fluent
import FluentPostgresDriver
import JWT
import PostgresKit
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
  // MARK: - Environment Detection
  let environment = Environment.get("ENVIRONMENT") ?? "development"
  app.logger.info("Running in \(environment) environment")

  // MARK: - Server Configuration
  // Render uses PORT, fallback to SERVER_PORT, then default to 8080
  let port =
    Environment.get("PORT").flatMap(Int.init) ?? Environment.get("SERVER_PORT").flatMap(Int.init)
    ?? 8080
  app.http.server.configuration.hostname = "0.0.0.0"
  app.http.server.configuration.port = port

  // MARK: - Database Configuration
  // Render provides individual variables, not DATABASE_URL
  guard let databaseHost = Environment.get("DATABASE_HOST"),
    let databaseName = Environment.get("DATABASE_NAME"),
    let databaseUsername = Environment.get("DATABASE_USERNAME"),
    let databasePassword = Environment.get("DATABASE_PASSWORD")
  else {
    app.logger.critical("Database environment variables not set!")
    throw Abort(.internalServerError, reason: "Database configuration missing")
  }

  let databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432

  let postgresConfig = SQLPostgresConfiguration(
    hostname: databaseHost,
    port: databasePort,
    username: databaseUsername,
    password: databasePassword,
    database: databaseName,
    tls: .disable
  )

  app.databases.use(
    .postgres(
      configuration: postgresConfig
    ),
    as: .psql
  )

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

  // MARK: - Seed Database (optional, set SEED_DATABASE=true to enable)
  let seedDatabase = Environment.get("SEED_DATABASE")
  if seedDatabase == "true" {
    app.migrations.add(SeedDatabase())
  }

  // MARK: - Content Configuration (Date Decoding)
  // Configure date decoder to accept ISO-8601 with fractional seconds (e.g., "2025-11-10T10:00:00.261Z")
  let jsonEncoder = JSONEncoder()
  jsonEncoder.dateEncodingStrategy = .iso8601

  let jsonDecoder = JSONDecoder()
  jsonDecoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)

    // Create formatters inside closure to avoid Sendable issues
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // Try parsing with fractional seconds first
    if let date = dateFormatter.date(from: dateString) {
      return date
    }

    // Fallback to standard ISO8601 without fractional seconds
    let standardFormatter = ISO8601DateFormatter()
    standardFormatter.formatOptions = [.withInternetDateTime]
    if let date = standardFormatter.date(from: dateString) {
      return date
    }

    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Expected date string to be ISO8601-formatted."
    )
  }

  ContentConfiguration.global.use(encoder: jsonEncoder, for: .json)
  ContentConfiguration.global.use(decoder: jsonDecoder, for: .json)

  // MARK: - Middleware
  app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
  app.middleware.use(LocalizationMiddleware())

  // MARK: - Routes
  try routes(app)

  // MARK: - Run Migrations
  // Always run migrations on Render (safe for production)
  try await app.autoMigrate()
  app.logger.info("Migrations completed successfully")

  // MARK: - Verify Seed (if enabled)
  if seedDatabase == "true" {
    let db = app.db
    let userCount = try await User.query(on: db).count()
    let activityCount = try await Activity.query(on: db).count()
    let expenseCount = try await Expense.query(on: db).count()
    let paymentCount = try await ExpensePayment.query(on: db).count()

    app.logger.info(
      "📊 [SEED] Users: \(userCount), Activities: \(activityCount), Expenses: \(expenseCount), Payments: \(paymentCount)"
    )
  }

  app.logger.info("Application configured successfully on port \(port)")
}
