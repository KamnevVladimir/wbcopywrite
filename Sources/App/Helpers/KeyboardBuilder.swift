import Vapor

/// Builder для создания Telegram клавиатур
struct KeyboardBuilder {
    
    // MARK: - Category Keyboards
    
    /// Создать клавиатуру выбора категории (включая последние и "Своя категория")
    static func createCategoryKeyboard(recentCategories: [String] = []) -> TelegramReplyMarkup {
        var rows: [[TelegramInlineKeyboardButton]] = []
        
        // Если есть последние категории - показываем их первым рядом с emoji ⚡️
        if !recentCategories.isEmpty {
            var recentRow: [TelegramInlineKeyboardButton] = []
            
            for categoryRaw in recentCategories.prefix(2) {
                if let category = Constants.ProductCategory(rawValue: categoryRaw) {
                    let button = TelegramInlineKeyboardButton(
                        text: "⚡️ \(category.name)",
                        callbackData: "quick_generate_\(category.rawValue)"
                    )
                    recentRow.append(button)
                }
            }
            
            if !recentRow.isEmpty {
                rows.append(recentRow)
            }
        }
        
        // Фильтруем .other (его заменяет "Своя категория")
        let categories = Constants.ProductCategory.allCases.filter { $0 != .other }
        
        var currentRow: [TelegramInlineKeyboardButton] = []
        
        // Стандартные категории по 2 в ряд
        for category in categories {
            let button = TelegramInlineKeyboardButton(
                text: category.displayName,
                callbackData: "category_\(category.rawValue)"
            )
            currentRow.append(button)
            
            if currentRow.count == 2 {
                rows.append(currentRow)
                currentRow = []
            }
        }
        
        // Добавить остаток
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        // Кнопка "Своя категория" отдельным рядом
        rows.append([
            TelegramInlineKeyboardButton(
                text: "✏️ Своя категория",
                callbackData: "custom_category"
            )
        ])
        
        return TelegramReplyMarkup(inlineKeyboard: rows)
    }
    
    // MARK: - Action Keyboards
    
    /// Создать клавиатуру действий после генерации
    static func createPostGenerationKeyboard(
        category: Constants.ProductCategory?,
        remainingText: Int,
        remainingPhoto: Int
    ) -> TelegramReplyMarkup {
        var buttons: [[TelegramInlineKeyboardButton]] = []
        
        // РЯД 1: Quick Repeat (если есть категория)
        if let category = category {
            buttons.append([
                TelegramInlineKeyboardButton(
                    text: "🔄 Ещё \(category.emoji) \(category.name)",
                    callbackData: "quick_generate_\(category.rawValue)"
                )
            ])
        }
        
        // РЯД 2: Улучшить + Копировать
        buttons.append([
            TelegramInlineKeyboardButton(text: "✨ Улучшить", callbackData: "improve_last"),
            TelegramInlineKeyboardButton(text: "📋 Копировать", callbackData: "copy_menu")
        ])
        
        // РЯД 3: Навигация
        buttons.append([
            TelegramInlineKeyboardButton(text: "🔄 Другая", callbackData: "new_generation"),
            TelegramInlineKeyboardButton(text: "💰 Баланс", callbackData: "my_balance")
        ])
        
        // РЯД 4: Экспорт + Покупка (приоритизация если мало кредитов)
        if remainingText + remainingPhoto <= 5 {
            // Мало кредитов - выделяем покупку
            buttons.append([
                TelegramInlineKeyboardButton(text: "💎 КУПИТЬ ПАКЕТ", callbackData: "view_packages")
            ])
            buttons.append([
                TelegramInlineKeyboardButton(text: "📄 Экспорт", callbackData: "export_last")
            ])
        } else {
            // Нормально кредитов - обычная раскладка
            buttons.append([
                TelegramInlineKeyboardButton(text: "📄 Экспорт", callbackData: "export_last"),
                TelegramInlineKeyboardButton(text: "💎 Пакеты", callbackData: "view_packages")
            ])
        }
        
        return TelegramReplyMarkup(inlineKeyboard: buttons)
    }
    
    // MARK: - Payment Keyboards
    
