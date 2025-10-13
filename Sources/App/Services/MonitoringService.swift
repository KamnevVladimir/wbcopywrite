import Vapor

/// Сервис для мониторинга и отправки ошибок в GlitchTip/Sentry через HTTP API
final class MonitoringService: @unchecked Sendable {
    private let app: Application
    private let dsn: String?
    private var isEnabled: Bool = false
    private let projectId: String?
    private let publicKey: String?
    private let host: String?
    
    init(app: Application) {
        self.app = app
        self.dsn = Environment.get("GLITCHTIP_DSN") ?? Environment.get("SENTRY_DSN")
        
        if let dsn = dsn, let components = Self.parseDSN(dsn) {
            self.publicKey = components.publicKey
            self.projectId = components.projectId
            self.host = components.host
            self.isEnabled = true
            app.logger.info("✅ GlitchTip monitoring enabled: \(components.host)/\(components.projectId)")
        } else {
            self.publicKey = nil
            self.projectId = nil
            self.host = nil
            app.logger.warning("⚠️ GlitchTip DSN not configured")
        }
    }
    
    // Парсинг DSN: https://[key]@glitchtip.com/[project]
    private static func parseDSN(_ dsn: String) -> (publicKey: String, projectId: String, host: String)? {
        guard let url = URL(string: dsn),
              let publicKey = url.user,
              let host = url.host else {
            return nil
        }
        
        let projectId = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return (publicKey: publicKey, projectId: projectId, host: host)
    }
    
    // MARK: - Error Tracking
    
    /// Отправить ошибку в GlitchTip
    func captureError(_ error: Error, context: [String: Any] = [:]) {
        guard isEnabled, let host = host, let projectId = projectId, let publicKey = publicKey else {
            return
        }
        
        let event = SentryEvent(
            message: error.localizedDescription,
            level: "error",
            extra: context
        )
        
        Task {
            await sendEvent(event, host: host, projectId: projectId, publicKey: publicKey)
        }
        
        app.logger.error("📊 Error logged to GlitchTip: \(error)")
    }
    
    /// Отправить кастомное сообщение
    func captureMessage(_ message: String, level: String = "warning", context: [String: Any] = [:]) {
        guard isEnabled, let host = host, let projectId = projectId, let publicKey = publicKey else {
            return
        }
        
        let event = SentryEvent(
            message: message,
            level: level,
            extra: context
        )
        
        Task {
            await sendEvent(event, host: host, projectId: projectId, publicKey: publicKey)
        }
    }
    
    // MARK: - Business Metrics
    
    /// Мониторинг операций с кредитами
    func trackCreditOperation(
        operation: CreditOperation,
        userId: Int64,
        creditsBefore: Int,
        creditsAfter: Int,
        success: Bool
    ) {
        let context: [String: Any] = [
            "operation": operation.rawValue,
            "user_id": userId,
            "credits_before": creditsBefore,
            "credits_after": creditsAfter,
            "success": success
        ]
        
        // Проверяем аномалии
        if creditsAfter < 0 {
            captureMessage(
                "🚨 CRITICAL: Negative credits detected!",
                level: "fatal",
                context: context
            )
        }
        
        if creditsAfter > 10000 {
            captureMessage(
                "⚠️ WARNING: Suspiciously high credits",
                level: "warning",
                context: context
            )
        }
        
        // Логируем большие изменения
        let delta = abs(creditsAfter - creditsBefore)
        if delta > 100 {
            captureMessage(
                "📊 Large credit change detected",
                level: "info",
                context: context
            )
        }
    }
    
    /// Мониторинг платежей
    func trackPayment(
        userId: Int64,
        amount: Int,
        plan: String,
        success: Bool,
        isDuplicate: Bool = false
    ) {
        let level = isDuplicate ? "warning" : (success ? "info" : "error")
        let message = isDuplicate
            ? "💳 Duplicate payment webhook detected"
            : (success ? "💰 Payment successful" : "❌ Payment failed")
        
        captureMessage(message, level: level, context: [
            "user_id": userId,
            "amount_rub": amount / 100,
            "plan": plan,
            "is_duplicate": isDuplicate
        ])
    }
    
    /// Мониторинг генераций
    func trackGeneration(
        userId: Int64,
        type: GenerationType,
        tokensUsed: Int,
        processingTimeMs: Int,
        success: Bool,
        error: Error? = nil
    ) {
        if !success, let error = error {
            captureError(error, context: [
                "user_id": userId,
                "generation_type": type.rawValue,
                "tokens_used": tokensUsed,
                "processing_time_ms": processingTimeMs
            ])
        }
        
        // Алерт на долгие генерации
        if processingTimeMs > 30000 {
            captureMessage(
                "⏱️ Slow generation detected",
                level: "warning",
                context: [
                    "user_id": userId,
                    "type": type.rawValue,
                    "processing_time_ms": processingTimeMs
                ]
            )
        }
    }
    
    // MARK: - HTTP Sender
    
    private func sendEvent(_ event: SentryEvent, host: String, projectId: String, publicKey: String) async {
        let url = "https://\(host)/api/\(projectId)/store/"
        let uri = URI(string: url)
        
        do {
            let timestamp = Int(Date().timeIntervalSince1970)
            
            struct GlitchTipPayload: Content {
                let eventId: String
                let timestamp: Int
                let platform: String
                let level: String
                let message: String
                let environment: String
                
                enum CodingKeys: String, CodingKey {
                    case eventId = "event_id"
                    case timestamp
                    case platform
                    case level
                    case message
                    case environment
                }
            }
            
            let payload = GlitchTipPayload(
                eventId: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
                timestamp: timestamp,
                platform: "swift",
                level: event.level,
                message: event.message,
                environment: Environment.get("ENVIRONMENT") ?? "production"
            )
            
            _ = try await app.client.post(uri) { req in
                req.headers.add(name: "X-Sentry-Auth", value: "Sentry sentry_version=7, sentry_key=\(publicKey), sentry_client=kartochkapro/1.0")
                req.headers.contentType = .json
                try req.content.encode(payload)
            }
            
        } catch {
            app.logger.error("❌ Failed to send event to GlitchTip: \(error)")
        }
    }
    
    // MARK: - Types
    
    private struct SentryEvent {
        let message: String
        let level: String
        let extra: [String: Any]
    }
    
    enum CreditOperation: String {
        case charge = "charge"
        case refund = "refund"
        case purchase = "purchase"
        case rollback = "rollback"
    }
    
    enum GenerationType: String {
        case text = "text"
        case photo = "photo"
    }
}

// MARK: - Application Extension

extension Application {
    private struct MonitoringServiceKey: StorageKey {
        typealias Value = MonitoringService
    }
    
    var monitoring: MonitoringService {
        get {
            if let service = storage[MonitoringServiceKey.self] {
                return service
            }
            let service = MonitoringService(app: self)
            storage[MonitoringServiceKey.self] = service
            return service
        }
        set {
            storage[MonitoringServiceKey.self] = newValue
        }
    }
}
