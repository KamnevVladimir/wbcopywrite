import Vapor
import Logging
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        // Vapor создаёт Application с дефолтными настройками
        // Мы НЕ хотим чтобы он парсил --port из аргументов командной строки
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            
            // Запустить сервер напрямую без парсинга CLI аргументов
            try await app.asyncBoot()
            try await app.running?.onStop.get()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        
        try await app.asyncShutdown()
    }
}

