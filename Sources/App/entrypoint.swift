import Vapor
import Logging
import NIOCore
import NIOPosix

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            try await app.asyncBoot()
            
            // Запустить HTTP сервер
            try app.server.start()
            
            app.logger.info("🎉 Application started successfully!")
            
            // Запустить Telegram polling через 2 секунды
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                app.telegramPolling.start()
            }
            
            // Бесконечно ждать (приложение работает пока не получит SIGTERM/SIGINT)
            try await Task.sleep(nanoseconds: UInt64.max)
            
        } catch {
            app.logger.report(error: error)
            await app.telegramPolling.stop()
            try? await app.asyncShutdown()
            throw error
        }
        
        app.logger.info("👋 Shutting down...")
        await app.telegramPolling.stop()
        try await app.asyncShutdown()
    }
}

