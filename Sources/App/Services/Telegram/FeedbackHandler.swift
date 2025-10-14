import Vapor
import Fluent

/// Обработчик сбора обратной связи от пользователей
final class FeedbackHandler: @unchecked Sendable {
    private let app: Application
    private let api: TelegramAPI
    private let log: BotLogger
    
    init(app: Application, api: TelegramAPI) {
        self.app = app
        self.api = api
        self.log = app.botLogger
    }
    
    // MARK: - Start Feedback Flow
    
    /// Начать сбор фидбека - показать оценки 0-9
    func startFeedbackFlow(user: User, chatId: Int64) async throws {
        user.selectedCategory = "awaiting_feedback_rating"
        try await user.update(on: app.db)
        
        let keyboard = createRatingKeyboard()
        
        let message = MessageFormatter.feedbackRatingPrompt()
        
        try await api.sendMessage(
            chatId: chatId,
            text: message,
            replyMarkup: keyboard
        )
        
        log.debug("Feedback flow started for user \(user.telegramId)")
    }
    
    // MARK: - Handle Rating Selection
    
    /// Обработать выбор оценки
    func handleRatingSelection(_ rating: Int, user: User, chatId: Int64, messageId: Int) async throws {
        guard rating >= 0 && rating <= 9 else {
            throw Abort(.badRequest, reason: "Invalid rating")
        }
        
        // Сохраняем оценку во временном состоянии
        user.selectedCategory = "awaiting_feedback_comment:\(rating)"
        try await user.update(on: app.db)
        
        // Удаляем клавиатуру с оценками (просто отправляем новое сообщение)
        
        let keyboard = createCommentKeyboard()
        
        let message = MessageFormatter.feedbackCommentPrompt(rating: rating)
        
        try await api.sendMessage(
            chatId: chatId,
            text: message,
            replyMarkup: keyboard
        )
        
        log.debug("Rating \(rating) selected by user \(user.telegramId)")
    }
    
    // MARK: - Handle Comment Input
    
    /// Обработать текстовый комментарий
    func handleCommentInput(_ comment: String, user: User, chatId: Int64) async throws {
        guard let state = user.selectedCategory,
              state.starts(with: "awaiting_feedback_comment:"),
              let ratingStr = state.split(separator: ":").last,
              let rating = Int(ratingStr) else {
            throw Abort(.badRequest, reason: "Invalid feedback state")
        }
        
        try await saveFeedback(
            user: user,
            rating: rating,
            comment: comment.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        user.selectedCategory = nil
        try await user.update(on: app.db)
        
        let message = MessageFormatter.feedbackThankYou(rating: rating)
        
        try await api.sendMessage(
            chatId: chatId,
            text: message
        )
        
        log.debug("Feedback saved: user=\(user.telegramId) rating=\(rating) comment_length=\(comment.count)")
    }
    
    // MARK: - Handle Skip Comment
    
    /// Пропустить комментарий
    func handleSkipComment(user: User, chatId: Int64, messageId: Int) async throws {
        guard let state = user.selectedCategory,
              state.starts(with: "awaiting_feedback_comment:"),
              let ratingStr = state.split(separator: ":").last,
              let rating = Int(ratingStr) else {
            throw Abort(.badRequest, reason: "Invalid feedback state")
        }
        
        try await saveFeedback(
            user: user,
            rating: rating,
            comment: nil
        )
        
        user.selectedCategory = nil
        try await user.update(on: app.db)
        
        // Удаляем клавиатуру (просто отправляем новое сообщение)
        
        let message = MessageFormatter.feedbackThankYou(rating: rating)
        
        try await api.sendMessage(
            chatId: chatId,
            text: message
        )
        
        log.debug("Feedback saved without comment: user=\(user.telegramId) rating=\(rating)")
    }
    
    // MARK: - Private Helpers
    
    private func saveFeedback(user: User, rating: Int, comment: String?) async throws {
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User ID not found")
        }
        
        let feedback = Feedback(
            userId: userId,
            rating: rating,
            comment: comment
        )
        
        try await feedback.save(on: app.db)
    }
    
    private func createRatingKeyboard() -> TelegramReplyMarkup {
        // 2 ряда по 5 кнопок (0-4, 5-9)
        let row1 = (0...4).map { rating in
            TelegramInlineKeyboardButton(
                text: "\(rating)",
                callbackData: "feedback_rate:\(rating)"
            )
        }
        
        let row2 = (5...9).map { rating in
            TelegramInlineKeyboardButton(
                text: "\(rating)",
                callbackData: "feedback_rate:\(rating)"
            )
        }
        
        return TelegramReplyMarkup(inlineKeyboard: [row1, row2])
    }
    
    private func createCommentKeyboard() -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [[
            TelegramInlineKeyboardButton(
                text: "⏭️ Пропустить",
                callbackData: "feedback_skip"
            )
        ]])
    }
}

