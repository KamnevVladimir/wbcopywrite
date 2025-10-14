import Vapor

/// Форматирование сообщений для бота
struct MessageFormatter {
    
    // MARK: - Welcome Messages
    
    static func welcome(user: User, plan: Constants.SubscriptionPlan, remainingText: Int, remainingPhoto: Int) -> String {
        let pricePerItem = String(format: "%.1f", Double(truncating: plan.pricePerGeneration as NSNumber))
        
        return """
        👋 *Привет, \(user.displayName)!*
        
        Я *КарточкаПРО* — AI-копирайтер для WB/Ozon
        
        📊 *Твой пакет:* \(plan.emoji) \(plan.name)
        Осталось: \(remainingText) текстов + \(remainingPhoto) фото
        
        💡 *Что я создаю:*
        
        Ты: _"Кроссовки женские"_
        
        Я:
        📝 Заголовок (SEO): _"Кроссовки женские спортивные белые легкие дышащие размер 36-41"_
        📄 Описание: _"Стильные кроссовки для активного образа жизни..."_
        🎯 5 выгод + 7 хештегов
        
        🚀 *Мои возможности:*
        ✅ SEO-заголовки (до 100 символов)
        ✅ Продающие описания (до 1000 символов)
        ✅ 5 ключевых выгод (bullets)
        ✅ 7 хештегов для поиска
        ✅ Анализ фото товара 📷
        
        💰 *Экономия:* Копирайтер 300₽ → Мы \(pricePerItem)₽!
        
        Подсказка:
        
        💡 Можно сразу прислать текст с названием/кратким описанием товара — я спрошу подтверждение и начну генерацию. Также можно отправить фото товара 📷.
        
        Команды: /generate — новое описание, /help — помощь, /price — тарифы
        
        Выбери категорию товара:
        """
    }
    
    // MARK: - Generation Results
    
    static func generationResult(
        title: String,
        description: String,
        bullets: [String],
        hashtags: [String],
        remainingText: Int,
        remainingPhoto: Int,
        nudge: String
    ) -> (part1: String, part2: String, part3: String) {
        let message1 = """
        ✅ *Готово!*
        
        📝 *ЗАГОЛОВОК:*
        \(title)
        
        📄 *ОПИСАНИЕ:*
        \(description)
        """
        
        let bulletsText = bullets.map { "• \($0)" }.joined(separator: "\n")
        let message2 = """
        🎯 *КЛЮЧЕВЫЕ ВЫГОДЫ:*
        
        \(bulletsText)
        """
        
        let hashtagsText = hashtags.joined(separator: " ")
        let message3 = """
        🏷 *ХЕШТЕГИ:*
        \(hashtagsText)
        
        ━━━━━━━━━━━━━━━━━━━
        ⚡️ *Осталось:* \(remainingText) текстов + \(remainingPhoto) фото\(nudge)
        """
        
        return (message1, message2, message3)
    }
    
    // MARK: - Smart Nudges
    
    static func smartNudge(remainingText: Int, remainingPhoto: Int, isFree: Bool) -> String {
        if remainingText == 1 && isFree {
            return """
            
            ⚠️ *Остался последний FREE кредит!*
            
            💡 В пакете "Малый" (299₽):
            • 23 описания (20 текстов + 3 фото)
            • 13.0₽ за каждое описание
            • Копирайтер берет 300₽!
            • Экономия: 95%
            """
        } else if remainingText == 0 && isFree {
            return """
            
            😔 *FREE кредиты закончились*
            
            🎉 Тебе понравилось?
            Продолжи с любым пакетом:
            
            📦 Малый: 20 текстов + 3 фото за 299₽
            📦📦 Средний: 50 текстов + 5 фото за 599₽ (популярный!)
            📦📦📦 Большой: 100 текстов + 10 фото за 999₽
            """
        } else if remainingText + remainingPhoto <= 5 && !isFree {
            return """
            
            ⚠️ *Скоро закончатся кредиты!*
            Успей докупить пакет 💎
            """
        }
        
        return ""
    }
    
    // MARK: - Balance
    
    static func balance(
        plan: Constants.SubscriptionPlan,
        remainingText: Int,
        remainingPhoto: Int,
        hasTextCredits: Bool,
        hasPhotoCredits: Bool
    ) -> String {
        let textLine = hasTextCredits 
            ? "• Текстовые кредиты: \(remainingText)"
            : "• Текстовых: \(remainingText) из \(plan.textGenerationsLimit)"
        
        let photoLine = hasPhotoCredits
            ? "• Фото кредиты: \(remainingPhoto)"
            : "• С фото: \(remainingPhoto) из \(plan.photoGenerationsLimit)"
        
        let totalLine = (hasTextCredits || hasPhotoCredits)
            ? "• Итого кредитов: \(remainingText + remainingPhoto)"
            : "• Всего: \(remainingText + remainingPhoto) из \(plan.totalGenerationsLimit)"
        
        let pricePerItem = String(format: "%.1f", Double(truncating: plan.pricePerGeneration as NSNumber))
        
        return """
        💰 *Твой баланс*
        
        📦 *Текущий пакет:* \(plan.emoji) \(plan.name)
        
        📊 *Осталось генераций:*
        \(textLine)
        \(photoLine)
        \(totalLine)
        
        💡 *Цена за описание:* \(pricePerItem)₽
        """
    }
    
