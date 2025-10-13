import Vapor

/// Форматирование сообщений для бота
struct MessageFormatter {
    
    // MARK: - Welcome Messages
    
    static func welcome(user: User, plan: Constants.SubscriptionPlan, remainingText: Int, remainingPhoto: Int) -> String {
        """
        👋 *Привет, \(user.displayName)!*
        
        Я *КарточкаПРО* — AI-копирайтер для WB/Ozon
        
        📊 *Твой пакет:* \(plan.emoji) \(plan.name)
        Осталось: \(remainingText) текстов + \(remainingPhoto) фото
        
        💡 *Пример что я создаю:*
        
        До: _"Кроссовки мужские белые"_
        После: _"Кроссовки мужские Mizuno Wave белые 46 размер спортивные подошва Мишлен"_
        
        🚀 *Что я делаю:*
        ✅ SEO-заголовки (100 символов)
        ✅ Продающие описания (500 символов)
        ✅ 5 ключевых выгод (bullets)
        ✅ 7 хештегов для поиска
        ✅ Анализ фото товара 📷
        
        💰 *Экономия:* Копирайтер 500₽ → Мы 14₽!
        
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
            • 20 описаний = 14.95₽ за каждое
            • Копирайтер берет 500₽!
            • Экономия: 97%
            """
        } else if remainingText == 0 && isFree {
            return """
            
            😔 *FREE кредиты закончились*
            
            🎉 Тебе понравилось?
            Продолжи с любым пакетом:
            
            📦 Малый: 20 описаний за 299₽
            📦📦 Средний: 50 описаний за 599₽ (популярный!)
            📦📦📦 Большой: 100 за 999₽
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
        
        return """
        💰 *Твой баланс*
        
        📦 *Текущий пакет:* \(plan.emoji) \(plan.name)
        
        📊 *Осталось генераций:*
        \(textLine)
        \(photoLine)
        \(totalLine)
        
        💡 *Цена за генерацию:* \(plan.pricePerGeneration) ₽
        """
    }
    
    // MARK: - Subscriptions
    
    static func subscriptionPlans(currentPlan: Constants.SubscriptionPlan) -> String {
        """
        💎 *ПАКЕТЫ КАРТОЧКАПРО*
        
        Твой текущий: *\(currentPlan.emoji) \(currentPlan.name)*
        
        📦 *МАЛЫЙ* - 299₽
        • 20 описаний (20 текстов + 3 бонус фото)
        • 14.95₽ за описание
        • Для 1-5 товаров/неделя
        
        📦📦 *СРЕДНИЙ* - 599₽
        • 50 описаний (50 текстов + 5 бонус фото)
        • 11.98₽ за описание
        • Для 10-15 товаров/неделя
        
        📦📦📦 *БОЛЬШОЙ* - 999₽
        • 100 описаний (100 текстов + 10 бонус фото)
        • 9.99₽ за описание
        • Для 20-30 товаров/неделя
        
        🎁💎 *МАКСИМАЛЬНЫЙ* - 1,399₽
        • 200 описаний (200 текстов + 20 бонус фото)
        • 6.99₽ за описание
        • Для агентств, 30+ товаров/неделя
        
        ━━━━━━━━━━━━━━━━━━━
        💰 *ТВОЯ ЭКОНОМИЯ:*
        
        Копирайтер: 500₽ за описание
        Малый пакет: 14.95₽ за описание
        
        *Экономия: 97%!*
        
        Пример (Средний пакет):
        ❌ Копирайтер: 50 × 500₽ = 25,000₽
        ✅ КарточкаПРО: 599₽
        💎 *Экономишь: 24,401₽/мес!*
        ━━━━━━━━━━━━━━━━━━━
        
        💳 *Выбери пакет для покупки:*
        
        ❓ Вопросы? \(Constants.Support.username)
        """
    }
    
    static func planDetails(plan: Constants.SubscriptionPlan) -> String {
        """
        💎 *Пакет "\(plan.name)"*
        
        💰 *Цена:* \(plan.price)₽
        
        📦 *Что получишь:*
        \(plan.description)
        
        💡 *Цена за описание:* \(plan.pricePerGeneration) ₽
        
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
        
        📝 Например:
        "\(categoryName) [название модели], характеристики, особенности"
        
        📷 Или отправь фото товара
        """
    }
    
    static func photoLimitExceeded(plan: Constants.SubscriptionPlan) -> String {
        """
        📷 *Лимит фото исчерпан!*
        
        Твой план: *\(plan.emoji) \(plan.name)*
        Осталось фото: *0*
        
        Обнови пакет для большего количества описаний по фото:
        
        📦 Малый (299₽): 20 описаний (3 фото)
        📦📦 Средний (599₽): 50 описаний (5 фото)
        📦📦📦 Большой (999₽): 100 описаний (10 фото)
        🎁💎 Максимальный (1,399₽): 200 описаний (20 фото)
        
        /subscribe - посмотреть все пакеты
        """
    }
}

