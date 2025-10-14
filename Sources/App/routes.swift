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
    /// Документация: https://wiki.tribute.tg/ru/api-dokumentaciya/vebkhuki
    /// Защита: HMAC-SHA256 подпись в заголовке trbt-signature
    app.post("api", "tribute", "webhook") { req async throws -> HTTPStatus in
        guard let body = req.body.data else {
            req.logger.info("ℹ️ Tribute webhook ping without body — OK")
            return .ok
        }
        
        guard let signature = req.headers.first(name: "trbt-signature") ?? req.headers.first(name: "X-Tribute-Signature") else {
            req.logger.warning("⚠️ Missing HMAC signature in webhook")
            throw Abort(.unauthorized, reason: "Missing signature")
        }
        
        let isValid = req.application.tribute.verifyWebhookSignature(
            payload: Data(buffer: body),
            signature: signature
        )
        
        guard isValid else {
            req.logger.warning("⚠️ Invalid HMAC signature from \(req.remoteAddress?.description ?? "unknown")")
            throw Abort(.unauthorized, reason: "Invalid signature")
        }
        
        req.logger.info("✅ HMAC signature verified")
        
        do {
            let parser = TributeWebhookParser()
            let event = try parser.parse(req)
            
            let handler = TributeWebhookHandler(app: req.application)
            try await handler.handle(event, on: req)
            
            return .ok
        } catch TributeWebhookParser.ParseError.invalidFormat {
            req.logger.warning("⚠️ Invalid webhook format, returning 200 for compatibility")
            return .ok
        } catch TributeWebhookHandler.HandlerError.duplicateEvent {
            req.logger.info("⏭️ Duplicate event, skipping")
            return .ok
        } catch {
            req.logger.error("❌ Webhook processing error: \(error)")
            throw error
        }
    }

    /// GET /api/tribute/webhook
    /// Health-check от Tribute UI "Отправить тестовый запрос"
    app.get("api", "tribute", "webhook") { req async throws -> HTTPStatus in
        req.logger.info("✅ Tribute webhook GET ping OK")
        return .ok
    }
    
    app.logger.info("🛣️  Routes configured (long polling mode)")
}