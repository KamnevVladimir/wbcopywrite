import Vapor

// MARK: - Tribute Webhook DTO (по официальной документации)

/// Структура вебхука о покупке цифрового товара
/// Документация: https://wiki.tribute.tg/ru/api-dokumentaciya/vebkhuki
struct TributeDigitalProductWebhook: Content {
    let name: String
    let createdAt: String
    let sentAt: String
    let payload: Payload
    
    enum CodingKeys: String, CodingKey {
        case name
        case createdAt = "created_at"
        case sentAt = "sent_at"
        case payload
    }
    
    struct Payload: Content {
        let productId: Int
        let amount: Int
        let currency: String
        let userId: Int?
        let telegramUserId: Int64
        
        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case amount
            case currency
            case userId = "user_id"
            case telegramUserId = "telegram_user_id"
        }
    }
    
    var isDigitalProductPurchase: Bool {
        name == "new_digital_product"
    }
}

// MARK: - Внутренняя нормализованная модель

struct NormalizedWebhookEvent {
    let id: String
    let type: EventType
    let telegramUserId: Int64
    let productId: Int?
    let amount: Int
    let currency: String
    let createdAt: String
    
    enum EventType {
        case digitalProductPurchase
        case unknown
    }
}

// MARK: - Legacy DTOs (для обратной совместимости)

struct TributePaymentRequest: Content {
    let amount: Int
    let currency: String
    let description: String
    let userId: String
    let recurring: Bool
    let returnUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case description
        case userId = "user_id"
        case recurring
        case returnUrl = "return_url"
    }
    
    init(amount: Decimal, description: String, userId: String, recurring: Bool = true) {
        self.amount = Int(truncating: (amount * 100) as NSNumber)
        self.currency = "RUB"
        self.description = description
        self.userId = userId
        self.recurring = recurring
        self.returnUrl = nil
    }
}

struct TributePaymentResponse: Content {
    let id: String
    let url: String
    let status: String
}
