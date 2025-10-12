import Vapor

func routes(_ app: Application) throws {
    // MARK: - Health Check
    
    app.get("health") { req async -> Response in
        let response = Response(status: .ok)
        response.headers.contentType = .json
        response.body = .init(string: """
        {
            "status": "ok",
            "service": "КарточкаПРО",
            "version": "0.1.0",
            "environment": "\(app.environmentConfig.environment)"
        }
        """)
        return response
    }
    
    // MARK: - Root
    
    app.get { req async -> String in
        """
        🎯 КарточкаПРО API
        
        Telegram Bot: @kartochka_pro
        Mode: Long Polling
        Status: /health
        Version: 0.1.0
        """
    }
    
    // MARK: - Tribute webhook (для платежей, позже)
    
    app.post("payment", "webhook") { req async throws -> HTTPStatus in
        req.logger.info("💰 Tribute webhook received")
        // TODO: Implement TributeWebhookController when needed
        return .ok
    }
    
    app.logger.info("🛣️  Routes configured (long polling mode)")
}

