import Fluent
import Vapor

/// Запись об обработанном вебхуке (для защиты от дубликатов)
final class ProcessedWebhook: Model, Content {
    static let schema = "processed_webhooks"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "event_id")
    var eventId: String
    
    @Field(key: "event_type")
    var eventType: String
    
    @Timestamp(key: "processed_at", on: .create)
    var processedAt: Date?
    
    @OptionalField(key: "user_id")
    var userId: Int64?
    
    @OptionalField(key: "amount")
    var amount: Int?
    
    init() {}
    
    init(
        eventId: String,
        eventType: String,
        userId: Int64? = nil,
        amount: Int? = nil
    ) {
        self.eventId = eventId
        self.eventType = eventType
        self.userId = userId
        self.amount = amount
    }
}

