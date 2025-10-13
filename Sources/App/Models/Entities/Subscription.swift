import Vapor
import Fluent

final class Subscription: Model, Content, @unchecked Sendable {
    static let schema = "subscriptions"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "plan")
    var planRaw: String
    
    @Field(key: "status")
    var statusRaw: String
    
    @Field(key: "generations_limit")
    var generationsLimit: Int
    
    @Field(key: "price")
    var price: Decimal
    
    @Field(key: "started_at")
    var startedAt: Date
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @OptionalField(key: "tribute_subscription_id")
    var tributeSubscriptionId: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userId: User.IDValue,
        plan: Constants.SubscriptionPlan,
        status: Status = .active,
        startedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.planRaw = plan.rawValue
        self.statusRaw = status.rawValue
        self.generationsLimit = plan.totalGenerationsLimit
        self.price = plan.price
        self.startedAt = startedAt
        self.expiresAt = expiresAt ?? Calendar.current.date(byAdding: .month, value: 1, to: startedAt)!
    }
    
    // MARK: - Computed properties
    var plan: Constants.SubscriptionPlan {
        get { Constants.SubscriptionPlan(rawValue: planRaw) ?? .free }
        set { planRaw = newValue.rawValue }
    }
    
    var status: Status {
        get { Status(rawValue: statusRaw) ?? .expired }
        set { statusRaw = newValue.rawValue }
    }
    
    var isActive: Bool {
        status == .active && expiresAt > Date()
    }
    
    var currentPeriodStart: Date {
        // Начало текущего месяца подписки
        let calendar = Calendar.current
        let now = Date()
        
        var currentStart = startedAt
        while currentStart < now {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentStart) else {
                break
            }
            if nextMonth > now {
                break
            }
            currentStart = nextMonth
        }
        
        return currentStart
    }
    
    enum Status: String, Codable {
        case active = "active"
        case cancelled = "cancelled"
        case expired = "expired"
        case suspended = "suspended"
    }
}

// MARK: - Convenience methods
extension Subscription {
    func renew(on db: Database) async throws {
        let calendar = Calendar.current
        self.startedAt = Date()
        self.expiresAt = calendar.date(byAdding: .month, value: 1, to: startedAt)!
        self.status = .active
        try await self.update(on: db)
    }
    
    func cancel(on db: Database) async throws {
        self.status = .cancelled
        try await self.update(on: db)
    }
    
    func expire(on db: Database) async throws {
        self.status = .expired
        try await self.update(on: db)
    }
}

