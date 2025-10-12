import Fluent

struct CreateSubscriptions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("subscriptions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("plan", .string, .required)
            .field("status", .string, .required)
            .field("generations_limit", .int, .required)
            .field("price", .double, .required)
            .field("started_at", .datetime, .required)
            .field("expires_at", .datetime, .required)
            .field("tribute_subscription_id", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("subscriptions").delete()
    }
}


