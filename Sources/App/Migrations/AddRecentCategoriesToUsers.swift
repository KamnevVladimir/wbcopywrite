import Fluent

struct AddRecentCategoriesToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("recent_categories", .array(of: .string))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("recent_categories")
            .update()
    }
}

