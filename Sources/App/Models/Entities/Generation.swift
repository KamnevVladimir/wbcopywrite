import Vapor
import Fluent

final class Generation: Model, Content {
    static let schema = "generations"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "category")
    var category: String
    
    @Field(key: "product_name")
    var productName: String
    
    @OptionalField(key: "product_details")
    var productDetails: String?
    
    @OptionalField(key: "result_title")
    var resultTitle: String?
    
    @OptionalField(key: "result_description")
    var resultDescription: String?
    
    @OptionalField(key: "result_bullets")
    var resultBullets: [String]?
    
    @OptionalField(key: "result_hashtags")
    var resultHashtags: [String]?
    
    @Field(key: "tokens_used")
    var tokensUsed: Int
    
    @Field(key: "processing_time_ms")
    var processingTimeMs: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        userId: User.IDValue,
        category: String,
        productName: String,
        productDetails: String? = nil,
        tokensUsed: Int = 0,
        processingTimeMs: Int = 0
    ) {
        self.id = id
        self.$user.id = userId
        self.category = category
        self.productName = productName
        self.productDetails = productDetails
        self.tokensUsed = tokensUsed
        self.processingTimeMs = processingTimeMs
    }
}

// MARK: - Response models
extension Generation {
    struct Output: Content {
        let title: String
        let description: String
        let bullets: [String]
        let hashtags: [String]
        let tokensUsed: Int
        let processingTimeMs: Int
    }
    
    func toOutput() -> Output {
        Output(
            title: resultTitle ?? "",
            description: resultDescription ?? "",
            bullets: resultBullets ?? [],
            hashtags: resultHashtags ?? [],
            tokensUsed: tokensUsed,
            processingTimeMs: processingTimeMs
        )
    }
}

