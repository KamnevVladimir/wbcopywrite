import Vapor
import Fluent

/// Repository для работы с пользователями
/// Инкапсулирует всю логику работы с БД
struct UserRepository {
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    // MARK: - CRUD
    
    /// Найти пользователя по Telegram ID
    func find(telegramId: Int64) async throws -> User? {
        try await User.query(on: database)
            .filter(\.$telegramId == telegramId)
            .first()
    }
    
    /// Создать нового пользователя
    func create(
        telegramId: Int64,
        username: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User {
        let user = User(
            telegramId: telegramId,
            username: username,
            firstName: firstName,
            lastName: lastName
        )
        try await user.save(on: database)
        return user
    }
    
    /// Получить или создать пользователя (upsert)
    func getOrCreate(
        telegramId: Int64,
        username: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> User {
        if let existing = try await find(telegramId: telegramId) {
            // Обновить данные если изменились
            var needsUpdate = false
            
            if existing.username != username {
                existing.username = username
                needsUpdate = true
            }
            if existing.firstName != firstName {
                existing.firstName = firstName
                needsUpdate = true
            }
            if existing.lastName != lastName {
                existing.lastName = lastName
                needsUpdate = true
            }
            
            if needsUpdate {
                try await existing.update(on: database)
            }
            
            return existing
        }
        
        return try await create(
            telegramId: telegramId,
            username: username,
            firstName: firstName,
            lastName: lastName
        )
    }
    
    /// Обновить выбранную категорию
    func updateCategory(_ user: User, category: String?) async throws {
        user.selectedCategory = category
        try await user.update(on: database)
    }
    
    /// Списать 1 текстовый кредит (или увеличить старый счётчик, если кредитов нет)
    /// Thread-safe: использует pessimistic locking через FOR UPDATE
    func incrementGenerations(_ user: User) async throws {
        // Pessimistic locking: блокируем строку в БД
        guard let freshUser = try await User.query(on: database)
            .filter(\.$id == user.id!)
            .for(.update)
            .first() else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Атомарно проверяем и обновляем
        if freshUser.textCredits > 0 {
            freshUser.textCredits -= 1
        } else {
            freshUser.generationsUsed += 1
        }
        
        try await freshUser.update(on: database)
        
        // Обновляем переданного пользователя для консистентности
        user.textCredits = freshUser.textCredits
        user.generationsUsed = freshUser.generationsUsed
    }
    
    /// Списать 1 фото кредит (или увеличить старый счётчик, если кредитов нет)
    /// Thread-safe: использует pessimistic locking через FOR UPDATE
    func incrementPhotoGenerations(_ user: User) async throws {
        // Pessimistic locking: блокируем строку в БД
        guard let freshUser = try await User.query(on: database)
            .filter(\.$id == user.id!)
            .for(.update)
            .first() else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Атомарно проверяем и обновляем
        if freshUser.photoCredits > 0 {
            freshUser.photoCredits -= 1
        } else {
            freshUser.photoGenerationsUsed += 1
        }
        
        try await freshUser.update(on: database)
        
        // Обновляем переданного пользователя для консистентности
        user.photoCredits = freshUser.photoCredits
        user.photoGenerationsUsed = freshUser.photoGenerationsUsed
    }
    
    /// Откатить текстовую генерацию (если произошла ошибка после списания)
    func rollbackGeneration(_ user: User) async throws {
        guard let freshUser = try await User.query(on: database)
            .filter(\.$id == user.id!)
            .for(.update)
            .first() else {
            return
        }
        
        // Возвращаем кредит обратно
        if freshUser.textCredits < 1000 { // Защита от переполнения
            freshUser.textCredits += 1
        } else if freshUser.generationsUsed > 0 {
            freshUser.generationsUsed -= 1
        }
        
        try await freshUser.update(on: database)
    }
    
    /// Откатить фото генерацию (если произошла ошибка после списания)
    func rollbackPhotoGeneration(_ user: User) async throws {
        guard let freshUser = try await User.query(on: database)
            .filter(\.$id == user.id!)
            .for(.update)
            .first() else {
            return
        }
        
        // Возвращаем кредит обратно
        if freshUser.photoCredits < 1000 {
            freshUser.photoCredits += 1
        } else if freshUser.photoGenerationsUsed > 0 {
            freshUser.photoGenerationsUsed -= 1
        }
        
        try await freshUser.update(on: database)
    }
    
    // MARK: - Queries
    
    /// Получить текущий план подписки
    func getCurrentPlan(_ user: User) async throws -> Constants.SubscriptionPlan {
        try await user.currentPlan(on: database)
    }
    
    /// Получить количество оставшихся текстовых генераций
    func getRemainingGenerations(_ user: User) async throws -> Int {
        // Новая логика: кредиты имеют приоритет
        if user.textCredits > 0 { return user.textCredits }
        return try await user.remainingGenerations(on: database)
    }
    
    /// Получить количество оставшихся фото генераций
    func getRemainingPhotoGenerations(_ user: User) async throws -> Int {
        // Новая логика: кредиты имеют приоритет
        if user.photoCredits > 0 { return user.photoCredits }
        return try await user.remainingPhotoGenerations(on: database)
    }
    
    /// Проверить есть ли лимит на текстовые генерации
    func hasGenerationsAvailable(_ user: User) async throws -> Bool {
        let remaining = try await getRemainingGenerations(user)
        return remaining > 0
    }
    
    /// Проверить есть ли лимит на фото генерации
    func hasPhotoGenerationsAvailable(_ user: User) async throws -> Bool {
        let remaining = try await getRemainingPhotoGenerations(user)
        return remaining > 0
    }
}

// MARK: - Request Extension

extension Request {
    var userRepository: UserRepository {
        UserRepository(database: db)
    }
}

