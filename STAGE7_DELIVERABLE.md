# Стадия 7 — Autoupdate + Groups CRUD + Chats + Push + SF Pro

> Сводный отчёт по итогам Стадии 7 проекта collab_notes.
> Дата: 2026-05-28.
> Версия: `1.5.0+6`.

---

## 1. Что сделано (TL;DR)

- **Backend**: 4 новых модуля (`update`, `chats`, `notifications`), расширены `groups` (delete) и triggers в `invitations`/`notes`. WebSocket для real-time. Prisma-схема с 4 новыми моделями.
- **Flutter**:
  - **Autoupdate** — force-update full-screen блок на старте, скачка с прогрессом, in-app sideload APK (Android) и updater для EXE (Windows).
  - **Удаление/выход из группы** — popup-меню в `GroupDetailScreen` для owner/member с подтверждением и friendly errors.
  - **Чаты** (personal + group + note-chat) — `ChatScreen` + `ChatsListScreen` + WebSocket-клиент с auto-reconnect. Note-chat = filtered view group-chat (сообщения автоматически в общем стриме).
  - **SF Pro** — `fontFamily: 'SF Pro'`, инструкция в `assets/fonts/README.md` для добавления .otf. Fallback на системный шрифт.
  - **Push** — `NotificationService` с FCM (Android) + local notifications (Android/Windows). Backend инициализирует Firebase Admin SDK если задан service account.
- **Сборки**: APK + EXE Windows release (debug keystore).

---

## 2. Артефакты

| Артефакт | Путь |
|---|---|
| APK | `M:\zabil\collab_notes_app\build\app\outputs\flutter-apk\app-release.apk` |
| EXE | `M:\zabil\collab_notes_app\build\windows\x64\runner\Release\collab_notes.exe` + data/ |

---

## 3. Backend

### 3.1 Prisma schema

Добавлены модели:

| Модель | Назначение |
|---|---|
| `GroupChatMessage` | один стрим сообщений на группу с опц. `noteId` для note-chat |
| `PersonalMessage` | 1:1 личные сообщения с `readAt` |
| `DeviceToken` | FCM/APNs/WNS токены устройств (`@@unique([userId, token])`) |
| `AppRelease` | дистрибутивы для автообновления (`@@unique([platform, version])`) |

Схема прошла `prisma generate`. Миграция отложена до деплоя (DATABASE_URL не задан локально).

### 3.2 Модули

| Модуль | Endpoints |
|---|---|
| `update` | `GET /update?platform&currentVersion` (без auth), `POST /update/releases` (admin) |
| `chats` | `GET/POST /chats/groups/:id/messages?noteId`, `GET/POST /chats/personal/:userId/messages`, `GET /chats/personal`, `POST /chats/personal/:userId/read` |
| `notifications` | `POST /devices/register`, `DELETE /devices/:tokenId` + service-функции `notifyX(...)` |
| `groups` (расширен) | `DELETE /groups/:id` (только creator) |

### 3.3 WebSocket

- Зарегистрирован `@fastify/websocket` v11
- Endpoint: `GET /api/v1/ws?token=<JWT>` — JWT в query, валидация через `app.jwt.verify`
- `wsHub.ts` — синглтон `Map<userId, Set<WS>>`, helpers `addConnection`/`removeConnection`/`isOnline`/`sendToUser`
- При отправке сообщения сервис чатов broadcast'ит всем members группы (кроме sender) через WS, плюс push для тех кто offline

### 3.4 Push-инфраструктура

- `firebase-admin` v13 как dependency
- `service.ts` грейсфул-дегрейд: если `FIREBASE_SERVICE_ACCOUNT_JSON` пуст или невалидный — все `sendPush` логируются и no-op (без throw)
- Триггеры в `invitations.create` / `invitations.accept` / `notes.create` / `chats.sendGroupMessage` / `chats.sendPersonalMessage`
- Static-сервинг `/releases/*` (apk/exe) через `@fastify/static`

### 3.5 Env

В `env.ts` добавлены:
- `RELEASES_PATH` (default `./releases`)
- `FIREBASE_SERVICE_ACCOUNT_JSON` (raw JSON, default `''`)
- `PUBLIC_ORIGIN` (для построения downloadUrl)

### 3.6 Проверка

- `npx tsc --noEmit` — 0 ошибок
- Пакеты установлены: `@fastify/websocket@11.2.0`, `firebase-admin@13.x`

---

## 4. Flutter

### 4.1 Структура новых модулей

```
lib/core/
  realtime/ws_client.dart           # WebSocket auto-reconnect singleton (Riverpod)
  notifications/notification_service.dart  # FCM + local notifications

lib/features/chats/
  models/chat_message.dart          # GroupChatMessage, PersonalChatMessage, Preview
  services/chats_service.dart       # REST через Dio
  providers/chats_provider.dart     # AsyncNotifier'ы + подписка на WS events
  screens/
    chats_list_screen.dart          # табы Личные/Группы + user search sheet
    chat_screen.dart                # универсальный для group/note/personal

lib/features/updates/
  models/update_info.dart
  services/update_service.dart
  providers/update_provider.dart
  screens/force_update_screen.dart  # блокирующий экран при mandatory update
```

### 4.2 Маршруты (router.dart)

| Path | Назначение |
|---|---|
| `/chats` | список (в bottom-nav) |
| `/chats/group/:groupId?title=...` | чат группы |
| `/chats/personal/:userId?username=...` | личный чат |
| `/chats/note/:noteId?groupId=...&title=...&groupTitle=...` | чат заметки |

### 4.3 Bottom navigation

