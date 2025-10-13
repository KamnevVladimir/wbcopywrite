# Интеграция Tribute для оплаты

## Что нужно

1. Зарегистрироваться на https://tribute.to
2. Получить API ключ и Secret
3. Создать продукты (пакеты подписок)

## Настройка

### 1. Environment Variables

Добавь в `.env`:

```bash
TRIBUTE_API_KEY=your_api_key_here
TRIBUTE_SECRET=your_secret_here
TRIBUTE_API_URL=https://api.tribute.to/v1
```

### 2. Создание продуктов в Tribute

Создай 4 продукта в Tribute Dashboard:

- **Small**: 299₽/мес (20 описаний)
- **Medium**: 499₽/мес (50 описаний)
- **Large**: 799₽/мес (100 описаний)
- **Max**: 1299₽/мес (200 описаний)

Сохрани Product IDs.

### 3. Обновление кода

В `Constants.swift` добавь Tribute Product IDs:

```swift
enum SubscriptionPlan {
    // ...
    
    var tributeProductId: String {
        switch self {
        case .free: return ""
        case .small: return "prod_xxx"
        case .medium: return "prod_xxx"
        case .large: return "prod_xxx"
        case .max: return "prod_xxx"
        }
    }
}
```

### 4. Реализация `handleBuyPlan`

```swift
private func handleBuyPlan(plan: String, user: User, chatId: Int64) async throws {
    guard let subscriptionPlan = Constants.SubscriptionPlan(rawValue: plan) else {
        try await sendMessage(chatId: chatId, text: "❌ Неизвестный пакет")
        return
    }
    
    // Создаём платежную ссылку через Tribute API
    let paymentUrl = try await createTributePayment(
        userId: user.telegramId,
        productId: subscriptionPlan.tributeProductId,
        amount: subscriptionPlan.price
    )
    
    let buyText = """
    💎 *Покупка пакета \(subscriptionPlan.name)*
    
    💵 Стоимость: \(subscriptionPlan.price)₽/мес
    📦 Включено: \(subscriptionPlan.description)
    
    👇 Нажми кнопку для оплаты:
    """
    
    let keyboard = TelegramReplyMarkup(inlineKeyboard: [[
        TelegramInlineKeyboardButton(text: "💳 Оплатить \(subscriptionPlan.price)₽", url: paymentUrl)
    ]])
    
    try await sendMessage(chatId: chatId, text: buyText, replyMarkup: keyboard)
}

private func createTributePayment(userId: Int64, productId: String, amount: Decimal) async throws -> String {
    let tributeUrl = app.environmentConfig.tributeApiUrl
    let apiKey = app.environmentConfig.tributeApiKey
    
    struct CreatePaymentRequest: Content {
        let productId: String
        let userId: String
        let successUrl: String
        let cancelUrl: String
        
        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case userId = "user_id"
            case successUrl = "success_url"
            case cancelUrl = "cancel_url"
        }
    }
    
    struct CreatePaymentResponse: Content {
        let paymentUrl: String
        
        enum CodingKeys: String, CodingKey {
            case paymentUrl = "payment_url"
        }
    }
    
    let request = CreatePaymentRequest(
        productId: productId,
        userId: String(userId),
        successUrl: "https://t.me/kartochka_pro_bot?start=payment_success",
        cancelUrl: "https://t.me/kartochka_pro_bot?start=payment_cancel"
    )
    
    let response = try await app.client.post(URI(string: "\(tributeUrl)/payments")) { req in
        req.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        try req.content.encode(request)
    }
    
    let paymentResponse = try response.content.decode(CreatePaymentResponse.self)
    return paymentResponse.paymentUrl
}
```

### 5. Webhook для подтверждения оплаты

Добавь эндпоинт в `routes.swift`:

```swift
app.post("webhook", "tribute") { req async throws -> HTTPStatus in
    let webhook = try req.content.decode(TributeWebhook.self)
    
    // Проверка подписи
    guard isValidTributeSignature(req) else {
        throw Abort(.unauthorized)
    }
    
    // Обработка успешной оплаты
    if webhook.event == "payment.succeeded" {
        let userId = Int64(webhook.userId) ?? 0
        let productId = webhook.productId
        
        // Находим пользователя
        let user = try await User.query(on: req.db)
            .filter(\.$telegramId == userId)
            .first()
        
        guard let user = user else {
            throw Abort(.notFound)
        }
        
        // Создаём/обновляем подписку
        let plan = Constants.SubscriptionPlan.allCases.first { $0.tributeProductId == productId }
        
        if let plan = plan {
            let subscription = Subscription(
                userId: user.id!,
                plan: plan,
                status: .active,
                startedAt: Date(),
                expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date())
            )
            try await subscription.save(on: req.db)
            
            // Уведомляем пользователя
            try await req.application.telegram.sendMessage(
                chatId: userId,
                text: """
                ✅ *Подписка активирована!*
                
                📦 Пакет: \(plan.name)
                💵 Цена: \(plan.price)₽/мес
                🎁 Доступно: \(plan.totalGenerationsLimit) описаний
                
                Используй /generate чтобы начать!
                """
            )
        }
    }
    
    return .ok
}
```

## Тестирование

1. Используй Tribute Test Mode для тестирования
2. Проверь webhook endpoint доступен извне (используй ngrok для локальной разработки)
3. Протестируй весь flow: выбор пакета → оплата → активация подписки

## Production Checklist

- [ ] Добавлены реальные Tribute ключи
- [ ] Созданы продукты в Tribute
- [ ] Webhook endpoint доступен и защищен
- [ ] Проверка подписи webhook
- [ ] Обработка всех событий (success, cancel, refund)
- [ ] Логирование всех платежей
- [ ] Уведомления пользователю
- [ ] Обработка ошибок

## Альтернативы

Если Tribute не подходит, можно использовать:

- **ЮKassa** (Яндекс.Касса)
- **CloudPayments**
- **Stripe** (для международных платежей)
- **Telegram Stars** (встроенные платежи Telegram)

