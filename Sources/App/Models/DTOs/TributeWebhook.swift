import Vapor

// MARK: - Tribute Payment DTOs

struct TributePaymentRequest: Content {
    let amount: Int // в копейках
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

struct TributeWebhookEvent: Content {
    let id: String
    let type: String
    let data: WebhookData
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case data
        case createdAt = "created_at"
    }
    
    struct WebhookData: Content {
        let paymentId: String
        let subscriptionId: String?
        let userId: String
        let amount: Int
        let currency: String
        let status: String
        let description: String?
        
        enum CodingKeys: String, CodingKey {
            case paymentId = "payment_id"
            case subscriptionId = "subscription_id"
            case userId = "user_id"
            case amount
            case currency
            case status
            case description
        }
    }
    
    enum EventType: String {
        case paymentSucceeded = "payment.succeeded"
        case paymentFailed = "payment.failed"
        case subscriptionCreated = "subscription.created"
        case subscriptionCancelled = "subscription.cancelled"
        case subscriptionRenewed = "subscription.renewed"
    }
}

// MARK: - Signature verification

struct TributeWebhookSignature {
    let timestamp: String
    let signature: String
    
    static func verify(payload: String, signature: String, secret: String) -> Bool {
        // TODO: Implement HMAC-SHA256 verification
        // For now, just return true in development
        return true
    }
}


