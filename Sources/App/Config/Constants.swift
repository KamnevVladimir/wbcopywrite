import Foundation

enum Constants {
    // Subscription plans
    enum SubscriptionPlan: String, CaseIterable {
        case free = "free"
        case starter = "starter"
        case business = "business"
        case pro = "pro"
        
        var name: String {
            switch self {
            case .free: return "Free"
            case .starter: return "Starter"
            case .business: return "Business"
            case .pro: return "Pro"
            }
        }
        
        var price: Decimal {
            switch self {
            case .free: return 0
            case .starter: return 299
            case .business: return 599
            case .pro: return 999
            }
        }
        
        var generationsLimit: Int {
            switch self {
            case .free: return 3
            case .starter: return 30
            case .business: return 150
            case .pro: return 500
            }
        }
        
        var description: String {
            switch self {
            case .free:
                return "3 описания для знакомства с ботом"
            case .starter:
                return "30 описаний в месяц для небольших селлеров"
            case .business:
                return "150 описаний в месяц для активных селлеров"
            case .pro:
                return "500 описаний в месяц для крупных селлеров и агентств"
            }
        }
    }
    
    // Product categories
    enum ProductCategory: String, CaseIterable {
        case clothing = "clothing"
        case electronics = "electronics"
        case home = "home"
        case beauty = "beauty"
        case sports = "sports"
        
        var emoji: String {
            switch self {
            case .clothing: return "👗"
            case .electronics: return "📱"
            case .home: return "🏠"
            case .beauty: return "💄"
            case .sports: return "⚽️"
            }
        }
        
        var name: String {
            switch self {
            case .clothing: return "Одежда и обувь"
            case .electronics: return "Электроника"
            case .home: return "Дом и сад"
            case .beauty: return "Красота и здоровье"
            case .sports: return "Спорт и отдых"
            }
        }
        
        var displayName: String {
            "\(emoji) \(name)"
        }
    }
    
    // Bot commands
    enum BotCommand: String {
        case start = "/start"
        case generate = "/generate"
        case balance = "/balance"
        case subscribe = "/subscribe"
        case help = "/help"
        case cancel = "/cancel"
        
        var description: String {
            switch self {
            case .start:
                return "Начать работу с ботом"
            case .generate:
                return "Сгенерировать описание товара"
            case .balance:
                return "Проверить остаток генераций"
            case .subscribe:
                return "Управление подпиской"
            case .help:
                return "Помощь и инструкции"
            case .cancel:
                return "Отменить текущее действие"
            }
        }
    }
    
    // Bot messages
    enum BotMessage {
        static let welcome = """
        👋 Привет! Я помогу создать продающие описания для твоих товаров на Wildberries и Ozon.
        
        🎯 Что я умею:
        • Генерирую SEO-оптимизированные описания
        • Создаю цепляющие заголовки
        • Подбираю ключевые слова
        • Пишу bullet-points с выгодами
        
        Нажми /generate чтобы начать!
        """
        
        static let selectCategory = """
        Выбери категорию товара:
        """
        
        static let enterProductInfo = """
        Отлично! Теперь опиши товар:
        
        Пример:
        Название: Женские кроссовки Nike Air Max
        Материал: текстиль, резина
        Цвет: белый, черный
        Размеры: 36-41
        Особенности: дышащие, легкие, амортизация
        """
        
        static let generating = """
        ⏳ Генерирую описание...
        
        Обычно это занимает 10-15 секунд.
        """
        
        static let limitExceeded = """
        😔 У тебя закончились генерации.
        
        Перейди на платный план чтобы продолжить:
        /subscribe
        """
        
        static func subscriptionInfo(plan: SubscriptionPlan, remaining: Int, total: Int) -> String {
            """
            📊 Твоя подписка: \(plan.name)
            
            Осталось генераций: \(remaining) из \(total)
            Цена: \(plan.price)₽/мес
            
            Хочешь больше? /subscribe
            """
        }
        
        static func generationResult(title: String, description: String, bullets: [String]) -> String {
            let bulletsText = bullets.map { "• \($0)" }.joined(separator: "\n")
            
            return """
            ✅ Готово! Вот твое описание:
            
            📝 Заголовок:
            \(title)
            
            📄 Описание:
            \(description)
            
            🎯 Ключевые выгоды:
            \(bulletsText)
            
            Нажми "Экспорт в файл" чтобы скачать или /generate для нового описания
            """
        }
        
        static let error = """
        ❌ Произошла ошибка. Попробуй еще раз или напиши в поддержку.
        """
    }
    
    // Timeouts
    enum Timeout {
        static let claudeRequest: TimeInterval = 30
        static let tributeRequest: TimeInterval = 15
        static let webhookTimeout: TimeInterval = 10
    }
    
    // Limits
    enum Limits {
        static let maxProductNameLength = 500
        static let maxDescriptionLength = 5000
        static let minGenerationInterval: TimeInterval = 2 // секунды между генерациями
    }
}


