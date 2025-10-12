import Fluent

struct CreateGenerations: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("generations")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("category", .string, .required)
            .field("product_name", .string, .required)
            .field("product_details", .string)
            .field("result_title", .string)
            .field("result_description", .string)
            .field("result_bullets", .array(of: .string))
            .field("result_hashtags", .array(of: .string))
            .field("tokens_used", .int, .required)
            .field("processing_time_ms", .int, .required)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("generations").delete()
    }
}

