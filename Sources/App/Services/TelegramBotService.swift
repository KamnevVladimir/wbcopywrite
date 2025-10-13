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
        
        // Обработка документа (если есть)
        if let document = message.document {
            app.logger.info("📄 Document from @\(message.from.username ?? "unknown"): \(document.fileName ?? "unknown")")
            try await handleBatchDocument(document: document, user: user, chatId: message.chat.id)
            return
        }
        
        // Обработка фото (если есть)
        if let photos = message.photo, !photos.isEmpty {
            app.logger.info("📷 Photo from @\(message.from.username ?? "unknown")")
            try await handlePhotoDescription(photos: photos, caption: message.caption, user: user, chatId: message.chat.id)
            return
        }
        
        guard let text = message.text else { return }
        
        app.logger.info("💬 Message from @\(message.from.username ?? "unknown"): \(text)")
        
        // Обработка команд
        if text.starts(with: "/") {
            try await handleCommand(text, user: user, chatId: message.chat.id)
        } else {
            // Проверяем, ожидается ли улучшение описания
            if let category = user.selectedCategory, category.starts(with: "improve_") {
                try await handleImproveInput(text: text, user: user, chatId: message.chat.id)
            } else {
                // Обработка текста товара для генерации
                try await handleProductDescription(text: text, user: user, chatId: message.chat.id)
            }
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
            
        case "/subscribe":
            try await handleSubscribeCommand(user: user, chatId: chatId)
            
        case "/history":
            try await handleHistoryCommand(user: user, chatId: chatId)
            
        case "/cancel":
            try await handleCancelCommand(user: user, chatId: chatId)
            
        case "/batch":
            try await handleBatchCommand(user: user, chatId: chatId)
            
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
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        
        let welcomeText = """
        👋 *Привет, \(user.displayName)!*
        
        Я *КарточкаПРО* — AI-копирайтер для WB/Ozon
        
        📊 *Твой пакет:* \(plan.emoji) \(plan.name)
        Осталось: \(remainingText) текстов + \(remainingPhoto) фото
        
        💡 *Пример что я создаю:*
        
        До: _"Кроссовки мужские белые"_
        После: _"Кроссовки мужские Mizuno Wave белые 46 размер спортивные подошва Мишлен"_
        
        🚀 *Что я делаю:*
        ✅ SEO-заголовки (100 символов)
        ✅ Продающие описания (500 символов)
        ✅ 5 ключевых выгод (bullets)
        ✅ 7 хештегов для поиска
        ✅ Анализ фото товара 📷
        
        💰 *Экономия:* Копирайтер 500₽ → Мы 14₽!
        
        Выбери категорию товара:
        """
        
        // Категории + кнопка подписки
        let categoryKeyboard = createCategoryKeyboard()
        let subscribeButton = [[
            TelegramInlineKeyboardButton(text: "💎 Тарифы и цены", callbackData: "view_packages")
        ]]
        
        let fullKeyboard = TelegramReplyMarkup(
            inlineKeyboard: (categoryKeyboard.inlineKeyboard ?? []) + subscribeButton
        )
        
        try await sendMessage(
            chatId: chatId,
            text: welcomeText,
            replyMarkup: fullKeyboard
        )
    }
    
    private func handleHelpCommand(chatId: Int64) async throws {
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
        От 299₽/мес за 20 описаний
        = 14.95₽ за описание (vs 500₽ у копирайтера!)
        
        ❓ *Вопросы?* \(Constants.Support.username)
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
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        
        let balanceText = """
        💰 *Твой баланс*
        
        📦 *Текущий пакет:* \(plan.emoji) \(plan.name)
        
        📊 *Осталось генераций:*
        • Текстовых: \(remainingText) из \(plan.textGenerationsLimit)
        • С фото: \(remainingPhoto) из \(plan.photoGenerationsLimit)
        • Всего: \(remainingText + remainingPhoto) из \(plan.totalGenerationsLimit)
        
        💡 *Цена за генерацию:* \(plan.pricePerGeneration) ₽
        """
        
        let buttons = [[
            TelegramInlineKeyboardButton(text: "💎 Пакеты", callbackData: "view_packages")
        ]]
        let keyboard = TelegramReplyMarkup(inlineKeyboard: buttons)
        
        try await sendMessage(chatId: chatId, text: balanceText, replyMarkup: keyboard)
    }
    
    private func handleSubscribeCommand(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let currentPlan = try await repo.getCurrentPlan(user)
        
        let subscribeText = """
        💎 *ПАКЕТЫ КАРТОЧКАПРО*
        
        Твой текущий: *\(currentPlan.emoji) \(currentPlan.name)*
        
        📦 *МАЛЫЙ* - 299₽/мес
        • 20 описаний (17 текстов + 3 фото)
        • 14.95₽ за описание
        • Для 1-5 товаров/неделя
        
        📦📦 *СРЕДНИЙ* - 599₽/мес
        • 50 описаний (45 текстов + 5 фото)
        • 11.98₽ за описание
        • Для 10-15 товаров/неделя
        
        📦📦📦 *БОЛЬШОЙ* - 999₽/мес
        • 100 описаний (90 текстов + 10 фото)
        • 9.99₽ за описание
        • Для 20-30 товаров/неделя
        
        🎁💎 *МАКСИМАЛЬНЫЙ* - 1,399₽/мес
        • 200 описаний (180 текстов + 20 фото)
        • 6.99₽ за описание
        • Для агентств, 30+ товаров/неделя
        
        ━━━━━━━━━━━━━━━━━━━
        💰 *ТВОЯ ЭКОНОМИЯ:*
        
        Копирайтер: 500₽ за описание
        Малый пакет: 14.95₽ за описание
        
        *Экономия: 97%!*
        
        Пример (Средний пакет):
        ❌ Копирайтер: 50 × 500₽ = 25,000₽
        ✅ КарточкаПРО: 599₽
        💎 *Экономишь: 24,401₽/мес!*
        ━━━━━━━━━━━━━━━━━━━
        
        ⚠️ Оплата через Tribute скоро!
        Пока доступен Free пакет.
        
        ❓ Вопросы? \(Constants.Support.username)
        """
        
        try await sendMessage(chatId: chatId, text: subscribeText)
    }
    
    private func handleHistoryCommand(user: User, chatId: Int64, offset: Int = 0, limit: Int = 5) async throws {
        let generations = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .range(offset..<(offset + limit))
            .all()
        
        let totalCount = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .count()
        
        guard !generations.isEmpty else {
            try await sendMessage(
                chatId: chatId,
                text: "📜 У тебя пока нет сохранённых описаний.\n\nИспользуй /generate чтобы создать первое!"
            )
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM, HH:mm"
        dateFormatter.locale = Locale(identifier: "ru_RU")
        
        var historyText = "📜 *История генераций* (\(offset+1)-\(offset+generations.count) из \(totalCount)):\n\n"
        
        var buttons: [[TelegramInlineKeyboardButton]] = []
        
        for (index, gen) in generations.enumerated() {
            let date = dateFormatter.string(from: gen.createdAt ?? Date())
            let categoryEmoji = Constants.ProductCategory(rawValue: gen.category)?.emoji ?? "📝"
            let title = (gen.resultTitle ?? gen.productName).prefix(35)
            
            historyText += "\(offset + index + 1)️⃣ \(categoryEmoji) \(date)\n"
            historyText += "\(title)...\n\n"
            
            // Кнопки для каждой генерации
            if let genId = gen.id?.uuidString {
                buttons.append([
                    TelegramInlineKeyboardButton(text: "👁 #\(offset + index + 1)", callbackData: "view_gen_\(genId)"),
                    TelegramInlineKeyboardButton(text: "✨ Улучшить", callbackData: "improve_\(genId)")
                ])
            }
        }
        
        // Пагинация
        var paginationButtons: [TelegramInlineKeyboardButton] = []
        if offset > 0 {
            paginationButtons.append(TelegramInlineKeyboardButton(text: "⬅️ Назад", callbackData: "history_\(max(0, offset - limit))_\(limit)"))
        }
        if offset + limit < totalCount {
            paginationButtons.append(TelegramInlineKeyboardButton(text: "Вперёд ➡️", callbackData: "history_\(offset + limit)_\(limit)"))
        }
        if !paginationButtons.isEmpty {
            buttons.append(paginationButtons)
        }
        
        // Кнопка экспорта всего
        buttons.append([
            TelegramInlineKeyboardButton(text: "📊 Экспорт всех в Excel", callbackData: "export_all_excel")
        ])
        
        let keyboard = TelegramReplyMarkup(inlineKeyboard: buttons)
        
        try await sendMessage(chatId: chatId, text: historyText, replyMarkup: keyboard)
    }
    
    private func handleCancelCommand(user: User, chatId: Int64) async throws {
        // Очистить выбранную категорию
        let repo = UserRepository(database: app.db)
        try await repo.updateCategory(user, category: nil)
        
        try await sendMessage(
            chatId: chatId,
            text: "✅ Действие отменено. Используй /start для возврата в меню."
        )
    }
    
    private func handleBatchCommand(user: User, chatId: Int64) async throws {
        let batchText = """
        📦 *Массовая генерация*
        
        Загрузи TXT файл с товарами, и я создам описания для всех!
        
        📝 *Формат файла:*
        ```
        Категория: одежда
        ---
        Платье женское красное 42 размер
        Кроссовки мужские Nike белые 45
        Футболка унисекс хлопок XXL
        ```
        
        📋 *Правила:*
        • Первая строка: `Категория: [название]`
        • Разделитель: `---`
        • Каждый товар на отдельной строке
        • Максимум 10 товаров за раз
        
        💡 *Результат:*
        • Получишь Excel файл со всеми описаниями
        • Каждый товар = 1 генерация из твоего лимита
        
        ⚡️ Загрузи файл, и начнём!
        """
        
        try await sendMessage(chatId: chatId, text: batchText)
    }
    
    // MARK: - Batch Processing (FR-6)
    
    private func handleBatchDocument(document: TelegramDocument, user: User, chatId: Int64) async throws {
        // Проверяем тип файла
        guard document.mimeType == "text/plain" || document.fileName?.hasSuffix(".txt") == true else {
            try await sendMessage(chatId: chatId, text: "❌ Поддерживаются только TXT файлы.")
            return
        }
        
        try await sendMessage(chatId: chatId, text: "⏳ Обрабатываю файл...")
        
        do {
            // Загружаем файл
            let fileContent = try await downloadFile(fileId: document.fileId)
            
            // Парсим содержимое
            let lines = fileContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            guard !lines.isEmpty else {
                try await sendMessage(chatId: chatId, text: "❌ Файл пустой.")
                return
            }
            
            // Первая строка должна быть категорией
            guard let firstLine = lines.first, firstLine.lowercased().starts(with: "категория:") else {
                try await sendMessage(chatId: chatId, text: "❌ Файл должен начинаться с 'Категория: [название]'")
                return
            }
            
            let categoryName = firstLine.replacingOccurrences(of: "Категория:", with: "").replacingOccurrences(of: "категория:", with: "").trimmingCharacters(in: .whitespaces)
            
            guard let category = Constants.ProductCategory.allCases.first(where: { $0.name.lowercased().contains(categoryName.lowercased()) }) else {
                try await sendMessage(chatId: chatId, text: "❌ Неизвестная категория: \(categoryName)")
                return
            }
            
            // Находим разделитель
            guard let separatorIndex = lines.firstIndex(of: "---") else {
                try await sendMessage(chatId: chatId, text: "❌ Не найден разделитель '---' после категории.")
                return
            }
            
            // Товары после разделителя
            let products = Array(lines[(separatorIndex + 1)...]).prefix(10) // Максимум 10
            
            guard !products.isEmpty else {
                try await sendMessage(chatId: chatId, text: "❌ Нет товаров в файле.")
                return
            }
            
            // Проверяем лимит
            let repo = UserRepository(database: app.db)
            let remaining = try await repo.getRemainingGenerations(user)
            
            guard remaining >= products.count else {
                try await sendMessage(chatId: chatId, text: "❌ Недостаточно генераций. Нужно: \(products.count), доступно: \(remaining)")
                return
            }
            
            // Генерируем описания
            try await sendMessage(chatId: chatId, text: "🚀 Генерирую \(products.count) описаний...")
            
            var results: [(product: String, description: ClaudeService.ProductDescription)] = []
            
            for (index, product) in products.enumerated() {
                try await sendMessage(chatId: chatId, text: "⏳ \(index + 1)/\(products.count): \(product.prefix(30))...")
                
                let description = try await app.claude.generateProductDescription(
                    productInfo: String(product),
                    category: category
                )
                
                results.append((product: String(product), description: description))
                
                // Инкрементируем счётчик
                try await repo.incrementGenerations(user)
                
                // Небольшая задержка между запросами
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 сек
            }
            
            // Отправляем результат
            try await sendBatchResults(chatId: chatId, results: results, category: category.name, user: user)
            
            app.logger.info("✅ Batch generation completed for user \(user.telegramId): \(results.count) products")
            
        } catch {
            app.logger.error("❌ Batch processing error: \(error)")
            try await sendMessage(chatId: chatId, text: "❌ Ошибка обработки файла: \(error.localizedDescription)")
        }
    }
    
    private func sendBatchResults(chatId: Int64, results: [(product: String, description: ClaudeService.ProductDescription)], category: String, user: User) async throws {
        // Формируем текстовый результат
        var resultText = """
        ✅ *Готово! Сгенерировано \(results.count) описаний*
        
        📦 Категория: \(category)
        
        """
        
        for (index, result) in results.enumerated() {
            resultText += "\(index + 1). \(result.product.prefix(30))... ✓\n"
        }
        
        try await sendMessage(chatId: chatId, text: resultText)
        
        // Создаём TXT файл с результатами
        var fileContent = "Массовая генерация описаний\n"
        fileContent += "Категория: \(category)\n"
        fileContent += "Дата: \(Date())\n"
        fileContent += "=" + String(repeating: "=", count: 60) + "\n\n"
        
        for (index, result) in results.enumerated() {
            fileContent += "\n📦 ТОВАР \(index + 1): \(result.product)\n\n"
            fileContent += "📝 ЗАГОЛОВОК:\n\(result.description.title)\n\n"
            fileContent += "📄 ОПИСАНИЕ:\n\(result.description.description)\n\n"
            fileContent += "🎯 КЛЮЧЕВЫЕ ВЫГОДЫ:\n"
            fileContent += result.description.bullets.map { "• \($0)" }.joined(separator: "\n")
            fileContent += "\n\n🏷 ХЕШТЕГИ:\n\(result.description.hashtags.joined(separator: " "))\n\n"
            fileContent += String(repeating: "-", count: 60) + "\n"
        }
        
        // Отправляем как документ
        try await sendDocument(
            chatId: chatId,
            content: fileContent,
            filename: "batch_\(Date().timeIntervalSince1970).txt",
            caption: "📦 Все описания в одном файле!"
        )
    }
    
    private func downloadFile(fileId: String) async throws -> String {
        // Получаем путь к файлу
        let getFileUrl = "https://api.telegram.org/bot\(app.environmentConfig.telegramBotToken)/getFile?file_id=\(fileId)"
        let getFileResponse = try await app.client.get(URI(string: getFileUrl))
        
        struct FileResponse: Content {
            struct Result: Content {
                let filePath: String
                
                enum CodingKeys: String, CodingKey {
                    case filePath = "file_path"
                }
            }
            let ok: Bool
            let result: Result
        }
        
        let fileInfo = try getFileResponse.content.decode(FileResponse.self)
        
        // Скачиваем файл
        let downloadUrl = "https://api.telegram.org/file/bot\(app.environmentConfig.telegramBotToken)/\(fileInfo.result.filePath)"
        let downloadResponse = try await app.client.get(URI(string: downloadUrl))
        
        guard let body = downloadResponse.body, let data = body.getData(at: 0, length: body.readableBytes) else {
            throw Abort(.internalServerError, reason: "Failed to download file")
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Callback Handlers
    
    private func handleCallback(_ callback: TelegramCallbackQuery) async throws {
        guard let data = callback.data else { return }
        
        app.logger.info("🔘 Callback from @\(callback.from.username ?? "unknown"): \(data)")
        
        let user = try await getOrCreateUser(from: callback.from, chatId: callback.message?.chat.id ?? callback.from.id)
        let chatId = callback.message?.chat.id ?? callback.from.id
        
        // Парсинг callback data
        guard let callbackData = CallbackData(rawValue: data) else {
            app.logger.warning("⚠️ Unknown callback data: \(data)")
            try await answerCallback(callbackId: callback.id, text: "Неизвестное действие")
            return
        }
        
        // Обработка через switch
        switch callbackData {
        case .category(let categoryRaw):
            try await handleCategorySelected(category: categoryRaw, user: user, chatId: chatId)
            
        case .quickGenerate(let categoryRaw):
            // Быстрая генерация - сразу просим текст
            let repo = UserRepository(database: app.db)
            try await repo.updateCategory(user, category: categoryRaw)
            
            guard let category = Constants.ProductCategory(rawValue: categoryRaw) else { return }
            
            try await sendMessage(
                chatId: chatId,
                text: "✅ Категория: \(category.displayName)\n\n\(Constants.BotMessage.enterProductInfo)"
            )
            
        case .newGeneration:
            try await handleGenerateCommand(user: user, chatId: chatId)
            
        case .myBalance:
            try await handleBalanceCommand(user: user, chatId: chatId)
            
        case .exportLast:
            try await handleExportFormatChoice(user: user, chatId: chatId)
            
        case .exportFormat(let format):
            if format == "excel" {
                try await handleExportExcel(user: user, chatId: chatId)
            } else {
                try await handleExportTxt(user: user, chatId: chatId)
            }
            
        case .exportAllExcel:
            try await handleExportAllExcel(user: user, chatId: chatId)
            
        case .buyPlan(let plan):
            try await handleBuyPlan(plan: plan, user: user, chatId: chatId)
            
        case .viewPackages:
            try await handleSubscribeCommand(user: user, chatId: chatId)
            
        case .copyMenu:
            try await handleCopyMenu(user: user, chatId: chatId)
            
        case .copyPart(let part):
            try await handleCopyPart(part: part, user: user, chatId: chatId, callbackId: callback.id)
            
        case .viewGeneration(let uuid):
            try await handleViewGeneration(uuid: uuid, user: user, chatId: chatId)
            
        case .improveResult(let uuid):
            try await handleImproveResult(generationUuid: uuid, user: user, chatId: chatId)
            
        case .viewHistory(let offset, let limit):
            try await handleHistoryCommand(user: user, chatId: chatId, offset: offset, limit: limit)
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
    
    // MARK: - Product Description Generation
    
    private func handleProductDescription(text: String, user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        
        app.logger.info("🟢 Starting product description generation")
        app.logger.info("  User: \(user.telegramId)")
        app.logger.info("  Text: \(text)")
        
        // Проверка что категория выбрана
        guard let categoryRaw = user.selectedCategory,
              let category = Constants.ProductCategory(rawValue: categoryRaw) else {
            app.logger.warning("⚠️ Category not selected for user \(user.telegramId)")
            try await sendMessage(
                chatId: chatId,
                text: "⚠️ Сначала выбери категорию товара через /start"
            )
            return
        }
        
        app.logger.info("  Category: \(category.name)")
        
        // Проверка лимитов
        let remaining = try await repo.getRemainingGenerations(user)
        app.logger.info("  Remaining generations: \(remaining)")
        
        guard try await repo.hasGenerationsAvailable(user) else {
            app.logger.warning("⚠️ User \(user.telegramId) exceeded limit")
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // Показать прогресс генерации
        let progressMessage = try await sendMessage(
            chatId: chatId,
            text: "⏳ *Анализирую товар...* 🔍"
        )
        
        do {
            app.logger.info("🟢 Calling Claude API...")
            
            // Обновляем статус через 3 секунды
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                try? await editMessage(
                    chatId: chatId,
                    messageId: progressMessage,
                    text: "⏳ *Генерирую описание...* ✍️"
                )
            }
            
            // Вызвать Claude API
            let description = try await app.claude.generateProductDescription(
                productInfo: text,
                category: category
            )
            
            app.logger.info("🟢 Claude API responded successfully")
            app.logger.info("  Tokens used: \(description.tokensUsed)")
            app.logger.info("  Processing time: \(description.processingTimeMs)ms")
            app.logger.info("  Title: \(description.title)")
            
            // Сохранить в БД
            app.logger.info("🟢 Saving to database...")
            
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
            app.logger.info("🟢 Saved to database: \(generation.id?.uuidString ?? "unknown")")
            
            // Увеличить счетчик
            try await repo.incrementGenerations(user)
            app.logger.info("🟢 Incremented user counter. Used: \(user.generationsUsed + 1)")
            
            // Отправить результат
            app.logger.info("🟢 Sending result to user...")
            try await sendGenerationResult(
                chatId: chatId,
                description: description,
                user: user
            )
            
            app.logger.info("✅ Successfully generated description for user \(user.telegramId) in \(description.processingTimeMs)ms")
            
        } catch {
            app.logger.error("❌ Generation error: \(error)")
            app.logger.error("❌ Error type: \(type(of: error))")
            app.logger.error("❌ Error description: \(String(describing: error))")
            
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
    }
    
    private func sendGenerationResult(
        chatId: Int64,
        description: ClaudeService.ProductDescription,
        user: User
    ) async throws {
        let repo = UserRepository(database: app.db)
        let remainingText = try await repo.getRemainingGenerations(user)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        
        // Получаем текущую категорию
        let currentCategory = user.selectedCategory.flatMap { Constants.ProductCategory(rawValue: $0) }
        
        // СООБЩЕНИЕ 1: Заголовок + Описание
        let message1 = """
        ✅ *Готово!*
        
        📝 *ЗАГОЛОВОК:*
        \(description.title)
        
        📄 *ОПИСАНИЕ:*
        \(description.description)
        """
        
        try await sendMessage(chatId: chatId, text: message1)
        
        // Небольшая задержка для читаемости
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 сек
        
        // СООБЩЕНИЕ 2: Bullets
        let bulletsText = description.bullets.map { "• \($0)" }.joined(separator: "\n")
        
        let message2 = """
        🎯 *КЛЮЧЕВЫЕ ВЫГОДЫ:*
        
        \(bulletsText)
        """
        
        try await sendMessage(chatId: chatId, text: message2)
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // СООБЩЕНИЕ 3: Хештеги + кнопки
        let hashtagsText = description.hashtags.joined(separator: " ")
        
        let message3 = """
        🏷 *ХЕШТЕГИ:*
        \(hashtagsText)
        
        ━━━━━━━━━━━━━━━━━━━
        ⚡️ *Осталось:* \(remainingText) текстов + \(remainingPhoto) фото
        """
        
        // Умные кнопки для дальнейших действий
        var buttons: [[TelegramInlineKeyboardButton]] = []
        
        // Первая строка: быстрая генерация той же категории
        if let category = currentCategory {
            buttons.append([
                TelegramInlineKeyboardButton(
                    text: "🔄 Ещё \(category.emoji) \(category.name)",
                    callbackData: "quick_generate_\(category.rawValue)"
                )
            ])
        }
        
        // Вторая строка: другая категория + баланс
        buttons.append([
            TelegramInlineKeyboardButton(text: "🔄 Другая категория", callbackData: "new_generation"),
            TelegramInlineKeyboardButton(text: "💰 Баланс", callbackData: "my_balance")
        ])
        
        // Третья строка: копирование по частям
        buttons.append([
            TelegramInlineKeyboardButton(text: "📋 Скопировать части", callbackData: "copy_menu")
        ])
        
        // Четвертая строка: экспорт + подписка
        buttons.append([
            TelegramInlineKeyboardButton(text: "📄 Экспорт", callbackData: "export_last"),
            TelegramInlineKeyboardButton(text: "💎 Пакеты", callbackData: "view_packages")
        ])
        
        let keyboard = TelegramReplyMarkup(inlineKeyboard: buttons)
        
        try await sendMessage(chatId: chatId, text: message3, replyMarkup: keyboard)
    }
    
    // MARK: - Photo Description Generation
    
    private func handlePhotoDescription(
        photos: [TelegramPhotoSize],
        caption: String?,
        user: User,
        chatId: Int64
    ) async throws {
        let repo = UserRepository(database: app.db)
        let plan = try await repo.getCurrentPlan(user)
        
        app.logger.info("📷 Photo generation request from user \(user.telegramId)")
        app.logger.info("  Current plan: \(plan.name)")
        
        // Проверка что категория выбрана
        guard let categoryRaw = user.selectedCategory,
              let category = Constants.ProductCategory(rawValue: categoryRaw) else {
            try await sendMessage(
                chatId: chatId,
                text: "⚠️ Сначала выбери категорию товара через /start"
            )
            return
        }
        
        // Проверка лимитов ФОТО (отдельно!)
        let remainingPhoto = try await repo.getRemainingPhotoGenerations(user)
        app.logger.info("  Remaining photo generations: \(remainingPhoto)")
        
        guard try await repo.hasPhotoGenerationsAvailable(user) else {
            let upgradeText = """
            📷 *Лимит фото исчерпан!*
            
            Твой план: *\(plan.emoji) \(plan.name)*
            Осталось фото: *0*
            
            Обнови пакет для большего количества описаний по фото:
            
            📦 Малый (299₽): 20 описаний (3 фото)
            📦📦 Средний (599₽): 50 описаний (5 фото)
            📦📦📦 Большой (999₽): 100 описаний (10 фото)
            🎁💎 Максимальный (1,399₽): 200 описаний (20 фото)
            
            /subscribe - посмотреть все пакеты
            """
            
            try await sendMessage(chatId: chatId, text: upgradeText)
            return
        }
        
        // Показать "Анализирую фото..."
        try await sendMessage(chatId: chatId, text: "🔍 Анализирую фотографию...\n\nЭто может занять 15-20 секунд.")
        
        do {
            // Получить самое большое фото
            guard let largestPhoto = photos.max(by: { $0.fileSize ?? 0 < $1.fileSize ?? 0 }) else {
                throw BotError.telegramAPIError(.badRequest)
            }
            
            // Скачать фото
            let imageData = try await downloadPhoto(fileId: largestPhoto.fileId)
            app.logger.info("  Downloaded photo: \(imageData.count) bytes")
            
            // СЖАТЬ фото до 1024x1024 (экономия токенов!)
            let compressedImage = try await compressImage(imageData, maxSize: 1024)
            app.logger.info("  Compressed photo: \(compressedImage.count) bytes (saved \(imageData.count - compressedImage.count) bytes)")
            
            // Вызвать Claude Vision API
            let additionalContext = caption ?? "Товар без дополнительного описания"
            let description = try await app.claude.generateProductDescriptionFromPhoto(
                imageData: compressedImage,
                productInfo: additionalContext,
                category: category
            )
            
            // Сохранить в БД
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
            
            // Увеличить счетчик ФОТО (отдельно!)
            try await repo.incrementPhotoGenerations(user)
            
            // Отправить результат
            try await sendGenerationResult(
                chatId: chatId,
                description: description,
                user: user
            )
            
            app.logger.info("✅ Generated description from photo for user \(user.telegramId)")
            
        } catch {
            app.logger.error("❌ Photo generation error: \(error)")
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
    }
    
    private func compressImage(_ imageData: Data, maxSize: Int) async throws -> Data {
        // Упрощённая реализация: если изображение больше 200KB, считаем что оно большое
        // В production лучше использовать CoreGraphics для реального сжатия
        
        let maxBytes = 200 * 1024 // 200KB
        
        if imageData.count <= maxBytes {
            app.logger.debug("  Image already small enough: \(imageData.count) bytes")
            return imageData
        }
        
        // Для production: здесь должно быть реальное сжатие через CoreGraphics
        // Сейчас просто возвращаем как есть и логируем
        app.logger.warning("  Image is large (\(imageData.count) bytes), but compression not implemented yet")
        app.logger.info("  TODO: Add CoreGraphics compression to \(maxSize)x\(maxSize)")
        
        return imageData
    }
    
    private func downloadPhoto(fileId: String) async throws -> Data {
        // Получить file_path через getFile API
        struct GetFileResponse: Content {
            let ok: Bool
            let result: FileInfo
        }
        
        struct FileInfo: Content {
            let filePath: String
            
            enum CodingKeys: String, CodingKey {
                case filePath = "file_path"
            }
        }
        
        let uri = URI(string: "\(baseURL)/getFile")
        
        let response = try await app.client.post(uri) { req in
            try req.content.encode(["file_id": fileId])
        }
        
        guard response.status == .ok else {
            throw BotError.telegramAPIError(response.status)
        }
        
        let fileResponse = try response.content.decode(GetFileResponse.self)
        
        // Скачать файл
        let fileURL = "https://api.telegram.org/file/bot\(botToken)/\(fileResponse.result.filePath)"
        let fileUri = URI(string: fileURL)
        
        let fileDataResponse = try await app.client.get(fileUri)
        
        guard fileDataResponse.status == .ok,
              let buffer = fileDataResponse.body else {
            throw BotError.telegramAPIError(.notFound)
        }
        
        return Data(buffer: buffer)
    }
    
    // MARK: - Export & Buy Handlers
    
    private func handleExportFormatChoice(user: User, chatId: Int64) async throws {
        let formatText = """
        📄 *Выбери формат экспорта:*
        """
        
        let keyboard = TelegramReplyMarkup(inlineKeyboard: [
            [
                TelegramInlineKeyboardButton(text: "📊 Excel (.xlsx)", callbackData: "export_excel"),
                TelegramInlineKeyboardButton(text: "📄 Текст (.txt)", callbackData: "export_txt")
            ]
        ])
        
        try await sendMessage(chatId: chatId, text: formatText, replyMarkup: keyboard)
    }
    
    private func handleExportExcel(user: User, chatId: Int64) async throws {
        // TODO: Реализовать Excel export через библиотеку
        try await sendMessage(
            chatId: chatId,
            text: "📊 Excel экспорт в разработке! Пока используй TXT формат."
        )
    }
    
    private func handleExportAllExcel(user: User, chatId: Int64) async throws {
        // TODO: Реализовать массовый Excel export
        try await sendMessage(
            chatId: chatId,
            text: "📊 Массовый Excel экспорт в разработке!\n\nПока доступен экспорт последнего описания через /history"
        )
    }
    
    private func handleExportTxt(user: User, chatId: Int64) async throws {
        // Получить последнюю генерацию
        let lastGeneration = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .first()
        
        guard let generation = lastGeneration,
              let title = generation.resultTitle,
              let description = generation.resultDescription,
              let bullets = generation.resultBullets,
              let hashtags = generation.resultHashtags else {
            try await sendMessage(
                chatId: chatId,
                text: "❌ Нет сохранённых описаний для экспорта. Сначала сгенерируй описание!"
            )
            return
        }
        
        // Формируем текстовый файл
        let bulletsText = bullets.map { "• \($0)" }.joined(separator: "\n")
        let hashtagsText = hashtags.joined(separator: " ")
        
        let fileContent = """
        📝 ОПИСАНИЕ ТОВАРА
        Создано: КарточкаПРО AI Bot
        Дата: \(generation.createdAt?.formatted() ?? "")
        
        ════════════════════════════════════
        
        ЗАГОЛОВОК:
        \(title)
        
        ════════════════════════════════════
        
        ОПИСАНИЕ:
        \(description)
        
        ════════════════════════════════════
        
        КЛЮЧЕВЫЕ ВЫГОДЫ:
        \(bulletsText)
        
        ════════════════════════════════════
        
        ХЕШТЕГИ:
        \(hashtagsText)
        
        ════════════════════════════════════
        
        Категория: \(generation.category)
        Токены использовано: \(generation.tokensUsed)
        Время обработки: \(generation.processingTimeMs)ms
        
        Создано через @kartochka_pro_bot
        """
        
        // Отправляем как документ
        try await sendDocument(
            chatId: chatId,
            content: fileContent,
            filename: "opisanie_\(generation.id?.uuidString.prefix(8) ?? "export").txt",
            caption: "📄 Твоё описание в удобном формате!"
        )
        
        app.logger.info("✅ Exported generation \(generation.id?.uuidString ?? "unknown") for user \(user.telegramId)")
    }
    
    private func handleBuyPlan(plan: String, user: User, chatId: Int64) async throws {
        // Пока Tribute не интегрирован - показываем заглушку
        let buyText = """
        💎 *Покупка подписки \(plan.capitalized)*
        
        ⚠️ Интеграция оплаты пока в разработке!
        
        Скоро здесь будет:
        • Автоматическая оплата через Tribute
        • Мгновенная активация подписки
        • Авторенев каждый месяц
        
        А пока пользуйся Free планом (3 описания).
        
        Хочешь больше описаний прямо сейчас?
        Напиши в поддержку: @vskamnev
        """
        
        try await sendMessage(chatId: chatId, text: buyText)
    }
    
    // MARK: - Copy Parts Feature (FR-8)
    
    private func handleCopyMenu(user: User, chatId: Int64) async throws {
        // Проверяем, есть ли генерации
        let hasGenerations = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .count() > 0
        
        guard hasGenerations else {
            try await sendMessage(chatId: chatId, text: "❌ У тебя пока нет генераций для копирования.")
            return
        }
        
        let menuText = """
        📋 *Копирование по частям*
        
        Выбери, что скопировать из последней генерации:
        """
        
        let buttons: [[TelegramInlineKeyboardButton]] = [
            [TelegramInlineKeyboardButton(text: "📝 Заголовок", callbackData: "copy_title")],
            [TelegramInlineKeyboardButton(text: "📄 Описание", callbackData: "copy_description")],
            [TelegramInlineKeyboardButton(text: "🎯 Ключевые выгоды", callbackData: "copy_bullets")],
            [TelegramInlineKeyboardButton(text: "🏷 Хештеги", callbackData: "copy_hashtags")],
            [TelegramInlineKeyboardButton(text: "📋 Всё сразу", callbackData: "copy_all")]
        ]
        
        let keyboard = TelegramReplyMarkup(inlineKeyboard: buttons)
        
        try await sendMessage(chatId: chatId, text: menuText, replyMarkup: keyboard)
    }
    
    private func handleCopyPart(part: String, user: User, chatId: Int64, callbackId: String) async throws {
        // Получаем последнюю генерацию
        guard let lastGeneration = try await Generation.query(on: app.db)
            .filter(\.$user.$id == user.id!)
            .sort(\.$createdAt, .descending)
            .first() else {
            try await answerCallback(callbackId: callbackId, text: "❌ Нет данных для копирования")
            return
        }
        
        let content: String
        let label: String
        
        switch part {
        case "title":
            content = lastGeneration.resultTitle ?? ""
            label = "📝 Заголовок"
        case "description":
            content = lastGeneration.resultDescription ?? ""
            label = "📄 Описание"
        case "bullets":
            content = (lastGeneration.resultBullets ?? []).joined(separator: "\n")
            label = "🎯 Ключевые выгоды"
        case "hashtags":
            content = (lastGeneration.resultHashtags ?? []).joined(separator: " ")
            label = "🏷 Хештеги"
        case "all":
            let bullets = (lastGeneration.resultBullets ?? []).joined(separator: "\n")
            let hashtags = (lastGeneration.resultHashtags ?? []).joined(separator: " ")
            content = """
            \(lastGeneration.resultTitle ?? "")
            
            \(lastGeneration.resultDescription ?? "")
            
            \(bullets)
            
            \(hashtags)
            """
            label = "📋 Полное описание"
        default:
            try await answerCallback(callbackId: callbackId, text: "❌ Неизвестная часть")
            return
        }
        
        // Отправляем контент для копирования
        try await sendMessage(chatId: chatId, text: "```\n\(content)\n```")
        try await answerCallback(callbackId: callbackId, text: "✅ \(label) скопирован!")
    }
    
    // MARK: - View Generation Feature
    
    private func handleViewGeneration(uuid: String, user: User, chatId: Int64) async throws {
        guard let generationUuid = UUID(uuidString: uuid),
              let generation = try await Generation.find(generationUuid, on: app.db) else {
            try await sendMessage(chatId: chatId, text: "❌ Генерация не найдена")
            return
        }
        
        // Показываем полное описание
        let bullets = (generation.resultBullets ?? []).map { "• \($0)" }.joined(separator: "\n")
        let hashtags = (generation.resultHashtags ?? []).joined(separator: " ")
        
        let resultText = """
        ✅ *Твоя генерация*
        
        📝 *ЗАГОЛОВОК:*
        \(generation.resultTitle ?? "")
        
        📄 *ОПИСАНИЕ:*
        \(generation.resultDescription ?? "")
        
        🎯 *КЛЮЧЕВЫЕ ВЫГОДЫ:*
        \(bullets)
        
        🏷 *ХЕШТЕГИ:*
        \(hashtags)
        """
        
        let buttons: [[TelegramInlineKeyboardButton]] = [
            [
                TelegramInlineKeyboardButton(text: "✨ Улучшить это", callbackData: "improve_\(uuid)"),
                TelegramInlineKeyboardButton(text: "📋 Копировать", callbackData: "copy_menu")
            ],
            [
                TelegramInlineKeyboardButton(text: "📄 Экспорт", callbackData: "export_last")
            ]
        ]
        
        let keyboard = TelegramReplyMarkup(inlineKeyboard: buttons)
        
        try await sendMessage(chatId: chatId, text: resultText, replyMarkup: keyboard)
    }
    
    // MARK: - Improve Result Feature (FR-5)
    
    private func handleImproveResult(generationUuid: String, user: User, chatId: Int64) async throws {
        // Находим генерацию
        guard let uuid = UUID(uuidString: generationUuid),
              let generation = try await Generation.find(uuid, on: app.db) else {
            try await sendMessage(chatId: chatId, text: "❌ Генерация не найдена")
            return
        }
        
        // Проверяем лимит
        let repo = UserRepository(database: app.db)
        guard try await repo.hasGenerationsAvailable(user) else {
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
            return
        }
        
        // Просим пользователя указать, что улучшить
        let improveText = """
        ✨ *Улучшение описания*
        
        Текущее описание:
        _\((generation.resultTitle ?? "").prefix(50))..._
        
        Напиши, что хочешь изменить или улучшить:
        
        Например:
        • "Сделай более эмоциональным"
        • "Добавь больше конкретики"
        • "Сделай короче"
        • "Упор на экологичность"
        
        Или отправь /cancel для отмены.
        """
        
        // Сохраняем UUID генерации для улучшения
        user.selectedCategory = "improve_\(generationUuid)"
        try await user.save(on: app.db)
        
        try await sendMessage(chatId: chatId, text: improveText)
    }
    
    private func handleImproveInput(text: String, user: User, chatId: Int64) async throws {
        // Извлекаем UUID из selectedCategory
        guard let category = user.selectedCategory,
              category.starts(with: "improve_"),
              let uuidString = category.split(separator: "_").last,
              let uuid = UUID(uuidString: String(uuidString)),
              let originalGeneration = try await Generation.find(uuid, on: app.db) else {
            try await sendMessage(chatId: chatId, text: "❌ Ошибка: не найдена оригинальная генерация")
            return
        }
        
        // Очищаем selectedCategory
        user.selectedCategory = nil
        try await user.save(on: app.db)
        
        app.logger.info("✨ Improving generation \(uuid) for user \(user.telegramId)")
        
        // Показываем прогресс
        let progressMessage = try await sendMessage(
            chatId: chatId,
            text: "⏳ *Улучшаю описание...* ✨"
        )
        
        do {
            // Создаём промпт для улучшения
            let bullets = (originalGeneration.resultBullets ?? []).joined(separator: "\n")
            let hashtags = (originalGeneration.resultHashtags ?? []).joined(separator: " ")
            
            let improvePrompt = """
            ЗАДАЧА: Улучши существующее описание товара согласно пожеланиям клиента.
            
            ОРИГИНАЛЬНОЕ ОПИСАНИЕ:
            Заголовок: \(originalGeneration.resultTitle ?? "")
            Описание: \(originalGeneration.resultDescription ?? "")
            Выгоды: \(bullets)
            Хештеги: \(hashtags)
            
            ПОЖЕЛАНИЯ КЛИЕНТА:
            \(text)
            
            Создай УЛУЧШЕННУЮ версию с учётом пожеланий. Сохрани структуру (заголовок, описание, bullets, hashtags).
            """
            
            // Вызываем Claude API
            guard let category = Constants.ProductCategory(rawValue: originalGeneration.category) else {
                throw Abort(.badRequest, reason: "Invalid category")
            }
            
            let description = try await app.claude.generateProductDescription(
                productInfo: improvePrompt,
                category: category
            )
            
            // Сохраняем улучшенную генерацию
            let generation = Generation(
                userId: user.id!,
                category: originalGeneration.category,
                productName: "✨ Улучшение: \(originalGeneration.productName)",
                productDetails: text
            )
            generation.resultTitle = description.title
            generation.resultDescription = description.description
            generation.resultBullets = description.bullets
            generation.resultHashtags = description.hashtags
            try await generation.save(on: app.db)
            
            // Инкрементируем счётчик
            let repo = UserRepository(database: app.db)
            try await repo.incrementGenerations(user)
            
            // Отправляем результат
            try await sendGenerationResult(chatId: chatId, description: description, user: user)
            
            app.logger.info("✅ Successfully improved generation for user \(user.telegramId)")
            
        } catch {
            app.logger.error("❌ Error improving generation: \(error)")
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.error)
        }
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
    
    @discardableResult
    func sendMessage(
        chatId: Int64,
        text: String,
        parseMode: String = "Markdown",
        replyMarkup: TelegramReplyMarkup? = nil
    ) async throws -> Int64? {
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
        
        // Извлекаем message_id из ответа
        struct SendMessageResponse: Content {
            let ok: Bool
            let result: MessageResult
            
            struct MessageResult: Content {
                let messageId: Int64
                
                enum CodingKeys: String, CodingKey {
                    case messageId = "message_id"
                }
            }
        }
        
        let sendResponse = try? response.content.decode(SendMessageResponse.self)
        return sendResponse?.result.messageId
    }
    
    func editMessage(
        chatId: Int64,
        messageId: Int64?,
        text: String,
        parseMode: String = "Markdown"
    ) async throws {
        guard let messageId = messageId else { return }
        
        struct EditMessageText: Content {
            let chatId: Int64
            let messageId: Int64
            let text: String
            let parseMode: String?
            
            enum CodingKeys: String, CodingKey {
                case chatId = "chat_id"
                case messageId = "message_id"
                case text
                case parseMode = "parse_mode"
            }
        }
        
        let uri = URI(string: "\(baseURL)/editMessageText")
        
        _ = try await app.client.post(uri) { req in
            try req.content.encode(EditMessageText(
                chatId: chatId,
                messageId: messageId,
                text: text,
                parseMode: parseMode
            ))
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
    
    private func sendDocument(
        chatId: Int64,
        content: String,
        filename: String,
        caption: String? = nil
    ) async throws {
        // Создаём временный файл
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Отправляем через Telegram API
        let uri = URI(string: "\(baseURL)/sendDocument")
        
        let response = try await app.client.post(uri) { req in
            let boundary = UUID().uuidString
            req.headers.contentType = HTTPMediaType(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
            
            var body = ByteBuffer()
            
            // chat_id
            body.writeString("--\(boundary)\r\n")
            body.writeString("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n")
            body.writeString("\(chatId)\r\n")
            
            // document (file)
            body.writeString("--\(boundary)\r\n")
            body.writeString("Content-Disposition: form-data; name=\"document\"; filename=\"\(filename)\"\r\n")
            body.writeString("Content-Type: text/plain\r\n\r\n")
            
            let fileData = try Data(contentsOf: fileURL)
            body.writeData(fileData)
            body.writeString("\r\n")
            
            // caption
            if let caption = caption {
                body.writeString("--\(boundary)\r\n")
                body.writeString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
                body.writeString(caption)
                body.writeString("\r\n")
            }
            
            body.writeString("--\(boundary)--\r\n")
            
            req.body = body
        }
        
        guard response.status == HTTPResponseStatus.ok else {
            throw BotError.telegramAPIError(response.status)
        }
    }
    
    // MARK: - Errors
    
    enum BotError: Error {
        case telegramAPIError(HTTPResponseStatus)
        case userNotFound
        case limitExceeded
    }
    
    // MARK: - Callback Data
    
    enum CallbackData {
        case category(String)
        case newGeneration
        case quickGenerate(String) // быстрая генерация той же категории
        case myBalance
        case exportLast
        case buyPlan(String)
        case viewPackages
        case exportFormat(String) // "excel" or "txt"
        case exportAllExcel
        case copyMenu // показать меню копирования
        case copyPart(String) // "title", "description", "bullets", "hashtags", "all"
        case viewGeneration(String) // UUID генерации для просмотра
        case improveResult(String) // UUID генерации для улучшения
        case viewHistory(Int, Int) // offset, limit
        
        init?(rawValue: String) {
            if rawValue.starts(with: "category_") {
                let category = String(rawValue.dropFirst("category_".count))
                self = .category(category)
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
                } else {
                    return nil
                }
            } else if rawValue.starts(with: "export_") {
                let format = String(rawValue.dropFirst("export_".count))
                self = .exportFormat(format)
            } else {
                return nil
            }
        }
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