    // MARK: - Subscriptions
    
    static func subscriptionPlans(currentPlan: Constants.SubscriptionPlan) -> String {
        """
        💎 *ПАКЕТЫ КАРТОЧКАПРО*
        
        Твой текущий: *\(currentPlan.emoji) \(currentPlan.name)*
        
        📦 *МАЛЫЙ* - 299₽
        • 20 текстов + 3 бонус фото
        • 13.0₽ за описание
        • Для 5-10 товаров
        
        📦📦 *СРЕДНИЙ* - 599₽ ⭐️
        • 50 текстов + 5 бонус фото
        • 10.9₽ за описание
        • Для 15-25 товаров
        
        📦📦📦 *БОЛЬШОЙ* - 999₽
        • 100 текстов + 10 бонус фото
        • 9.1₽ за описание
        • Для 30-50 товаров
        
        🎁💎 *МАКСИМАЛЬНЫЙ* - 1,399₽
        • 200 текстов + 20 бонус фото
        • 6.4₽ за описание
        • Для агентств и 50+ товаров
        
        ━━━━━━━━━━━━━━━━━━━
        💰 *ТВОЯ ЭКОНОМИЯ:*
        
        Копирайтер: 300₽ за описание
        КарточкаПРО: от 6.4₽ до 13₽
        
        *Экономия: до 95%!*
        
        Пример (Средний пакет):
        ❌ Копирайтер: 55 × 300₽ = 16,500₽
        ✅ КарточкаПРО: 599₽
        💎 *Экономишь: 15,901₽!*
        ━━━━━━━━━━━━━━━━━━━
        
        💳 *Выбери пакет для покупки:*
        
        ❓ Вопросы? \(Constants.Support.username)
        """
    }
    
    static func planDetails(plan: Constants.SubscriptionPlan) -> String {
        let pricePerItem = String(format: "%.1f", Double(truncating: plan.pricePerGeneration as NSNumber))
        
        return """
        💎 *Пакет "\(plan.name)"*
        
        💰 *Цена:* \(plan.price)₽
        
        📦 *Что получишь:*
        \(plan.description)
        
        💡 *Цена за описание:* \(pricePerItem)₽
        
        ━━━━━━━━━━━━━━━━━━━
        
        💳 Нажми кнопку ниже для оплаты
        
        После успешной оплаты кредиты будут начислены автоматически! ✅
        """
    }
    
    // MARK: - Errors & Info
    
    static func categorySelected(_ category: Constants.ProductCategory) -> String {
        """
        ✅ Категория выбрана: \(category.displayName)
        
        \(Constants.BotMessage.enterProductInfo)
        """
    }
    
    static func customCategoryPrompt() -> String {
        """
        ✏️ *Своя категория*
        
        Напиши название категории товара:
        
        📝 *Примеры:*
        • Книги и журналы
        • Автозапчасти
        • Зоотовары
        • Детские игрушки
        • Садовый инвентарь
        • Строительные материалы
        • Музыкальные инструменты
        
        Или /cancel для отмены
        """
    }
    
    static func customCategoryAccepted(_ categoryName: String) -> String {
        """
        ✅ Категория: *\(categoryName)*
        
        Отлично! Теперь опиши товар:
        
        📝 *Примеры:*
        
        Простой: _"\(categoryName) название модели"_
        Детальный: _"\(categoryName) модель цвет размер материал"_
        
        💡 Или просто отправь фото — я сам всё опишу!
        """
    }
    
    static func photoLimitExceeded(plan: Constants.SubscriptionPlan) -> String {
        """
        📷 *Лимит фото исчерпан!*
        
        Твой план: *\(plan.emoji) \(plan.name)*
        Осталось фото: *0*
        
        Обнови пакет для большего количества фото:
        
        📦 Малый (299₽): 20 текстов + 3 фото
        📦📦 Средний (599₽): 50 текстов + 5 фото
        📦📦📦 Большой (999₽): 100 текстов + 10 фото
        🎁💎 Максимальный (1,399₽): 200 текстов + 20 фото
        
        /subscribe - посмотреть все пакеты
        """
    }
}

