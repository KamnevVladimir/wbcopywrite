import Vapor
import Fluent

/// Обработчик текстовых сообщений и документов
final class MessageHandler: @unchecked Sendable {
    private let app: Application
    private let api: TelegramAPI
    private let commandHandler: CommandHandler
    private let generationService: GenerationService
    private let log: BotLogger
    
    init(app: Application, api: TelegramAPI, commandHandler: CommandHandler, generationService: GenerationService) {
        self.app = app
        self.api = api
        self.commandHandler = commandHandler
        self.generationService = generationService
        self.log = app.botLogger
    }
    
    // MARK: - Main Handler
    
    func handle(_ message: TelegramMessage, user: User) async throws {
        let chatId = message.chat.id
        
        // Документ (для batch generation)
        if let document = message.document {
            log.debug("Document received: \(document.fileName ?? "unknown")")
            try await handleBatchDocument(document, user: user, chatId: chatId)
            return
        }
        
        // Фото
        if let photos = message.photo, !photos.isEmpty {
            log.photoReceived(user, size: photos.first?.fileSize ?? 0)
            try await handlePhoto(photos, caption: message.caption, user: user, chatId: chatId)
            return
        }
        
        // Текст
        guard let text = message.text else { return }
        
        log.userMessage(user, text: text)
        
        // Команды
        if text.starts(with: "/") {
            try await commandHandler.handle(text, user: user, chatId: chatId)
            return
        }
        
        // Специальные состояния
        if let state = user.selectedCategory {
            if state.starts(with: "improve_") {
                try await handleImproveInput(text, user: user, chatId: chatId)
                return
            } else if state == "awaiting_custom_category" {
                try await handleCustomCategoryInput(text, user: user, chatId: chatId)
                return
            } else if state.starts(with: "awaiting_feedback_comment:") {
                try await handleFeedbackComment(text, user: user, chatId: chatId)
                return
            }
        }
        
        // Обычный текст товара для генерации
        try await handleProductText(text, user: user, chatId: chatId)
    }
    
    // MARK: - Text Handlers
    
    private func handleProductText(_ text: String, user: User, chatId: Int64) async throws {
        // Если категория не выбрана — спросим подтверждение и предложим быстро начать в категории "Другое"
        guard let categoryRaw = user.selectedCategory,
              let category = Constants.ProductCategory(rawValue: categoryRaw) else {
            let preview = text.prefix(80)
            let confirmText = """
            ✍️ Сгенерировать описание для:
            "\(preview)"
            """
            
            // Кнопка быстрого старта: выбираем категорию "other" и начинаем ввод
            let keyboard = TelegramReplyMarkup(
                inlineKeyboard: [[
                    TelegramInlineKeyboardButton(text: "🚀 Сгенерировать", callbackData: "quick_generate_other")
                ]]
            )
            
            try await api.sendMessage(chatId: chatId, text: confirmText, replyMarkup: keyboard)
            return
        }
        
        try await generationService.generateFromText(
            text: text,
            category: category,
            user: user,
            chatId: chatId
        )
    }
    
