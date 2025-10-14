import Fluent

struct CreateFeedbacks: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("feedbacks")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("rating", .int, .required)
            .field("comment", .string)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("feedbacks").delete()
    }
}

