# 📅 План разработки MVP (День 1)

## 🎯 Цель дня

Создать минимально работающий бот который:
- Принимает команду `/start`
- Генерирует описания товаров через Claude
- Отслеживает лимиты пользователей
- Работает локально через ngrok

**Общее время:** 10 часов чистой разработки

---

## ⏰ Расписание (по часам)

### 09:00 - 09:30 | Подготовка (30 мин)

**Задачи:**
- [ ] Получить Telegram Bot Token
- [ ] Получить Claude API Key
- [ ] Создать `.env` файл
- [ ] Запустить PostgreSQL
- [ ] Проверить что `swift package resolve` прошел

**Результат:**
- ✅ Окружение готово к разработке
- ✅ Все токены на месте
- ✅ БД запущена

---

### 09:30 - 11:00 | Core + Repositories (1.5 часа)

#### 09:30 - 10:15 | configure.swift + routes.swift (45 мин)

**Что писать:**

**`configure.swift`:**
```swift
- Database configuration (PostgreSQL)
- Migrations registration
- Services registration (DI)
- Middleware setup
- Routes registration
```

**`routes.swift`:**
```swift
- HealthController registration
- TelegramWebhookController registration
- TributeWebhookController registration
```

#### 10:15 - 11:00 | Repositories (45 мин)

**Что писать:**

**`UserRepository.swift`:**
```swift
- find(byTelegramId:)
- create(_:)
- update(_:)
```

**`SubscriptionRepository.swift`:**
```swift
- find(forUser:)
- create(_:)
- update(_:)
```

**`GenerationRepository.swift`:**
```swift
- create(_:)
- count(forUser:since:)
```

**Результат:**
- ✅ Vapor сконфигурирован
- ✅ Routes зарегистрированы
- ✅ 3 Repository готовы

---

### 11:00 - 13:00 | Prompts + Claude Service (2 часа)

#### 11:00 - 12:00 | Prompts (1 час)

**Что писать:**

**`SystemPrompt.swift`:**
```swift
static let system = """
Ты — эксперт-копирайтер для российских маркетплейсов 
с 10+ лет опыта.

ПРИНЦИПЫ:
1. Hook первых 2 предложений
2. Эмоциональные триггеры
3. Конкретные выгоды
4. SEO-оптимизация
5. Структура: описание → преимущества → CTA

ИЗБЕГАТЬ:
- Штампов
- КАПСЛОКА
- Обещаний без гарантий

JSON формат ответа обязателен.
"""
```

**`CategoryPrompts.swift`:**
```swift
enum CategoryPrompt {
    case clothing
    case electronics
    case home
    case beauty
    case sports
    
    func prompt(productName: String, details: String?) -> String {
        // 5 разных промптов под категории
    }
}
```

#### 12:00 - 13:00 | ClaudeService (1 час)

**Что писать:**

**`ClaudeService.swift`:**
```swift
class ClaudeService {
    func generateDescription(
        productName: String,
        category: ProductCategory,
        details: String?,
        on req: Request
    ) async throws -> ProductDescription
    
    private func callClaudeAPI(...) async throws
    private func parseResponse(...) throws -> ProductDescription
}
```

**Ключевые моменты:**
- Timeout 30 секунд
- Error handling для rate limits
- Логирование токенов
- JSON parsing с fallback

**Результат:**
- ✅ System prompt написан
- ✅ 5 category prompts готовы
- ✅ Claude API интегрирован

---

### 13:00 - 14:00 | ОБЕД 🍕

---

### 14:00 - 16:00 | Telegram Bot Service (2 часа)

**Что писать:**

**`TelegramBotService.swift`:**

#### 14:00 - 14:30 | Routing команд (30 мин)
```swift
func handleUpdate(_ update: TelegramUpdate) async throws {
    switch message.text {
    case "/start": handleStart()
    case "/generate": handleGenerate()
    case "/balance": handleBalance()
    case "/help": handleHelp()
    default: handleTextMessage()
    }
}
```

#### 14:30 - 15:15 | Основные команды (45 мин)
```swift
private func handleStart() async throws
private func handleGenerate() async throws
private func handleBalance() async throws
```

#### 15:15 - 16:00 | Генерация описания (45 мин)
```swift
private func handleTextMessage() async throws {
    // 1. Проверка лимитов
    // 2. Вызов ClaudeService
    // 3. Сохранение в Generation
    // 4. Отправка результата
}

private func sendDescription(...) async throws
```

**Результат:**
- ✅ Все команды работают
- ✅ Генерация описаний работает
- ✅ Inline keyboards работают

---

### 16:00 - 17:00 | Controllers (1 час)

#### 16:00 - 16:20 | HealthController (20 мин)

**`HealthController.swift`:**
```swift
func boot(routes: RoutesBuilder) {
    routes.get("health", use: health)
}

func health(req: Request) async throws -> HealthResponse {
    return HealthResponse(status: "ok")
}
```

#### 16:20 - 16:45 | TelegramWebhookController (25 мин)

**`TelegramWebhookController.swift`:**
```swift
func boot(routes: RoutesBuilder) {
    routes.post("webhook", use: handleWebhook)
}

func handleWebhook(req: Request) async throws -> HTTPStatus {
    let update = try req.content.decode(TelegramUpdate.self)
    
    let botService = req.application.telegramBotService
    try await botService.handleUpdate(update, on: req)
    
    return .ok
}
```

#### 16:45 - 17:00 | TributeWebhookController (15 мин)

**`TributeWebhookController.swift`:**
```swift
// Заглушка на MVP
func handleWebhook(req: Request) async throws -> HTTPStatus {
    req.logger.info("Tribute webhook received (not implemented)")
    return .ok
}
```

