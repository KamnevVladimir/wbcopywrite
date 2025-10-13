import Vapor

// MARK: - Claude API DTOs

struct ClaudeRequest: Content {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [Message]
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
    
    struct Message: Content {
        let role: String
        let content: String
    }
    
    init(model: String = "claude-3-5-sonnet-20240620", maxTokens: Int = 2048, system: String? = nil, messages: [Message]) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.messages = messages
    }
}

struct ClaudeResponse: Content {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let usage: Usage
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case usage
        case stopReason = "stop_reason"
    }
    
    struct ContentBlock: Content {
        let type: String
        let text: String
    }
    
    struct Usage: Content {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
        
        var totalTokens: Int {
            inputTokens + outputTokens
        }
    }
    
    var text: String {
        content.first?.text ?? ""
    }
}

struct ClaudeError: Content, Error {
    let type: String
    let error: ErrorDetail
    
    struct ErrorDetail: Content {
        let type: String
        let message: String
    }
}

// MARK: - Product description output from Claude

struct ProductDescription: Content {
    let title: String
    let description: String
    let bullets: [String]
    let hashtags: [String]?
    
    init(title: String, description: String, bullets: [String], hashtags: [String]? = nil) {
        self.title = title
        self.description = description
        self.bullets = bullets
        self.hashtags = hashtags
    }
}


