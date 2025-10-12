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
            
            // Запустить Telegram polling через 2 секунды после boot
            app.lifecycle.use(TelegramPollingLifecycle(app: app))
            
            // Использовать стандартный Vapor способ запуска
            // Vapor автоматически обработает SIGTERM/SIGINT
            try await app.execute()
            
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
    }
}

// MARK: - Lifecycle для Telegram Polling

struct TelegramPollingLifecycle: LifecycleHandler {
    let app: Application
    
    func didBoot(_ application: Application) throws {
        // Запустить polling через 2 секунды
        application.eventLoopGroup.any().scheduleTask(in: .seconds(2)) {
            application.telegramPolling.start()
        }
    }
    
    func shutdown(_ application: Application) {
        // Graceful shutdown
        let promise = application.eventLoopGroup.next().makePromise(of: Void.self)
        
        Task {
            await application.telegramPolling.stop()
            promise.succeed(())
        }
        
        // Ждать завершения
        try? promise.futureResult.wait()
    }
}

