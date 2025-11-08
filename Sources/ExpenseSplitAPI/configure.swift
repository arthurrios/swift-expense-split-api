import Vapor
import Fluent
import FluentPostgresDriver
import PostgresKit
import JWT

// configures your application
public func configure(_ app: Application) async throws {
    // MARK: - Environment Configuration
    let databaseHost = Environment.get("DATABASE_HOST") ?? "localhost"
    let databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432
    let databaseName = Environment.get("DATABASE_NAME") ?? "expense_split_dev"
    let databaseUsername = Environment.get("DATABASE_USERNAME") ?? "vapor"
    let databasePassword = Environment.get("DATABASE_PASSWORD") ?? "password"
    
    // MARK: - Database Configuration
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
    if let jwtSecret = Environment.get("JWT_SECRET") {
        app.jwt.signers.use(.hs256(key: jwtSecret))
    } else {
        app.logger.warning("JWT_SECRET not set! User default (INSECURE)")
        app.jwt.signers.use(.hs256(key: "secret"))
    }
    
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
    app.middleware.use(LocalizationMiddleware())

    // MARK: - Routes
    try routes(app)
}
