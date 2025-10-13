// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WBCopywriterBot",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        
        // Fluent ORM
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        
        // PostgreSQL driver
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        
        // Sentry for error tracking (works with GlitchTip)
        .package(url: "https://github.com/getsentry/sentry-swift.git", from: "8.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Sentry", package: "sentry-swift"),
            ],
            path: "Sources/App"
        )
        // Tests will be added later
    ]
)

