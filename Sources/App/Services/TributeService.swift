import Vapor
import Fluent
import Crypto

/// Сервис для работы с Tribute API (платежи)
final class TributeService: @unchecked Sendable {
    private let app: Application
    private let apiKey: String
    private let apiSecret: String
    private let baseURL: String = "https://api.tribute.to/v1"
    
    init(app: Application, apiKey: String, apiSecret: String) {
        self.app = app
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }
    
    // MARK: - Public API
    
    /// Создать ссылку на оплату для пользователя
    /// - Parameters:
    ///   - plan: Тариф подписки
    ///   - telegramId: Telegram ID пользователя
    /// - Returns: URL для оплаты
    func createPaymentLink(
        plan: Constants.SubscriptionPlan,
        telegramId: Int64
    ) async throws -> String {
        // Вариант 1: Используем прямую web-ссылку на продукт (проще)
        // Tribute автоматически привяжет платеж к продукту
        if !plan.tributeWebLink.isEmpty {
            // Добавляем параметр user_id в URL для идентификации
            var components = URLComponents(string: plan.tributeWebLink)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "user_id", value: "\(telegramId)"))
            queryItems.append(URLQueryItem(name: "return_url", value: "https://t.me/kartochka_pro"))
            components?.queryItems = queryItems
            
            if let url = components?.url?.absoluteString {
                app.logger.info("💳 Payment link created: \(url)")
                return url
            }
        }
        
        // Вариант 2: Создаем платеж через API (если нужна кастомизация)
        // Пока используем Вариант 1, но оставляю код для референса
        throw Abort(.serviceUnavailable, reason: "Payment link unavailable")
    }
    
    /// Обработать вебхук от Tribute
    func handleWebhook(_ event: TributeWebhookEvent, on req: Request) async throws {
        req.logger.info("💰 Tribute webhook: type=\(event.type) userId=\(event.data.userId) eventId=\(event.id)")
        
        // 🔒 Проверяем что event еще не был обработан (защита от дубликатов)
        let duplicate = try await ProcessedWebhook.query(on: req.db)
            .filter(\.$eventId == event.id)
            .first()
        
        if duplicate != nil {
            req.logger.info("⏭️ Duplicate webhook detected, skipping: \(event.id)")
            return
        }
        
        // Проверяем тип события
        guard event.type == TributeWebhookEvent.EventType.paymentSucceeded.rawValue else {
            req.logger.info("⏭️ Skipping non-payment event: \(event.type)")
            
            // Сохраняем даже non-payment события для истории
            let processed = ProcessedWebhook(
                eventId: event.id,
                eventType: event.type,
                userId: Int64(event.data.userId),
                amount: event.data.amount
            )
            try await processed.save(on: req.db)
            
            return
        }
        
        // Проверяем статус платежа
        guard event.data.status.lowercased() == "succeeded" || event.data.status.lowercased() == "paid" else {
            req.logger.warning("⚠️ Payment not succeeded: \(event.data.status)")
            return
        }
        
        // Извлекаем Telegram ID
        guard let telegramId = Int64(event.data.userId) else {
            req.logger.error("❌ Invalid telegram ID: \(event.data.userId)")
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Находим план по subscriptionId или description
        let plan = try identifyPlan(from: event)
        
        // Начисляем кредиты пользователю
        try await addCreditsToUser(telegramId: telegramId, plan: plan, on: req.db)
        
        // Отправляем уведомление пользователю
        try await notifyUserAboutPayment(telegramId: telegramId, plan: plan)
        
        // ✅ Сохраняем event_id чтобы не обработать повторно
        let processed = ProcessedWebhook(
            eventId: event.id,
            eventType: event.type,
            userId: telegramId,
            amount: event.data.amount
        )
        try await processed.save(on: req.db)
        
        req.logger.info("✅ Payment processed: user=\(telegramId) plan=\(plan.name) amount=\(event.data.amount/100)₽")
    }
    
    /// Проверить подпись вебхука
    func verifyWebhookSignature(payload: Data, signature: String) -> Bool {
        // HMAC-SHA256 верификация
        guard let payloadString = String(data: payload, encoding: .utf8) else {
            return false
        }
        
        let key = SymmetricKey(data: Data(apiSecret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: Data(payloadString.utf8), using: key)
        let computedSignature = Data(hmac).base64EncodedString()
        
        return computedSignature == signature
    }
    
    // MARK: - Private Helpers
    
    /// Определить план по данным вебхука
    private func identifyPlan(from event: TributeWebhookEvent) throws -> Constants.SubscriptionPlan {
        // Вариант 1: По subscriptionId (Product ID)
        if let subId = event.data.subscriptionId {
            if let plan = Constants.SubscriptionPlan.allCases.first(where: { $0.tributeProductId == subId }) {
                return plan
            }
        }
        
        // Вариант 2: По описанию платежа
        if let description = event.data.description {
            // "Пакет Small" → .small
            for plan in Constants.SubscriptionPlan.allCases {
                if description.contains(plan.name) || description.contains(plan.rawValue) {
                    return plan
                }
            }
        }
        
        // Вариант 3: По сумме (fallback)
        let amountRub = event.data.amount / 100 // копейки → рубли
        if let plan = Constants.SubscriptionPlan.allCases.first(where: { Int(truncating: $0.price as NSNumber) == amountRub }) {
            return plan
        }
        
        app.logger.error("❌ Cannot identify plan from webhook: \(event)")
        throw Abort(.badRequest, reason: "Cannot identify subscription plan")
    }
    
    /// Начислить кредиты пользователю
    /// Thread-safe: перечитывает пользователя из БД перед обновлением
    private func addCreditsToUser(
        telegramId: Int64,
        plan: Constants.SubscriptionPlan,
        on db: any Database
    ) async throws {
        // Перечитываем свежее состояние пользователя
        guard let user = try await User.query(on: db)
            .filter(\.$telegramId == telegramId)
            .first() else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Начисляем кредиты
        user.textCredits += plan.textGenerationsLimit
        user.photoCredits += plan.photoGenerationsLimit
        
        try await user.update(on: db)
        
        app.logger.info("✅ Credits added: text=\(plan.textGenerationsLimit) photo=\(plan.photoGenerationsLimit) for user=\(telegramId)")
    }
    
    /// Отправить уведомление пользователю об успешной оплате
    private func notifyUserAboutPayment(
        telegramId: Int64,
        plan: Constants.SubscriptionPlan
    ) async throws {
        let botService = app.telegramBot
        
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
        
        try await botService.sendMessage(
            chatId: telegramId,
            text: message
        )
    }
}

// MARK: - Application Extension

extension Application {
    private struct TributeServiceKey: StorageKey {
        typealias Value = TributeService
    }
    
    var tribute: TributeService {
        get {
            guard let service = storage[TributeServiceKey.self] else {
                fatalError("TributeService not configured. Call app.tribute = TributeService(...)")
            }
            return service
        }
        set {
            storage[TributeServiceKey.self] = newValue
        }
    }
}