**Результат:**
- ✅ 3 Controller готовы
- ✅ Webhook endpoint работает

---

### 17:00 - 18:00 | Services (1 час)

#### 17:00 - 17:30 | SubscriptionService (30 мин)

**`SubscriptionService.swift`:**
```swift
func getCurrentPlan(for user: User) async throws -> SubscriptionPlan
func createSubscription(...) async throws
func renewSubscription(...) async throws
```

#### 17:30 - 18:00 | UsageLimitService (30 мин)

**`UsageLimitService.swift`:**
```swift
func checkLimit(for user: User) async throws -> Bool
func getRemainingGenerations(for user: User) async throws -> Int
func decrementLimit(for user: User) async throws
```

**Результат:**
- ✅ Subscription logic работает
- ✅ Usage limits работают

---

### 18:00 - 19:00 | Первый запуск + Debugging (1 час)

#### 18:00 - 18:15 | Миграции (15 мин)
```bash
swift run App migrate --auto-migrate
```

Проверить что создались таблицы.

#### 18:15 - 18:30 | Запуск сервера (15 мин)
```bash
swift run App serve --hostname 0.0.0.0 --port 8080
```

Смотрим логи — фиксим compile errors.

#### 18:30 - 18:45 | Ngrok + Webhook (15 мин)
```bash
ngrok http 8080
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" ...
```

#### 18:45 - 19:00 | Первый тест (15 мин)
- Отправить `/start` → должен ответить
- Отправить `/generate` → выбрать категорию
- Описать товар → получить описание

**Результат:**
- ✅ Бот запущен
- ✅ Отвечает на команды
- ✅ Генерирует описания

---

### 19:00 - 20:00 | Тестирование + Фиксы (1 час)

**Что тестировать:**

1. **Happy path:**
   - [ ] `/start` → приветствие
   - [ ] `/generate` → категория → описание товара → результат
   - [ ] `/balance` → показывает лимиты
   - [ ] `/help` → показывает помощь

2. **Edge cases:**
   - [ ] Повторный `/start` (уже зарегистрирован)
   - [ ] Генерация без выбора категории
   - [ ] Превышение лимита (для Free плана)
   - [ ] Слишком длинный текст товара

3. **Ошибки:**
   - [ ] Claude API timeout
   - [ ] Invalid JSON от Claude
   - [ ] Database connection error

**Результат:**
- ✅ Основной флоу работает
- ✅ Критичных багов нет
- ✅ Error handling адекватный

---

## 📊 Checklist завершения дня

### Обязательно (Must Have)

- [ ] Бот отвечает на `/start`
- [ ] Генерация описаний работает
- [ ] Лимиты отслеживаются (Free: 3 описания)
- [ ] Результат выглядит адекватно
- [ ] Нет критичных багов

### Желательно (Nice to Have)

- [ ] Inline keyboards работают
- [ ] Экспорт в файл (можно на день 2)
- [ ] История генераций (можно на день 2)
- [ ] Admin команды (можно на день 2)

### Можно пропустить (Skip for MVP)

- [ ] Tribute интеграция (только заглушка)
- [ ] Тесты (будут на день 2)
- [ ] Продвинутый error handling
- [ ] Метрики и мониторинг

---

## 🎯 Success Criteria

**Минимум для "готово":**

1. ✅ Бот запущен локально
2. ✅ Можно сгенерировать хотя бы 1 описание
3. ✅ Описание выглядит продающим (не мусор)
4. ✅ Лимиты работают (Free юзер не может сгенерить 4-ое)
5. ✅ Нет critical bugs (не крашится)

**Бонус если успел:**

6. ⭐ Красивые inline keyboards
7. ⭐ Экспорт результата в .txt файл
8. ⭐ Команда `/balance` показывает красивую статистику

---

## 🐛 Типичные ошибки (и как фиксить)

### Claude API timeout
```swift
// Увеличить timeout
let timeout = HTTPClient.Timeout.init(
    connect: .seconds(10),
    read: .seconds(30)
)
```

### Invalid JSON от Claude
```swift
// Добавить fallback parsing
do {
    return try JSONDecoder().decode(ProductDescription.self, from: data)
} catch {
    // Parse manually from text
    return parseManually(claudeResponse.text)
}
```

### Database connection refused
```bash
# Проверить что PostgreSQL запущен
docker ps | grep postgres

# Перезапустить
docker-compose restart
```

### Telegram webhook не работает
```bash
# Проверить ngrok
curl https://your-ngrok-url.ngrok.io/health

# Переустановить webhook
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=https://your-ngrok-url.ngrok.io/webhook"
```

---

## 📝 После завтра (Day 2)

### Приоритеты:

1. **Тесты** (≥90% coverage)
2. **Beta-тест** (10-20 друзей)
3. **Фикс багов** из feedback
4. **Оптимизация промптов** (если описания не очень)
5. **Экспорт в файл** (если не успел день 1)

---

## 💪 Мотивация

### Помни:

- **10 часов разработки** → бизнес на **380k₽/год**
- Первый день самый важный
- Не стремись к идеалу — делай MVP
- Баги будут — это нормально
- После запуска всё станет проще

### Если застрял:

1. Перечитай FULL_GUIDE.md
2. Посмотри код в Models/Entities (там примеры)
3. Погугли ошибку
4. Vapor Docs: docs.vapor.codes
5. Спроси в Vapor Discord

---

**Удачи! Ты справишься! 🚀**

_P.S. Не забудь попить кофе перед стартом ☕_

