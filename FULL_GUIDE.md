# 📖 Полное руководство: AI-Копирайтер для WB/Ozon

## 📑 Содержание

1. [Быстрый старт](#быстрый-старт)
2. [Бизнес-план и финансы](#бизнес-план)
3. [Архитектура проекта](#архитектура)
4. [Локальная разработка](#локальная-разработка)
5. [Deployment в Railway](#deployment)
6. [API интеграции](#api-интеграции)
7. [Тестирование](#тестирование)
8. [Маркетинг](#маркетинг)

---

## 🚀 Быстрый старт

### Подготовка (10 минут)

```bash
# 1. Перейти в папку проекта
cd /Users/vskamnev/Desktop/идеи/WBCopywriterBot

# 2. Создать .env файл
cat > .env << 'EOF'
ENVIRONMENT=development
LOG_LEVEL=debug

DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=wbcopywriter
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

TELEGRAM_BOT_TOKEN=ТВОЙ_ТОКЕН_СЮДА
CLAUDE_API_KEY=ТВОЙ_КЛЮЧ_СЮДА

TRIBUTE_API_KEY=test_key
TRIBUTE_SECRET=test_secret
EOF

# 3. Запустить PostgreSQL
docker-compose up -d

# 4. Установить зависимости
swift package resolve

# 5. Запустить миграции
swift run App migrate --auto-migrate

# 6. Запустить сервер
swift run App serve
```

### Получение токенов

#### Telegram Bot Token
1. Открой [@BotFather](https://t.me/botfather) в Telegram
2. Отправь `/newbot`
3. Введи имя бота (пока любое, потом придумаем)
4. Введи username (должен заканчиваться на `_bot`)
5. Скопируй токен

#### Claude API Key
1. Зарегистрируйся на [console.anthropic.com](https://console.anthropic.com/)
2. Перейди в API Keys
3. Создай новый ключ
4. Скопируй ключ (начинается с `sk-ant-`)

### Настройка Telegram Webhook (для локалки)

```bash
# 1. Установи ngrok (если еще нет)
brew install ngrok

# 2. Запусти туннель
ngrok http 8080

# 3. Скопируй HTTPS URL (например: https://abc123.ngrok.io)

# 4. Установи webhook
curl -X POST "https://api.telegram.org/bot<ТВОЙ_ТОКЕН>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://abc123.ngrok.io/webhook"}'

# 5. Проверь
curl "https://api.telegram.org/bot<ТВОЙ_ТОКЕН>/getWebhookInfo"
```

### Первый тест

1. Открой Telegram
2. Найди своего бота
3. Отправь `/start`
4. Если ответил — всё работает! 🎉

---

## 💰 Бизнес-план

### Финансовый прогноз (реалистичный)

| Месяц | Регистр. | Платных | MRR | Расходы | Прибыль | Накопл. |
|-------|----------|---------|-----|---------|---------|---------|
| 1 | 120 | 5 | 1,795₽ | 6,500₽ | -4,705₽ | -4,705₽ |
| 2 | 280 | 15 | 5,090₽ | 8,200₽ | -3,110₽ | -7,815₽ |
| 3 | 450 | 30 | 12,176₽ | 10,500₽ | +1,676₽ | -6,139₽ |
| 4 | 580 | 45 | 19,565₽ | 12,000₽ | +7,565₽ | +1,426₽ |
| 6 | 760 | 75 | 35,443₽ | 15,000₽ | +20,443₽ | +35,323₽ |
| 12 | 1,350 | 200 | 111,810₽ | 30,000₽ | +81,810₽ | **+380,000₽** |

### Ключевые метрики

**Конверсия Free → Paid:**
- Месяц 1: 4.2%
- Месяц 6: 9.9%
- Месяц 12: 14.8%

**Churn Rate:**
- Месяц 1-2: 35%
- Месяц 3+: 12-15%

**LTV/CAC:**
- Начало: 2.4
- Через 6 мес: 5.9
- Через год: 8.9

### Тарифы

| План | Цена | Лимит | Целевая аудитория |
|------|------|-------|-------------------|
| Free | 0₽ | 3 описания | Попробовать |
| Starter | 299₽/мес | 30 описаний | Малые селлеры |
| Business | 599₽/мес | 150 описаний | Средние селлеры |
| Pro | 999₽/мес | 500 описаний | Крупные + агентства |

### Расходы по месяцам

**Месяц 1: 6,500₽**
- Railway Starter: 470₽
- Claude API: 350₽
- Tribute: 50₽
- Реклама: 5,000₽
- Резерв: 630₽

**Месяц 6: 15,000₽**
- Railway Developer: 1,880₽
- Claude API: 1,850₽
- Tribute: 992₽
- Маркетинг: 8,000₽
- Support: 2,000₽
- Резерв: 278₽

**Месяц 12: 30,000₽**
- Railway Pro: 3,760₽
- Claude API: 5,250₽
- Tribute: 3,131₽
- Маркетинг: 12,000₽
- Support: 4,000₽
- Бухгалтерия: 1,500₽
- Резерв: 359₽

---

## 🏗️ Архитектура

### Принципы
- **Service Layer Pattern** (не Clean Architecture — overkill)
- **SOLID** без фанатизма
- **KISS, DRY, YAGNI**
- **TDD** (≥90% coverage)

### Схема слоев

```
┌──────────────────────────────────────┐
│      Controllers (HTTP/Webhook)      │  ← Тонкие, только HTTP
├──────────────────────────────────────┤
│         Services (Logic)             │  ← Вся бизнес-логика
├──────────────────────────────────────┤
│      Repositories (Data Access)      │  ← Только запросы к БД
├──────────────────────────────────────┤
│          Models (Entities)           │  ← Чистые структуры
└──────────────────────────────────────┘
```

### Структура файлов

```
WBCopywriterBot/
├── Package.swift                      # Dependencies
├── docker-compose.yml                 # PostgreSQL local
├── Dockerfile                         # Production image
├── railway.toml                       # Railway config
├── README.md                          # Quick start
├── PROJECT_PLAN.md                    # Business plan
├── FULL_GUIDE.md                      # Это файл
│
├── Sources/App/
│   ├── entrypoint.swift              # Entry point
│   ├── configure.swift               # App config
│   ├── routes.swift                  # Route registration
│   │
│   ├── Controllers/                  # 🎯 HTTP endpoints
│   │   ├── HealthController.swift
│   │   ├── TelegramWebhookController.swift
│   │   └── TributeWebhookController.swift
│   │
│   ├── Services/                     # 🧠 Business logic
│   │   ├── TelegramBotService.swift
│   │   ├── ClaudeService.swift
│   │   ├── SubscriptionService.swift
│   │   ├── TributeService.swift
│   │   └── UsageLimitService.swift
│   │
│   ├── Repositories/                 # 💾 Data access
│   │   ├── UserRepository.swift
│   │   ├── SubscriptionRepository.swift
│   │   └── GenerationRepository.swift
│   │
│   ├── Models/
│   │   ├── Entities/                 # Database models
│   │   │   ├── User.swift
│   │   │   ├── Subscription.swift
│   │   │   └── Generation.swift
│   │   └── DTOs/                     # API DTOs
│   │       ├── TelegramUpdate.swift
│   │       ├── ClaudeRequest.swift
│   │       └── TributeWebhook.swift
│   │
│   ├── Prompts/                      # 📝 AI prompts
│   │   ├── SystemPrompt.swift
│   │   └── CategoryPrompts.swift
│   │
│   ├── Migrations/                   # 🗄️ DB migrations
│   │   ├── CreateUsers.swift
│   │   ├── CreateSubscriptions.swift
│   │   └── CreateGenerations.swift
│   │
│   ├── Config/                       # ⚙️ Configuration
│   │   ├── Environment.swift
│   │   └── Constants.swift
│   │
│   └── Extensions/                   # 🔧 Helpers
│
└── Tests/AppTests/                   # 🧪 Tests (≥90%)
    ├── Services/
    ├── Repositories/
    └── Mocks/
```

### База данных (PostgreSQL)

#### Users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255),
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    selected_category VARCHAR(50),
    generations_used INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Subscriptions
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    generations_limit INT NOT NULL,
    price DECIMAL(10, 2),
    started_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    tribute_subscription_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Generations
```sql
CREATE TABLE generations (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL,
    product_name TEXT NOT NULL,
    product_details TEXT,
    result_title TEXT,
    result_description TEXT,
    result_bullets JSONB,
    result_hashtags JSONB,
    tokens_used INT NOT NULL DEFAULT 0,
    processing_time_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 💻 Локальная разработка

### Prerequisites
- macOS 13+ (Sonoma)
- Xcode 15.0+
- Swift 5.9+
- Docker Desktop
- ngrok (для Telegram webhook)

### Шаг за шагом

#### 1. Setup проекта

```bash
# Клонировать или перейти в папку
cd /Users/vskamnev/Desktop/идеи/WBCopywriterBot

# Проверить структуру
ls -la

# Должны быть:
# - Package.swift
# - docker-compose.yml
# - Sources/
# - Tests/
```

#### 2. Environment variables

Создай `.env` в корне проекта:

```bash
ENVIRONMENT=development
LOG_LEVEL=debug

DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=wbcopywriter
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

TELEGRAM_BOT_TOKEN=your_token_here
CLAUDE_API_KEY=your_key_here

TRIBUTE_API_KEY=test_key
TRIBUTE_SECRET=test_secret

RATE_LIMIT_FREE=3
RATE_LIMIT_STARTER=30
RATE_LIMIT_BUSINESS=150
RATE_LIMIT_PRO=500
```

#### 3. Запуск PostgreSQL

```bash
# Запустить
docker-compose up -d

# Проверить
docker ps | grep postgres

# Должен быть контейнер wbcopywriter-postgres
```

#### 4. Установка зависимостей

```bash
# Resolve packages (может занять 2-5 минут)
swift package resolve

# Если ошибка — очистить кэш
rm -rf .build
rm Package.resolved
swift package clean
swift package resolve
```

#### 5. Миграции

```bash
# Запустить миграции
swift run App migrate --auto-migrate

# Должны создаться таблицы:
# - users
# - subscriptions
# - generations
```

#### 6. Запуск сервера

```bash
# Dev mode
swift run App serve --hostname 0.0.0.0 --port 8080

# Или в фоне
swift run App serve --hostname 0.0.0.0 --port 8080 &

# Проверить health
curl http://localhost:8080/health
# Должен вернуть: {"status":"ok"}
```

#### 7. Ngrok для webhook

```bash
# В новом терминале
ngrok http 8080

# Скопировать HTTPS URL
# Например: https://abc123.ngrok.io
```

#### 8. Установить Telegram webhook

```bash
# Заменить <TOKEN> и <NGROK_URL>
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://<NGROK_URL>/webhook"}'

# Проверить
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

### Полезные команды

```bash
# Посмотреть логи сервера
tail -f Logs/app.log

# Подключиться к PostgreSQL
docker exec -it wbcopywriter-postgres psql -U postgres -d wbcopywriter

# Посмотреть юзеров
SELECT * FROM users;

# Откатить миграции
swift run App migrate --revert

# Пересоздать БД
swift run App migrate --revert --all
swift run App migrate --auto-migrate

# Остановить PostgreSQL
docker-compose down

# Удалить с данными
docker-compose down -v
```

---

## 🌐 Deployment в Railway

### Шаг 1: Установка Railway CLI

```bash
brew install railway
railway login
```

### Шаг 2: Создание проекта

```bash
# В папке проекта
cd /Users/vskamnev/Desktop/идеи/WBCopywriterBot

# Инициализация
railway init

# Добавить PostgreSQL
railway add --plugin postgresql
```

### Шаг 3: Environment Variables

```bash
railway variables set TELEGRAM_BOT_TOKEN=your_token
railway variables set CLAUDE_API_KEY=your_key
railway variables set TRIBUTE_API_KEY=your_key
railway variables set TRIBUTE_SECRET=your_secret
railway variables set ENVIRONMENT=production
railway variables set LOG_LEVEL=info
```

### Шаг 4: Deploy

```bash
# Deploy
railway up

# Посмотреть логи
railway logs --follow

# Получить URL
railway domain
```

### Шаг 5: Установить webhook (production)

```bash
# Получить URL из Railway
RAILWAY_URL=$(railway domain)

# Установить webhook
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"https://$RAILWAY_URL/webhook\"}"
```

### Railway Dashboard

- Открой [railway.app](https://railway.app)
- Найди свой проект
- Проверь метрики:
  - CPU usage
  - Memory usage
  - Network
  - Logs

---

## 🔌 API Интеграции

### Claude API

#### Получение ключа
1. [console.anthropic.com](https://console.anthropic.com/)
2. API Keys → Create Key
3. Скопируй ключ (`sk-ant-...`)

#### Pricing (2025)
- **Claude 3.5 Sonnet:**
  - Input: $3 / 1M tokens
  - Output: $15 / 1M tokens
  - **Prompt Caching:** -90% стоимость (используем!)

#### Пример запроса

```swift
let request = ClaudeRequest(
    model: "claude-3-5-sonnet-20241022",
    maxTokens: 2048,
    system: "Ты эксперт-копирайтер для маркетплейсов...",
    messages: [
        ClaudeRequest.Message(
            role: "user",
            content: "Напиши описание для товара: ..."
        )
    ]
)
```

#### Лимиты
- Rate limit: 50 requests/minute (Tier 1)
- Можно увеличить: support@anthropic.com

### Telegram Bot API

#### Документация
- [core.telegram.org/bots/api](https://core.telegram.org/bots/api)

#### Основные endpoints

**Установить webhook:**
```bash
POST https://api.telegram.org/bot<TOKEN>/setWebhook
{
  "url": "https://your-domain.com/webhook"
}
```

**Отправить сообщение:**
```bash
POST https://api.telegram.org/bot<TOKEN>/sendMessage
{
  "chat_id": 12345,
  "text": "Привет!",
  "parse_mode": "Markdown"
}
```

**Отправить файл:**
```bash
POST https://api.telegram.org/bot<TOKEN>/sendDocument
{
  "chat_id": 12345,
  "document": "file_url_or_file_id",
  "caption": "Твое описание.txt"
}
```

### Tribute (Payments)

#### Документация
- [docs.tribute.to](https://docs.tribute.to/)

#### Регистрация
1. [tribute.to](https://tribute.to/)
2. Зарегистрироваться как продавец
3. Получить API key и Secret

#### Создание платежа

```bash
POST https://api.tribute.to/v1/payments
{
  "amount": 29900,  # копейки
  "currency": "RUB",
  "description": "Подписка Starter",
  "user_id": "telegram_12345",
  "recurring": true
}

# Response:
{
  "id": "payment_123",
  "url": "https://tribute.to/pay/abc123",
  "status": "pending"
}
```

#### Webhook events

Tribute отправляет события на твой endpoint:

- `payment.succeeded` — платеж прошел
- `payment.failed` — платеж провалился
- `subscription.created` — подписка создана
- `subscription.renewed` — подписка продлена
- `subscription.cancelled` — подписка отменена

#### Verification (важно!)

```swift
// Проверка подписи webhook
let signature = request.headers["X-Tribute-Signature"].first
let payload = try request.content.decode(String.self)

let isValid = TributeWebhookSignature.verify(
    payload: payload,
    signature: signature,
    secret: config.tributeSecret
)

guard isValid else {
    throw Abort(.unauthorized, reason: "Invalid signature")
}
```

---

## 🧪 Тестирование

### Запуск тестов

```bash
# Все тесты
swift test

# С покрытием
swift test --enable-code-coverage

# Конкретный тест
swift test --filter UserRepositoryTests
```

### Структура тестов

```
Tests/AppTests/
├── Services/
│   ├── TelegramBotServiceTests.swift
│   ├── ClaudeServiceTests.swift
│   └── SubscriptionServiceTests.swift
├── Repositories/
│   ├── UserRepositoryTests.swift
│   └── SubscriptionRepositoryTests.swift
└── Mocks/
    ├── MockClaudeService.swift
    └── MockUserRepository.swift
```

### Пример теста

```swift
final class ClaudeServiceTests: XCTestCase {
    var app: Application!
    var service: ClaudeService!
    
    override func setUp() async throws {
        app = Application(.testing)
        service = ClaudeService(/*...*/)
    }
    
    func testGenerateDescription() async throws {
        let result = try await service.generateDescription(
            productName: "Test Product",
            category: .electronics,
            on: app
        )
        
        XCTAssertFalse(result.title.isEmpty)
        XCTAssertFalse(result.description.isEmpty)
        XCTAssertGreaterThan(result.bullets.count, 0)
    }
}
```

### Coverage цель: ≥90%

Исключения:
- `main.swift` / `entrypoint.swift`
- DTOs (простые структуры)
- Migrations

---

## 📣 Маркетинг

### Месяц 1: Запуск (5,000₽)

#### 1. Telegram-канал селлеров
- **Бюджет:** 3,000-5,000₽
- **Где искать:**
  - "WB Sellers Chat" (40k+)
  - "Ozon. Продавцы" (25k+)
  - "Маркетплейсы без воды" (15k+)
- **Креатив:**
  - "Генерируй описания за 10₽ вместо 500₽"
  - Скриншот до/после
  - Промокод FIRST50 (скидка 50% первый месяц)

#### 2. VC.ru пост (бесплатно)
- **Заголовок:** "Я создал AI-бот для селлеров за 1 день. Честные цифры через месяц"
- **Формат:** Кейс с реальными цифрами
- **CTA:** Ссылка на бот в конце

#### 3. Личная сеть
- Анонс знакомым селлерам
- Попросить прото протестировать

### Месяц 2-3: Оптимизация (8,000₽)

#### 1. Повторная реклама
- **Новый креатив:** "100+ селлеров уже используют"
- Социальное доказательство

#### 2. Кейсы клиентов
- Попросить 2-3 отзыва
- Опубликовать в боте + VC.ru

#### 3. Квиз-воронка
- "Получи 1 бесплатное описание"
- После → регистрация

### Месяц 4-6: Масштабирование (10,000₽)

#### 1. Telegram Ads
- **Бюджет:** 5,000₽/мес
- **Таргет:** "бизнес" + "маркетплейсы"
- **CPM:** ~180₽
- **Прогноз:** 70 регистраций, 5-7 платных

#### 2. Новые каналы
- 2-3 малых канала (5-10k подписчиков)
- **Бюджет:** 5,000₽

#### 3. Сарафан
- 15-25% регистраций органические

### Каналы (список для рекламы)

1. **Telegram-каналы:**
   - @wb_sellers_chat
   - @ozon_prodavci
   - @marketplaces_russia
   - @seller_academy
   - @wildberries_ozon_tips

2. **YouTube блогеры:**
   - Найти через поиск "wildberries как продавать"
   - Микроблогеры 5-20k подписчиков
   - Бартер: бесплатный Pro за обзор

3. **VC.ru / Habr:**
   - Контент-маркетинг (бесплатно)
   - Кейсы, инструкции, аналитика

---

## 🐛 Troubleshooting

### База данных не подключается

```bash
# Проверить контейнер
docker ps | grep postgres

# Логи контейнера
docker logs wbcopywriter-postgres

# Перезапустить
docker-compose restart

# Пересоздать
docker-compose down -v
docker-compose up -d
```

### Telegram webhook не работает

```bash
# Проверить статус
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Удалить webhook
curl "https://api.telegram.org/bot<TOKEN>/deleteWebhook"

# Установить заново
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=https://your-url/webhook"

# Проверить ngrok работает
curl https://your-ngrok-url.ngrok.io/health
```

### Claude API ошибка 429 (rate limit)

- Уменьши частоту запросов
- Добавь exponential backoff
- Проверь квоту на console.anthropic.com
- Напиши в support для увеличения лимитов

### Swift package resolve зависает

```bash
# Очистить всё
rm -rf .build
rm Package.resolved
swift package clean

# Попробовать снова
swift package resolve

# Если не помогает — проверить интернет
ping github.com
```

### Ошибка "Missing environment variable"

```bash
# Проверить .env файл существует
ls -la .env

# Проверить содержимое
cat .env

# Vapor читает .env автоматически
# Убедись что TELEGRAM_BOT_TOKEN и CLAUDE_API_KEY заполнены
```

---

## 📊 Метрики для отслеживания

### Day 1-7
- [ ] Регистраций/день
- [ ] Ошибок в логах
- [ ] Response time Claude API
- [ ] Webhook success rate

### Week 2-4
- [ ] Free → Paid конверсия
- [ ] Время до первой генерации
- [ ] Количество генераций на юзера
- [ ] Feedback scores

### Month 2+
- [ ] MRR growth rate
- [ ] Churn rate (по плану)
- [ ] CAC / LTV ratio
- [ ] NPS (Net Promoter Score)
- [ ] Server uptime
- [ ] API latency p95/p99

---

## ✅ Чек-лист запуска

### Перед запуском

- [ ] Telegram bot создан
- [ ] Claude API key получен
- [ ] Tribute аккаунт настроен (можно позже)
- [ ] PostgreSQL запущен
- [ ] Миграции выполнены
- [ ] .env файл заполнен
- [ ] Сервер запускается без ошибок
- [ ] Health endpoint отвечает
- [ ] Telegram webhook установлен
- [ ] Бот отвечает на /start

### Перед деплоем в Railway

- [ ] Тесты проходят (≥90% coverage)
- [ ] Railway проект создан
- [ ] PostgreSQL plugin добавлен
- [ ] Environment variables установлены
- [ ] Dockerfile тестирован локально
- [ ] Deploy прошел успешно
- [ ] Production webhook установлен
- [ ] Мониторинг настроен

### Перед первой рекламой

- [ ] Beta-тест пройден (10-20 юзеров)
- [ ] Критичных багов нет
- [ ] Onboarding понятен
- [ ] Промпты Claude оптимизированы
- [ ] Landing page готов (Telegraph или простой)
- [ ] Скриншоты для рекламы
- [ ] Кейсы / отзывы (хотя бы 2-3)

---

## 📚 Полезные ссылки

### Документация
- [Vapor Docs](https://docs.vapor.codes/)
- [Fluent ORM](https://docs.vapor.codes/fluent/overview/)
- [Claude API Reference](https://docs.anthropic.com/claude/reference)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Tribute API](https://docs.tribute.to/)
- [Railway Docs](https://docs.railway.app/)

### Инструменты
- [ngrok](https://ngrok.com/) — Туннели для localhost
- [Postico](https://eggerapps.at/postico/) — PostgreSQL GUI (macOS)
- [Postman](https://www.postman.com/) — API testing
- [Sentry](https://sentry.io/) — Error tracking

### Сообщества
- [Vapor Discord](https://discord.gg/vapor)
- [Swift Server Discord](https://discord.gg/swift-server)
- Telegram: @vapor_community

---

## 🤝 Что дальше?

### Следующие шаги (по порядку):

1. **Сегодня:** Получить токены (Telegram + Claude)
2. **Завтра:** Разработка MVP (10 часов)
3. **День 3:** Beta-тест с друзьями
4. **Неделя 1:** Фикс багов + оптимизация промптов
5. **Неделя 2:** Публичный запуск (VC.ru + Telegram канал)
6. **Месяц 1:** Мониторинг метрик + первые платные
7. **Месяц 2-3:** Оптимизация конверсии
8. **Месяц 4+:** Масштабирование рекламы

---

**Версия:** 1.0  
**Дата:** 11 октября 2025  
**Статус:** 🚧 Готов к разработке

---

_Удачи! Если что-то непонятно — пиши вопросы в процессе разработки. 🚀_

