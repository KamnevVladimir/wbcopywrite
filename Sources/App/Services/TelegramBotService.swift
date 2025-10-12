import Vapor
import Fluent

/// Telegram Bot Service - обработка команд и сообщений
final class TelegramBotService: @unchecked Sendable {
    private let app: Application
    private let botToken: String
    private let baseURL: String
    
    init(app: Application, botToken: String) {
        self.app = app
        self.botToken = botToken
        self.baseURL = "https://api.telegram.org/bot\(botToken)"
    }
    
    // MARK: - Public API
    
    /// Обработать входящее обновление от Telegram
    func handleUpdate(_ update: TelegramUpdate) async {
        do {
            if let message = update.message {
                try await handleMessage(message)
            }
            
            if let callback = update.callbackQuery {
                try await handleCallback(callback)
            }
        } catch {
            app.logger.error("❌ Error handling update #\(update.updateId): \(error)")
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleMessage(_ message: TelegramMessage) async throws {
        let user = try await getOrCreateUser(from: message.from, chatId: message.chat.id)
        
        guard let text = message.text else { return }
        
        app.logger.info("💬 Message from @\(message.from.username ?? "unknown"): \(text)")
        
        // Обработка команд
        if text.starts(with: "/") {
            try await handleCommand(text, user: user, chatId: message.chat.id)
        } else {
            // TODO: Обработка текста (название товара для генерации)
            try await sendMessage(
                chatId: message.chat.id,
                text: "Используй команды:\n/start - главное меню\n/generate - сгенерировать описание"
            )
        }
    }
    
    private func handleCommand(_ command: String, user: User, chatId: Int64) async throws {
        switch command {
        case "/start":
            try await handleStartCommand(user: user, chatId: chatId)
            
        case "/help":
            try await handleHelpCommand(chatId: chatId)
            
        case "/generate":
            try await handleGenerateCommand(user: user, chatId: chatId)
            
        case "/balance":
            try await handleBalanceCommand(user: user, chatId: chatId)
            
        case "/cancel":
            try await handleCancelCommand(user: user, chatId: chatId)
            
        default:
            try await sendMessage(
                chatId: chatId,
                text: "Неизвестная команда. Используй /help для справки."
            )
        }
    }
    
    // MARK: - Command Implementations
    
    private func handleStartCommand(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let plan = try await repo.getCurrentPlan(user)
        let remaining = try await repo.getRemainingGenerations(user)
        
        let welcomeText = """
        👋 Привет, \(user.displayName)!
        
        🎯 Я КарточкаПРО — твой AI-помощник для создания продающих описаний товаров на Wildberries и Ozon.
        
        📊 Твой план: \(plan.name)
        Осталось генераций: \(remaining)
        
        🚀 Что я умею:
        • Генерирую SEO-оптимизированные описания
        • Создаю цепляющие заголовки
        • Подбираю ключевые слова и хештеги
        • Пишу убедительные bullet-points
        
        Выбери категорию товара:
        """
        
        let keyboard = createCategoryKeyboard()
        
        try await sendMessage(
            chatId: chatId,
            text: welcomeText,
            replyMarkup: keyboard
        )
    }
    
    private func handleHelpCommand(chatId: Int64) async throws {
        let helpText = """
        📖 Как пользоваться ботом:
        
        1️⃣ Нажми /generate или выбери категорию
        2️⃣ Опиши свой товар (название, характеристики)
        3️⃣ Получи готовое описание за 15 секунд!
        
        💡 Команды:
        /start - Главное меню
        /generate - Новое описание
        /balance - Проверить остаток
        /help - Эта справка
        /cancel - Отменить действие
        
        ❓ Вопросы? Пиши @support_kartochka
        """
        
        try await sendMessage(chatId: chatId, text: helpText)
    }
    
    private func handleGenerateCommand(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        
        // Проверить лимит
        guard try await repo.hasGenerationsAvailable(user) else {
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // Показать выбор категории
        let keyboard = createCategoryKeyboard()
        
        try await sendMessage(
            chatId: chatId,
            text: Constants.BotMessage.selectCategory,
            replyMarkup: keyboard
        )
    }
    
    private func handleBalanceCommand(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let plan = try await repo.getCurrentPlan(user)
        let remaining = try await repo.getRemainingGenerations(user)
        let total = plan.generationsLimit
        
        let balanceText = Constants.BotMessage.subscriptionInfo(
            plan: plan,
            remaining: remaining,
            total: total
        )
        
        try await sendMessage(chatId: chatId, text: balanceText)
    }
    
    private func handleCancelCommand(user: User, chatId: Int64) async throws {
        // TODO: Очистить состояние пользователя
        try await sendMessage(
            chatId: chatId,
            text: "✅ Действие отменено. Используй /start для возврата в меню."
        )
    }
    
    // MARK: - Callback Handlers
    
    private func handleCallback(_ callback: TelegramCallbackQuery) async throws {
        guard let data = callback.data else { return }
        
        app.logger.info("🔘 Callback from @\(callback.from.username ?? "unknown"): \(data)")
        
        let user = try await getOrCreateUser(from: callback.from, chatId: callback.message?.chat.id ?? callback.from.id)
        let chatId = callback.message?.chat.id ?? callback.from.id
        
        // Обработка callback data
        if data.starts(with: "category_") {
            let category = String(data.dropFirst("category_".count))
            try await handleCategorySelected(category: category, user: user, chatId: chatId)
        }
        
        // Подтвердить callback
        try await answerCallback(callbackId: callback.id)
    }
    
    private func handleCategorySelected(category: String, user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        
        // Сохранить выбранную категорию
        try await repo.updateCategory(user, category: category)
        
        guard let productCategory = Constants.ProductCategory(rawValue: category) else {
            return
        }
        
        let text = """
        ✅ Категория выбрана: \(productCategory.displayName)
        
        \(Constants.BotMessage.enterProductInfo)
        """
        
        try await sendMessage(chatId: chatId, text: text)
    }
    
    // MARK: - Helpers
    
    private func getOrCreateUser(from telegramUser: TelegramUser, chatId: Int64) async throws -> User {
        let repo = UserRepository(database: app.db)
        return try await repo.getOrCreate(
            telegramId: telegramUser.id,
            username: telegramUser.username,
            firstName: telegramUser.firstName,
            lastName: telegramUser.lastName
        )
    }
    
    private func createCategoryKeyboard() -> TelegramReplyMarkup {
        let categories = Constants.ProductCategory.allCases
        
        // Создаем кнопки по 2 в ряд
        var rows: [[TelegramInlineKeyboardButton]] = []
        var currentRow: [TelegramInlineKeyboardButton] = []
        
        for category in categories {
            let button = TelegramInlineKeyboardButton(
                text: category.displayName,
                callbackData: "category_\(category.rawValue)"
            )
            currentRow.append(button)
            
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        
        // Добавить остаток
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return TelegramReplyMarkup(inlineKeyboard: rows)
    }
    
    // MARK: - Telegram API
    
    func sendMessage(
        chatId: Int64,
        text: String,
        parseMode: String = "Markdown",
        replyMarkup: TelegramReplyMarkup? = nil
    ) async throws {
        let uri = URI(string: "\(baseURL)/sendMessage")
        
        let response = try await app.client.post(uri) { req in
            try req.content.encode(TelegramSendMessage(
                chatId: chatId,
                text: text,
                parseMode: parseMode,
                replyMarkup: replyMarkup
            ))
        }
        
        guard response.status == HTTPResponseStatus.ok else {
            throw BotError.telegramAPIError(response.status)
        }
    }
    
    private func answerCallback(callbackId: String, text: String? = nil) async throws {
        struct AnswerCallbackQuery: Content {
            let callback_query_id: String
            let text: String?
        }
        
        let uri = URI(string: "\(baseURL)/answerCallbackQuery")
        
        _ = try await app.client.post(uri) { req in
            try req.content.encode(AnswerCallbackQuery(
                callback_query_id: callbackId,
                text: text
            ))
        }
    }
    
    // MARK: - Errors
    
    enum BotError: Error {
        case telegramAPIError(HTTPResponseStatus)
        case userNotFound
        case limitExceeded
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

