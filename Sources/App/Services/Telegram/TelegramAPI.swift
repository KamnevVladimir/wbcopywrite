import Vapor

/// Обертка для Telegram Bot API
final class TelegramAPI: @unchecked Sendable {
    private let app: Application
    private let botToken: String
    private let baseURL: String
    
    init(app: Application, botToken: String) {
        self.app = app
        self.botToken = botToken
        self.baseURL = "https://api.telegram.org/bot\(botToken)"
    }
    
    // MARK: - Send Message
    
    @discardableResult
    func sendMessage(
        chatId: Int64,
        text: String,
        replyMarkup: TelegramReplyMarkup? = nil,
        parseMode: String = "Markdown"
    ) async throws -> Int {
        let uri = URI(string: "\(baseURL)/sendMessage")
        
        struct SendMessageRequest: Content {
            let chat_id: Int64
            let text: String
            let parse_mode: String
            let reply_markup: TelegramReplyMarkup?
        }
        
        let response = try await app.client.post(uri) { req in
            try req.content.encode(SendMessageRequest(
                chat_id: chatId,
                text: text,
                parse_mode: parseMode,
                reply_markup: replyMarkup
            ))
        }
        
        struct MessageResponse: Content {
            let ok: Bool
            let result: MessageResult
        }
        
        struct MessageResult: Content {
            let message_id: Int
        }
        
        let result = try response.content.decode(MessageResponse.self)
        return result.result.message_id
    }
    
    // MARK: - Edit Message
    
    func editMessage(
        chatId: Int64,
        messageId: Int,
        text: String,
        replyMarkup: TelegramReplyMarkup? = nil
    ) async throws {
        let uri = URI(string: "\(baseURL)/editMessageText")
        
        struct EditMessageRequest: Content {
            let chat_id: Int64
            let message_id: Int
            let text: String
            let parse_mode: String
            let reply_markup: TelegramReplyMarkup?
        }
        
        _ = try await app.client.post(uri) { req in
            try req.content.encode(EditMessageRequest(
                chat_id: chatId,
                message_id: messageId,
                text: text,
                parse_mode: "Markdown",
                reply_markup: replyMarkup
            ))
        }
    }
    
    // MARK: - Answer Callback Query
    
    func answerCallback(callbackId: String, text: String? = nil) async throws {
        struct AnswerCallbackQuery: Content {
            let callback_query_id: String
            let text: String?
        }
        
        let uri = URI(string: "\(baseURL)/answerCallbackQuery")
        
        _ = try await app.client.post(uri) { req in
            try req.content.encode(AnswerCallbackQuery(
                callback_query_id: callbackId,
                text: text
            ))
        }
    }
    
    // MARK: - Send Document
    
    func sendDocument(
        chatId: Int64,
        content: String,
        filename: String,
        caption: String? = nil
    ) async throws {
        // Создаем multipart/form-data
        let boundary = "----WebKitFormBoundary\(UUID().uuidString)"
        var body = Data()
        
        func append(_ string: String) {
            body.append(Data(string.utf8))
        }
        
        // chat_id
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n")
        append("\(chatId)\r\n")
        
        // document (file)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"document\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: text/plain\r\n\r\n")
        append(content)
        append("\r\n")
        
        // caption (if provided)
        if let caption = caption {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
            append(caption)
            append("\r\n")
        }
        
        append("--\(boundary)--\r\n")
        
        let uri = URI(string: "\(baseURL)/sendDocument")
        
        _ = try await app.client.post(uri) { req in
            req.headers.contentType = HTTPMediaType(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
            req.body = ByteBuffer(data: body)
        }
    }
    
    // MARK: - Get File
    
    func getFilePath(fileId: String) async throws -> String {
        struct GetFileResponse: Content {
            let ok: Bool
            let result: FileInfo
        }
        
        struct FileInfo: Content {
            let filePath: String
            
            enum CodingKeys: String, CodingKey {
                case filePath = "file_path"
            }
        }
        
        let uri = URI(string: "\(baseURL)/getFile")
        
        let response = try await app.client.post(uri) { req in
            try req.content.encode(["file_id": fileId])
            req.headers.add(name: .contentType, value: "application/json")
        }
        
        guard response.status == .ok else {
            throw TelegramAPIError.httpError(response.status)
        }
        
        let fileResponse = try response.content.decode(GetFileResponse.self)
        return fileResponse.result.filePath
    }
    
    // MARK: - Download File
    
    func downloadFile(filePath: String) async throws -> Data {
        let fileURL = "https://api.telegram.org/file/bot\(botToken)/\(filePath)"
        let uri = URI(string: fileURL)
        
        let response = try await app.client.get(uri)
        
        guard response.status == .ok, let buffer = response.body else {
            throw TelegramAPIError.httpError(.notFound)
        }
        
        return Data(buffer: buffer)
    }
    
    // MARK: - Errors
    
    enum TelegramAPIError: Error {
        case httpError(HTTPResponseStatus)
        case invalidResponse
    }
}

// MARK: - Application Extension

extension Application {
    private struct TelegramAPIKey: StorageKey {
        typealias Value = TelegramAPI
    }
    
    var telegramAPI: TelegramAPI {
        get {
            guard let api = storage[TelegramAPIKey.self] else {
                fatalError("TelegramAPI not configured")
            }
            return api
        }
        set {
            storage[TelegramAPIKey.self] = newValue
        }
    }
}

