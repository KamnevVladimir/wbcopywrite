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
        
        let request = ClaudeRequest(
            model: "claude-sonnet-4-5-20250929",
            maxTokens: 2000,
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
        let basePrompt = """
        Ты профессиональный копирайтер для маркетплейсов Wildberries и Ozon.
        Твоя задача — создать продающее описание товара на основе информации от пользователя.
        
        КАТЕГОРИЯ: \(category.name)
        
        ИНФОРМАЦИЯ О ТОВАРЕ:
        \(productInfo)
        
        ТРЕБОВАНИЯ:
        1. Заголовок (до 100 символов): цепляющий, с ключевыми словами
        2. Описание (200-500 символов): SEO-оптимизированное, продающее
        3. Bullet-points (5 штук): конкретные выгоды для покупателя
        4. Хештеги (5-7 штук): релевантные для поиска
        
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
    
    private func getCategorySpecificGuidelines(_ category: Constants.ProductCategory) -> String {
        switch category {
        case .clothing:
            return """
            ОСОБЕННОСТИ ДЛЯ ОДЕЖДЫ И ОБУВИ:
            - Указывай материалы и их качества (дышащий, гипоаллергенный)
            - Подчеркивай посадку, комфорт, стиль
            - Упоминай сезонность и случаи использования
            - Добавляй информацию об уходе
            - Используй эмоциональные триггеры (уверенность, комфорт, стиль)
            """
            
        case .electronics:
            return """
            ОСОБЕННОСТИ ДЛЯ ЭЛЕКТРОНИКИ:
            - Четко указывай технические характеристики
            - Подчеркивай преимущества перед конкурентами
            - Объясняй выгоды функций простым языком
            - Упоминай совместимость, гарантию
            - Используй цифры и факты
            """
            
        case .home:
            return """
            ОСОБЕННОСТИ ДЛЯ ДОМА И САДА:
            - Описывай функциональность и удобство
            - Подчеркивай качество материалов и долговечность
            - Упоминай как товар решает проблемы
            - Добавляй информацию о размерах и уходе
            - Используй триггеры уюта и практичности
            """
            
        case .beauty:
            return """
            ОСОБЕННОСТИ ДЛЯ КРАСОТЫ И ЗДОРОВЬЯ:
            - Указывай состав и активные компоненты
            - Описывай результаты и эффект
            - Подчеркивай безопасность и сертификаты
            - Упоминай подходящие типы кожи/волос
            - Используй эмоциональные триггеры красоты
            """
            
        case .sports:
            return """
            ОСОБЕННОСТИ ДЛЯ СПОРТА И ОТДЫХА:
            - Описывай функциональность для спорта
            - Подчеркивай прочность и надежность
            - Упоминай технологии и инновации
            - Добавляй информацию о применении
            - Используй триггеры активности и здоровья
            """
        }
    }
    
    private func buildPhotoPrompt(productInfo: String, category: Constants.ProductCategory) -> String {
        let basePrompt = """
        Ты профессиональный копирайтер для маркетплейсов Wildberries и Ozon.
        Твоя задача — проанализировать ФОТОГРАФИЮ товара и создать продающее описание.
        
        КАТЕГОРИЯ: \(category.name)
        
        ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ ОТ ПОЛЬЗОВАТЕЛЯ:
        \(productInfo)
        
        ИНСТРУКЦИИ ПО АНАЛИЗУ ФОТО:
        1. Внимательно рассмотри фотографию товара
        2. Определи визуальные характеристики: цвет, форма, размер, материал
        3. Обрати внимание на детали, которые видны на фото
        4. Используй визуальную информацию для создания точного описания
        
        ТРЕБОВАНИЯ:
        1. Заголовок (до 100 символов): цепляющий, с ключевыми словами
        2. Описание (200-500 символов): SEO-оптимизированное, продающее, основанное на ВИДИМЫХ характеристиках
        3. Bullet-points (5 штук): конкретные выгоды, основанные на том что видно на фото
        4. Хештеги (5-7 штук): релевантные для поиска
        
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
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            app.logger.error("❌ Failed to convert JSON string to data")
            throw ClaudeError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        
        do {
            return try decoder.decode(ParsedDescription.self, from: jsonData)
        } catch {
            app.logger.error("❌ JSON parsing error: \(error)")
            app.logger.error("Content: \(content)")
            throw ClaudeError.invalidJSON
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

