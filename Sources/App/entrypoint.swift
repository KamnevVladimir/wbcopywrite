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
            
            // Ждать сигнала остановки
            try await app.running!.onStop.get()
            
            app.logger.info("👋 Shutting down...")
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        
        try await app.asyncShutdown()
    }
}

