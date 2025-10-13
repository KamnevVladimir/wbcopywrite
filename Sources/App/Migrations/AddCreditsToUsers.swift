import Fluent

struct AddCreditsToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("text_credits", .int, .sql(.default(0)))
            .field("photo_credits", .int, .sql(.default(0)))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("text_credits")
            .deleteField("photo_credits")
            .update()
    }
}


