import Vapor
import Fluent
import FluentPostgresDriver
import PostgresKit
import NIOSSL

public func configure(_ app: Application) async throws {
    // Load environment config
    app.environmentConfig = try EnvironmentConfig.load()
    let config = app.environmentConfig
    
    // MARK: - Logging Configuration
    
    // Устанавливаем уровень логирования из ENV (production = info, development = debug)
    let logLevel: Logger.Level = config.environment == "production" ? .info : .debug
    app.logger.logLevel = logLevel
    app.logger.info("📝 Log level set to: \(logLevel) (environment: \(config.environment))")
    
    // MARK: - Server Configuration
    
    // Railway provides PORT environment variable
    if let portString = Environment.get("PORT"), let port = Int(portString) {
        app.http.server.configuration.port = port
        app.logger.info("🌐 Server will listen on port: \(port)")
    } else {
        app.http.server.configuration.port = 8080
        app.logger.info("🌐 Server will listen on default port: 8080")
    }
    
    app.http.server.configuration.hostname = "0.0.0.0"
    
    // MARK: - Database Configuration
    
    // Railway uses DATABASE_URL, local uses separate variables
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Production: Parse DATABASE_URL (Railway format)
        // postgres://user:password@host:port/database
        // Railway требует SSL но с разрешением самоподписанных сертификатов
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateVerification = .none
        
        let nioSSLContext = try NIOSSLContext(configuration: tlsConfig)
        
        var postgresConfig = try SQLPostgresConfiguration(url: databaseURL)
        postgresConfig.coreConfiguration.tls = .require(nioSSLContext)
        
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
        app.logger.info("📦 Database connected via DATABASE_URL (SSL enabled)")
    } else {
        // Development: Use separate variables without SSL
        let postgresConfig = SQLPostgresConfiguration(
            hostname: config.databaseHost,
            port: config.databasePort,
            username: config.databaseUsername,
            password: config.databasePassword,
            database: config.databaseName,
            tls: .disable
        )
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
        app.logger.info("📦 Database connected: \(config.databaseHost):\(config.databasePort)/\(config.databaseName)")
    }
    
    // MARK: - Migrations
    
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateSubscriptions())
    app.migrations.add(CreateGenerations())
    app.migrations.add(AddPhotoGenerationsToUsers())
    app.migrations.add(AddCreditsToUsers())
    app.migrations.add(CreateProcessedWebhooks())
    
    // Автоматически запускать миграции при старте (для Railway)
    if app.environment == .production {
        try await app.autoMigrate()
        app.logger.info("✅ Database migrations completed")
    }
    
    // MARK: - Middleware
    
    // Request logging
    app.middleware.use(RequestLoggingMiddleware())
    
    // Error handling
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // MARK: - Claude Service
    
    let claudeService = ClaudeService(
        app: app,
        apiKey: config.claudeApiKey
    )
    app.claude = claudeService
    
    // MARK: - Tribute Service (Payments)
    
    let tributeService = TributeService(
        app: app,
        apiKey: config.tributeApiKey,
        apiSecret: config.tributeSecret
    )
    app.tribute = tributeService
    app.logger.info("✅ TributeService configured")
    
    // MARK: - Telegram Bot Service
    
    let botService = TelegramBotService(
        app: app,
        botToken: config.telegramBotToken
    )
    app.telegramBot = botService
    
    // MARK: - Telegram Long Polling
    
    let pollingService = TelegramPollingService(
        app: app,
        botToken: config.telegramBotToken
    )
    app.telegramPolling = pollingService
    
    // MARK: - Routes
    
    try routes(app)
    
    app.logger.info("✅ КарточкаПРО configured successfully")
    app.logger.info("🌍 Environment: \(config.environment)")
    app.logger.info("📝 Log level: \(config.logLevel)")
    app.logger.info("🤖 Bot: @kartochka_pro (polling mode)")
}

