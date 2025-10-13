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
    
    @Field(key: "generations_used")
    var generationsUsed: Int
    
    @Field(key: "photo_generations_used")
    var photoGenerationsUsed: Int
    
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
        let plan = try await currentPlan(on: db)
        let limit = plan.textGenerationsLimit
        
        // Для free - считаем общее количество
        if plan == .free {
            return max(0, limit - generationsUsed)
        }
        
        // Для платных - считаем за текущий месяц
        guard let subscription = try await self.$subscription.get(on: db) else {
            return 0
        }
        
        let startOfMonth = subscription.currentPeriodStart
        let generationsThisMonth = try await Generation.query(on: db)
            .filter(\.$user.$id == self.id!)
            .filter(\.$createdAt >= startOfMonth)
            .count()
        
        return max(0, limit - generationsThisMonth)
    }
    
    func remainingPhotoGenerations(on db: Database) async throws -> Int {
        let plan = try await currentPlan(on: db)
        let limit = plan.photoGenerationsLimit
        
        // Безлимит
        if limit == -1 {
            return 999
        }
        
        // Для free - считаем общее количество
        if plan == .free {
            return max(0, limit - photoGenerationsUsed)
        }
        
        // Для платных - считаем за текущий месяц
        guard let subscription = try await self.$subscription.get(on: db) else {
            return 0
        }
        
        let startOfMonth = subscription.currentPeriodStart
        
        // Считаем фото генерации (можно добавить флаг в Generation модель)
        // Пока упрощённо - считаем по названию
        let photoGenerationsThisMonth = try await Generation.query(on: db)
            .filter(\.$user.$id == self.id!)
            .filter(\.$createdAt >= startOfMonth)
            .filter(\.$productName == "Генерация по фото")
            .count()
        
        return max(0, limit - photoGenerationsThisMonth)
    }
}


