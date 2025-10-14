import Vapor
import Fluent

/// Обработчик callback queries (inline кнопки)
final class CallbackHandler: @unchecked Sendable {
    private let app: Application
    private let api: TelegramAPI
    private let generationService: GenerationService
    private let log: BotLogger
    
    init(app: Application, api: TelegramAPI, generationService: GenerationService) {
        self.app = app
        self.api = api
        self.generationService = generationService
        self.log = app.botLogger
    }
    
    // MARK: - Main Handler
    
    func handle(_ callback: TelegramCallbackQuery, user: User, chatId: Int64) async throws {
        guard let data = callback.data else { return }
        
        log.userCallback(user, data: data)
        
        guard let callbackData = CallbackData(rawValue: data) else {
            log.warning("Unknown callback from user \(user.telegramId): '\(data)'")
            try await api.answerCallback(callbackId: callback.id, text: "Неизвестное действие")
            return
        }
        
        // Обработка по типу
        switch callbackData {
        case .category(let categoryRaw):
            try await handleCategory(categoryRaw, user: user, chatId: chatId)
            
        case .customCategory:
            try await handleCustomCategory(user: user, chatId: chatId)
            
        case .quickGenerate(let categoryRaw):
            try await handleQuickGenerate(categoryRaw, user: user, chatId: chatId)
            
        case .newGeneration:
            try await handleNewGeneration(user: user, chatId: chatId)
            
        case .myBalance:
            try await handleMyBalance(user: user, chatId: chatId)
            
        case .exportLast:
            try await handleExportLast(user: user, chatId: chatId)
            
        case .exportFormat(let format):
            try await handleExportFormat(format, user: user, chatId: chatId)
            
        case .exportAllExcel:
            try await handleExportAllExcel(user: user, chatId: chatId)
            
        case .buyPlan(let plan):
            try await handleBuyPlan(plan, user: user, chatId: chatId)
            
        case .viewPackages:
            try await handleViewPackages(user: user, chatId: chatId)
            
        case .copyMenu:
            return // копирование отключено
            
        case .copyPart:
            return // копирование отключено
            
        case .viewGeneration(let uuid):
            try await handleViewGeneration(uuid, user: user, chatId: chatId)
            
        case .improveLast:
            try await handleImproveLast(user: user, chatId: chatId)
            
        case .improveResult(let uuid):
            try await handleImproveResult(uuid, user: user, chatId: chatId)
            
        case .viewHistory(let offset, let limit):
            try await handleViewHistory(offset, limit, user: user, chatId: chatId)
            
        case .backToMain:
            try await handleBackToMain(user: user, chatId: chatId)
        }
        
        try await api.answerCallback(callbackId: callback.id)
    }
    
    // MARK: - Callback Handlers
    
    private func handleCategory(_ categoryRaw: String, user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: categoryRaw)
        
        guard let category = Constants.ProductCategory(rawValue: categoryRaw) else { return }
        
        let text = MessageFormatter.categorySelected(category)
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    private func handleCustomCategory(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: "awaiting_custom_category")
        
        let text = MessageFormatter.customCategoryPrompt()
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    private func handleQuickGenerate(_ categoryRaw: String, user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: categoryRaw)
        
        guard let category = Constants.ProductCategory(rawValue: categoryRaw) else { return }
        
