# ⚡ Быстрый старт за 15 минут

## Шаг 1: Получить токены (5 минут)

### Telegram Bot Token

1. Открой Telegram
2. Найди [@BotFather](https://t.me/botfather)
3. Отправь `/newbot`
4. Придумай имя: "WB Copywriter Bot" (временное)
5. Придумай username: "wb_copy_test_bot" (временное)
6. **Скопируй токен** — он выглядит так: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`

### Claude API Key

1. Открой [console.anthropic.com](https://console.anthropic.com/)
2. Зарегистрируйся / войди
3. Перейди в "API Keys"
4. Нажми "Create Key"
5. **Скопируй ключ** — он выглядит так: `sk-ant-api03-...`

---

## Шаг 2: Создать .env файл (2 минуты)

```bash
cd /Users/vskamnev/Desktop/идеи/WBCopywriterBot

# Создать .env
cat > .env << 'EOF'
ENVIRONMENT=development
LOG_LEVEL=debug

DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=wbcopywriter
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres

TELEGRAM_BOT_TOKEN=ВСТАВЬ_СЮДА_ТОКЕН_ОТ_BOTFATHER
CLAUDE_API_KEY=ВСТАВЬ_СЮДА_КЛЮЧ_ОТ_CLAUDE

TRIBUTE_API_KEY=test_key
TRIBUTE_SECRET=test_secret
EOF

# Открой в редакторе и вставь токены
nano .env
# или
open -a TextEdit .env
```

**Важно:** Замени `ВСТАВЬ_СЮДА_...` на реальные токены!

---

## Шаг 3: Запустить PostgreSQL (1 минута)

```bash
# Запустить
docker-compose up -d

# Проверить что запустился
docker ps | grep postgres

# Должна быть строка с wbcopywriter-postgres
```

Если Docker не установлен:
```bash
# Установить Docker Desktop
brew install --cask docker
# Запустить Docker Desktop из Applications
# Потом вернуться сюда и повторить команды выше
```

---

## Шаг 4: Установить зависимости (3 минуты)

```bash
# Resolve Swift packages
swift package resolve

# Это может занять 2-5 минут при первом запуске
# Пока можно попить кофе ☕
```

Если ошибка — попробуй:
```bash
rm -rf .build
rm Package.resolved
swift package clean
swift package resolve
```

---

## Шаг 5: Запустить миграции (1 минута)

**ВАЖНО:** Сначала нужно дописать `configure.swift` и `routes.swift`!

Пока этого не сделано, миграции не запустятся.

**Вернись к этому шагу после того как завершишь разработку core файлов.**

```bash
# Когда configure.swift будет готов:
swift run App migrate --auto-migrate

# Должны создаться 3 таблицы:
# ✅ users
# ✅ subscriptions
# ✅ generations
```

---

## Шаг 6: Запустить сервер (1 минута)

**ВАЖНО:** Этот шаг тоже после написания core файлов.

```bash
swift run App serve --hostname 0.0.0.0 --port 8080

# Должно быть:
# [ INFO ] Server starting on http://0.0.0.0:8080
```

В другом терминале проверь:
```bash
curl http://localhost:8080/health

# Должен вернуть: {"status":"ok"}
```

---

## Шаг 7: Настроить Telegram webhook (2 минуты)

### Запустить ngrok

```bash
# Установить (если еще нет)
brew install ngrok

# Запустить в новом терминале
ngrok http 8080

# Скопировать HTTPS URL
# Например: https://abc123.ngrok.io
```

### Установить webhook

```bash
# Заменить переменные:
TOKEN="твой_telegram_токен"
NGROK_URL="https://abc123.ngrok.io"

# Установить webhook
curl -X POST "https://api.telegram.org/bot${TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"${NGROK_URL}/webhook\"}"

# Должен вернуть: {"ok":true,"result":true,...}

# Проверить
curl "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"

# Должно быть:
# "url": "https://abc123.ngrok.io/webhook"
# "pending_update_count": 0
```

---

## Шаг 8: Первый тест! (1 минута)

1. Открой Telegram
2. Найди своего бота (по username который создал)
3. Отправь `/start`
4. **Если бот ответил — ВСЁ РАБОТАЕТ! 🎉**

---

## 🐛 Если что-то не работает

### PostgreSQL не запускается

```bash
# Проверить Docker
docker --version

# Проверить контейнер
docker ps -a | grep wbcopywriter

# Логи
docker logs wbcopywriter-postgres

# Пересоздать
docker-compose down -v
docker-compose up -d
```

### Swift package resolve зависает

```bash
# Очистить и попробовать снова
rm -rf .build
rm Package.resolved
swift package clean
swift package resolve
```

### Бот не отвечает

1. **Проверь сервер запущен:**
   ```bash
   curl http://localhost:8080/health
   ```

2. **Проверь ngrok работает:**
   ```bash
   curl https://твой-ngrok-url.ngrok.io/health
   ```

3. **Проверь webhook установлен:**
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
   ```

4. **Посмотри логи сервера** — там будут ошибки

---

## 📝 Что дальше?

После того как всё запустилось:

1. **Протестируй все команды:**
   - `/start`
   - `/generate`
   - `/balance`
   - `/help`

2. **Попробуй сгенерировать описание:**
   - Выбери категорию
   - Опиши товар
   - Проверь что описание адекватное

3. **Найди баги:**
   - Запиши всё что не работает
   - Запиши идеи для улучшения

4. **Позови друзей на beta-тест:**
   - 5-10 человек достаточно
   - Попроси честный feedback

---

## ✅ Чек-лист готовности

Перед тем как считать "готово", проверь:

- [ ] Telegram бот создан, токен получен
- [ ] Claude API key получен
- [ ] `.env` файл создан и заполнен
- [ ] Docker Desktop запущен
- [ ] PostgreSQL контейнер работает
- [ ] Swift dependencies установлены
- [ ] Миграции выполнены (3 таблицы созданы)
- [ ] Сервер запускается без ошибок
- [ ] `curl http://localhost:8080/health` возвращает OK
- [ ] ngrok запущен и выдал HTTPS URL
- [ ] Telegram webhook установлен
- [ ] Бот отвечает на `/start` в Telegram

---

## 🎯 Следующий этап

Когда всё работает локально:

1. **Beta-тест** (неделя 1)
   - Пригласи 10-20 знакомых
   - Собери feedback
   - Фикс критичных багов

2. **Deploy на Railway** (неделя 2)
   - Создай Railway проект
   - Deploy код
   - Переключи webhook на production URL

3. **Первая реклама** (неделя 3)
   - Пост на VC.ru
   - Реклама в Telegram-канале
   - Мониторинг метрик

---

**Время:** 15 минут (без разработки core файлов)  
**Сложность:** 🟢 Легко  
**Статус:** Готов к запуску

_Если застрял — пиши вопросы, помогу! 🚀_

