import Vapor

// MARK: - Telegram Bot API DTOs

struct TelegramUpdate: Content {
    let updateId: Int64
    let message: TelegramMessage?
    let callbackQuery: TelegramCallbackQuery?
    
    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
        case callbackQuery = "callback_query"
    }
}

struct TelegramMessage: Content {
    let messageId: Int64
    let from: TelegramUser
    let chat: TelegramChat
    let date: Int64
    let text: String?
    let caption: String?
    let photo: [TelegramPhotoSize]?
    let document: TelegramDocument?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from
        case chat
        case date
        case text
        case caption
        case photo
        case document
    }
}

struct TelegramUser: Content {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let lastName: String?
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
    }
}

struct TelegramChat: Content {
    let id: Int64
    let type: String
    let username: String?
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case username
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct TelegramPhotoSize: Content {
    let fileId: String
    let fileUniqueId: String
    let width: Int
    let height: Int
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case width
        case height
        case fileSize = "file_size"
    }
}

struct TelegramDocument: Content {
    let fileId: String
    let fileUniqueId: String
    let fileName: String?
    let mimeType: String?
    let fileSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileName = "file_name"
        case mimeType = "mime_type"
        case fileSize = "file_size"
    }
}

struct TelegramCallbackQuery: Content {
    let id: String
    let from: TelegramUser
    let message: TelegramMessage?
    let data: String?
}

// MARK: - Outgoing messages

struct TelegramSendMessage: Content {
    let chatId: Int64
    let text: String
    let parseMode: String?
    let replyMarkup: TelegramReplyMarkup?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case parseMode = "parse_mode"
        case replyMarkup = "reply_markup"
    }
    
    init(chatId: Int64, text: String, parseMode: String? = "Markdown", replyMarkup: TelegramReplyMarkup? = nil) {
        self.chatId = chatId
        self.text = text
        self.parseMode = parseMode
        self.replyMarkup = replyMarkup
    }
}

struct TelegramReplyMarkup: Content {
    let inlineKeyboard: [[TelegramInlineKeyboardButton]]?
    
    enum CodingKeys: String, CodingKey {
        case inlineKeyboard = "inline_keyboard"
    }
    
    init(inlineKeyboard: [[TelegramInlineKeyboardButton]]) {
        self.inlineKeyboard = inlineKeyboard
    }
}

struct TelegramInlineKeyboardButton: Content {
    let text: String
    let callbackData: String?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case callbackData = "callback_data"
        case url
    }
    
    init(text: String, callbackData: String) {
        self.text = text
        self.callbackData = callbackData
        self.url = nil
    }
    
    init(text: String, url: String) {
        self.text = text
        self.callbackData = nil
        self.url = url
    }
}

struct TelegramSendDocument: Content {
    let chatId: Int64
    let document: String // file_id or URL
    let caption: String?
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case document
        case caption
    }
}

// MARK: - API Response

struct TelegramResponse<T: Content>: Content {
    let ok: Bool
    let result: T?
    let description: String?
}


