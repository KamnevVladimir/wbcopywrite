# 🤖 AI-Копирайтер для Wildberries/Ozon

Telegram-бот для генерации продающих описаний товаров на маркетплейсах через Claude AI.

## 🚀 Quick Start (Локальная разработка)

### Требования
- macOS 13+ (Sonoma)
- Xcode 15.0+
- Swift 5.9+
- Docker Desktop

### Шаг 1: Клонирование и setup

```bash
cd /Users/vskamnev/Desktop/идеи/WBCopywriterBot

# Создать .env файл
cat > .env << EOF
ENVIRONMENT=development
LOG_LEVEL=debug

DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=wbcopywriter
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
CLAUDE_API_KEY=your_claude_api_key

# Пока разрабатываем, Tribute не нужен
TRIBUTE_API_KEY=test_key
TRIBUTE_SECRET=test_secret
EOF
```

### Шаг 2: Запуск PostgreSQL

```bash
# Запустить PostgreSQL в Docker
docker-compose up -d

# Проверить что запустился
docker ps
```

### Шаг 3: Установка зависимостей

```bash
# Resolve dependencies
swift package resolve

# Может занять 2-5 минут при первом запуске
```

### Шаг 4: Миграции БД

```bash
# Запустить миграции
swift run App migrate --auto-migrate
```

### Шаг 5: Запуск dev server

```bash
# Запустить сервер
swift run App serve --hostname 0.0.0.0 --port 8080

# Или в background
swift run App serve --hostname 0.0.0.0 --port 8080 &
```

Сервер запустится на `http://localhost:8080`

### Шаг 6: Настройка Telegram webhook (через ngrok)

**Пока разрабатываем локально, используем ngrok:**

```bash
# В новом терминале
# Установить ngrok (если еще нет)
brew install ngrok

# Запустить туннель
ngrok http 8080

# Скопировать HTTPS URL (например: https://abc123.ngrok.io)
```

**Установить webhook в Telegram:**

```bash
curl -X POST https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook \
  -H "Content-Type: application/json" \
  -d '{"url": "https://abc123.ngrok.io/webhook"}'
```

**Проверить webhook:**

```bash
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo
```

### Шаг 7: Тестирование

Открой Telegram → найди своего бота → `/start`

---

## 🧪 Тестирование

```bash
# Запустить все тесты
swift test

# Запустить с покрытием
swift test --enable-code-coverage

# Посмотреть покрытие
xcrun llvm-cov report .build/debug/WBCopywriterBotPackageTests.xctest/Contents/MacOS/WBCopywriterBotPackageTests -instr-profile=.build/debug/codecov/default.profdata
```

---

## 📁 Структура проекта

```
WBCopywriterBot/
├── Sources/App/
│   ├── configure.swift              # Vapor config
│   ├── routes.swift                 # Routes registration
│   ├── entrypoint.swift            # Entry point
│   │
│   ├── Controllers/                # HTTP endpoints
│   │   ├── HealthController.swift
│   │   ├── TelegramWebhookController.swift
│   │   └── TributeWebhookController.swift
│   │
│   ├── Services/                   # Business logic
│   │   ├── TelegramBotService.swift
│   │   ├── ClaudeService.swift
│   │   ├── SubscriptionService.swift
│   │   ├── TributeService.swift
│   │   └── UsageLimitService.swift
│   │
│   ├── Repositories/               # Data access
│   │   ├── UserRepository.swift
│   │   ├── SubscriptionRepository.swift
│   │   └── GenerationRepository.swift
│   │
│   ├── Models/                     # Entities + DTOs
│   │   ├── Entities/
│   │   └── DTOs/
│   │
│   ├── Prompts/                    # AI prompts
│   │   ├── SystemPrompt.swift
│   │   └── CategoryPrompts.swift
│   │
│   ├── Migrations/                 # DB migrations
│   └── Config/                     # Configuration
│
└── Tests/AppTests/                 # Tests (≥90% coverage)
```

---

## 🗄️ База данных

### Подключиться к PostgreSQL

```bash
# Через psql
docker exec -it wbcopywriter-postgres psql -U postgres -d wbcopywriter

# Или через GUI (Postico, TablePlus, etc)
# Host: localhost
# Port: 5432
# User: postgres
# Password: postgres
# Database: wbcopywriter
```

### Полезные команды

```sql
-- Посмотреть таблицы
\dt

-- Посмотреть юзеров
SELECT * FROM users;

-- Посмотреть подписки
SELECT * FROM subscriptions;

-- Посмотреть генерации
SELECT * FROM generations ORDER BY created_at DESC LIMIT 10;

-- Сбросить БД (осторожно!)
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```

