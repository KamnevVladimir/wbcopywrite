# 💳 Tribute Integration - Полная документация

## 📋 Оглавление
1. [Что такое Tribute](#что-такое-tribute)
2. [Как работает процесс оплаты](#как-работает-процесс-оплаты)
3. [Архитектура интеграции](#архитектура-интеграции)
4. [Настройка Tribute](#настройка-tribute)
5. [API Endpoints](#api-endpoints)
6. [Вебхуки](#вебхуки)
7. [Тестирование](#тестирование)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Что такое Tribute

**Tribute** — российская платежная система для приема платежей через Telegram.

**Ключевые особенности:**
- ✅ Работает через Telegram (нет редиректов на внешние сайты)
- ✅ Низкая комиссия (2.8%)
- ✅ Быстрая интеграция
- ✅ Вебхуки о статусе платежа
- ✅ Поддержка подписок и разовых платежей

**Альтернативы:**
- ЮKassa (3.5% комиссия)
- CloudPayments
- Robokassa

---

## 🔄 Как работает процесс оплаты

### Шаг 1: Пользователь нажимает "Купить"

```
Telegram Bot → Пользователь выбирает /subscribe
             → Видит список пакетов
             → Нажимает "📦 Малый 299₽"
```

### Шаг 2: Бот создает ссылку на оплату

```swift
// TributeService.createPaymentLink()
https://web.tribute.tg/p/lDH?user_id=123456789&return_url=https://t.me/kartochka_pro
```

**Параметры:**
- `user_id` — Telegram ID пользователя (для идентификации после оплаты)
- `return_url` — Куда вернуть пользователя после оплаты

### Шаг 3: Пользователь оплачивает

```
Telegram → Открывается Mini App Tribute
         → Форма оплаты (карта/СБП)
         → Пользователь оплачивает 299₽
```

### Шаг 4: Tribute отправляет вебхук

```json
POST https://your-server.railway.app/api/tribute/webhook
{
  "id": "evt_12345",
  "type": "payment.succeeded",
  "data": {
    "payment_id": "pay_67890",
    "subscription_id": "83185",  // Product ID
    "user_id": "123456789",       // Telegram ID
    "amount": 29900,              // в копейках
    "currency": "RUB",
    "status": "succeeded",
    "description": "Пакет Small"
  },
  "created_at": "2025-10-13T12:00:00Z"
}
```

### Шаг 5: Сервер начисляет кредиты

```swift
// TributeService.handleWebhook()
1. Проверить подпись вебхука (HMAC-SHA256)
2. Найти пользователя по user_id
3. Определить пакет по subscription_id или description
4. Начислить кредиты:
   user.textCredits += 20
   user.photoCredits += 3
5. Отправить уведомление в Telegram
```

### Шаг 6: Пользователь получает уведомление

```
✅ Оплата прошла успешно!

📦 Пакет: 📦 Малый
💰 Сумма: 299 ₽

🎉 Начислено кредитов:
• Текстовые: +20
• С фото: +3

Теперь ты можешь создавать описания товаров!
```

---

## 🏗️ Архитектура интеграции

### Файлы проекта

```
WBCopywriterBot/
├── Sources/App/
│   ├── Services/
│   │   └── TributeService.swift          # 💳 Основная логика
│   ├── Models/DTOs/
│   │   └── TributeWebhook.swift          # 📦 Модели вебхука
│   ├── Config/
│   │   └── Constants.swift               # 🔧 Product IDs
│   └── routes.swift                      # 🛣️ API endpoints
```

### Компоненты

#### 1. **TributeService** (`Services/TributeService.swift`)

```swift
class TributeService {
    // Создать ссылку на оплату
    func createPaymentLink(plan:, telegramId:) -> String
    
    // Обработать вебхук от Tribute
    func handleWebhook(_ event:, on req:) async throws
    
    // Проверить подпись вебхука
    func verifyWebhookSignature(payload:, signature:) -> Bool
}
```

#### 2. **API Endpoints** (`routes.swift`)

```swift
// Создание платежа
POST /api/tribute/create-payment
{
  "plan": "small",
  "telegramUserId": 123456789
}
→ 
{
  "paymentUrl": "https://web.tribute.tg/p/lDH?user_id=...",
  "plan": "Малый",
  "amount": 299
}

// Вебхук от Tribute
POST /api/tribute/webhook
→ HTTPStatus.ok
```

#### 3. **Constants** (`Config/Constants.swift`)

```swift
enum SubscriptionPlan {
    case small, medium, large, max
    
    var tributeProductId: String {
        case .small: return "83185"  // Product ID из Tribute
        case .medium: return "83187"
        ...
    }
    
    var tributeWebLink: String {
        case .small: return "https://web.tribute.tg/p/lDH"
        ...
    }
}
```

---

## ⚙️ Настройка Tribute

### Шаг 1: Регистрация продавца

1. Открой https://tribute.to/
2. Нажми "Стать продавцом"
3. Заполни профиль:
   - **Тип:** Самозанятый (проще чем ИП)
   - **ИНН:** Твой ИНН самозанятого
   - **Контакты:** Телефон, email
4. Подключи карту для выплат
5. Загрузи паспорт для верификации
6. Жди подтверждения (1-2 дня)

### Шаг 2: Создание продуктов

После верификации:

1. **Dashboard** → **Продукты** → **Создать продукт**

2. **Для пакета "Малый":**
   ```
   Название: Пакет Small
   Цена: 299₽
   Тип: Разовый платеж
   Описание: 20 описаний товаров для WildBerries/Ozon
   ```

3. **Скопируй Product ID** (например: `83185`)

4. **Скопируй Web Link** (например: `https://web.tribute.tg/p/lDH`)

5. **Повтори для всех пакетов:**
   - Medium (599₽)
   - Large (999₽)
   - Max (1,399₽)

### Шаг 3: Получение API ключей

1. **Dashboard** → **Настройки** → **API**
2. **Создать API Key**
3. **Скопируй:**
   - `API Key` → в `.env` как `TRIBUTE_API_KEY`
   - `API Secret` → в `.env` как `TRIBUTE_SECRET`

### Шаг 4: Настройка вебхуков

1. **Dashboard** → **Настройки** → **Вебхуки**
2. **Добавить вебхук:**
   ```
   URL: https://your-app.railway.app/api/tribute/webhook
   События: payment.succeeded
   ```

### Шаг 5: Обновление констант

Обнови `Sources/App/Config/Constants.swift`:

```swift
case .small:
    return "83185" // Product ID из Tribute (твой реальный)

var tributeWebLink: String {
    case .small:
        return "https://web.tribute.tg/p/lDH" // Твоя реальная ссылка
}
```

---

## 🛣️ API Endpoints

### POST /api/tribute/create-payment

**Описание:** Создать ссылку на оплату для пользователя

**Request:**
```json
{
  "plan": "small",           // small | medium | large | max
  "telegramUserId": 123456789
}
```

**Response:**
```json
{
  "paymentUrl": "https://web.tribute.tg/p/lDH?user_id=123456789&return_url=...",
  "plan": "Малый",
  "amount": 299
}
```

**Errors:**
- `400 Bad Request` — Неизвестный план или Free
- `503 Service Unavailable` — Пакет временно недоступен

---

### POST /api/tribute/webhook

**Описание:** Вебхук для получения уведомлений о платежах

**Headers:**
```
X-Tribute-Signature: <HMAC-SHA256 подпись>
Content-Type: application/json
```

**Request Body:**
```json
{
  "id": "evt_12345",
  "type": "payment.succeeded",
  "data": {
    "payment_id": "pay_67890",
    "subscription_id": "83185",
    "user_id": "123456789",
    "amount": 29900,
    "currency": "RUB",
    "status": "succeeded",
    "description": "Пакет Small"
  },
  "created_at": "2025-10-13T12:00:00Z"
}
```

**Response:**
```
200 OK
```

**Обработка:**
1. Проверка подписи (HMAC-SHA256)
2. Декодирование события
3. Определение плана по `subscription_id` или `description`
4. Начисление кредитов пользователю
5. Отправка уведомления в Telegram

**Errors:**
- `400 Bad Request` — Пустое тело или некорректный JSON
- `401 Unauthorized` — Неверная подпись
- `404 Not Found` — Пользователь не найден

---

## 📨 Вебхуки

### Типы событий

```swift
enum EventType: String {
    case paymentSucceeded = "payment.succeeded"    // ✅ Оплата прошла
    case paymentFailed = "payment.failed"          // ❌ Оплата не прошла
    case subscriptionCreated = "subscription.created"
    case subscriptionCancelled = "subscription.cancelled"
    case subscriptionRenewed = "subscription.renewed"
}
```

### Верификация подписи

```swift
func verifyWebhookSignature(payload: Data, signature: String) -> Bool {
    let key = SymmetricKey(data: Data(apiSecret.utf8))
    let hmac = HMAC<SHA256>.authenticationCode(
        for: Data(payloadString.utf8),
        using: key
    )
    let computedSignature = Data(hmac).base64EncodedString()
    return computedSignature == signature
}
```

### Идемпотентность

**Проблема:** Tribute может отправить один вебхук несколько раз

**Решение:** Сохранять `event.id` в БД и пропускать дубликаты

```swift
// TODO: Добавить в будущем
let isDuplicate = try await processedWebhooks.contains(event.id)
if isDuplicate {
    return .ok // Уже обработан
}
```

---

## 🧪 Тестирование

### Локальное тестирование

1. **Запусти ngrok:**
   ```bash
   ngrok http 8080
   ```

2. **Скопируй HTTPS URL:**
   ```
   https://abc123.ngrok.io
   ```

3. **Настрой вебхук в Tribute:**
   ```
   https://abc123.ngrok.io/api/tribute/webhook
   ```

4. **Сделай тестовый платеж**

5. **Проверь логи:**
   ```bash
   swift run App serve
   ```

### Симуляция вебхука

```bash
curl -X POST http://localhost:8080/api/tribute/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "id": "evt_test_123",
    "type": "payment.succeeded",
    "data": {
      "payment_id": "pay_test_456",
      "subscription_id": "83185",
      "user_id": "123456789",
      "amount": 29900,
      "currency": "RUB",
      "status": "succeeded",
      "description": "Пакет Small"
    },
    "created_at": "2025-10-13T12:00:00Z"
  }'
```

### Проверка начисления кредитов

```sql
-- Подключись к Railway PostgreSQL
SELECT telegram_id, text_credits, photo_credits 
FROM users 
WHERE telegram_id = 123456789;
```

---

## 🐛 Troubleshooting

### Проблема: Вебхук не приходит

**Причины:**
- ❌ URL вебхука некорректный
- ❌ Сервер недоступен (Railway down)
- ❌ Вебхук не настроен в Tribute

**Решение:**
1. Проверь URL: https://your-app.railway.app/api/tribute/webhook
2. Проверь логи Railway: `railway logs`
3. Проверь настройки Tribute Dashboard
4. Попробуй ручной тест: `curl -X POST ...`

---

### Проблема: Invalid signature

**Причины:**
- ❌ Неверный `TRIBUTE_SECRET` в `.env`
- ❌ Tribute не отправляет подпись в header

**Решение:**
1. Проверь `.env`: `TRIBUTE_SECRET=...`
2. Проверь header: `X-Tribute-Signature`
3. Временно отключи проверку для теста (опасно!)

---

### Проблема: Кредиты не начисляются

**Причины:**
- ❌ Неверный `subscription_id` в Constants
- ❌ Пользователь не найден по `user_id`
- ❌ План не определен

**Решение:**
1. Проверь логи: "Cannot identify plan from webhook"
2. Проверь `subscription_id` в Constants
3. Проверь что `user_id` = Telegram ID

---

### Проблема: Payment link не работает

**Причины:**
- ❌ Неверный `tributeWebLink` в Constants
- ❌ Product не активен в Tribute
- ❌ Product удален

**Решение:**
1. Проверь ссылку в браузере
2. Проверь Tribute Dashboard → Продукты
3. Создай новый продукт если нужно

---

## 📊 Monitoring & Analytics

### Логи которые важно смотреть

```bash
railway logs --filter "tribute"
```

**Ключевые события:**
```
✅ TributeService configured
💳 Payment link created: https://...
💰 Tribute webhook: type=payment.succeeded userId=123456789
✅ Payment processed: user=123456789 plan=Малый amount=299₽
```

### Метрики для отслеживания

1. **Конверсия:**
   ```
   Платежей / Кликов на "Купить" × 100%
   ```

2. **Средний чек:**
   ```
   Общая сумма / Количество платежей
   ```

3. **Popular план:**
   ```sql
   SELECT description, COUNT(*) as count
   FROM tribute_events
   WHERE type = 'payment.succeeded'
   GROUP BY description
   ORDER BY count DESC;
   ```

---

## 🎓 Best Practices

### 1. Обработка ошибок
✅ Всегда логируй ошибки с контекстом
✅ Возвращай 200 OK даже при ошибке (чтобы Tribute не retry)
✅ Отправляй алерт в Telegram при критичных ошибках

### 2. Безопасность
✅ Всегда проверяй подпись вебхука
✅ Используй HTTPS (Railway дает автоматически)
✅ Не логируй API Secret

### 3. Масштабирование
✅ Используй идемпотентность (сохраняй event.id)
✅ Используй очередь для обработки вебхуков (если много платежей)
✅ Кэшируй Product IDs

---

## 📚 Ресурсы

- [Tribute Documentation](https://docs.tribute.to/) (если есть)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [HMAC Authentication](https://en.wikipedia.org/wiki/HMAC)

---

**Автор:** КарточкаПРО Team  
**Дата:** 13 октября 2025  
**Версия:** 1.0
