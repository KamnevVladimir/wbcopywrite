import Vapor

/// Главный координатор бота - делегирует работу специализированным сервисам
final class TelegramBotService: @unchecked Sendable {
    private let app: Application
    private let botToken: String
    
    // Сервисы
    private let api: TelegramAPI
    private let generationService: GenerationService
    private let commandHandler: CommandHandler
    private let callbackHandler: CallbackHandler
    private let messageHandler: MessageHandler
    private let log: BotLogger
    
    init(app: Application, botToken: String) {
        self.app = app
        self.botToken = botToken
        self.log = app.botLogger
        
        // Инициализация сервисов
        self.api = TelegramAPI(app: app, botToken: botToken)
        self.generationService = GenerationService(app: app, api: api)
        self.commandHandler = CommandHandler(app: app, api: api)
        self.callbackHandler = CallbackHandler(app: app, api: api, generationService: generationService)
        self.messageHandler = MessageHandler(
            app: app,
            api: api,
            commandHandler: commandHandler,
            generationService: generationService
        )
        
        // Регистрируем API в Application
        app.telegramAPI = api
        app.generationService = generationService
    }
    
    // MARK: - Public API
    
    /// Обработать update от Telegram
    func handleUpdate(_ update: TelegramUpdate) async {
        do {
            // Обработка сообщения
            if let message = update.message {
                let user = try await getOrCreateUser(from: message.from, chatId: message.chat.id)
                try await messageHandler.handle(message, user: user)
            }
            
            // Обработка callback
            if let callback = update.callbackQuery {
                let user = try await getOrCreateUser(
                    from: callback.from,
                    chatId: callback.message?.chat.id ?? callback.from.id
                )
                let chatId = callback.message?.chat.id ?? callback.from.id
                try await callbackHandler.handle(callback, user: user, chatId: chatId)
            }
            
        } catch {
            log.error("Error handling update #\(update.updateId)", error: error)
        }
    }
    
    /// Отправить сообщение (для вызова из других сервисов, например Tribute)
    func sendMessage(chatId: Int64, text: String) async throws {
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    // MARK: - User Management
    
    private func getOrCreateUser(from telegramUser: TelegramUser, chatId: Int64) async throws -> User {
        let repo = UserRepository(database: app.db)
        return try await repo.getOrCreate(
            telegramId: telegramUser.id,
            username: telegramUser.username,
            firstName: telegramUser.firstName,
            lastName: telegramUser.lastName
        )
    }
}

// MARK: - Application Extension

extension Application {
    private struct TelegramBotServiceKey: StorageKey {
        typealias Value = TelegramBotService
    }
    
    var telegramBot: TelegramBotService {
        get {
            guard let service = storage[TelegramBotServiceKey.self] else {
                fatalError("TelegramBotService not configured")
            }
            return service
        }
        set {
            storage[TelegramBotServiceKey.self] = newValue
        }
    }
}

