import Vapor
import Fluent

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "telegram_id")
    var telegramId: Int64
    
    @OptionalField(key: "username")
    var username: String?
    
    @OptionalField(key: "first_name")
    var firstName: String?
    
    @OptionalField(key: "last_name")
    var lastName: String?
    
    @OptionalField(key: "selected_category")
    var selectedCategory: String?
    
    @OptionalField(key: "recent_categories")
    var recentCategories: [String]?
    
    // Deprecated counters (kept for backward compatibility during migration)
    @Field(key: "generations_used")
    var generationsUsed: Int
    
    @Field(key: "photo_generations_used")
    var photoGenerationsUsed: Int

    // New credit-based fields
    @Field(key: "text_credits")
    var textCredits: Int
    
    @Field(key: "photo_credits")
    var photoCredits: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    // Relationships
    @OptionalChild(for: \.$user)
    var subscription: Subscription?
    
    @Children(for: \.$user)
    var generations: [Generation]
    
    init() { }
    
    init(
        id: UUID? = nil,
        telegramId: Int64,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) {
        self.id = id
        self.telegramId = telegramId
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.generationsUsed = 0
        self.photoGenerationsUsed = 0
        self.textCredits = 0
        self.photoCredits = 0
    }
}

// MARK: - Convenience methods
extension User {
    var displayName: String {
        if let firstName = firstName {
            return firstName
        } else if let username = username {
            return "@\(username)"
        } else {
            return "User \(telegramId)"
        }
    }
    
    func currentPlan(on db: Database) async throws -> Constants.SubscriptionPlan {
        if let subscription = try await self.$subscription.get(on: db),
           subscription.isActive {
            return subscription.plan
        }
        return .free
    }
    
    func remainingGenerations(on db: Database) async throws -> Int {
        // Кредитная модель: считаем от общего лимита пакета минус использованные
        let plan = try await currentPlan(on: db)
        let limit = plan.textGenerationsLimit
        return max(0, limit - generationsUsed)
    }
    
    func remainingPhotoGenerations(on db: Database) async throws -> Int {
        // Кредитная модель: считаем от общего лимита пакета минус использованные
        let plan = try await currentPlan(on: db)
        let limit = plan.photoGenerationsLimit
        if limit == -1 { return 999 }
        return max(0, limit - photoGenerationsUsed)
    }
}


