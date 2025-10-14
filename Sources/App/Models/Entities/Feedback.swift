import Vapor
import Fluent

/// Модель для хранения отзывов пользователей
final class Feedback: Model, Content, @unchecked Sendable {
    static let schema = "feedbacks"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "rating")
    var rating: Int
    
    @OptionalField(key: "comment")
    var comment: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userId: User.IDValue,
        rating: Int,
        comment: String? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.rating = rating
        self.comment = comment
    }
}

