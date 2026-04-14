# Messenger Flutter App

Telegram-inspired Flutter messenger app for Android.

## Сборка APK

### Вариант 1 — GitHub Actions (рекомендуется)

1. Push код на GitHub
2. Actions → Build APK → Run workflow
3. Укажи `API_URL` = URL твоего Railway backend
4. Скачай APK из Artifacts

### Вариант 2 — локально

```bash
flutter pub get

# Debug APK
flutter build apk --debug \
  --dart-define=API_URL=https://your-backend.railway.app

# Release APK  
flutter build apk --release \
  --dart-define=API_URL=https://your-backend.railway.app

# APK будет в: build/app/outputs/flutter-apk/
```

## Функции

- ✅ Email + OTP авторизация (без пароля)
- ✅ Realtime сообщения через WebSocket
- ✅ Правильное выравнивание: свои справа (синий), чужие слева (тёмный)
- ✅ Статус онлайн / "печатает..." с именем пользователя
- ✅ 4 вкладки: Чаты, Контакты, Каналы, Профиль
- ✅ Реакции (долгое нажатие → эмодзи)
- ✅ Ответ / пересылка / редактирование / удаление
- ✅ Закреплённые сообщения
- ✅ AI-ассистент (Groq Llama)
- ✅ Каналы с постами
- ✅ Telegram-style тёмная тема

## Архитектура

```
lib/
  config.dart          # API URL конфигурация
  theme.dart           # Цвета, градиенты, тема
  main.dart            # Точка входа, splash screen
  models/              # User, Chat, Message, Channel, Contact
  services/
    api.dart           # HTTP API клиент
    ws.dart            # WebSocket клиент
  screens/
    auth/              # Email, OTP, Register
    chats/             # Список чатов, Чат
    contacts/          # Контакты
    channels/          # Каналы, Канал
    profile/           # Профиль
  widgets/
    avatar.dart        # Аватар с инициалами и онлайн-индикатором
```
