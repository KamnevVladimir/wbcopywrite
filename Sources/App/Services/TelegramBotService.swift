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
            // Обработка текста товара для генерации
            try await handleProductDescription(text: text, user: user, chatId: message.chat.id)
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
    
    private func handleSubscribeCommand(user: User, chatId: Int64) async throws {
        let repo = UserRepository(database: app.db)
        let currentPlan = try await repo.getCurrentPlan(user)
        
        let subscribeText = """
        💎 *Тарифные планы КарточкаПРО*
        
        Твой текущий план: *\(currentPlan.name)*
        
        📦 *Starter* - 299₽/мес
        • 30 описаний в месяц
        • Все категории товаров
        • SEO-оптимизация
        • Экономия 95% vs копирайтер!
        
        🚀 *Business* - 599₽/мес
        • 150 описаний в месяц
        • Все категории товаров
        • SEO-оптимизация
        • Идеально для активных селлеров
        
        💼 *Pro* - 999₽/мес
        • 500 описаний в месяц
        • Все категории товаров
        • Приоритетная обработка
        • Для крупных селлеров и агентств
        
        ⭐️ *Ultra* - 1,499₽/мес
        • 1000 описаний в месяц
        • Генерация по ФОТО 📷
        • Все категории товаров
        • Приоритетная поддержка
        • Для power-селлеров
        
        💰 *ROI:* 1 описание от копирайтера = 500₽
        С нашим ботом = 10₽! Экономия 98%!
        
        ⚠️ Скоро здесь будет оплата через Tribute!
        Пока можно пользоваться Free планом (3 описания).
        
        Хочешь протестировать? Используй /generate
        """
        
        try await sendMessage(chatId: chatId, text: subscribeText)
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
            
        case .newGeneration:
            try await handleGenerateCommand(user: user, chatId: chatId)
            
        case .myBalance:
            try await handleBalanceCommand(user: user, chatId: chatId)
            
        case .exportLast:
            try await handleExportLast(user: user, chatId: chatId)
            
        case .buyPlan(let plan):
            try await handleBuyPlan(plan: plan, user: user, chatId: chatId)
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
        
        // Показать "Генерирую..."
        try await sendMessage(chatId: chatId, text: Constants.BotMessage.generating)
        
        do {
            app.logger.info("🟢 Calling Claude API...")
            
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
        let remaining = try await repo.getRemainingGenerations(user)
        
        let bulletsText = description.bullets.map { "• \($0)" }.joined(separator: "\n")
        let hashtagsText = description.hashtags.joined(separator: " ")
        
        let resultText = """
        ✅ *Готово!* Вот твоё описание:
        
        📝 *Заголовок:*
        \(description.title)
        
        📄 *Описание:*
        \(description.description)
        
        🎯 *Ключевые выгоды:*
        \(bulletsText)
        
        🏷 *Хештеги:*
        \(hashtagsText)
        
        ⚡️ Осталось генераций: *\(remaining)*
        """
        
        // Кнопки для дальнейших действий
        let keyboard = TelegramReplyMarkup(inlineKeyboard: [
            [
                TelegramInlineKeyboardButton(text: "🔄 Новая генерация", callbackData: "new_generation"),
                TelegramInlineKeyboardButton(text: "💰 Мой баланс", callbackData: "my_balance")
            ],
            [
                TelegramInlineKeyboardButton(text: "📄 Экспорт в файл", callbackData: "export_last")
            ]
        ])
        
        try await sendMessage(chatId: chatId, text: resultText, replyMarkup: keyboard)
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
        
        // Проверка Ultra подписки (фото доступно только для Ultra)
        guard plan == .ultra else {
            let upgradeText = """
            📷 *Генерация по фото доступна только в Ultra!*
            
            С Ultra подпиской ты получаешь:
            • ✨ Генерация по фотографиям товара
            • 🚀 1000 описаний в месяц
            • ⚡️ Приоритетная обработка
            • 🎯 Расширенные промпты
            
            Цена: *1,499₽/мес*
            
            Хочешь попробовать текстовую генерацию? Используй /start
            """
            
            let keyboard = TelegramReplyMarkup(inlineKeyboard: [
                [TelegramInlineKeyboardButton(text: "⭐️ Купить Ultra", callbackData: "buy_ultra")]
            ])
            
            try await sendMessage(chatId: chatId, text: upgradeText, replyMarkup: keyboard)
            return
        }
        
        // Проверка что категория выбрана
        guard let categoryRaw = user.selectedCategory,
              let category = Constants.ProductCategory(rawValue: categoryRaw) else {
            try await sendMessage(
                chatId: chatId,
                text: "⚠️ Сначала выбери категорию товара через /start"
            )
            return
        }
        
        // Проверка лимитов
        guard try await repo.hasGenerationsAvailable(user) else {
            try await sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
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
            
            // Вызвать Claude Vision API
            let additionalContext = caption ?? "Товар без дополнительного описания"
            let description = try await app.claude.generateProductDescriptionFromPhoto(
                imageData: imageData,
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
            
            // Увеличить счетчик
            try await repo.incrementGenerations(user)
            
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
    
    private func handleExportLast(user: User, chatId: Int64) async throws {
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
        case myBalance
        case exportLast
        case buyPlan(String)
        
        init?(rawValue: String) {
            if rawValue.starts(with: "category_") {
                let category = String(rawValue.dropFirst("category_".count))
                self = .category(category)
            } else if rawValue == "new_generation" {
                self = .newGeneration
            } else if rawValue == "my_balance" {
                self = .myBalance
            } else if rawValue == "export_last" {
                self = .exportLast
            } else if rawValue.starts(with: "buy_") {
                let plan = String(rawValue.dropFirst("buy_".count))
                self = .buyPlan(plan)
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