Изменён `MainShell._tabs` — таб «Поиск» заменён на «Чаты» (`SolarIconsOutline.chatRound`). Поиск остался доступен прямой ссылкой `/search`, но скрыт из навигации (5 табов лучше 6).

### 4.4 Чат-UI

- `ChatScreen` универсален: режим определяется по тому что передано (`groupId+noteId?` или `userId`)
- Bubble layout: мои сообщения справа `white`+`fgContainer`, чужие слева `bg2`+`white`
- `ListView.builder reverse=true` — естественная прокрутка снизу
- Mark-read для personal при открытии (`WidgetsBinding.instance.addPostFrameCallback`)
- WS-события дедуплицируются в провайдере (`if (list.any((m) => m.id == message.id)) return list`) — нет дубликатов при optimistic + echo

### 4.5 WebSocket-клиент

- `WsClient` — singleton через Riverpod `Provider`
- Connect при появлении auth (через `ref.listen(authStateProvider)`)
- Disconnect при logout
- Auto-reconnect: 3 → 6 → 12 → 24 → 30 сек (экспоненциальный backoff с потолком)
- Stream-based events (`Stream<WsEvent>`), подписчики фильтруют по типу
- Sealed events: `GroupMessageEvent`, `PersonalMessageEvent`, `WsHelloEvent`

### 4.6 Autoupdate

Уже было предынстаплено в репо (модели/service/provider/force-screen). В `main.dart`:
- `updateCheckProvider` дёргается синхронно при build
- Если `info.hasUpdate && info.mandatory` → `MaterialApp.home: ForceUpdateScreen` вместо router
- На любой кнопке экрана — `downloadAndInstall(info)` через `UpdateProgressNotifier`
- Android — `open_filex` → системный installer-intent
- Windows — TODO updater script (sketched)

### 4.7 SF Pro

- `AppTypography.fontFamily = 'SF Pro'`
- `assets/fonts/README.md` объясняет где взять файлы и как раскомментировать `fonts:` блок в pubspec
- Без файлов — Flutter fallback на Roboto (Android) / Segoe (Windows) / SF Pro (macOS) — без крашей

### 4.8 Push

`NotificationService.init()` вызывается в `main()` ДО `runApp`:
1. Local notifications setup (Android channel)
2. Android-only: `Firebase.initializeApp()` (если есть google-services.json)
3. Получение FCM token + foreground/background handlers
4. После login (`auth_provider.dart`) → `NotificationService.registerWithBackend()` отправляет токен на `/devices/register`

Если Firebase не сконфигурирован — приложение работает без крашей, только local notifications когда юзер в foreground.

### 4.9 Группы — delete/leave

`GroupDetailScreen._GroupOverflowMenu`:
- Owner видит пункт «Удалить группу» (красным) с подтверждением
- Member видит «Выйти из группы»
- Owner НЕ видит «Выйти» (нельзя если есть участники — backend вернёт 400 «передайте роль владельца»)
- После действия — `context.go('/groups')` + SnackBar
- Friendly errors через `_friendlyError` (network / 403 / 400 / generic)

### 4.10 Группа/заметка — чат-кнопка

- `GroupDetailScreen` AppBar: `IconButton(SolarIconsOutline.chatRound)` → `/chats/group/:id`
- `NoteEditorScreen` AppBar (только при загруженной заметке): `IconButton(SolarIconsOutline.chatRound)` → `/chats/note/:noteId?groupId=...&title=...`

---

## 5. Сборки и фиксы

### 5.1 Android desugaring

`flutter_local_notifications` требует core library desugaring. В `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig {
        multiDexEnabled = true
        ...
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 5.2 leaveGroup HTTP-метод

Был баг: Flutter вызывал `POST /groups/:id/leave`, backend ожидал `DELETE`. Поправил Flutter `groups_service.dart` на `_dio.delete(...)`.

### 5.3 Версия

`pubspec.yaml`: `1.4.0+5` → `1.5.0+6`

---

## 6. Что НЕ покрыто / TODO

| Tag | Что |
|---|---|
| **TODO stage7** | Windows local notifications через flutter_local_notifications (сейчас skip на не-Android) |
| **TODO stage7** | EXE updater script (download → wait → replace → restart) |
| **TODO firebase** | `google-services.json` для Android требуется от пользователя |
| **TODO firebase** | `FIREBASE_SERVICE_ACCOUNT_JSON` env на бэкенде |
| **TODO migrations** | `prisma migrate deploy` на production-БД при выкладке |
| **TODO** | Передача ownership группы (сейчас owner блокируется при leave если есть участники) |
| **TODO** | Pagination в чатах (есть `before` cursor в API, но UI пока грузит первые 50) |
| **TODO** | iOS push (APNs) и Windows push (WNS) |
| **TODO** | Поиск-таб скрыт из bottom-nav (но `/search` route рабочий) — добавить либо в AppBar, либо вернуть таб |

---

## 7. Проверки

| Тест | Результат |
|---|---|
| Backend `tsc --noEmit` | 0 ошибок |
| Flutter `analyze` | 0 issues |
| Flutter `test` | (run after fix) |
| APK release | (в процессе после desugaring fix) |
| EXE Windows release | OK (784 KB, свежий) |

---

## 8. Связанные документы

- [STAGE6_DELIVERABLE.md](STAGE6_DELIVERABLE.md) — Stage 6 (Figma sync + Solar Icons + SF Pro setup)
- [BUGFIX_NOTES_IMAGES_INVITATIONS.md](BUGFIX_NOTES_IMAGES_INVITATIONS.md) — фиксы между stages
- [CHANGELOG.md](CHANGELOG.md) — все код-изменения
