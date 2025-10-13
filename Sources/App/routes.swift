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
    
    // MARK: - Tribute minimal API
    struct CreatePaymentRequest: Content { let plan: String; let telegramUserId: Int64 }
    struct CreatePaymentResponse: Content { let paymentUrl: String }
    
    // Симуляция создания оплаты: пока возвращаем прямую web ссылку на продукт
    app.post("api", "tribute", "create-payment") { req async throws -> CreatePaymentResponse in
        let body = try req.content.decode(CreatePaymentRequest.self)
        guard let plan = Constants.SubscriptionPlan(rawValue: body.plan) else {
            throw Abort(.badRequest, reason: "Unknown plan")
        }
        guard !plan.tributeWebLink.isEmpty else {
            throw Abort(.badRequest, reason: "Plan is temporarily unavailable")
        }
        req.logger.info("💳 Create payment for user=\(body.telegramUserId) plan=\(plan.rawValue)")
        return CreatePaymentResponse(paymentUrl: plan.tributeWebLink)
    }
    
    // Вебхук для Tribute (минимальная заглушка)
    app.post("api", "tribute", "webhook") { req async throws -> HTTPStatus in
        let event = try req.content.decode(TributeWebhookEvent.self)
        req.logger.info("💰 Tribute webhook: type=\(event.type) userId=\(event.data.userId)")
        
        if event.type == TributeWebhookEvent.EventType.paymentSucceeded.rawValue {
            // Найдём пользователя и пополним кредиты согласно описанию платежа
            guard let telegramId = Int64(event.data.userId) else { return .ok }
            let repo = UserRepository(database: req.db)
            if let user = try await repo.find(telegramId: telegramId),
               let plan = Constants.SubscriptionPlan.allCases.first(where: { event.data.description?.contains($0.name) == true || event.data.description == $0.rawValue || $0.tributeProductId == event.data.subscriptionId }) {
                // Прибавляем кредиты плана к текущему балансу
                user.textCredits += plan.textGenerationsLimit
                user.photoCredits += plan.photoGenerationsLimit
                try await user.update(on: req.db)
                req.logger.info("✅ Credits added: text=\(plan.textGenerationsLimit) photo=\(plan.photoGenerationsLimit) for user=\(telegramId)")
            }
        }
        return .ok
    }
    
    app.logger.info("🛣️  Routes configured (long polling mode)")
}