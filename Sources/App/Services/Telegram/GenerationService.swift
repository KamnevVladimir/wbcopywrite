import Vapor
import Fluent

/// Сервис для генерации описаний товаров
final class GenerationService: @unchecked Sendable {
    private let app: Application
    private let api: TelegramAPI
    private let log: BotLogger
    
    init(app: Application, api: TelegramAPI) {
        self.app = app
        self.api = api
        self.log = app.botLogger
    }
    
    // MARK: - Text Generation
    
    /// Сгенерировать описание по тексту
    func generateFromText(
        text: String,
        category: Constants.ProductCategory,
        user: User,
        chatId: Int64
    ) async throws {
        let repo = UserRepository(database: app.db)
        
        log.generationStarted(user, category: category.rawValue)
        
        // Проверка лимитов
        let remaining = try await repo.getRemainingGenerations(user)
        guard remaining > 0 else {
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // 🔒 Резервируем кредит ДО генерации
        log.creditReserved(user, remaining: remaining - 1)
        try await repo.incrementGenerations(user)
        
        // Показываем прогресс
        let progressMsg = try await api.sendMessage(
            chatId: chatId,
            text: "⏳ *Анализирую товар...* 🔍"
        )
        
        do {
            // Обновление статуса через 3 сек
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                try? await api.editMessage(
                    chatId: chatId,
                    messageId: progressMsg,
                    text: "⏳ *Генерирую описание...* ✍️"
                )
            }
            
            // Вызов Claude API
            let description = try await app.claude.generateProductDescription(
                productInfo: text,
                category: category
            )
            
            log.claudeAPICall(tokens: description.tokensUsed, timeMs: description.processingTimeMs)
            
            // Сохранение в БД
            let generation = Generation(
                userId: user.id!,
                category: category.rawValue,
                productName: text,
                productDetails: text,
                tokensUsed: description.tokensUsed,
                processingTimeMs: description.processingTimeMs
            )
            generation.resultTitle = description.title
            generation.resultDescription = description.description
            generation.resultBullets = description.bullets
            generation.resultHashtags = description.hashtags
            
            try await generation.save(on: app.db)
            
            // Сохраняем категорию в список последних
            try await repo.addRecentCategory(user, category: category.rawValue)
            
            // Отправка результата
            try await sendResult(description: description, user: user, chatId: chatId)
            
            log.generationSuccess(user, tokensUsed: description.tokensUsed, timeMs: description.processingTimeMs)
            
        } catch {
            log.generationError(error)
            
            // Откат кредита
            log.creditRolledBack(user)
            try? await repo.rollbackGeneration(user)
            
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
    }
    
    // MARK: - Photo Generation
    
    /// Сгенерировать описание по фото
    func generateFromPhoto(
        photos: [TelegramPhotoSize],
        caption: String?,
        category: Constants.ProductCategory,
        user: User,
        chatId: Int64
    ) async throws {
        let repo = UserRepository(database: app.db)
        
        // Проверка лимитов фото
        let remaining = try await repo.getRemainingPhotoGenerations(user)
        guard remaining > 0 else {
            let plan = try await repo.getCurrentPlan(user)
            try await api.sendMessage(
                chatId: chatId,
                text: MessageFormatter.photoLimitExceeded(plan: plan)
            )
            return
        }
        
        // 🔒 Резервируем фото кредит
        try await repo.incrementPhotoGenerations(user)
        
        try await api.sendMessage(
            chatId: chatId,
            text: "🔍 Анализирую фотографию...\n\nЭто может занять 15-20 секунд."
        )
        
        do {
            // Скачать фото
            guard let largestPhoto = photos.max(by: { $0.fileSize ?? 0 < $1.fileSize ?? 0 }) else {
                throw GenerationError.photoNotFound
            }
            
            let filePath = try await api.getFilePath(fileId: largestPhoto.fileId)
            let imageData = try await api.downloadFile(filePath: filePath)
            
            log.photoDownloaded(size: imageData.count)
            
            // Проверка размера
            guard imageData.count <= 10 * 1024 * 1024 else {
                throw GenerationError.imageTooLarge
            }
            
            // Вызов Claude Vision API
            let additionalContext = caption ?? "Товар без дополнительного описания"
            let description = try await app.claude.generateProductDescriptionFromPhoto(
                imageData: imageData,
                productInfo: additionalContext,
                category: category
            )
            
            // Сохранение в БД
            let generation = Generation(
                userId: user.id!,
                category: category.rawValue,
                productName: "Генерация по фото",
                productDetails: additionalContext,
                tokensUsed: description.tokensUsed,
                processingTimeMs: description.processingTimeMs
            )
            generation.resultTitle = description.title
            generation.resultDescription = description.description
            generation.resultBullets = description.bullets
            generation.resultHashtags = description.hashtags
            
            try await generation.save(on: app.db)
            
            // Сохраняем категорию в список последних
            try await repo.addRecentCategory(user, category: category.rawValue)
            
            // Отправка результата
            try await sendResult(description: description, user: user, chatId: chatId)
            
            log.generationSuccess(user, tokensUsed: description.tokensUsed, timeMs: description.processingTimeMs)
            
        } catch {
            log.generationError(error)
            
            // Откат фото кредита
            try? await repo.rollbackPhotoGeneration(user)
            
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
    }
    
    // MARK: - Send Result
    
    private func sendResult(
        description: ClaudeService.ProductDescription,
        user: User,
        chatId: Int64
    ) async throws {
        let repo = UserRepository(database: app.db)
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        let plan = try await repo.getCurrentPlan(user)
        let currentCategory = user.selectedCategory.flatMap { Constants.ProductCategory(rawValue: $0) }
        
        // Smart Nudge
        let nudge = MessageFormatter.smartNudge(
            remainingText: remainingText,
            remainingPhoto: remainingPhoto,
            isFree: plan == .free
        )
        
        // Форматируем сообщения
        let (msg1, msg2, msg3) = MessageFormatter.generationResult(
            title: description.title,
            description: description.description,
            bullets: description.bullets,
            hashtags: description.hashtags,
            remainingText: remainingText,
            remainingPhoto: remainingPhoto,
            nudge: nudge
        )
        // Отправляем одним цитированным блоком без кнопок копирования
        let joined = [msg1, msg2, msg3].joined(separator: "\n\n").markdownV2Escaped
        let codeBlock = "```\n\(joined)\n```"
        try await api.sendMessage(chatId: chatId, text: codeBlock, replyMarkup: nil, parseMode: "MarkdownV2")
    }
    
    // MARK: - Errors
    
    enum GenerationError: Error {
        case photoNotFound
        case imageTooLarge
        case categoryNotSelected
    }
}

// MARK: - Application Extension

extension Application {
    private struct GenerationServiceKey: StorageKey {
        typealias Value = GenerationService
    }
    
    var generationService: GenerationService {
        get {
            guard let service = storage[GenerationServiceKey.self] else {
                fatalError("GenerationService not configured")
            }
            return service
        }
        set {
            storage[GenerationServiceKey.self] = newValue
        }
    }
}

