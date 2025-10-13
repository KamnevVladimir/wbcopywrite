import Vapor

/// Telegram Long Polling Service
/// Профессиональная реализация с error handling, graceful shutdown и exponential backoff
/// Thread-safe: использует actor для защиты mutable state
actor TelegramPollingService {
    private let app: Application
    private let botToken: String
    private let baseURL: String
    private var isRunning: Bool = false
    private var offset: Int64 = 0
    private var pollingTask: Task<Void, Never>?
    
    // Retry configuration
    private let maxRetries = 5
    private var currentRetry = 0
    private let baseRetryDelay: TimeInterval = 1.0
    
    init(app: Application, botToken: String) {
        self.app = app
        self.botToken = botToken
        self.baseURL = "https://api.telegram.org/bot\(botToken)"
    }
    
    // MARK: - Public API
    
    /// Запустить long polling в фоновом режиме
    func start() {
        guard !isRunning else {
            app.logger.warning("⚠️ Polling already running")
            return
        }
        
        isRunning = true
        app.logger.info("🚀 Starting Telegram long polling...")
        
        Task {
            await startPolling()
        }
    }
    
    /// Остановить long polling (graceful shutdown)
    func stop() async {
        guard isRunning else { return }
        
        app.logger.info("🛑 Stopping Telegram long polling...")
        isRunning = false
        
        // Дождаться завершения текущего запроса
        pollingTask?.cancel()
        
        app.logger.info("✅ Telegram polling stopped")
    }
    
    // MARK: - Polling Loop
    
    private func startPolling() async {
        pollingTask = Task {
            while isRunning && !Task.isCancelled {
                do {
                    let updates = try await getUpdates()
                    
                    if !updates.isEmpty {
                        app.logger.info("📨 Received \(updates.count) update(s)")
                        
                        // Обработать updates параллельно
                        await withTaskGroup(of: Void.self) { group in
                            for update in updates {
                                group.addTask {
                                    await self.handleUpdate(update)
                                }
                            }
                        }
                        
                        // Обновить offset для следующего запроса
                        if let lastUpdate = updates.last {
                            offset = lastUpdate.updateId + 1
                        }
                    }
                    
                    // Сбросить счетчик retry при успехе
                    currentRetry = 0
                    
                } catch {
                    await handlePollingError(error)
                }
            }
        }
    }
    
    // MARK: - Telegram API
    
    private func getUpdates() async throws -> [TelegramUpdate] {
        let uri = URI(string: "\(baseURL)/getUpdates")
        
        struct GetUpdatesRequest: Content {
            let offset: Int64
            let timeout: Int
            let allowed_updates: [String]
        }
        
        let response = try await app.client.post(uri) { req in
            try req.content.encode(GetUpdatesRequest(
                offset: offset,
                timeout: 30,
                allowed_updates: ["message", "callback_query"]
            ))
        }
        
        guard response.status == HTTPResponseStatus.ok else {
            throw PollingError.httpError(response.status)
        }
        
        let result = try response.content.decode(TelegramResponse<[TelegramUpdate]>.self)
        
        guard result.ok, let updates = result.result else {
            throw PollingError.telegramError(result.description ?? "Unknown error")
        }
        
        return updates
    }
    
    // MARK: - Update Handling
    
    private func handleUpdate(_ update: TelegramUpdate) async {
        app.logger.info("📬 Processing update #\(update.updateId)")
        
        // Передать в TelegramBotService для обработки
        await app.telegramBot.handleUpdate(update)
    }
    
    // MARK: - Error Handling
    
    private func handlePollingError(_ error: Error) async {
        currentRetry += 1
        
        if currentRetry >= maxRetries {
            app.logger.error("❌ Polling failed after \(maxRetries) retries: \(error)")
            app.logger.error("🛑 Stopping polling due to repeated failures")
            isRunning = false
            return
        }
        
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = baseRetryDelay * pow(2.0, Double(currentRetry - 1))
        
        app.logger.warning("⚠️ Polling error (retry \(currentRetry)/\(maxRetries)): \(error)")
        app.logger.info("⏳ Retrying in \(Int(delay))s...")
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    // MARK: - Errors
    
    enum PollingError: Error, CustomStringConvertible {
        case httpError(HTTPStatus)
        case telegramError(String)
        case cancelled
        
        var description: String {
            switch self {
            case .httpError(let status):
                return "HTTP error: \(status)"
            case .telegramError(let message):
                return "Telegram error: \(message)"
            case .cancelled:
                return "Polling cancelled"
            }
        }
    }
}

// MARK: - Application Extension

extension Application {
    private struct TelegramPollingServiceKey: StorageKey {
        typealias Value = TelegramPollingService
    }
    
    var telegramPolling: TelegramPollingService {
        get {
            guard let service = storage[TelegramPollingServiceKey.self] else {
                fatalError("TelegramPollingService not configured")
            }
            return service
        }
        set {
            storage[TelegramPollingServiceKey.self] = newValue
        }
    }
}