---

## 🔧 Полезные команды

### Development

```bash
# Запустить с авто-перезагрузкой (TODO: настроить)
# swift run App serve --auto-reload

# Посмотреть логи
tail -f Logs/app.log

# Проверить health endpoint
curl http://localhost:8080/health
```

### Database

```bash
# Создать миграцию
# (пока делаем вручную в Sources/App/Migrations/)

# Откатить последнюю миграцию
swift run App migrate --revert

# Пересоздать БД с нуля
swift run App migrate --revert --all
swift run App migrate --auto-migrate
```

### Docker

```bash
# Остановить PostgreSQL
docker-compose down

# Удалить с данными
docker-compose down -v

# Пересоздать контейнер
docker-compose up -d --force-recreate
```

---

## 🌐 Deployment на Railway (для продакшна)

### 1. Установить Railway CLI

```bash
brew install railway
railway login
```

### 2. Создать проект

```bash
railway init
railway add --plugin postgresql
```

### 3. Установить environment variables

```bash
railway variables set TELEGRAM_BOT_TOKEN=your_token
railway variables set CLAUDE_API_KEY=your_key
railway variables set TRIBUTE_API_KEY=your_key
railway variables set TRIBUTE_SECRET=your_secret
railway variables set ENVIRONMENT=production
railway variables set LOG_LEVEL=info
```

### 4. Deploy

```bash
railway up
```

### 5. Установить webhook (production)

```bash
# Получить URL
railway domain

# Установить webhook
curl -X POST https://api.telegram.org/bot<TOKEN>/setWebhook \
  -H "Content-Type: application/json" \
  -d '{"url": "https://your-app.railway.app/webhook"}'
```

---

## 📊 Мониторинг

### Логи

```bash
# Локально
tail -f Logs/app.log

# Railway
railway logs
```

### Метрики (TODO)

- [ ] Request count
- [ ] Response time
- [ ] Error rate
- [ ] Claude API latency
- [ ] Database query time

---

## 🐛 Troubleshooting

### Проблема: База данных не подключается

```bash
# Проверить что PostgreSQL запущен
docker ps | grep postgres

# Проверить логи контейнера
docker logs wbcopywriter-postgres

# Перезапустить
docker-compose restart
```

### Проблема: Telegram webhook не работает

```bash
# Проверить статус webhook
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo

# Удалить webhook
curl https://api.telegram.org/bot<TOKEN>/deleteWebhook

# Установить заново
curl -X POST https://api.telegram.org/bot<TOKEN>/setWebhook \
  -d "url=https://your-url/webhook"
```

### Проблема: Claude API ошибка 429 (rate limit)

- Уменьши частоту запросов
- Проверь квоту на anthropic.com
- Добавь exponential backoff в ClaudeService

### Проблема: Swift package resolve зависает

```bash
# Очистить кэш
rm -rf .build
rm Package.resolved
swift package clean
swift package resolve
```

---

## 📚 Документация

- [PROJECT_PLAN.md](./PROJECT_PLAN.md) - Полный бизнес-план и архитектура
- [Vapor Docs](https://docs.vapor.codes/)
- [Fluent Docs](https://docs.vapor.codes/fluent/overview/)
- [Claude API](https://docs.anthropic.com/claude/reference)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Tribute API](https://docs.tribute.to/)

---

## 🤝 Contributing

Пока это solo-проект, но если будут помощники:

1. Создай ветку от `main`
2. Напиши тесты (TDD)
3. Реализуй фичу
4. Проверь coverage (≥90%)
5. Создай PR
6. Коммиты на русском, <50 символов

---

## 📝 TODO

### MVP (День 1)
- [ ] Setup проекта
- [ ] База данных (Models, Migrations, Repositories)
- [ ] Claude интеграция
- [ ] Telegram bot (основные команды)
- [ ] Tribute payments (заглушки)
- [ ] Тесты (≥90%)

### Post-MVP (Неделя 2)
- [ ] Улучшение промптов
- [ ] Экспорт в файл (TXT)
- [ ] История генераций
- [ ] Admin команды

### Future
- [ ] Экспорт в Excel
- [ ] A/B тест описаний
- [ ] Анализ конкурентов
- [ ] Bulk-генерация

---

## 📞 Контакты

- Telegram: @your_username
- Email: your@email.com

---

**Версия:** 0.1.0  
**Статус:** 🚧 В разработке  
**Последнее обновление:** 11 октября 2025

