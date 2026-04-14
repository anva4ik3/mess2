# Messenger Backend 1

Express + TypeScript + PostgreSQL + WebSocket backend.

## Быстрый старт (Railway)

1. Создай аккаунт на [railway.app](https://railway.app)
2. New Project → Deploy from GitHub → выбери этот репозиторий  
3. Добавь PostgreSQL сервис: New → Database → PostgreSQL
4. Добавь переменные окружения (Settings → Variables):

```
DATABASE_URL      = (автоматически от Railway PostgreSQL)
JWT_SECRET        = $(openssl rand -hex 32)
GROQ_API_KEY      = gsk_...  (бесплатно на console.groq.com)
SMTP_HOST         = smtp.resend.com
SMTP_PORT         = 465
SMTP_USER         = resend
SMTP_PASS         = re_...   (бесплатно на resend.com — 3000 писем/мес)
FROM_EMAIL        = noreply@yourdomain.com
NODE_ENV          = production
```

5. Railway сам запустит сборку через Dockerfile

## Локальный запуск

```bash
npm install
cp .env.example .env  # заполни переменные
npm run dev
```

## API

| Метод | Путь | Описание |
|-------|------|----------|
| POST | /api/auth/send-otp | Отправить код |
| POST | /api/auth/verify-otp | Проверить код |
| POST | /api/auth/register | Регистрация |
| GET | /api/auth/me | Текущий пользователь |
| GET | /api/chats | Список чатов |
| POST | /api/chats/direct | Открыть личный чат |
| GET | /api/chats/:id/messages | Сообщения |
| GET | /api/contacts | Контакты |
| GET | /api/channels/explore | Поиск каналов |
| POST | /api/ai/chat/:chatId | AI-ответ |
| WS | /ws?token=... | WebSocket |
