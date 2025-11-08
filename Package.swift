// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ExpenseSplitAPI",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        
        // Fluent (ORM for database operations)
        .package(url: "https://github.com/vapor/fluent.git", from: "4.8.0"),
        
        // 🐘 PostgreSQL Driver
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.7.2"),
        
        // 🔐 JWT Authentication
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.2"),
        
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "4.9.1"),
    ],
    targets: [
        .executableTarget(
            name: "ExpenseSplitAPI",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ExpenseSplitAPITests",
            dependencies: [
                .target(name: "ExpenseSplitAPI"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
