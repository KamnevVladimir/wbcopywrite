import Vapor
import Sentry

/// Сервис для мониторинга и отправки ошибок в GlitchTip/Sentry
final class MonitoringService: @unchecked Sendable {
    private let app: Application
    private let dsn: String?
    private var isEnabled: Bool = false
    
    init(app: Application) {
        self.app = app
        self.dsn = Environment.get("GLITCHTIP_DSN") ?? Environment.get("SENTRY_DSN")
        
        if let dsn = dsn, !dsn.isEmpty {
            configureSentry(dsn: dsn)
            isEnabled = true
            app.logger.info("✅ GlitchTip/Sentry monitoring enabled")
        } else {
            app.logger.warning("⚠️ GlitchTip/Sentry DSN not configured (set GLITCHTIP_DSN env var)")
        }
    }
    
    private func configureSentry(dsn: String) {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = Environment.get("ENVIRONMENT") ?? "production"
            options.tracesSampleRate = 0.1 // 10% traces
            options.enableCaptureFailedRequests = true
            
            // Фильтруем чувствительные данные
            options.beforeSend = { event in
                // Убираем токены и ключи из breadcrumbs
                event.breadcrumbs = event.breadcrumbs?.map { crumb in
                    var sanitized = crumb
                    if var data = crumb.data {
                        data.removeValue(forKey: "token")
                        data.removeValue(forKey: "api_key")
                        sanitized.data = data
                    }
                    return sanitized
                }
                return event
            }
        }
    }
    
    // MARK: - Error Tracking
    
    /// Отправить ошибку в GlitchTip
    func captureError(_ error: Error, context: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        SentrySDK.capture(error: error) { scope in
            for (key, value) in context {
                scope.setExtra(value: value, key: key)
            }
        }
        
        app.logger.error("📊 Error sent to GlitchTip: \(error)")
    }
    
    /// Отправить кастомное сообщение
    func captureMessage(_ message: String, level: SentryLevel = .warning, context: [String: Any] = [:]) {
        guard isEnabled else { return }
        
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
            for (key, value) in context {
                scope.setExtra(value: value, key: key)
            }
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
                level: .fatal,
                context: context
            )
        }
        
        if creditsAfter > 10000 {
            captureMessage(
                "⚠️ WARNING: Suspiciously high credits",
                level: .warning,
                context: context
            )
        }
        
        // Логируем большие изменения
        let delta = abs(creditsAfter - creditsBefore)
        if delta > 100 {
            captureMessage(
                "📊 Large credit change detected",
                level: .info,
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
        let level: SentryLevel = isDuplicate ? .warning : (success ? .info : .error)
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
                level: .warning,
                context: [
                    "user_id": userId,
                    "type": type.rawValue,
                    "processing_time_ms": processingTimeMs
                ]
            )
        }
    }
    
    // MARK: - Types
    
    enum CreditOperation: String {
        case charge = "charge"        // Списание
        case refund = "refund"        // Возврат
        case purchase = "purchase"    // Покупка
        case rollback = "rollback"    // Откат
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

