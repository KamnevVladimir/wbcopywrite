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
            case .small: return 20
            case .medium: return 50
            case .large: return 100
            case .max: return 200
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
                return "4 описания (3 текста + 1 бонус фото)"
            case .small:
                return "20 описаний (20 текстов + 3 бонус фото)"
            case .medium:
                return "50 описаний (50 текстов + 5 бонус фото)"
            case .large:
                return "100 описаний (100 текстов + 10 бонус фото)"
            case .max:
                return "200 описаний (200 текстов + 20 бонус фото)"
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
        
        var tributeProductId: String {
            switch self {
            case .free:
                return "" // Free не требует оплаты
            case .small:
                return "83185" // Small 299₽ (status: new, updated 13.10.2025)
            case .medium:
                return "83187" // Medium 599₽ (status: new, updated 13.10.2025)
            case .large:
                return "83188" // Large 999₽ (status: new, updated 13.10.2025)
            case .max:
                return "83189" // Max 1399₽ (status: new, updated 13.10.2025)
            }
        }

        // Direct web links to Tribute product pages (fallback without API)
        var tributeWebLink: String {
            switch self {
            case .free:
                return ""
            case .small:
                return "https://web.tribute.tg/p/lDH" // Updated 13.10.2025
            case .medium:
                return "https://web.tribute.tg/p/lDJ" // Updated 13.10.2025
            case .large:
                return "https://web.tribute.tg/p/lDK" // Updated 13.10.2025
            case .max:
                return "https://web.tribute.tg/p/lDL" // Updated 13.10.2025
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


