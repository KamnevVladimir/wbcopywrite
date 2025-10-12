import Vapor

/// Environment configuration wrapper
struct EnvironmentConfig {
    // Application
    let environment: String
    let logLevel: String
    
    // Server
    let serverHost: String
    let serverPort: Int
    
    // Database
    let databaseHost: String
    let databasePort: Int
    let databaseName: String
    let databaseUsername: String
    let databasePassword: String
    
    // Telegram
    let telegramBotToken: String
    let telegramWebhookUrl: String?
    
    // Claude
    let claudeApiKey: String
    let claudeApiUrl: String
    let claudeModel: String
    
    // Tribute
    let tributeApiKey: String
    let tributeSecret: String
    let tributeApiUrl: String
    
    // Rate limits
    let rateLimitFree: Int
    let rateLimitStarter: Int
    let rateLimitBusiness: Int
    let rateLimitPro: Int
    
    static func load() throws -> EnvironmentConfig {
        guard let telegramToken = Environment.get("TELEGRAM_BOT_TOKEN") else {
            throw ConfigError.missingEnvironmentVariable("TELEGRAM_BOT_TOKEN")
        }
        
        guard let claudeKey = Environment.get("CLAUDE_API_KEY") else {
            throw ConfigError.missingEnvironmentVariable("CLAUDE_API_KEY")
        }
        
        return EnvironmentConfig(
            environment: Environment.get("ENVIRONMENT") ?? "development",
            logLevel: Environment.get("LOG_LEVEL") ?? "debug",
            
            serverHost: Environment.get("SERVER_HOST") ?? "0.0.0.0",
            serverPort: Int(Environment.get("SERVER_PORT") ?? "8080") ?? 8080,
            
            databaseHost: Environment.get("DATABASE_HOST") ?? "localhost",
            databasePort: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432,
            databaseName: Environment.get("DATABASE_NAME") ?? "wbcopywriter",
            databaseUsername: Environment.get("DATABASE_USERNAME") ?? "postgres",
            databasePassword: Environment.get("DATABASE_PASSWORD") ?? "postgres",
            
            telegramBotToken: telegramToken,
            telegramWebhookUrl: Environment.get("TELEGRAM_WEBHOOK_URL"),
            
            claudeApiKey: claudeKey,
            claudeApiUrl: Environment.get("CLAUDE_API_URL") ?? "https://api.anthropic.com/v1/messages",
            claudeModel: Environment.get("CLAUDE_MODEL") ?? "claude-3-5-sonnet-20241022",
            
            tributeApiKey: Environment.get("TRIBUTE_API_KEY") ?? "test_key",
            tributeSecret: Environment.get("TRIBUTE_SECRET") ?? "test_secret",
            tributeApiUrl: Environment.get("TRIBUTE_API_URL") ?? "https://api.tribute.to/v1",
            
            rateLimitFree: Int(Environment.get("RATE_LIMIT_FREE") ?? "3") ?? 3,
            rateLimitStarter: Int(Environment.get("RATE_LIMIT_STARTER") ?? "30") ?? 30,
            rateLimitBusiness: Int(Environment.get("RATE_LIMIT_BUSINESS") ?? "150") ?? 150,
            rateLimitPro: Int(Environment.get("RATE_LIMIT_PRO") ?? "500") ?? 500
        )
    }
    
    var isDevelopment: Bool {
        environment == "development"
    }
    
    var isProduction: Bool {
        environment == "production"
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case missingEnvironmentVariable(String)
    
    var description: String {
        switch self {
        case .missingEnvironmentVariable(let name):
            return "Missing required environment variable: \(name)"
        }
    }
}

// Extension для удобного доступа из Application
extension Application {
    struct EnvironmentConfigKey: StorageKey {
        typealias Value = EnvironmentConfig
    }
    
    var environmentConfig: EnvironmentConfig {
        get {
            guard let config = storage[EnvironmentConfigKey.self] else {
                fatalError("EnvironmentConfig not configured. Call app.environmentConfig = try EnvironmentConfig.load() in configure.swift")
            }
            return config
        }
        set {
            storage[EnvironmentConfigKey.self] = newValue
        }
    }
}

