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
        let event = try req.content.decode(TributeWebhookEvent.self)
        
        // 🔒 ЗАЩИТА 3: Проверка дубликатов (уже внутри handleWebhook)
        
        // Шаг 4: Обработать через TributeService
        try await req.application.tribute.handleWebhook(event, on: req)
        
        return .ok
    }
    
    app.logger.info("🛣️  Routes configured (long polling mode)")
}