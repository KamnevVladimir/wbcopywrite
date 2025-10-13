import Vapor

/// Middleware для детального логирования всех запросов
struct RequestLoggingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = Date()
        let requestId = UUID().uuidString.prefix(8)
        
        // Логируем входящий запрос
        request.logger.info("📥 [\(requestId)] \(request.method) \(request.url.path)")
        
        // Логируем headers (без чувствительных данных)
        if request.logger.logLevel <= .debug {
            for (name, value) in request.headers {
                if name.lowercased() != "authorization" && !name.lowercased().contains("key") {
                    request.logger.debug("  Header: \(name) = \(value)")
                }
            }
        }
        
        // Логируем body (если есть и не слишком большой)
        if let bodyString = request.body.string, bodyString.count < 1000 {
            request.logger.debug("  Body: \(bodyString)")
        }
        
        do {
            // Выполняем запрос
            let response = try await next.respond(to: request)
            
            let duration = Int(Date().timeIntervalSince(startTime) * 1000) // ms
            
            // Логируем ответ
            request.logger.info("📤 [\(requestId)] \(response.status.code) in \(duration)ms")
            
            return response
        } catch {
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            
            // Логируем ошибку
            request.logger.error("❌ [\(requestId)] Error after \(duration)ms: \(error)")
            
            throw error
        }
    }
}

