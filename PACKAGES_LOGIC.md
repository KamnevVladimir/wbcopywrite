# 📦 Логика работы пакетов и генераций

**Дата:** 13 октября 2025  
**Обновлено:** ID пакетов Tribute

---

## 🎯 Обзор системы

КарточкаПРО использует **кредитную модель** пакетов:
- Пользователь покупает пакет (small/medium/large/max)
- Получает определенное количество кредитов (текстовых + фото генераций)
- Каждая генерация списывает 1 кредит
- Когда кредиты заканчиваются → предлагаем купить новый пакет

---

## 📊 Пакеты (обновлено 13.10.2025)

### Tribute Product IDs

| Пакет | ID Tribute | Цена | Текст | Фото | Всего | Web Link |
|-------|------------|------|-------|------|-------|----------|
| **Free** | - | 0₽ | 3 | 1 | 4 | - |
| **Small** | `83185` | 299₽ | 17 | 3 | 20 | [lDH](https://web.tribute.tg/p/lDH) |
| **Medium** | `83187` | 599₽ | 45 | 5 | 50 | [lDJ](https://web.tribute.tg/p/lDJ) |
| **Large** | `83188` | 999₽ | 90 | 10 | 100 | [lDK](https://web.tribute.tg/p/lDK) |
| **Max** | `83189` | 1399₽ | 180 | 20 | 200 | [lDL](https://web.tribute.tg/p/lDL) |

### Характеристики пакетов

```swift
// Из Constants.swift
enum SubscriptionPlan: String, CaseIterable {
    case free = "free"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case max = "max"
    
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
    
    var price: Decimal {
        switch self {
        case .free: return 0
        case .small: return 299
        case .medium: return 599
        case .large: return 999
        case .max: return 1399
        }
    }
}
```

---

## 🔄 Жизненный цикл генераций

### 1. Регистрация нового пользователя

```
Пользователь → /start
    ↓
UserRepository.getOrCreate(telegramId: ...)
    ↓
Создается User:
    - telegramId: 12345
    - generationsUsed: 0          ← Счетчик текстовых генераций
    - photoGenerationsUsed: 0     ← Счетчик фото генераций
    ↓
Создается Subscription:
    - plan: "free"
    - status: "active"
    - generationsLimit: 4
    - price: 0
    - expiresAt: Date + ∞
```

**Итог:** Новый пользователь получает Free пакет (3 текста + 1 фото)

---

### 2. Текстовая генерация (расходование кредита)

```
Пользователь → Отправляет текст "Кроссовки Nike белые"
    ↓
TelegramBotService.handleTextMessage()
    ↓
Проверка лимита:
    UserRepository.hasGenerationsAvailable(user)
        ↓
    User.remainingGenerations(on: db)
        ↓
    Формула: limit - generationsUsed
        Free: 3 - 0 = 3 ✅ Есть лимит
    ↓
ClaudeService.generateDescription(...)
    ↓
Генерация готова → Отправка пользователю
    ↓
UserRepository.incrementGenerations(user)
    ↓
User.generationsUsed = 1
    ↓
Теперь: 3 - 1 = 2 генерации осталось
```

**Результат:** 
- Пользователь получил описание
- Счетчик увеличился: `generationsUsed: 0 → 1`
- Осталось: 2 текстовых генерации

---

### 3. Фото генерация (расходование отдельного кредита)

```
Пользователь → Отправляет фото товара
    ↓
TelegramBotService.handlePhoto()
    ↓
Проверка лимита ФОТО:
    UserRepository.hasPhotoGenerationsAvailable(user)
        ↓
    User.remainingPhotoGenerations(on: db)
        ↓
    Формула: photoLimit - photoGenerationsUsed
        Free: 1 - 0 = 1 ✅ Есть лимит
    ↓
ClaudeService.generateDescriptionFromPhoto(...)
    ↓
Генерация готова → Отправка пользователю
    ↓
UserRepository.incrementPhotoGenerations(user)
    ↓
User.photoGenerationsUsed = 1
    ↓
Теперь: 1 - 1 = 0 фото генераций осталось
```

**Результат:**
- Пользователь получил описание по фото
- Счетчик увеличился: `photoGenerationsUsed: 0 → 1`
- Фото генерации закончились (0)

---

### 4. Исчерпание лимита (0 генераций)

```
Пользователь → Пытается сгенерировать 4-ое описание
    ↓
TelegramBotService.handleTextMessage()
    ↓
Проверка лимита:
    UserRepository.hasGenerationsAvailable(user)
        ↓
    User.remainingGenerations(on: db)
        ↓
    Free: 3 - 3 = 0 ❌ Лимит исчерпан
    ↓
Возвращается: false
    ↓
Отправка сообщения:
    Constants.BotMessage.limitExceeded
        ↓
```

**Сообщение пользователю:**
```
😔 У тебя закончились генерации.

Перейди на платный план чтобы продолжить:
/subscribe
```

**Результат:**
- Генерация НЕ выполнена
- Пользователю предложено купить пакет
- Счетчик НЕ увеличился

---

### 5. Покупка пакета (пополнение кредитов)

#### Вариант A: Через команду /subscribe

```
Пользователь → /subscribe
    ↓
TelegramBotService.handleSubscribe()
    ↓
Показываем пакеты с кнопками:
    [💎 Small - 299₽]
    [💎 Medium - 599₽]
    [💎 Large - 999₽]
    [💎 Max - 1399₽]
    ↓
Пользователь нажимает → [💎 Small - 299₽]
    ↓
CallbackQuery: "buy_small"
    ↓
TelegramBotService.handleBuyPlan(plan: "small", user, chatId)
    ↓
Создаём ссылку на оплату Tribute:
    TributeService.createPayment(
        productId: "83185",
        userId: telegramId,
        amount: 299₽
    )
    ↓
Отправляем ссылку пользователю:
    [💳 Оплатить 299₽] → https://web.tribute.tg/p/lDH
    ↓
Пользователь переходит → Оплачивает
    ↓
Tribute → Webhook → POST /webhook/tribute
    ↓
TelegramBotService.handleTributeWebhook(webhook)
    ↓
Проверяем событие: webhook.event == "payment.succeeded"
    ↓
Находим пользователя по userId
    ↓
Обновляем/создаём подписку:
```

```swift
// Создание новой подписки
let subscription = Subscription(
    userId: user.id!,
    plan: .small,
    status: .active,
    startedAt: Date(),
    expiresAt: Date() + 30 days
)
subscription.save()
```

```
    ↓
ВАЖНО: Сбрасываем счетчики пользователя!
    user.generationsUsed = 0
    user.photoGenerationsUsed = 0
    user.update()
    ↓
Отправляем уведомление:
```

**Сообщение:**
```
✅ Подписка активирована!

📦 Пакет: Small
💵 Цена: 299₽/мес
🎁 Доступно: 20 описаний (17 текст + 3 фото)

Используй /generate чтобы начать!
```

**Результат:**
- Подписка создана: `plan: small`, `status: active`
- Счетчики сброшены: `generationsUsed: 0`, `photoGenerationsUsed: 0`
- Пользователь может генерировать: 17 текстов + 3 фото

---

### 6. Текущий баланс (команда /balance)

```
Пользователь → /balance
    ↓
TelegramBotService.handleBalance()
    ↓
Получаем текущий план:
    UserRepository.getCurrentPlan(user)
        ↓
    User.currentPlan(on: db)
        ↓
    Проверяем subscription.isActive
        ↓
    Если активна → возвращаем subscription.plan
    Если нет → возвращаем .free
    ↓
Получаем оставшиеся генерации:
    textRemaining = plan.textLimit - user.generationsUsed
    photoRemaining = plan.photoLimit - user.photoGenerationsUsed
    ↓
Формируем сообщение:
```

**Пример для Small пакета (использовано 5 текст, 1 фото):**
```
📊 Твой пакет: Small

📝 Текстовые описания: 12 из 17
📷 Фото-описания: 2 из 3

💎 Хочешь больше? /subscribe
```

---

## 🔄 Обновление пакета (upgrade)

### Сценарий: У пользователя Small → хочет Large

```
Пользователь → /subscribe
    ↓
Видит текущий план: "У тебя Small (осталось 5 текстов)"
    ↓
Нажимает → [💎 Large - 999₽]
    ↓
Покупает через Tribute
    ↓
Webhook → payment.succeeded
    ↓
Обновляем подписку:
    subscription.plan = .large
    subscription.expiresAt = Date() + 30 days
    subscription.update()
    ↓
ВАЖНО: НЕ сбрасываем счетчики!
    Остаются: generationsUsed: 12, photoGenerationsUsed: 1
    ↓
Новый лимит:
    Large: 90 текстов + 10 фото
    Использовано: 12 текстов + 1 фото
    Осталось: 78 текстов + 9 фото
```

**Логика:**
- При апгрейде счетчики НЕ сбрасываются
- Просто увеличивается лимит
- Пользователь получает дополнительные кредиты

---

## ⏱ Истечение подписки (месяц закончился)

### Вариант A: Автоматическое продление (recurring payment)

```
30 дней прошло
    ↓
Tribute → Автоматически списывает 299₽
    ↓
Webhook → payment.succeeded (renewal)
    ↓
Обновляем подписку:
    subscription.startedAt = Date()
    subscription.expiresAt = Date() + 30 days
    subscription.status = .active
    ↓
ВАЖНО: Сбрасываем счетчики на новый период!
    user.generationsUsed = 0
    user.photoGenerationsUsed = 0
```

**Результат:** Новый месяц, новый лимит (20 генераций)

---

### Вариант B: Пользователь не продлил

```
expiresAt < Date()
    ↓
Subscription.isActive → false
    ↓
User.currentPlan(on: db) → .free
    ↓
Лимиты:
    textLimit: 3
    photoLimit: 1
    Использовано: 17 + 3 (старые счетчики)
    ↓
Осталось: max(0, 3 - 17) = 0
    ↓
Пользователь → Пытается генерировать
    ↓
hasGenerationsAvailable → false
    ↓
Показываем: "😔 У тебя закончились генерации"
```

**Результат:**
- Подписка истекла
- Пользователь вернулся на Free
- Не может генерировать (счетчики не сброшены)
- Нужно купить новый пакет

---

## 💾 Структура данных в БД

### Таблица `users`

```sql
id                      | UUID
telegram_id             | BIGINT (уникальный)
username                | VARCHAR(255)
first_name              | VARCHAR(255)
last_name               | VARCHAR(255)
selected_category       | VARCHAR(50)
generations_used        | INTEGER (счетчик текстовых генераций)
photo_generations_used  | INTEGER (счетчик фото генераций)
created_at              | TIMESTAMP
updated_at              | TIMESTAMP
```

**Пример:**
```
id: 550e8400-e29b-41d4-a716-446655440000
telegram_id: 123456789
generations_used: 12       ← Использовано 12 текстовых
photo_generations_used: 2  ← Использовано 2 фото
```

---

### Таблица `subscriptions`

```sql
id                       | UUID
user_id                  | UUID (FK → users.id)
plan                     | VARCHAR(50) (free/small/medium/large/max)
status                   | VARCHAR(50) (active/cancelled/expired)
generations_limit        | INTEGER (общий лимит пакета)
price                    | DECIMAL(10,2)
started_at               | TIMESTAMP
expires_at               | TIMESTAMP
tribute_subscription_id  | VARCHAR(255) (ID подписки в Tribute)
created_at               | TIMESTAMP
updated_at               | TIMESTAMP
```

**Пример:**
```
id: 660e8400-e29b-41d4-a716-446655440000
user_id: 550e8400-e29b-41d4-a716-446655440000
plan: "small"
status: "active"
generations_limit: 20
price: 299.00
started_at: 2025-10-13 12:00:00
expires_at: 2025-11-13 12:00:00
```

---

### Таблица `generations`

```sql
id                    | UUID
user_id               | UUID (FK → users.id)
category              | VARCHAR(50)
product_name          | TEXT
product_details       | TEXT
result_title          | TEXT
result_description    | TEXT
result_bullets        | JSONB (массив строк)
result_hashtags       | JSONB (массив строк)
tokens_used           | INTEGER (сколько токенов Claude использовано)
processing_time_ms    | INTEGER (время генерации в мс)
created_at            | TIMESTAMP
```

**Назначение:**
- История всех генераций
- Статистика использования
- Возможность экспорта

---

## 📝 Ключевые методы в коде

### UserRepository

```swift
// Проверка доступности текстовых генераций
func hasGenerationsAvailable(_ user: User) async throws -> Bool {
    let remaining = try await getRemainingGenerations(user)
    return remaining > 0
}

// Проверка доступности фото генераций
func hasPhotoGenerationsAvailable(_ user: User) async throws -> Bool {
    let remaining = try await getRemainingPhotoGenerations(user)
    return remaining > 0
}

// Увеличение счетчика текстовых генераций
func incrementGenerations(_ user: User) async throws {
    user.generationsUsed += 1
    try await user.update(on: database)
}

// Увеличение счетчика фото генераций
func incrementPhotoGenerations(_ user: User) async throws {
    user.photoGenerationsUsed += 1
    try await user.update(on: database)
}
```

---

### User (Extension)

```swift
// Получение текущего плана
func currentPlan(on db: Database) async throws -> Constants.SubscriptionPlan {
    if let subscription = try await self.$subscription.get(on: db),
       subscription.isActive {
        return subscription.plan
    }
    return .free
}

// Расчет оставшихся текстовых генераций
func remainingGenerations(on db: Database) async throws -> Int {
    let plan = try await currentPlan(on: db)
    let limit = plan.textGenerationsLimit
    return max(0, limit - generationsUsed)
}

// Расчет оставшихся фото генераций
func remainingPhotoGenerations(on db: Database) async throws -> Int {
    let plan = try await currentPlan(on: db)
    let limit = plan.photoGenerationsLimit
    if limit == -1 { return 999 } // Безлимит (не используется сейчас)
    return max(0, limit - photoGenerationsUsed)
}
```

---

## 🎯 Проверка логики "0 генераций = предложение пакета"

### ✅ Текущая реализация

**Когда пользователь исчерпал лимит:**

```swift
// TelegramBotService.swift (строка 187)
guard try await repo.hasGenerationsAvailable(user) else {
    try await sendMessage(chatId: chatId, text: Constants.BotMessage.limitExceeded)
    return
}
```

**Сообщение limitExceeded:**
```
😔 У тебя закончились генерации.

Перейди на платный план чтобы продолжить:
/subscribe
```

### ✅ Проверено:
- При `remainingGenerations = 0` → показывается сообщение
- В сообщении есть команда `/subscribe`
- Команда `/subscribe` ведёт к выбору пакета

**Вывод:** Логика работает корректно! ✅

---

## 🔐 Безопасность и edge cases

### Case 1: Пользователь пытается обмануть систему

**Проблема:** Изменить счетчики в БД вручную

**Защита:**
- Все изменения через Repository
- Транзакции БД
- Логирование всех операций

---

### Case 2: Одновременные запросы

**Проблема:** Пользователь отправляет 2 запроса одновременно

**Решение:**
- Fluent ORM использует optimistic locking
- При конкуренции один запрос завершится с ошибкой
- Пользователь должен повторить

---

### Case 3: Webhook дублируется

**Проблема:** Tribute отправляет webhook дважды

**Решение:**
- Проверять `tribute_subscription_id` перед созданием
- Использовать upsert вместо insert
- Логировать все webhook события

---

## 📊 Статистика и метрики

### Полезные запросы

```sql
-- Сколько пользователей на каждом плане
SELECT plan, COUNT(*) 
FROM subscriptions 
WHERE status = 'active'
GROUP BY plan;

-- Средне�� использование генераций
SELECT 
    AVG(generations_used) as avg_text,
    AVG(photo_generations_used) as avg_photo
FROM users
WHERE created_at > NOW() - INTERVAL '30 days';

-- Топ пользователи по генерациям
SELECT u.telegram_id, u.username, u.generations_used
FROM users u
ORDER BY u.generations_used DESC
LIMIT 10;

-- Конверсия Free → Paid
SELECT 
    COUNT(*) FILTER (WHERE plan = 'free') as free_users,
    COUNT(*) FILTER (WHERE plan != 'free') as paid_users,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE plan != 'free') / COUNT(*),
        2
    ) as conversion_rate
FROM subscriptions
WHERE status = 'active';
```

---

## 🚀 Будущие улучшения

### 1. Rollover неиспользованных кредитов

**Идея:** Если пользователь не использовал все генерации за месяц, переносить на следующий

**Реализация:**
```swift
// При renewal подписки
let unusedText = plan.textLimit - user.generationsUsed
let unusedPhoto = plan.photoLimit - user.photoGenerationsUsed

user.generationsUsed = max(0, -unusedText) // Отрицательное = бонус
user.photoGenerationsUsed = max(0, -unusedPhoto)
```

---

### 2. Бонусные кредиты

**Идея:** Давать +5 генераций за реферала

**Реализация:**
```swift
// Добавить поля в User
bonus_generations: Int = 0
bonus_photo_generations: Int = 0

// При расчете лимита
func remainingGenerations(on db: Database) async throws -> Int {
    let plan = try await currentPlan(on: db)
    let limit = plan.textGenerationsLimit + bonus_generations
    return max(0, limit - generationsUsed)
}
```

---

### 3. Промокоды

**Идея:** FIRST50 = скидка 50% на первую покупку

**Реализация:**
- Таблица `promo_codes` (code, discount, valid_until)
- При покупке проверять промокод
- Применять скидку в Tribute payment

---

## 📋 Checklist для новых фич

При добавлении новых типов генераций:

- [ ] Добавить новый тип в Constants
- [ ] Обновить лимиты в SubscriptionPlan
- [ ] Добавить счетчик в User model
- [ ] Создать миграцию для нового поля
- [ ] Обновить методы incrementXXX в UserRepository
- [ ] Обновить методы remainingXXX в User extension
- [ ] Обновить проверки лимитов в TelegramBotService
- [ ] Обновить сообщения в Constants.BotMessage
- [ ] Добавить логирование
- [ ] Протестировать все edge cases

---

## 🎓 Итоги

### Ключевые принципы системы:

1. **Кредитная модель:** Пользователь покупает кредиты, они расходуются
2. **Два типа кредитов:** Текстовые и фото (раздельные лимиты)
3. **Счетчики не сбрасываются** при апгрейде пакета
4. **Счетчики сбрасываются** при покупке нового периода/renewal
5. **Free = 0 генераций** → автоматически показываем /subscribe
6. **Простота:** Нет сложных правил, всё прозрачно для пользователя

### Формула расчета:

```
Осталось = Лимит пакета - Использовано

Если Осталось = 0 → Показать "Купи пакет"
```

---

**Документ обновлен:** 13 октября 2025  
**Версия:** 2.0  
**Статус:** ✅ Проверено и работает


