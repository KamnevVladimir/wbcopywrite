#!/bin/bash

# Скрипт для удаления Telegram webhook и переключения на long polling

TOKEN="8494700026:AAHWU3WECRMEJuBovIUJlJQtEPBwA1b7aQw"

echo "🔧 Удаляем webhook..."

curl -X POST "https://api.telegram.org/bot${TOKEN}/deleteWebhook" \
  -H "Content-Type: application/json" \
  -d '{"drop_pending_updates": true}'

echo ""
echo ""
echo "✅ Webhook удалён!"
echo ""
echo "📊 Проверяем статус:"

curl "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"

echo ""
echo ""
echo "✅ Готово! Теперь бот будет использовать long polling."

