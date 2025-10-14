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

