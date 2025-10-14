import Vapor
import Fluent

/// Обработчик вебхуков от Tribute
/// Выполняет бизнес-логику после получения события
final class TributeWebhookHandler {
    private let app: Application
    
    init(app: Application) {
        self.app = app
    }
    
    enum HandlerError: Error {
        case duplicateEvent
        case userNotFound
        case planNotIdentified
    }
    
    /// Обрабатывает нормализованное событие
    func handle(_ event: NormalizedWebhookEvent, on req: Request) async throws {
        req.logger.info("💰 Processing webhook: type=\(event.type) userId=\(event.telegramUserId) eventId=\(event.id)")
        
        try await checkDuplicates(event, on: req)
        
        switch event.type {
        case .digitalProductPurchase:
            try await handleDigitalProductPurchase(event, on: req)
        case .unknown:
            req.logger.warning("⚠️ Unknown event type, skipping")
        }
        
        try await saveProcessedEvent(event, on: req)
    }
    
    // MARK: - Private Methods
    
    private func checkDuplicates(_ event: NormalizedWebhookEvent, on req: Request) async throws {
        let duplicate = try await ProcessedWebhook.query(on: req.db)
            .filter(\.$eventId == event.id)
            .first()
        
        if duplicate != nil {
            req.logger.info("⏭️ Duplicate webhook detected: \(event.id)")
            
            app.monitoring.trackPayment(
                userId: event.telegramUserId,
                amount: event.amount,
                plan: "unknown",
                success: true,
                isDuplicate: true
            )
            
            throw HandlerError.duplicateEvent
        }
    }
    
    private func handleDigitalProductPurchase(_ event: NormalizedWebhookEvent, on req: Request) async throws {
        guard let productId = event.productId else {
            req.logger.error("❌ Missing product_id in webhook")
            return
        }
        
        let plan = try identifyPlan(productId: productId, amount: event.amount)
        
        try await addCreditsToUser(
            telegramId: event.telegramUserId,
            plan: plan,
            on: req.db
        )
        
        app.monitoring.trackPayment(
            userId: event.telegramUserId,
            amount: event.amount,
            plan: plan.name,
            success: true,
            isDuplicate: false
        )
        
        try await notifyUser(
            telegramId: event.telegramUserId,
            plan: plan
        )
        
        req.logger.info("✅ Purchase processed: user=\(event.telegramUserId) plan=\(plan.name) amount=\(event.amount/100)₽")
    }
    
    private func identifyPlan(productId: Int, amount: Int) throws -> Constants.SubscriptionPlan {
        // Вариант 1: По product_id
        if let plan = Constants.SubscriptionPlan.allCases.first(where: {
            $0.tributeProductId == String(productId)
        }) {
            return plan
        }
        
        // Вариант 2: По сумме (fallback)
        let amountRub = amount / 100
        if let plan = Constants.SubscriptionPlan.allCases.first(where: {
            Int(truncating: $0.price as NSNumber) == amountRub
        }) {
            return plan
        }
        
        app.logger.error("❌ Cannot identify plan: productId=\(productId) amount=\(amount)")
        throw HandlerError.planNotIdentified
    }
    
    private func addCreditsToUser(
        telegramId: Int64,
        plan: Constants.SubscriptionPlan,
        on db: any Database
    ) async throws {
        try await db.transaction { transactionDb in
            guard let user = try await User.query(on: transactionDb)
                .filter(\.$telegramId == telegramId)
                .first() else {
                throw HandlerError.userNotFound
            }
            
            let creditsBefore = user.textCredits
            
            user.textCredits += plan.textGenerationsLimit
            user.photoCredits += plan.photoGenerationsLimit
            
            try await user.update(on: transactionDb)
            
            self.app.monitoring.trackCreditOperation(
                operation: .purchase,
                userId: telegramId,
                creditsBefore: creditsBefore,
                creditsAfter: user.textCredits,
                success: true
            )
            
            self.app.logger.info("✅ Credits added: text=\(plan.textGenerationsLimit) photo=\(plan.photoGenerationsLimit) user=\(telegramId)")
        }
    }
    
    private func notifyUser(
        telegramId: Int64,
        plan: Constants.SubscriptionPlan
    ) async throws {
        let message = """
        ✅ *Оплата прошла успешно!*
        
        📦 *Пакет:* \(plan.emoji) \(plan.name)
        💰 *Сумма:* \(plan.price) ₽
        
        🎉 *Начислено кредитов:*
        • Текстовые: +\(plan.textGenerationsLimit)
        • С фото: +\(plan.photoGenerationsLimit)
        
        Теперь ты можешь создавать описания товаров!
        
        Используй /generate чтобы начать 🚀
        """
        
        try await app.telegramBot.sendMessage(
            chatId: telegramId,
            text: message
        )
    }
    
    private func saveProcessedEvent(_ event: NormalizedWebhookEvent, on req: Request) async throws {
        let processed = ProcessedWebhook(
            eventId: event.id,
            eventType: event.type == .digitalProductPurchase ? "digital_product_purchase" : "unknown",
            userId: event.telegramUserId,
            amount: event.amount
        )
        try await processed.save(on: req.db)
    }
}

