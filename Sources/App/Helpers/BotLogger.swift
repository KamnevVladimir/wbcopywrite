import Vapor

/// Централизованное логирование для бота
struct BotLogger {
    private let logger: Logger
    private let context: String
    
    init(logger: Logger, context: String = "Bot") {
        self.logger = logger
        self.context = context
    }
    
    // MARK: - User Actions
    
    func userStarted(_ user: User) {
        logger.info("👋 User started: @\(user.username ?? "none") (ID: \(user.telegramId))")
    }
    
    func userMessage(_ user: User, text: String) {
        logger.info("💬 Message from @\(user.username ?? "none"): \(text.prefix(50))")
    }
    
    func userCallback(_ user: User, data: String) {
        logger.info("🔘 Callback from @\(user.username ?? "none"): \(data)")
    }
    
    // MARK: - Generation
    
    func generationStarted(_ user: User, category: String) {
        logger.info("🟢 Generation started: user=\(user.telegramId) category=\(category)")
    }
    
    func creditReserved(_ user: User, remaining: Int) {
        logger.info("🔒 Credit reserved: user=\(user.telegramId) remaining=\(remaining)")
    }
    
    func claudeAPICall(tokens: Int, timeMs: Int) {
        logger.info("🤖 Claude API: tokens=\(tokens) time=\(timeMs)ms")
    }
    
    func generationSuccess(_ user: User, tokensUsed: Int, timeMs: Int) {
        logger.info("✅ Generation success: user=\(user.telegramId) tokens=\(tokensUsed) time=\(timeMs)ms")
    }
    
    func generationError(_ error: Error) {
        logger.error("❌ Generation error: \(error)")
    }
    
    func creditRolledBack(_ user: User) {
        logger.info("🔄 Credit rolled back: user=\(user.telegramId)")
    }
    
    // MARK: - Photo
    
    func photoReceived(_ user: User, size: Int) {
        logger.info("📷 Photo received: user=\(user.telegramId) size=\(size/1024)KB")
    }
    
    func photoDownloaded(size: Int) {
        logger.info("✅ Photo downloaded: \(size/1024)KB")
    }
    
    func imageCompressed(from: Int, to: Int) {
        let saved = from - to
        let percent = (Double(saved) / Double(from)) * 100
        logger.info("📦 Image compressed: \(from/1024)KB → \(to/1024)KB (saved \(Int(percent))%)")
    }
    
    // MARK: - Payment
    
    func paymentLinkCreated(plan: String, url: String) {
        logger.info("💳 Payment link created: plan=\(plan) url=\(url)")
    }
    
    func webhookReceived(eventId: String, type: String, userId: String) {
        logger.info("💰 Webhook received: event=\(eventId) type=\(type) user=\(userId)")
    }
    
    func duplicateWebhook(eventId: String) {
        logger.info("⏭️ Duplicate webhook skipped: \(eventId)")
    }
    
    func creditsAdded(user: Int64, text: Int, photo: Int) {
        logger.info("✅ Credits added: user=\(user) text=+\(text) photo=+\(photo)")
    }
    
    // MARK: - Errors
    
    func error(_ message: String, error: Error? = nil) {
        if let error = error {
            logger.error("❌ \(message): \(error)")
        } else {
            logger.error("❌ \(message)")
        }
    }
    
    func warning(_ message: String) {
        logger.warning("⚠️ \(message)")
    }
    
    // MARK: - Debug (only in development)
    
    func debug(_ message: String) {
        logger.debug("🔍 \(message)")
    }
}

// MARK: - Application Extension

extension Application {
    var botLogger: BotLogger {
        BotLogger(logger: logger, context: "Bot")
    }
}

extension Request {
    var botLogger: BotLogger {
        BotLogger(logger: logger, context: "Bot")
    }
}