        try await api.sendMessage(
            chatId: chatId,
            text: "✅ Категория: \(category.displayName)\n\n\(Constants.BotMessage.enterProductInfo)"
        )
    }
    
    private func handleNewGeneration(user: User, chatId: Int64) async throws {
        let categoryKeyboard = KeyboardBuilder.createCategoryKeyboard()
        try await api.sendMessage(
            chatId: chatId,
            text: "Выбери категорию товара:",
            replyMarkup: categoryKeyboard
        )
    }
    
    private func handleMyBalance(user: User, chatId: Int64) async throws {
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
    
    private func handleExportLast(user: User, chatId: Int64) async throws {
        let keyboard = KeyboardBuilder.createExportFormatKeyboard()
        try await api.sendMessage(
            chatId: chatId,
            text: "📄 *Выбери формат экспорта:*",
            replyMarkup: keyboard
        )
    }
    
    private func handleExportFormat(_ format: String, user: User, chatId: Int64) async throws {
        // Получить последнюю генерацию
        let lastGeneration = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .first()
        
        guard let generation = lastGeneration else {
            try await api.sendMessage(
                chatId: chatId,
                text: "❌ Нет сохранённых описаний для экспорта"
            )
            return
        }
        
        if format == "excel" {
            try await exportExcel(generation: generation, chatId: chatId)
        } else if format == "csv" {
            try await exportCSV(generation: generation, chatId: chatId)
        } else {
            try await exportTxt(generation: generation, chatId: chatId)
        }
    }
    
    private func exportTxt(generation: Generation, chatId: Int64) async throws {
        guard let title = generation.resultTitle,
              let description = generation.resultDescription,
              let bullets = generation.resultBullets,
              let hashtags = generation.resultHashtags else {
            try await api.sendMessage(chatId: chatId, text: "❌ Данные генерации неполные")
            return
        }
        
        let bulletsText = bullets.map { "• \($0)" }.joined(separator: "\n")
        let hashtagsText = hashtags.joined(separator: " ")
        
        let fileContent = """
        📝 ОПИСАНИЕ ТОВАРА
        Создано: КарточкаПРО AI Bot
        
        ════════════════════════════════════
        
        📝 ЗАГОЛОВОК:
        \(title)
        
        📄 ОПИСАНИЕ:
        \(description)
        
        🎯 КЛЮЧЕВЫЕ ВЫГОДЫ:
        \(bulletsText)
        
        🏷 ХЕШТЕГИ:
        \(hashtagsText)
        
        ════════════════════════════════════
        
        Готово к публикации на WB/Ozon!
        """
        
        try await api.sendDocument(
            chatId: chatId,
            content: fileContent,
            filename: "opisanie.txt",
            caption: "✅ Экспорт готов!"
        )
    }
    
    private func exportExcel(generation: Generation, chatId: Int64) async throws {
        guard let title = generation.resultTitle,
              let description = generation.resultDescription,
              let bullets = generation.resultBullets,
              let hashtags = generation.resultHashtags else {
            try await api.sendMessage(chatId: chatId, text: "❌ Данные генерации неполные")
            return
        }
        // Генерируем HTML-таблицу с расширением .xls — корректно открывается в Excel
        let bulletsHtml = bullets.map { "&bull; \($0.xmlEscaped)" }.joined(separator: "<br/>")
        let hashtagsText = hashtags.joined(separator: " ")
        let xml = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8"/>
          <title>Описание</title>
        </head>
        <body>
          <table border="1" cellspacing="0" cellpadding="5">
            <tr><th>Заголовок</th><td>\(title.xmlEscaped)</td></tr>
            <tr><th>Описание</th><td>\(description.xmlEscaped)</td></tr>
            <tr><th>Выгоды</th><td>\(bulletsHtml)</td></tr>
            <tr><th>Хештеги</th><td>\(hashtagsText.xmlEscaped)</td></tr>
          </table>
        </body>
        </html>
        """
        
        try await api.sendDocument(
            chatId: chatId,
            content: xml,
            filename: "description_\(generation.id?.uuidString.prefix(8) ?? "export").xls",
            caption: "📊 Экспорт в Excel (.xls)"
        )
    }

    private func exportCSV(generation: Generation, chatId: Int64) async throws {
        guard let title = generation.resultTitle,
              let description = generation.resultDescription,
              let bullets = generation.resultBullets,
              let hashtags = generation.resultHashtags else {
            try await api.sendMessage(chatId: chatId, text: "❌ Данные генерации неполные")
            return
        }
        let bulletsText = bullets.map { $0.replacingOccurrences(of: "\"", with: "\"\"") }.joined(separator: "\n")
        let hashtagsText = hashtags.joined(separator: " ")
        let csvContent = """
        "Поле","Значение"
        "Заголовок","\(title.replacingOccurrences(of: "\"", with: "\"\""))"
        "Описание","\(description.replacingOccurrences(of: "\"", with: "\"\""))"
        "Выгоды","\(bulletsText)"
        "Хештеги","\(hashtagsText)"
        """
        try await api.sendDocument(
            chatId: chatId,
            content: csvContent,
            filename: "description_\(generation.id?.uuidString.prefix(8) ?? "export").csv",
            caption: "📈 Экспорт в CSV"
        )
    }
    
    private func handleExportAllExcel(user: User, chatId: Int64) async throws {
        try await api.sendMessage(chatId: chatId, text: "📊 Экспорт всех в Excel - в разработке")
    }
    
    private func handleBuyPlan(_ plan: String, user: User, chatId: Int64) async throws {
        guard let selected = Constants.SubscriptionPlan(rawValue: plan) else {
            try await api.sendMessage(chatId: chatId, text: "❌ Неизвестный пакет")
            return
        }
        
        guard selected != .free else {
            try await api.sendMessage(chatId: chatId, text: "🆓 У тебя уже есть Free пакет!")
            return
        }
        
        guard !selected.tributeProductId.isEmpty && !selected.tributeWebLink.isEmpty else {
            try await api.sendMessage(
                chatId: chatId,
                text: "⚠️ Пакет временно недоступен. Напиши \(Constants.Support.username)"
            )
            return
        }
        
        do {
            let paymentUrl = try await app.tribute.createPaymentLink(
                plan: selected,
                telegramId: user.telegramId
            )
            
            let text = MessageFormatter.planDetails(plan: selected)
            let keyboard = KeyboardBuilder.createPlanPurchaseKeyboard(plan: selected, paymentUrl: paymentUrl)
            
            try await api.sendMessage(chatId: chatId, text: text, replyMarkup: keyboard)
            
        } catch {
            log.error("Failed to create payment link", error: error)
            try await api.sendMessage(
                chatId: chatId,
                text: "❌ Ошибка создания платежа. Напиши \(Constants.Support.username)"
            )
        }
    }
    
    private func handleViewPackages(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let currentPlan = try await repo.getCurrentPlan(user)
        
        let text = MessageFormatter.subscriptionPlans(currentPlan: currentPlan)
        let keyboard = KeyboardBuilder.createPaymentKeyboard()
        
        try await api.sendMessage(chatId: chatId, text: text, replyMarkup: keyboard)
    }
    
    private func handleCopyMenu(user: User, chatId: Int64) async throws { }
    
    private func handleCopyPart(_ part: String, user: User, chatId: Int64, callbackId: String) async throws { }
    
    private func handleViewGeneration(_ uuid: String, user: User, chatId: Int64) async throws {
        guard let genUUID = UUID(uuidString: uuid),
              let generation = try await Generation.find(genUUID, on: app.db) else {
            try await api.sendMessage(chatId: chatId, text: "❌ Генерация не найдена")
            return
        }
        
        let resultText = """
        📝 *ЗАГОЛОВОК:*
        \(generation.resultTitle ?? "")
        
        📄 *ОПИСАНИЕ:*
        \(generation.resultDescription ?? "")
        
        🎯 *ВЫГОДЫ:*
        \((generation.resultBullets ?? []).map { "• \($0)" }.joined(separator: "\n"))
        
        🏷 *ХЕШТЕГИ:*
        \((generation.resultHashtags ?? []).joined(separator: " "))
        """
        
        try await api.sendMessage(chatId: chatId, text: resultText)
    }
    
    private func handleImproveLast(user: User, chatId: Int64) async throws {
        // Получить последнюю генерацию
        let lastGen = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .first()
        
        guard let generation = lastGen else {
            try await api.sendMessage(chatId: chatId, text: "❌ Нет сохранённых описаний. Создай описание сначала!")
            return
        }
        
        let repo = UserRepository(database: app.db)
        guard try await repo.hasGenerationsAvailable(user) else {
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // Сохраняем UUID для улучшения
        user.selectedCategory = "improve_\(generation.id!.uuidString)"
        try await user.save(on: app.db)
        
        let text = """
        ✨ *Улучшение описания*
        
        Напиши что хочешь изменить:
        
        📝 Примеры:
        • "Сделай более эмоциональным"
        • "Добавь больше конкретики"
        • "Сделай короче"
        • "Упор на экологичность"
        
        Или /cancel для отмены
        """
        
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    private func handleImproveResult(_ uuid: String, user: User, chatId: Int64) async throws {
        guard let genUUID = UUID(uuidString: uuid),
              let _ = try await Generation.find(genUUID, on: app.db) else {
            try await api.sendMessage(chatId: chatId, text: "❌ Генерация не найдена")
            return
        }
        
        let repo = UserRepository(database: app.db)
        guard try await repo.hasGenerationsAvailable(user) else {
            try await api.sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // Сохраняем UUID для улучшения
        user.selectedCategory = "improve_\(uuid)"
        try await user.save(on: app.db)
        
        let text = """
        ✨ *Улучшение описания*
        
        Напиши что хочешь изменить:
        
        📝 Примеры:
        • "Сделай более эмоциональным"
        • "Добавь больше конкретики"
        • "Сделай короче"
        • "Упор на экологичность"
        
        Или /cancel для отмены
        """
        
        try await api.sendMessage(chatId: chatId, text: text)
    }
    
    private func handleViewHistory(_ offset: Int, _ limit: Int, user: User, chatId: Int64) async throws {
        let commandHandler = CommandHandler(app: app, api: api)
        try await commandHandler.handle("/history", user: user, chatId: chatId)
    }
    
    private func handleBackToMain(user: User, chatId: Int64) async throws {
        let commandHandler = CommandHandler(app: app, api: api)
        try await commandHandler.handle("/start", user: user, chatId: chatId)
    }
}

// MARK: - Callback Data Enum

extension CallbackHandler {
    enum CallbackData {
        case category(String)
        case customCategory
        case newGeneration
        case quickGenerate(String)
        case myBalance
        case exportLast
        case buyPlan(String)
        case viewPackages
        case exportFormat(String)
        case exportAllExcel
        case copyMenu
        case copyPart(String)
        case viewGeneration(String)
        case improveLast
        case improveResult(String)
        case viewHistory(Int, Int)
        case backToMain
        
        init?(rawValue: String) {
            if rawValue == "back_to_main" {
                self = .backToMain
            } else if rawValue == "improve_last" {
                self = .improveLast
            } else if rawValue.starts(with: "category_") {
                let category = String(rawValue.dropFirst("category_".count))
                self = .category(category)
            } else if rawValue == "custom_category" {
                self = .customCategory
            } else if rawValue.starts(with: "quick_generate_") {
                let category = String(rawValue.dropFirst("quick_generate_".count))
                self = .quickGenerate(category)
            } else if rawValue == "new_generation" {
                self = .newGeneration
            } else if rawValue == "my_balance" {
                self = .myBalance
            } else if rawValue == "export_last" {
                self = .exportLast
            } else if rawValue.starts(with: "buy_") {
                let plan = String(rawValue.dropFirst("buy_".count))
                self = .buyPlan(plan)
            } else if rawValue == "view_packages" {
                self = .viewPackages
            } else if rawValue == "export_all_excel" {
                self = .exportAllExcel
            } else if rawValue.starts(with: "export_") {
                let format = String(rawValue.dropFirst("export_".count))
                self = .exportFormat(format)
            } else if rawValue == "copy_menu" {
                self = .copyMenu
            } else if rawValue.starts(with: "copy_") {
                let part = String(rawValue.dropFirst("copy_".count))
                self = .copyPart(part)
            } else if rawValue.starts(with: "view_gen_") {
                let uuid = String(rawValue.dropFirst("view_gen_".count))
                self = .viewGeneration(uuid)
            } else if rawValue.starts(with: "improve_") {
                let uuid = String(rawValue.dropFirst("improve_".count))
                self = .improveResult(uuid)
            } else if rawValue.starts(with: "history_") {
                let parts = rawValue.dropFirst("history_".count).split(separator: "_")
                if parts.count == 2, let offset = Int(parts[0]), let limit = Int(parts[1]) {
                    self = .viewHistory(offset, limit)
                    return
                }
                return nil
            } else {
                return nil
            }
        }
    }
}