    /// Создать клавиатуру выбора пакета для покупки
    static func createPaymentKeyboard() -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [
            [TelegramInlineKeyboardButton(text: "📦 Малый 299₽", callbackData: "buy_small")],
            [TelegramInlineKeyboardButton(text: "📦📦 Средний 599₽", callbackData: "buy_medium")],
            [TelegramInlineKeyboardButton(text: "📦📦📦 Большой 999₽", callbackData: "buy_large")],
            [TelegramInlineKeyboardButton(text: "🎁💎 Максимальный 1,399₽", callbackData: "buy_max")],
            [TelegramInlineKeyboardButton(text: "🏠 На главную", callbackData: "back_to_main")]
        ])
    }
    
    /// Создать клавиатуру для конкретного пакета
    static func createPlanPurchaseKeyboard(plan: Constants.SubscriptionPlan, paymentUrl: String) -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [
            [TelegramInlineKeyboardButton(text: "💳 Оплатить \(plan.price)₽", url: paymentUrl)],
            [TelegramInlineKeyboardButton(text: "« Назад к пакетам", callbackData: "view_packages")]
        ])
    }
    
    // MARK: - Balance Keyboard
    
    /// Создать клавиатуру для баланса
    static func createBalanceKeyboard() -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [
            [TelegramInlineKeyboardButton(text: "💎 Купить пакет", callbackData: "view_packages")],
            [TelegramInlineKeyboardButton(text: "🔄 Новая генерация", callbackData: "new_generation")],
            [TelegramInlineKeyboardButton(text: "🏠 На главную", callbackData: "back_to_main")]
        ])
    }
    
    // MARK: - Export Keyboards
    
    /// Создать клавиатуру выбора формата экспорта
    static func createExportFormatKeyboard() -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [
            [
                TelegramInlineKeyboardButton(text: "📊 CSV (.csv)", callbackData: "export_excel"),
                TelegramInlineKeyboardButton(text: "📄 Текст (.txt)", callbackData: "export_txt")
            ],
            [TelegramInlineKeyboardButton(text: "« Назад", callbackData: "back_to_main")]
        ])
    }
    
    // MARK: - Copy Parts Keyboard
    
    /// Создать клавиатуру для копирования по частям
    static func createCopyPartsKeyboard() -> TelegramReplyMarkup {
        TelegramReplyMarkup(inlineKeyboard: [
            [
                TelegramInlineKeyboardButton(text: "📝 Заголовок", callbackData: "copy_title"),
                TelegramInlineKeyboardButton(text: "📄 Описание", callbackData: "copy_description")
            ],
            [
                TelegramInlineKeyboardButton(text: "🎯 Выгоды", callbackData: "copy_bullets"),
                TelegramInlineKeyboardButton(text: "🏷 Хештеги", callbackData: "copy_hashtags")
            ],
            [
                TelegramInlineKeyboardButton(text: "📋 Всё сразу", callbackData: "copy_all")
            ],
            [TelegramInlineKeyboardButton(text: "« Назад", callbackData: "back_to_main")]
        ])
    }
    
    // MARK: - History Keyboard
    
    /// Создать клавиатуру пагинации для истории
    static func createHistoryPaginationKeyboard(
        offset: Int,
        limit: Int,
        totalCount: Int
    ) -> TelegramReplyMarkup {
        var buttons: [[TelegramInlineKeyboardButton]] = []
        
        // Кнопки навигации
        var navButtons: [TelegramInlineKeyboardButton] = []
        
        if offset > 0 {
            navButtons.append(
                TelegramInlineKeyboardButton(
                    text: "⬅️ Назад",
                    callbackData: "history_\(max(0, offset - limit))_\(limit)"
                )
            )
        }
        
        if offset + limit < totalCount {
            navButtons.append(
                TelegramInlineKeyboardButton(
                    text: "➡️ Далее",
                    callbackData: "history_\(offset + limit)_\(limit)"
                )
            )
        }
        
        if !navButtons.isEmpty {
            buttons.append(navButtons)
        }
        
        // Кнопка экспорта всех
        buttons.append([
            TelegramInlineKeyboardButton(text: "📊 Экспорт всех в Excel", callbackData: "export_all_excel")
        ])
        
        // Кнопка возврата на главную
        buttons.append([
            TelegramInlineKeyboardButton(text: "🏠 На главную", callbackData: "back_to_main")
        ])
        
        return TelegramReplyMarkup(inlineKeyboard: buttons)
    }
}

