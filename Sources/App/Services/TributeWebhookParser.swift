import Vapor

/// Парсер вебхуков от Tribute
/// Поддерживает официальный формат из документации
final class TributeWebhookParser {
    
    enum ParseError: Error {
        case invalidFormat
        case unsupportedEvent
        case missingTelegramUserId
    }
    
    /// Парсит вебхук от Tribute в нормализованное событие
    /// - Parameters:
    ///   - request: HTTP запрос с телом вебхука
    /// - Returns: Нормализованное событие
    func parse(_ request: Request) throws -> NormalizedWebhookEvent {
        // Основной формат: new_digital_product
        if let webhook = try? request.content.decode(TributeDigitalProductWebhook.self),
           webhook.isDigitalProductPurchase {
            return normalize(webhook)
        }
        
        throw ParseError.invalidFormat
    }
    
    /// Нормализует вебхук покупки цифрового товара
    private func normalize(_ webhook: TributeDigitalProductWebhook) -> NormalizedWebhookEvent {
        let id = generateEventId(from: webhook)
        
        return NormalizedWebhookEvent(
            id: id,
            type: .digitalProductPurchase,
            telegramUserId: webhook.payload.telegramUserId,
            productId: webhook.payload.productId,
            amount: webhook.payload.amount,
            currency: webhook.payload.currency.uppercased(),
            createdAt: webhook.createdAt
        )
    }
    
    /// Генерирует уникальный ID события
    private func generateEventId(from webhook: TributeDigitalProductWebhook) -> String {
        let timestamp = webhook.createdAt
        let userId = webhook.payload.telegramUserId
        let productId = webhook.payload.productId
        return "dp_\(timestamp)_\(userId)_\(productId)"
    }
}

