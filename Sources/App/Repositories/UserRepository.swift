import Vapor
import Fluent
import SQLKit

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
    /// Thread-safe: использует атомарный SQL UPDATE для 100% защиты от race conditions
    func incrementGenerations(_ user: User) async throws {
        // 🔒 ATOMIC: Используем raw SQL для атомарного UPDATE с условием
        // Это единственный способ гарантировать отсутствие race condition!
        
        // Вариант 1: Если есть кредиты - списываем кредит
        let creditsUpdated = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET text_credits = text_credits - 1 
                WHERE id = \(bind: user.id!) AND text_credits > 0
                RETURNING text_credits, generations_used
                """)
            .first(decoding: CreditUpdateResult.self)
        
        if let result = creditsUpdated {
            // Успешно списали кредит
            user.textCredits = result.textCredits
            user.generationsUsed = result.generationsUsed
            return
        }
        
        // Вариант 2: Если кредитов нет - инкрементим счётчик
        let counterUpdated = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET generations_used = generations_used + 1 
                WHERE id = \(bind: user.id!)
                RETURNING text_credits, generations_used
                """)
            .first(decoding: CreditUpdateResult.self)
        
        if let result = counterUpdated {
            user.textCredits = result.textCredits
            user.generationsUsed = result.generationsUsed
        } else {
            throw Abort(.notFound, reason: "User not found")
        }
    }
    
    // Вспомогательная структура для результата UPDATE
    private struct CreditUpdateResult: Codable {
        let textCredits: Int
        let generationsUsed: Int
        
        enum CodingKeys: String, CodingKey {
            case textCredits = "text_credits"
            case generationsUsed = "generations_used"
        }
    }
    
    /// Списать 1 фото кредит (или увеличить старый счётчик, если кредитов нет)
    /// Thread-safe: использует атомарный SQL UPDATE для 100% защиты от race conditions
    func incrementPhotoGenerations(_ user: User) async throws {
        // 🔒 ATOMIC: Используем raw SQL для атомарного UPDATE с условием
        
        // Вариант 1: Если есть кредиты - списываем кредит
        let creditsUpdated = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET photo_credits = photo_credits - 1 
                WHERE id = \(bind: user.id!) AND photo_credits > 0
                RETURNING photo_credits, photo_generations_used
                """)
            .first(decoding: PhotoCreditUpdateResult.self)
        
        if let result = creditsUpdated {
            // Успешно списали кредит
            user.photoCredits = result.photoCredits
            user.photoGenerationsUsed = result.photoGenerationsUsed
            return
        }
        
        // Вариант 2: Если кредитов нет - инкрементим счётчик
        let counterUpdated = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET photo_generations_used = photo_generations_used + 1 
                WHERE id = \(bind: user.id!)
                RETURNING photo_credits, photo_generations_used
                """)
            .first(decoding: PhotoCreditUpdateResult.self)
        
        if let result = counterUpdated {
            user.photoCredits = result.photoCredits
            user.photoGenerationsUsed = result.photoGenerationsUsed
        } else {
            throw Abort(.notFound, reason: "User not found")
        }
    }
    
    // Вспомогательная структура для результата UPDATE фото кредитов
    private struct PhotoCreditUpdateResult: Codable {
        let photoCredits: Int
        let photoGenerationsUsed: Int
        
        enum CodingKeys: String, CodingKey {
            case photoCredits = "photo_credits"
            case photoGenerationsUsed = "photo_generations_used"
        }
    }
    
    /// Откатить текстовую генерацию (если произошла ошибка после списания)
    /// Thread-safe: использует атомарный SQL UPDATE
    func rollbackGeneration(_ user: User) async throws {
        // 🔒 ATOMIC: Возвращаем кредит атомарно
        _ = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET text_credits = LEAST(text_credits + 1, 10000),
                    generations_used = GREATEST(generations_used - 1, 0)
                WHERE id = \(bind: user.id!)
                RETURNING text_credits, generations_used
                """)
            .first(decoding: CreditUpdateResult.self)
    }
    
    /// Откатить фото генерацию (если произошла ошибка после списания)
    /// Thread-safe: использует атомарный SQL UPDATE
    func rollbackPhotoGeneration(_ user: User) async throws {
        // 🔒 ATOMIC: Возвращаем кредит атомарно
        _ = try await (database as! SQLDatabase)
            .raw("""
                UPDATE users 
                SET photo_credits = LEAST(photo_credits + 1, 10000),
                    photo_generations_used = GREATEST(photo_generations_used - 1, 0)
                WHERE id = \(bind: user.id!)
                RETURNING photo_credits, photo_generations_used
                """)
            .first(decoding: PhotoCreditUpdateResult.self)
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

