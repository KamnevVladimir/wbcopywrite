import Foundation

enum Constants {
    // Subscription plans - пакетная модель
    enum SubscriptionPlan: String, CaseIterable {
        case free = "free"
        case small = "small"
        case medium = "medium"
        case large = "large"
        case max = "max"
        
        var name: String {
            switch self {
            case .free: return "Free"
            case .small: return "Малый"
            case .medium: return "Средний"
            case .large: return "Большой"
            case .max: return "Максимальный"
            }
        }
        
        var emoji: String {
            switch self {
            case .free: return "🎁"
            case .small: return "📦"
            case .medium: return "📦📦"
            case .large: return "📦📦📦"
            case .max: return "🎁💎"
            }
        }
        
        var price: Decimal {
            switch self {
            case .free: return 0
            case .small: return 299
            case .medium: return 599
            case .large: return 999
            case .max: return 1399
            }
        }
        
        var textGenerationsLimit: Int {
            switch self {
            case .free: return 3
            case .small: return 17
            case .medium: return 45
            case .large: return 90
            case .max: return 180
            }
        }
        
        var photoGenerationsLimit: Int {
            switch self {
            case .free: return 1
            case .small: return 3
            case .medium: return 5
            case .large: return 10
            case .max: return 20
            }
        }
        
        var totalGenerationsLimit: Int {
            return textGenerationsLimit + photoGenerationsLimit
        }
        
        var pricePerGeneration: Decimal {
            guard price > 0 else { return 0 }
            return price / Decimal(totalGenerationsLimit)
        }
        
        var description: String {
            switch self {
            case .free:
                return "4 описания (3 текста + 1 фото)"
            case .small:
                return "20 описаний (17 текстов + 3 фото)"
            case .medium:
                return "50 описаний (45 текстов + 5 фото)"
            case .large:
                return "100 описаний (90 текстов + 10 фото)"
            case .max:
                return "200 описаний (180 текстов + 20 фото)"
            }
        }
        
        var targetAudience: String {
            switch self {
            case .free:
                return "Попробовать бота"
            case .small:
                return "1-5 товаров/неделя"
            case .medium:
                return "10-15 товаров/неделя"
            case .large:
                return "20-30 товаров/неделя"
            case .max:
                return "30+ товаров/неделя, агентства"
            }
        }
        
        var supportsPhotoGeneration: Bool {
            return true // Все пакеты поддерживают фото!
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
    
    // Support
    enum Support {
        static let telegramContact = "https://t.me/deedeepapp"
        static let username = "@deedeepapp"
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
        Отлично! Теперь опиши товар или отправь ФОТО 📷
        
        *Пример:*
        _Женские кроссовки Nike Air Max, текстиль/резина, белые/черные, 36-41, дышащие, легкие_
        
        Или просто отправь фото товара!
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


