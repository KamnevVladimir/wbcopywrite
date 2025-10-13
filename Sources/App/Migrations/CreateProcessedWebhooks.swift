import Fluent

struct CreateProcessedWebhooks: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("processed_webhooks")
            .id()
            .field("event_id", .string, .required)
            .field("event_type", .string, .required)
            .field("processed_at", .datetime, .required)
            .field("user_id", .int64)
            .field("amount", .int)
            .unique(on: "event_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("processed_webhooks").delete()
    }
}

