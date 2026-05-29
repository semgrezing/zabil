# Backlog

## P2 — Reminders / Deadlines
- Добавить поле `dueDate` (DateTime?) в Note (Prisma + миграция)
- Zod-схема: `dueDate: z.string().datetime().optional().nullable()`
- Flutter: поле в `NoteModel`, UI-пикер даты в редакторе, badge/chip на карточке
- Push-уведомление за N минут до deadline (backend cron или scheduled job)

## P3 — Шаблоны заметок
- Модель `NoteTemplate` (title, content, checklistItems JSON)
- CRUD эндпоинты `/templates`
- Flutter: экран выбора шаблона при создании заметки
- Предустановленные шаблоны: «Список покупок», «Задачи на день», «Планирование»

## P3 — Quick Input (быстрое создание)
- FAB long-press → bottom sheet с полем заголовка + выбором контекста
- Создание заметки в одно действие без перехода в редактор
- Опционально: голосовой ввод (speech_to_text)

## P3 — Реакции на заметки
- Модель `NoteReaction` (noteId, userId, emoji)
- Endpoint: POST/DELETE `/notes/:id/reactions`
- Flutter: строка emoji под карточкой, bottom sheet для выбора
- Предустановленные реакции: 👍 ❤️ 😂 🔥 ✅

## Инфраструктура
- **Gradle JVM crash**: Windows не может выделить 2G+ для Gradle daemon при сборке APK. Варианты:
  - Собирать APK на сервере (Docker / GitHub Actions)
  - Увеличить pagefile на Windows
  - Попробовать `org.gradle.jvmargs=-Xmx1536m -XX:+UseSerialGC`
- **APP_VERSION на бэке**: сейчас захардкожен `1.1.0` — синхронизировать с Flutter pubspec
- **CI/CD**: настроить GitHub Actions для автосборки APK + деплоя бэкенда

## Технический долг
- NoteModel: добавить `copyWith()` для избавления от ручных конструкторов в provider
- Вынести `_formatRelativeTime` в shared utility
- Прогресс-бар чеклиста: показывать и в grid-режиме карточек
