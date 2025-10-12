import Fluent

struct CreateUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("telegram_id", .int64, .required)
            .field("username", .string)
            .field("first_name", .string)
            .field("last_name", .string)
            .field("selected_category", .string)
            .field("generations_used", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "telegram_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}


