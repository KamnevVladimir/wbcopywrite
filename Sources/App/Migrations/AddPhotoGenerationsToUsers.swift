import Fluent

struct AddPhotoGenerationsToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("photo_generations_used", .int, .required, .sql(.default(0)))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("photo_generations_used")
            .update()
    }
}

