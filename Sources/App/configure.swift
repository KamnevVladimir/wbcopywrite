import Vapor
import Fluent
import FluentPostgresDriver

public func configure(_ app: Application) async throws {
    // Load environment config
    app.environmentConfig = try EnvironmentConfig.load()
    let config = app.environmentConfig
    
    // MARK: - Database Configuration
    
    // Railway uses DATABASE_URL, local uses separate variables
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Production: Parse DATABASE_URL (Railway format)
        // postgres://user:password@host:port/database
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
        app.logger.info("📦 Database connected via DATABASE_URL")
    } else {
        // Development: Use separate variables
        app.databases.use(
            .postgres(
                hostname: config.databaseHost,
                port: config.databasePort,
                username: config.databaseUsername,
                password: config.databasePassword,
                database: config.databaseName
            ),
            as: .psql
        )
        app.logger.info("📦 Database connected: \(config.databaseHost):\(config.databasePort)/\(config.databaseName)")
    }
    
    // MARK: - Migrations
    
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateSubscriptions())
    app.migrations.add(CreateGenerations())
    
    // MARK: - Middleware
    
    // Error handling
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Telegram Long Polling
    
    let pollingService = TelegramPollingService(
        app: app,
        botToken: config.telegramBotToken
    )
    app.telegramPolling = pollingService
    
    // Start polling after server starts
    app.lifecycle.use(
        TelegramPollingLifecycleHandler(pollingService: pollingService)
    )
    
    // MARK: - Routes
    
    try routes(app)
    
    app.logger.info("✅ КарточкаПРО configured successfully")
    app.logger.info("🌍 Environment: \(config.environment)")
    app.logger.info("📝 Log level: \(config.logLevel)")
    app.logger.info("🤖 Bot: @kartochka_pro (polling mode)")
}

// MARK: - Lifecycle Handler

struct TelegramPollingLifecycleHandler: LifecycleHandler {
    let pollingService: TelegramPollingService
    
    func didBoot(_ application: Application) throws {
        // Start polling after server is ready
        pollingService.start()
    }
    
    func shutdown(_ application: Application) {
        // Graceful shutdown
        Task {
            await pollingService.stop()
        }
    }
}