    private func handleCustomCategoryInput(_ categoryName: String, user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        // Выбираем категорию .other, но НЕ запускаем генерацию.
        try await repo.updateCategory(user, category: "other")
        
        let text = MessageFormatter.customCategoryAccepted(categoryName)
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    private func handleImproveInput(_ improvementText: String, user: User, chatId: Int64) async throws {
        // Извлечь UUID из state
        guard let state = user.selectedCategory,
              state.starts(with: "improve_"),
              let uuidString = state.split(separator: "_").last,
              let uuid = UUID(uuidString: String(uuidString)),
              let originalGen = try await Generation.find(uuid, on: app.db) else {
            try await api.sendMessage(chatId: chatId, text: "❌ Ошибка: генерация не найдена")
            return
        }
        
        // Очистить state
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: nil)
        
        // Проверка лимитов
        guard try await repo.hasGenerationsAvailable(user) else {
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // 🔒 Резервируем кредит
        try await repo.incrementGenerations(user)
        
        _ = try await api.sendMessage(
            chatId: chatId,
            text: "⏳ *Улучшаю описание...* ✨"
        )
        
        do {
            // Создаем промпт
            let bullets = (originalGen.resultBullets ?? []).joined(separator: "\n")
            let hashtags = (originalGen.resultHashtags ?? []).joined(separator: " ")
            
            let improvePrompt = """
            ЗАДАЧА: Улучши существующее описание товара согласно пожеланиям клиента.
            
            ОРИГИНАЛЬНОЕ ОПИСАНИЕ:
            Заголовок: \(originalGen.resultTitle ?? "")
            Описание: \(originalGen.resultDescription ?? "")
            Выгоды: \(bullets)
            Хештеги: \(hashtags)
            
            ПОЖЕЛАНИЯ КЛИЕНТА:
            \(improvementText)
            
            Создай УЛУЧШЕННУЮ версию с учётом пожеланий. Сохрани структуру.
            """
            
            guard let category = Constants.ProductCategory(rawValue: originalGen.category) else {
                throw Abort(.badRequest)
            }
            
            let description = try await app.claude.generateProductDescription(
                productInfo: improvePrompt,
                category: category
            )
            
            // Сохранить улучшенную версию
            let generation = Generation(
                userId: user.id!,
                category: originalGen.category,
                productName: "✨ Улучшение: \(originalGen.productName)",
                productDetails: improvementText
            )
            generation.resultTitle = description.title
            generation.resultDescription = description.description
            generation.resultBullets = description.bullets
            generation.resultHashtags = description.hashtags
            try await generation.save(on: app.db)
            
            // Отправляем улучшенный результат
            let remainingText = try await repo.getRemainingGenerations(user)
            let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
            let plan = try await repo.getCurrentPlan(user)
            
            let nudge = MessageFormatter.smartNudge(
                remainingText: remainingText,
                remainingPhoto: remainingPhoto,
                isFree: plan == .free
            )
            
            let (msg1, msg2, msg3) = MessageFormatter.generationResult(
                title: description.title,
                description: description.description,
                bullets: description.bullets,
                hashtags: description.hashtags,
                remainingText: remainingText,
                remainingPhoto: remainingPhoto,
                nudge: nudge
            )
            // Отправляем всё одной цитатой, чтобы удобно копировать
            let quotedAll = "```\n\([msg1, msg2, msg3].joined(separator: "\n\n").markdownV2Escaped)\n```"
            let keyboard = KeyboardBuilder.createPostGenerationKeyboard(
                category: category,
                remainingText: remainingText,
                remainingPhoto: remainingPhoto
            )
            try await api.sendMessage(chatId: chatId, text: quotedAll, replyMarkup: keyboard, parseMode: "MarkdownV2")
            
        } catch {
            log.generationError(error)
            try? await repo.rollbackGeneration(user)
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
    }
    
    // MARK: - Photo Handler
    
    private func handlePhoto(_ photos: [TelegramPhotoSize], caption: String?, user: User, chatId: Int64) async throws {
        guard let categoryRaw = user.selectedCategory,
              let category = Constants.ProductCategory(rawValue: categoryRaw) else {
            let keyboard = TelegramReplyMarkup(
                inlineKeyboard: [[
                    TelegramInlineKeyboardButton(text: "🚀 Сгенерировать по фото", callbackData: "quick_generate_other")
                ]]
            )
            try await api.sendMessage(
                chatId: chatId,
                text: """
                📷 *Вижу фото!*
                """,
                replyMarkup: keyboard
            )
            return
        }
        
        try await generationService.generateFromPhoto(
            photos: photos,
            caption: caption,
            category: category,
            user: user,
            chatId: chatId
        )
    }
    
    // MARK: - Batch Document Handler
    
    private func handleBatchDocument(_ document: TelegramDocument, user: User, chatId: Int64) async throws {
        try await api.sendMessage(
            chatId: chatId,
            text: "📄 Массовая генерация из документа - в разработке"
        )
    }
    
    // MARK: - Feedback Handler
    
    private func handleFeedbackComment(_ text: String, user: User, chatId: Int64) async throws {
        let feedbackHandler = FeedbackHandler(app: app, api: api)
        try await feedbackHandler.handleCommentInput(text, user: user, chatId: chatId)
    }
}

