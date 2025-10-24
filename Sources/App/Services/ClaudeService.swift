import Vapor

/// Claude AI Service для генерации описаний товаров
final class ClaudeService: @unchecked Sendable {
    private let app: Application
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    
    init(app: Application, apiKey: String) {
        self.app = app
        self.apiKey = apiKey
        
        // Логируем что ключ загружен (без показа самого ключа!)
        let keyPreview = String(apiKey.prefix(10))
        app.logger.info("🔑 Claude API key loaded: \(keyPreview)...")
    }
    
    // MARK: - Public API
    
    /// Сгенерировать описание товара
    func generateProductDescription(
        productInfo: String,
        category: Constants.ProductCategory
    ) async throws -> ProductDescription {
        let startTime = Date()
        
        app.logger.info("🤖 Generating description for category: \(category.name)")
        
        // Подготовить промпт
        let prompt = buildPrompt(productInfo: productInfo, category: category)
        
        // Вызвать Claude API
        let response = try await callClaudeAPI(prompt: prompt)
        
        // Парсить ответ
        let description = try parseResponse(response)
        
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000) // ms
        
        app.logger.info("✅ Description generated in \(processingTime)ms")
        
        return ProductDescription(
            title: description.title,
            description: description.description,
            bullets: description.bullets,
            hashtags: description.hashtags,
            tokensUsed: response.usage.inputTokens + response.usage.outputTokens,
            processingTimeMs: processingTime
        )
    }
    
    /// Улучшить существующее описание товара
    func improveProductDescription(
        currentTitle: String,
        currentDescription: String,
        currentBullets: [String],
        currentHashtags: [String],
        category: Constants.ProductCategory
    ) async throws -> ProductDescription {
        let startTime = Date()
        
        app.logger.info("🔧 Improving description for category: \(category.name)")
        
        // Получаем трендовые ключевые слова и триггеры
        let seoService = SEOOptimizationService(app: app)
        let trendingKeywords = seoService.getTrendingKeywords(for: category)
        let emotionalTriggers = seoService.getEmotionalTriggers(for: category)
        let fomoTriggers = seoService.getFOMOTriggers(for: category)
        let socialProofTriggers = seoService.getSocialProofTriggers()
        let urgencyTriggers = seoService.getUrgencyTriggers()
        
        let improvePrompt = """
        КАТЕГОРИЯ: \(category.name)
        
        ТЕКУЩЕЕ ОПИСАНИЕ:
        Заголовок: \(currentTitle)
        Описание: \(currentDescription)
        Bullets: \(currentBullets.joined(separator: ", "))
        Хештеги: \(currentHashtags.joined(separator: ", "))
        
        🎯 ЗАДАЧА: УЛУЧШИ ОПИСАНИЕ ДЛЯ МАКСИМАЛЬНОЙ КОНВЕРСИИ
        
        📈 ИСПОЛЬЗУЙ ТРЕНДОВЫЕ КЛЮЧЕВИКИ 2024-2025:
        \(trendingKeywords.joined(separator: ", "))
        
        💝 ДОБАВЬ ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
        \(emotionalTriggers.joined(separator: ", "))
        
        ⚡ ВКЛЮЧИ FOMO ТРИГГЕРЫ:
        \(fomoTriggers.joined(separator: ", "))
        
        👥 ДОБАВЬ СОЦИАЛЬНЫЕ ДОКАЗАТЕЛЬСТВА:
        \(socialProofTriggers.joined(separator: ", "))
        
        ⏰ ВКЛЮЧИ ТРИГГЕРЫ СРОЧНОСТИ:
        \(urgencyTriggers.joined(separator: ", "))
        
        \(getCategorySpecificGuidelines(category))
        
        УЛУЧШИ:
        1. Сделай заголовок более цепляющим и SEO-оптимизированным
        2. Добавь эмоциональные триггеры в описание
        3. Усиль bullets с конкретными выгодами и цифрами
        4. Обнови хештеги трендовыми ключевыми словами
        5. Добавь элементы конверсионной оптимизации
        
        Создай улучшенное описание в JSON формате.
        """
        
        // Вызвать Claude API
        let response = try await callClaudeAPI(prompt: improvePrompt)
        
        // Парсить ответ
        let description = try parseResponse(response)
        
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000) // ms
        
        app.logger.info("✅ Description improved in \(processingTime)ms")
        
        return ProductDescription(
            title: description.title,
            description: description.description,
            bullets: description.bullets,
            hashtags: description.hashtags,
            tokensUsed: response.usage.inputTokens + response.usage.outputTokens,
            processingTimeMs: processingTime
        )
    }
    
    /// Сгенерировать описание товара по фотографии (Vision API)
    func generateProductDescriptionFromPhoto(
        imageData: Data,
        productInfo: String,
        category: Constants.ProductCategory
    ) async throws -> ProductDescription {
        let startTime = Date()
        
        app.logger.info("📷 Generating description from photo for category: \(category.name)")
        
        // Конвертировать изображение в base64
        let base64Image = imageData.base64EncodedString()
        
        // Определить MIME тип (упрощенно, предполагаем JPEG)
        let mediaType = detectMediaType(from: imageData)
        
        // Подготовить промпт для Vision API
        let prompt = buildPhotoPrompt(productInfo: productInfo, category: category)
        
        // Вызвать Claude Vision API
        let response = try await callClaudeVisionAPI(
            prompt: prompt,
            imageBase64: base64Image,
            mediaType: mediaType
        )
        
        // Парсить ответ
        let description = try parseResponse(response)
        
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000) // ms
        
        app.logger.info("✅ Description from photo generated in \(processingTime)ms")
        
        return ProductDescription(
            title: description.title,
            description: description.description,
            bullets: description.bullets,
            hashtags: description.hashtags,
            tokensUsed: response.usage.inputTokens + response.usage.outputTokens,
            processingTimeMs: processingTime
        )
    }
    
    // MARK: - Claude API
    
    private func callClaudeAPI(prompt: String) async throws -> ClaudeResponse {
        let uri = URI(string: "\(baseURL)/messages")
        
        // Разделяем на system (кэшируется) и user (каждый раз новый)
        let systemPrompt = """
        Ты ТОП-копирайтер для маркетплейсов Wildberries и Ozon с 15+ лет опыта. Специализируешься на создании описаний, которые конвертируют в 2-3 раза лучше среднего.
        
        ТВОЯ ЗАДАЧА:
        Создавать максимально продающие SEO-оптимизированные описания товаров, которые увеличивают конверсию и выручку.
        
        ПРОДВИНУТЫЕ ПРИНЦИПЫ КОПИРАЙТИНГА:
        
        🎯 ПСИХОЛОГИЧЕСКИЕ ТРИГГЕРЫ:
        - FOMO (страх упустить выгоду): "Ограниченная серия", "Последние штуки"
        - Социальное доказательство: "Выбор 10,000+ покупателей", "Топ-продаж"
        - Авторитет: "Рекомендуют эксперты", "Сертифицировано"
        - Срочность: "Акция до конца недели", "Быстрая доставка"
        - Эмоции: "Почувствуй себя уверенно", "Подари радость"
        
        🔥 СТРУКТУРА МАКСИМАЛЬНОЙ КОНВЕРСИИ:
        1. HOOK (первые 2 предложения) - цепляющий, с эмоциональным триггером
        2. ПРОБЛЕМА/ПОТРЕБНОСТЬ - что решает товар
        3. РЕШЕНИЕ - как товар решает проблему
        4. ВЫГОДЫ - конкретные преимущества с цифрами
        5. ДОКАЗАТЕЛЬСТВА - характеристики, материалы, технологии
        6. CTA - призыв к действию
        
        📈 SEO-ОПТИМИЗАЦИЯ ПРЕМИУМ:
        - Используй трендовые ключевые слова 2024-2025
        - Включай длинные хвосты (long-tail keywords)
        - Добавляй синонимы и вариации
        - Учитывай сезонность и актуальность
        - Используй локальные запросы для России
        
        💎 ТЕХНИКИ ПРОДАЖ:
        - Конкретные цифры вместо общих фраз
        - Сравнения с конкурентами (не называя их)
        - Уникальные торговые предложения (УТП)
        - Эмоциональные описания ощущений
        - Призывы к действию в каждом блоке
        
        ФОРМАТ ОТВЕТА (строго JSON):
        {
          "title": "Заголовок товара (до 100 символов, с ключевыми словами)",
          "description": "Описание 200-500 символов (продающее, с триггерами)",
          "bullets": ["Выгода 1", "Выгода 2", "Выгода 3", "Выгода 4", "Выгода 5"],
          "hashtags": ["#хештег1", "#хештег2", "#хештег3", "#хештег4", "#хештег5", "#хештег6", "#хештег7"]
        }
        
        ВАЖНО: Отвечай ТОЛЬКО валидным JSON, без markdown блоков!
        """
        
        let request = ClaudeRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 2000,
            system: systemPrompt,
            messages: [
                ClaudeRequest.Message(role: "user", content: prompt)
            ]
        )
        
        // Детальное логирование запроса
        app.logger.info("🔵 Claude API Request:")
        app.logger.info("  Model: \(request.model)")
        app.logger.info("  Max tokens: \(request.maxTokens)")
        app.logger.info("  Prompt length: \(prompt.count) chars")
        app.logger.debug("  Prompt preview: \(prompt.prefix(200))...")
        
        let response = try await app.client.post(uri) { req in
            req.headers.add(name: "x-api-key", value: apiKey)
            req.headers.add(name: "anthropic-version", value: "2023-06-01")
            req.headers.contentType = .json
            
            try req.content.encode(request)
            
            // Логирование отправляемого JSON
            if let jsonData = try? JSONEncoder().encode(request),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                app.logger.debug("  Request JSON: \(jsonString)")
            }
        }
        
        // Детальное логирование ответа
        app.logger.info("🔵 Claude API Response: \(response.status)")
        
        guard response.status == HTTPStatus.ok else {
            app.logger.error("❌ Claude API error: \(response.status)")
            
            // Логировать полный ответ для отладки
            if let bodyString = response.body.flatMap({ String(buffer: $0) }) {
                app.logger.error("❌ Response body: \(bodyString)")
            }
            
            throw ClaudeError.apiError(response.status)
        }
        
        // Логировать успешный ответ
        if let bodyString = response.body.flatMap({ String(buffer: $0) }) {
            app.logger.debug("✅ Response body: \(bodyString.prefix(500))...")
        }
        
        return try response.content.decode(ClaudeResponse.self)
    }
    
    private func callClaudeVisionAPI(
        prompt: String,
        imageBase64: String,
        mediaType: String
    ) async throws -> ClaudeResponse {
        let uri = URI(string: "\(baseURL)/messages")
        
        // Структура для Vision API запроса
        struct VisionRequest: Content {
            let model: String
            let maxTokens: Int
            let messages: [VisionMessage]
            
            enum CodingKeys: String, CodingKey {
                case model
                case maxTokens = "max_tokens"
                case messages
            }
        }
        
        struct VisionMessage: Content {
            let role: String
            let content: [VisionContent]
        }
        
        struct VisionContent: Content {
            let type: String
            let text: String?
            let source: ImageSource?
            
            struct ImageSource: Content {
                let type: String
                let mediaType: String
                let data: String
                
                enum CodingKeys: String, CodingKey {
                    case type
                    case mediaType = "media_type"
                    case data
                }
            }
        }
        
        let request = VisionRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 2000,
            messages: [
                VisionMessage(
                    role: "user",
                    content: [
                        VisionContent(
                            type: "image",
                            text: nil,
                            source: VisionContent.ImageSource(
                                type: "base64",
                                mediaType: mediaType,
                                data: imageBase64
                            )
                        ),
                        VisionContent(
                            type: "text",
                            text: prompt,
                            source: nil
                        )
                    ]
                )
            ]
        )
        
        // Детальное логирование Vision запроса
        app.logger.info("🔵 Claude Vision API Request:")
        app.logger.info("  Model: \(request.model)")
        app.logger.info("  Max tokens: \(request.maxTokens)")
        app.logger.info("  Image size: \(imageBase64.count) chars (base64)")
        app.logger.info("  Media type: \(mediaType)")
        app.logger.info("  Prompt length: \(prompt.count) chars")
        
        let response = try await app.client.post(uri) { req in
            req.headers.add(name: "x-api-key", value: apiKey)
            req.headers.add(name: "anthropic-version", value: "2023-06-01")
            req.headers.contentType = .json
            
            try req.content.encode(request)
        }
        
        // Детальное логирование ответа
        app.logger.info("🔵 Claude Vision API Response: \(response.status)")
        
        guard response.status == HTTPStatus.ok else {
            app.logger.error("❌ Claude Vision API error: \(response.status)")
            
            // Логировать полный ответ для отладки
            if let bodyString = response.body.flatMap({ String(buffer: $0) }) {
                app.logger.error("❌ Response body: \(bodyString)")
            }
            
            throw ClaudeError.apiError(response.status)
        }
        
        // Логировать успешный ответ
        if let bodyString = response.body.flatMap({ String(buffer: $0) }) {
            app.logger.debug("✅ Response body: \(bodyString.prefix(500))...")
        }
        
        return try response.content.decode(ClaudeResponse.self)
    }
    
    // MARK: - Prompt Building
    
    private func buildPrompt(productInfo: String, category: Constants.ProductCategory) -> String {
        // Получаем трендовые ключевые слова и триггеры
        let seoService = SEOOptimizationService(app: app)
        let trendingKeywords = seoService.getTrendingKeywords(for: category)
        let emotionalTriggers = seoService.getEmotionalTriggers(for: category)
        let fomoTriggers = seoService.getFOMOTriggers(for: category)
        let socialProofTriggers = seoService.getSocialProofTriggers()
        let urgencyTriggers = seoService.getUrgencyTriggers()
        
        let userPrompt = """
        КАТЕГОРИЯ: \(category.name)
        
        ИНФОРМАЦИЯ О ТОВАРЕ:
        \(productInfo)
        
        🎯 ИСПОЛЬЗУЙ В ОПИСАНИИ:
        
        📈 ТРЕНДОВЫЕ КЛЮЧЕВИКИ 2024-2025:
        \(trendingKeywords.joined(separator: ", "))
        
        💝 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
        \(emotionalTriggers.joined(separator: ", "))
        
        ⚡ FOMO ТРИГГЕРЫ:
        \(fomoTriggers.joined(separator: ", "))
        
        👥 СОЦИАЛЬНЫЕ ДОКАЗАТЕЛЬСТВА:
        \(socialProofTriggers.joined(separator: ", "))
        
        ⏰ ТРИГГЕРЫ СРОЧНОСТИ:
        \(urgencyTriggers.joined(separator: ", "))
        
        \(getCategorySpecificGuidelines(category))
        
        Создай максимально продающее описание в JSON формате, используя эти триггеры естественно и органично.
        """
        
        return userPrompt
    }
    
    private func getCategorySpecificGuidelines(_ category: Constants.ProductCategory) -> String {
        switch category {
        case .clothing:
            return """
            👗 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ ОДЕЖДЫ И ОБУВИ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Почувствуй себя уверенно в любой ситуации"
            - "Создай неповторимый образ"
            - "Выделись из толпы стильным выбором"
            - "Подари себе комфорт на весь день"
            
            📊 КОНКРЕТНЫЕ ХАРАКТЕРИСТИКИ:
            - Материалы: состав, свойства (дышащий, гипоаллергенный, водоотталкивающий)
            - Размеры: точные параметры, универсальность
            - Сезонность: для какого времени года, температурный режим
            - Стиль: casual, business, вечерний, спортивный
            - Уход: как стирать, гладить, хранить
            
            🔥 УТП И ВЫГОДЫ:
            - Уникальные технологии (мембрана, антибактериальная пропитка)
            - Премиум-материалы по доступной цене
            - Универсальность (подходит для работы и отдыха)
            - Долговечность и износостойкость
            - Легкость и комфорт при носке
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "тренд", "модный", "стильный", "качественный"
            - "размер", "цвет", "материал", "сезон"
            - "женский/мужской", "унисекс", "детский"
            - "премиум", "бюджетный", "доступный"
            """
            
        case .electronics:
            return """
            📱 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ ЭЛЕКТРОНИКИ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Увеличь свою продуктивность в разы"
            - "Наслаждайся премиум-качеством"
            - "Будь на шаг впереди технологий"
            - "Подари себе комфорт и удобство"
            
            📊 ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ:
            - Процессор, память, экран, батарея
            - Совместимость с операционными системами
            - Скорость работы, время автономности
            - Разъемы, интерфейсы, беспроводные технологии
            - Гарантия, сертификация, безопасность
            
            🔥 УТП И ВЫГОДЫ:
            - Преимущества перед конкурентами (не называя их)
            - Уникальные функции и возможности
            - Энергоэффективность и экологичность
            - Простота использования и настройки
            - Соотношение цена/качество
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "быстрый", "мощный", "надежный", "качественный"
            - "новый", "последняя модель", "инновационный"
            - "беспроводной", "портативный", "компактный"
            - "умный", "автоматический", "интеллектуальный"
            """
            
        case .home:
            return """
            🏠 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ ДОМА И САДА:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Создай уютную атмосферу в доме"
            - "Преврати свой дом в место мечты"
            - "Подари семье комфорт и безопасность"
            - "Сделай жизнь проще и удобнее"
            
            📊 ФУНКЦИОНАЛЬНЫЕ ХАРАКТЕРИСТИКИ:
            - Материалы: экологичность, долговечность, безопасность
            - Размеры: точные параметры, компактность
            - Функциональность: что умеет, как работает
            - Установка: простота монтажа, инструкции
            - Уход: как чистить, обслуживать, хранить
            
            🔥 УТП И ВЫГОДЫ:
            - Решение конкретных бытовых проблем
            - Экономия времени и сил
            - Повышение комфорта и качества жизни
            - Долговечность и надежность
            - Эстетическая привлекательность
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "удобный", "практичный", "функциональный"
            - "качественный", "надежный", "долговечный"
            - "компактный", "портативный", "мобильный"
            - "эко", "экологичный", "безопасный"
            """
            
        case .beauty:
            return """
            💄 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ КРАСОТЫ И ЗДОРОВЬЯ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Подари себе сияющую красоту"
            - "Почувствуй себя уверенно и привлекательно"
            - "Заботься о себе с любовью"
            - "Открой свою естественную красоту"
            
            📊 СОСТАВ И ЭФФЕКТЫ:
            - Активные компоненты и их действие
            - Результаты: что получишь, через какое время
            - Безопасность: гипоаллергенность, тестирование
            - Типы кожи/волос: для кого подходит
            - Способ применения: как использовать
            
            🔥 УТП И ВЫГОДЫ:
            - Натуральные/органические компоненты
            - Доказанная эффективность
            - Безопасность и гипоаллергенность
            - Быстрый и видимый результат
            - Профессиональное качество по доступной цене
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "натуральный", "органический", "эко"
            - "эффективный", "результативный", "действенный"
            - "безопасный", "гипоаллергенный", "тестированный"
            - "профессиональный", "премиум", "качественный"
            """
            
        case .sports:
            return """
            ⚽️ ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ СПОРТА И ОТДЫХА:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Достигай новых высот в спорте"
            - "Почувствуй силу и выносливость"
            - "Преврати тренировки в удовольствие"
            - "Будь примером для других"
            
            📊 ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ:
            - Материалы: прочность, эластичность, воздухопроницаемость
            - Технологии: инновационные решения, патенты
            - Размеры: точные параметры, универсальность
            - Применение: для каких видов спорта/активности
            - Уход: как стирать, сушить, хранить
            
            🔥 УТП И ВЫГОДЫ:
            - Профессиональное качество для любителей
            - Уникальные технологии и материалы
            - Максимальный комфорт при нагрузках
            - Долговечность и износостойкость
            - Поддержка и стабилизация тела
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "профессиональный", "спортивный", "тренировочный"
            - "прочный", "надежный", "качественный"
            - "комфортный", "удобный", "эргономичный"
            - "технологичный", "инновационный", "современный"
            """
            
        case .kids:
            return """
            🧸 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ ДЕТСКИХ ТОВАРОВ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Подари ребенку радость и развитие"
            - "Позаботься о безопасности малыша"
            - "Создай счастливые воспоминания"
            - "Помоги ребенку расти и развиваться"
            
            📊 БЕЗОПАСНОСТЬ И КАЧЕСТВО:
            - Материалы: гипоаллергенные, экологичные, безопасные
            - Возрастные ограничения: для какого возраста подходит
            - Сертификация: соответствие стандартам безопасности
            - Размеры: подходящие для ребенка параметры
            - Уход: как чистить, стирать, дезинфицировать
            
            🔥 УТП И ВЫГОДЫ:
            - Развивающие функции и образовательная ценность
            - Безопасность и надежность для детей
            - Долговечность и износостойкость
            - Простота использования для родителей
            - Положительное влияние на развитие ребенка
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "детский", "безопасный", "развивающий"
            - "экологичный", "гипоаллергенный", "качественный"
            - "игровой", "обучающий", "интерактивный"
            - "мягкий", "удобный", "яркий"
            """
            
        case .auto:
            return """
            🚗 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ АВТОТОВАРОВ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Сделай свою машину идеальной"
            - "Позаботься о безопасности на дороге"
            - "Подари комфорт в поездках"
            - "Будь уверен в качестве запчастей"
            
            📊 ТЕХНИЧЕСКИЕ ХАРАКТЕРИСТИКИ:
            - Совместимость: марки и модели автомобилей
            - Материалы: качество, долговечность, износостойкость
            - Функциональность: что умеет, как работает
            - Установка: простота монтажа, инструкции
            - Гарантия: срок службы, условия замены
            
            🔥 УТП И ВЫГОДЫ:
            - Оригинальное качество по доступной цене
            - Улучшение характеристик автомобиля
            - Повышение безопасности и комфорта
            - Долговечность и надежность
            - Простота установки и использования
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "автомобильный", "автозапчасти", "оригинальный"
            - "качественный", "надежный", "долговечный"
            - "универсальный", "совместимый", "подходящий"
            - "профессиональный", "сертифицированный"
            """
            
        case .books:
            return """
            📚 ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ КНИГ И ЖУРНАЛОВ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Открой новые горизонты знаний"
            - "Подари себе интеллектуальное удовольствие"
            - "Расширь кругозор и эрудицию"
            - "Найди ответы на важные вопросы"
            
            📊 СОДЕРЖАНИЕ И КАЧЕСТВО:
            - Автор: известность, экспертность, репутация
            - Тематика: актуальность, востребованность
            - Формат: электронный/печатный, размер, объем
            - Качество издания: бумага, печать, оформление
            - Целевая аудитория: для кого предназначена
            
            🔥 УТП И ВЫГОДЫ:
            - Уникальные знания и инсайты
            - Практическая применимость информации
            - Высокое качество изложения
            - Актуальность и современность
            - Образовательная и развлекательная ценность
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "книга", "журнал", "издание", "литература"
            - "обучающий", "познавательный", "интересный"
            - "актуальный", "современный", "популярный"
            - "качественный", "профессиональный", "экспертный"
            """
            
        case .other:
            return """
            ✏️ ПРОДВИНУТЫЕ ТЕХНИКИ ДЛЯ ОБЩИХ ТОВАРОВ:
            
            🎯 ЭМОЦИОНАЛЬНЫЕ ТРИГГЕРЫ:
            - "Реши свою задачу быстро и эффективно"
            - "Подари себе/близким радость и пользу"
            - "Сделай жизнь проще и удобнее"
            - "Будь уверен в качестве и надежности"
            
            📊 КЛЮЧЕВЫЕ ХАРАКТЕРИСТИКИ:
            - Материалы: качество, безопасность, долговечность
            - Функциональность: что умеет, как работает
            - Размеры: точные параметры, компактность
            - Применение: где и как использовать
            - Уход: как обслуживать, хранить
            
            🔥 УТП И ВЫГОДЫ:
            - Уникальные особенности и преимущества
            - Решение конкретных проблем пользователя
            - Соотношение цена/качество
            - Простота использования
            - Долговечность и надежность
            
            📈 SEO-КЛЮЧЕВИКИ 2024-2025:
            - "качественный", "надежный", "долговечный"
            - "удобный", "практичный", "функциональный"
            - "доступный", "выгодный", "экономичный"
            - "универсальный", "многофункциональный"
            """
        }
    }
    
    private func buildPhotoPrompt(productInfo: String, category: Constants.ProductCategory) -> String {
        let basePrompt = """
        Ты ТОП-копирайтер для маркетплейсов Wildberries и Ozon с 15+ лет опыта.
        Твоя задача — проанализировать ФОТОГРАФИЮ товара и создать максимально продающее описание.
        
        КАТЕГОРИЯ: \(category.name)
        
        ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ ОТ ПОЛЬЗОВАТЕЛЯ:
        \(productInfo)
        
        🔍 ПРОДВИНУТЫЙ АНАЛИЗ ФОТО:
        1. ВИЗУАЛЬНЫЕ ХАРАКТЕРИСТИКИ:
           - Цвет, форма, размер, материал
           - Качество изготовления и отделки
           - Детали и особенности дизайна
           - Состояние и новизна товара
        
        2. ЭМОЦИОНАЛЬНОЕ ВОСПРИЯТИЕ:
           - Какие чувства вызывает товар
           - Кому подойдет (целевая аудитория)
           - В каких ситуациях будет использоваться
           - Какие проблемы решает
        
        3. КОНКУРЕНТНЫЕ ПРЕИМУЩЕСТВА:
           - Что выделяет товар среди аналогов
           - Уникальные особенности дизайна
           - Качество материалов и сборки
           - Функциональные преимущества
        
        🎯 ТРЕБОВАНИЯ К ОПИСАНИЮ:
        1. Заголовок (до 100 символов): цепляющий, с ключевыми словами, эмоциональный триггер
        2. Описание (200-500 символов): продающее, с психологическими триггерами, основанное на ВИДИМЫХ характеристиках
        3. Bullet-points (5 штук): конкретные выгоды, основанные на том что видно на фото + эмоциональные триггеры
        4. Хештеги (5-7 штук): релевантные для поиска + трендовые ключевые слова
        
        \(getCategorySpecificGuidelines(category))
        
        ФОРМАТ ОТВЕТА (строго JSON):
        {
          "title": "Заголовок товара",
          "description": "Подробное описание товара...",
          "bullets": [
            "Первая выгода",
            "Вторая выгода",
            "Третья выгода",
            "Четвертая выгода",
            "Пятая выгода"
          ],
          "hashtags": ["#хештег1", "#хештег2", "#хештег3", "#хештег4", "#хештег5"]
        }
        
        ВАЖНО: Отвечай ТОЛЬКО валидным JSON, без дополнительного текста!
        """
        
        return basePrompt
    }
    
    private func detectMediaType(from data: Data) -> String {
        // Определение типа изображения по magic bytes
        guard data.count >= 4 else {
            return "image/jpeg" // default
        }
        
        let bytes = data.prefix(4)
        
        // PNG: 89 50 4E 47
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        
        // JPEG: FF D8 FF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        
        // WebP: 52 49 46 46 ... 57 45 42 50
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count >= 12 {
            let webpMarker = data[8..<12]
            if webpMarker == Data([0x57, 0x45, 0x42, 0x50]) {
                return "image/webp"
            }
        }
        
        // GIF: 47 49 46 38
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "image/gif"
        }
        
        // Default to JPEG if unknown
        return "image/jpeg"
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ response: ClaudeResponse) throws -> ParsedDescription {
        guard let content = response.content.first?.text else {
            throw ClaudeError.emptyResponse
        }
        
        // Извлечь JSON из ответа (Claude может добавить текст до/после)
        let jsonString = extractJSON(from: content)
        
        // Детальное логирование для отладки
        app.logger.info("📋 Extracted JSON preview: \(jsonString.prefix(300))...")
        app.logger.info("📋 Full extracted JSON: \(jsonString)")
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            app.logger.error("❌ Failed to convert JSON string to data")
            throw ClaudeError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        
        do {
            // Попытка 1: Прямое декодирование
            let result = try decoder.decode(ParsedDescription.self, from: jsonData)
            app.logger.info("✅ Parsed JSON directly")
            return result
        } catch let directError {
            app.logger.warning("⚠️ Direct parsing failed: \(directError)")
            
            // Попытка 2: Claude обернул в {"result": {...}}
            do {
                let wrapper = try decoder.decode(ParsedDescriptionWrapper.self, from: jsonData)
                app.logger.info("✅ Parsed wrapped JSON with 'result' key")
                return wrapper.result
            } catch let wrapperError {
                app.logger.error("❌ JSON parsing error (both attempts failed)")
                app.logger.error("Direct error: \(directError)")
                app.logger.error("Wrapper error: \(wrapperError)")
                app.logger.error("Content: \(content)")
                app.logger.error("JSON string: \(jsonString)")
                throw ClaudeError.invalidJSON
            }
        }
    }
    
    private func extractJSON(from text: String) -> String {
        // Попытка 1: Найти JSON между ```json и ```
        if let start = text.range(of: "```json")?.upperBound,
           let end = text[start...].range(of: "```")?.lowerBound {
            return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Попытка 2: Найти JSON между { и }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        
        // Попытка 3: Весь текст (если это чистый JSON)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Models
    
    struct ProductDescription {
        let title: String
        let description: String
        let bullets: [String]
        let hashtags: [String]
        let tokensUsed: Int
        let processingTimeMs: Int
    }
    
    private struct ParsedDescription: Codable {
        let title: String
        let description: String
        let bullets: [String]
        let hashtags: [String]
    }
    
    // Обертка для случая когда Claude возвращает {"result": {...}}
    private struct ParsedDescriptionWrapper: Codable {
        let result: ParsedDescription
    }
    
    // MARK: - Errors
    
    enum ClaudeError: Error, CustomStringConvertible {
        case apiError(HTTPResponseStatus)
        case emptyResponse
        case invalidJSON
        case rateLimitExceeded
        
        var description: String {
            switch self {
            case .apiError(let status):
                return "Claude API error: \(status)"
            case .emptyResponse:
                return "Empty response from Claude"
            case .invalidJSON:
                return "Failed to parse JSON from Claude response"
            case .rateLimitExceeded:
                return "Claude API rate limit exceeded"
            }
        }
    }
}

// MARK: - Application Extension

extension Application {
    private struct ClaudeServiceKey: StorageKey {
        typealias Value = ClaudeService
    }
    
    var claude: ClaudeService {
        get {
            guard let service = storage[ClaudeServiceKey.self] else {
                fatalError("ClaudeService not configured")
            }
            return service
        }
        set {
            storage[ClaudeServiceKey.self] = newValue
        }
    }
}

