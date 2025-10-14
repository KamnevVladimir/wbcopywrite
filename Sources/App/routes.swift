import Vapor

func routes(_ app: Application) throws {
    // MARK: - Health Check
    
    app.get("health") { req async -> Response in
        let response = Response(status: .ok)
        response.headers.contentType = .json
        response.body = .init(string: """
        {
            "status": "ok",
            "service": "КарточкаПРО",
            "version": "0.1.0",
            "environment": "\(app.environmentConfig.environment)"
        }
        """)
        return response
    }
    
    // MARK: - Root
    
    app.get { req async -> String in
        """
        🎯 КарточкаПРО API
        
        Telegram Bot: @kartochka_pro
        Mode: Long Polling
        Status: /health
        Version: 0.1.0
        """
    }
    
    // MARK: - Tribute Payment API
    
    /// Структуры запроса/ответа
    struct CreatePaymentRequest: Content {
        let plan: String
        let telegramUserId: Int64
    }
    
    struct CreatePaymentResponse: Content {
        let paymentUrl: String
        let plan: String
        let amount: Int
    }
    
    /// POST /api/tribute/create-payment
    /// Создать ссылку на оплату для пользователя
    app.post("api", "tribute", "create-payment") { req async throws -> CreatePaymentResponse in
        let body = try req.content.decode(CreatePaymentRequest.self)
        
        guard let plan = Constants.SubscriptionPlan(rawValue: body.plan) else {
            throw Abort(.badRequest, reason: "Unknown plan: \(body.plan)")
        }
        
        guard plan != .free else {
            throw Abort(.badRequest, reason: "Free plan cannot be purchased")
        }
        
        req.logger.info("💳 Creating payment: user=\(body.telegramUserId) plan=\(plan.rawValue)")
        
        // Создаем ссылку через TributeService
        let paymentUrl = try await req.application.tribute.createPaymentLink(
            plan: plan,
            telegramId: body.telegramUserId
        )
        
        return CreatePaymentResponse(
            paymentUrl: paymentUrl,
            plan: plan.name,
            amount: Int(truncating: plan.price as NSNumber)
        )
    }
    
    /// POST /api/tribute/webhook
    /// Вебхук для получения уведомлений о платежах от Tribute
    /// 🔒 ЗАЩИТА: Secret token + IP whitelist + дубликаты
    app.post("api", "tribute", "webhook") { req async throws -> HTTPStatus in
        // 🔒 ЗАЩИТА 1: Secret token в URL или header
        let secretToken = Environment.get("TRIBUTE_WEBHOOK_SECRET") ?? "change_me_in_production"
        
        // Проверяем токен в query параметре ИЛИ в header
        let providedToken = req.query[String.self, at: "secret"] 
                         ?? req.headers.first(name: "X-Webhook-Secret")
        
        if providedToken != secretToken {
            req.logger.warning("⚠️ Unauthorized webhook attempt from \(req.remoteAddress?.description ?? "unknown")")
            throw Abort(.unauthorized, reason: "Invalid webhook secret")
        }
        
        // 🔒 ЗАЩИТА 2: IP Whitelist (опционально)
        // Tribute обычно использует фиксированные IP
        // let allowedIPs = ["34.123.45.67", "34.123.45.68"]
        // if let clientIP = req.remoteAddress?.ipAddress,
        //    !allowedIPs.contains(clientIP) {
        //     throw Abort(.forbidden)
        // }
        
        // Шаг 1: Получить тело запроса
        // Tribute может отправлять тестовый запрос с пустым телом через UI.
        // Если секрет верный, считаем это health‑check и отвечаем 200.
        guard let body = req.body.data else {
            req.logger.info("ℹ️ Tribute webhook ping without body — OK")
            return .ok
        }
        // Диагностика: логируем тип и превью тела (без чувствительных данных)
        let contentType = req.headers.first(name: "Content-Type") ?? ""
        let bodyString = String(buffer: body)
        let preview = bodyString.prefix(512)
        req.logger.info("ℹ️ Tribute webhook headers: Content-Type=\(contentType); body.len=\(body.readableBytes), preview=\(preview)")
        
        // Шаг 2: Проверить HMAC подпись (если Tribute отправляет)
        if let signature = req.headers.first(name: "X-Tribute-Signature") {
            let isValid = req.application.tribute.verifyWebhookSignature(
                payload: Data(buffer: body),
                signature: signature
            )
            
            if !isValid {
                req.logger.warning("⚠️ Invalid HMAC signature")
                throw Abort(.unauthorized, reason: "Invalid signature")
            }
            
            req.logger.info("✅ HMAC signature verified")
        }
        
        // Шаг 3: Декодировать событие
        do {
            // Попытка 1: обычный JSON
            let event = try req.content.decode(TributeWebhookEvent.self)
            // 🔒 ЗАЩИТА 3: Проверка дубликатов (уже внутри handleWebhook)
            // Шаг 4: Обработать через TributeService
            try await req.application.tribute.handleWebhook(event, on: req)
            return .ok
        } catch {
            // Попытка 2: application/x-www-form-urlencoded с полем payload
            if contentType.contains("application/x-www-form-urlencoded") {
                struct FormEnvelope: Content { let id: String?; let type: String?; let payload: String?; let data: String? }
                if let form = try? req.content.decode(FormEnvelope.self) {
                    if let json = form.payload ?? form.data,
                       let jsonData = json.data(using: .utf8),
                       let nested = try? JSONDecoder().decode(TributeWebhookEvent.self, from: jsonData) {
                        try await req.application.tribute.handleWebhook(nested, on: req)
                        return .ok
                    }
                }
            }
            // Тестовый/неизвестный формат — просто 200, чтобы они считали вебхук доступным
            req.logger.info("ℹ️ Tribute webhook test without payload — returning 200. Error: \(error)")
            return .ok
        }
    }

    /// GET /api/tribute/webhook
    /// Health-check от Tribute UI "Отправить тестовый запрос"
    app.get("api", "tribute", "webhook") { req async throws -> HTTPStatus in
        let secretToken = Environment.get("TRIBUTE_WEBHOOK_SECRET") ?? "change_me_in_production"
        let providedToken = req.query[String.self, at: "secret"]
                         ?? req.headers.first(name: "X-Webhook-Secret")
        if providedToken != secretToken {
            req.logger.warning("⚠️ Unauthorized webhook GET attempt from \(req.remoteAddress?.description ?? "unknown")")
            throw Abort(.unauthorized, reason: "Invalid webhook secret")
        }
        req.logger.info("✅ Tribute webhook GET ping OK")
        return .ok
    }
    
    app.logger.info("🛣️  Routes configured (long polling mode)")
}