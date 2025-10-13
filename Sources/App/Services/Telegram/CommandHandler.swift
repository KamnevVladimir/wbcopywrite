import Vapor
import Fluent

/// Обработчик команд бота (/start, /help, etc)
final class CommandHandler: @unchecked Sendable {
    private let app: Application
    private let api: TelegramAPI
    private let log: BotLogger
    
    init(app: Application, api: TelegramAPI) {
        self.app = app
        self.api = api
        self.log = app.botLogger
    }
    
    // MARK: - Main Handler
    
    func handle(_ command: String, user: User, chatId: Int64) async throws {
        switch command {
        case "/start":
            try await handleStart(user: user, chatId: chatId)
        case "/help":
            try await handleHelp(chatId: chatId)
        case "/generate":
            try await handleGenerate(user: user, chatId: chatId)
        case "/balance":
            try await handleBalance(user: user, chatId: chatId)
        case "/subscribe":
            try await handleSubscribe(user: user, chatId: chatId)
        case "/history":
            try await handleHistory(user: user, chatId: chatId)
        case "/cancel":
            try await handleCancel(user: user, chatId: chatId)
        case "/batch":
            try await handleBatch(user: user, chatId: chatId)
        default:
            log.warning("Unknown command: \(command)")
        }
    }
    
    // MARK: - Commands
    
    private func handleStart(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let plan = try await repo.getCurrentPlan(user)
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        
        log.userStarted(user)
        
        let welcomeText = MessageFormatter.welcome(
            user: user,
            plan: plan,
            remainingText: remainingText,
            remainingPhoto: remainingPhoto
        )
        
        // Клавиатура: категории + кнопка пакетов
        let categoryKeyboard = KeyboardBuilder.createCategoryKeyboard()
        let subscribeButton = [[
            TelegramInlineKeyboardButton(text: "💎 Тарифы и цены", callbackData: "view_packages")
        ]]
        
        let fullKeyboard = TelegramReplyMarkup(
            inlineKeyboard: (categoryKeyboard.inlineKeyboard ?? []) + subscribeButton
        )
        
        try await api.sendMessage(chatId: chatId, text: welcomeText, replyMarkup: fullKeyboard)
    }
    
    private func handleHelp(chatId: Int64) async throws {
        let helpText = """
        📖 *Как пользоваться:*
        
        1️⃣ /start - выбери категорию
        2️⃣ Отправь описание товара или ФОТО 📷
        3️⃣ Получи готовое описание за 10 сек!
        4️⃣ Экспортируй в Excel или TXT
        
        💡 *Команды:*
        /start - Главное меню
        /generate - Новое описание
        /history - Твои описания
        /balance - Проверить остаток
        /subscribe - Пакеты и цены
        /batch - Массовая генерация
        /help - Эта справка
        /cancel - Отменить
        
        💰 *Тарифы:*
        От 299₽ за 20 текстов + 3 фото
        = 13.0₽ за описание (vs 300₽ у копирайтера!)
        
        ❓ *Вопросы?* \(Constants.Support.username)
        """
        
        try await api.sendMessage(chatId: chatId, text: helpText)
    }
    
    private func handleGenerate(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        
        guard try await repo.hasGenerationsAvailable(user) else {
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        let categoryKeyboard = KeyboardBuilder.createCategoryKeyboard()
        try await api.sendMessage(
            chatId: chatId,
            text: "Выбери категорию товара:",
            replyMarkup: categoryKeyboard
        )
    }
    
    private func handleBalance(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let plan = try await repo.getCurrentPlan(user)
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        
        let balanceText = MessageFormatter.balance(
            plan: plan,
            remainingText: remainingText,
            remainingPhoto: remainingPhoto,
            hasTextCredits: user.textCredits > 0,
            hasPhotoCredits: user.photoCredits > 0
        )
        
        let keyboard = KeyboardBuilder.createBalanceKeyboard()
        try await api.sendMessage(chatId: chatId, text: balanceText, replyMarkup: keyboard)
    }
    
    private func handleSubscribe(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let currentPlan = try await repo.getCurrentPlan(user)
        
        let subscribeText = MessageFormatter.subscriptionPlans(currentPlan: currentPlan)
        let keyboard = KeyboardBuilder.createPaymentKeyboard()
        
        try await api.sendMessage(chatId: chatId, text: subscribeText, replyMarkup: keyboard)
    }
    
    private func handleHistory(user: User, chatId: Int64, offset: Int = 0, limit: Int = 5) async throws {
        let generations = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .range(offset..<(offset + limit))
            .all()
        
        let totalCount = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .count()
        
        guard !generations.isEmpty else {
            try await api.sendMessage(
                chatId: chatId,
                text: "📜 У тебя пока нет сохранённых описаний.\n\nИспользуй /generate чтобы создать первое!"
            )
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM, HH:mm"
        dateFormatter.locale = Locale(identifier: "ru_RU")
        
        var historyText = "📜 *История генераций* (\(offset+1)-\(offset+generations.count) из \(totalCount)):\n\n"
        
        for (index, gen) in generations.enumerated() {
            let date = dateFormatter.string(from: gen.createdAt ?? Date())
            let categoryEmoji = Constants.ProductCategory(rawValue: gen.category)?.emoji ?? "📝"
            let title = (gen.resultTitle ?? gen.productName).prefix(35)
            
            historyText += "\(offset + index + 1)️⃣ \(categoryEmoji) \(date)\n"
            historyText += "\(title)...\n\n"
        }
        
        let keyboard = KeyboardBuilder.createHistoryPaginationKeyboard(
            offset: offset,
            limit: limit,
            totalCount: totalCount
        )
        
        try await api.sendMessage(chatId: chatId, text: historyText, replyMarkup: keyboard)
    }
    
    private func handleCancel(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: nil)
        
        try await api.sendMessage(
            chatId: chatId,
            text: "❌ Операция отменена.\n\nИспользуй /start для нового начала"
        )
    }
    
    private func handleBatch(user: User, chatId: Int64) async throws {
        try await api.sendMessage(
            chatId: chatId,
            text: """
            📄 *Массовая генерация*
            
            Отправь TXT файл со списком товаров (каждый с новой строки).
            
            Пример содержимого:
            ```
            Кроссовки Nike Air Max белые 43
            Платье женское красное M
            Телефон iPhone 15 Pro 256GB
            ```
            
            Я сгенерирую описание для каждого товара!
            
            ⚠️ Одна генерация = один кредит
            """
        )
    }
}

