# Аудит и план реализации — collab_notes v1.22

> Дата: 2026-05-31  
> Ветка для реализации: `feature/ux-and-fixes-v122`

---

## I. БАГИ (реальные дефекты — реализовать все)

| # | Файл | Дефект | Фикс |
|---|------|--------|------|
| B1 | `note_editor_screen.dart:171` | **PopScope потеря данных** — `canPop: !_isSaving` не учитывает `_isDirty`. При нажатии «назад» экран закрывается до завершения save | `canPop: !_isDirty && !_isSaving`. Блокировать уход пока `_isDirty`, сначала сохранить |
| B2 | `note_editor_screen.dart:326-353` | **Изображения в редакторе без onTap** — нельзя открыть полноэкран и нет кнопки удаления, хотя `deleteImage` есть в провайдере | Добавить `GestureDetector` → fullscreen viewer + `long press` → «Удалить» |
| B3 | `note_editor_screen.dart` + `note_card.dart` | **Дублирование `_ResilientNoteImage`** — идентичный виджет в двух файлах | Вынести в `shared/widgets/resilient_image.dart`, импортировать |
| B4 | `middleware/auth.ts:7` | **`authenticate` не делает `return`** — handler может продолжить выполнение после 401 | `return reply.status(401).send(...)` в обоих местах (auth.ts + plugins/jwt.ts) |
| B5 | `notes/service.ts:321,358` | **Checklist item IDOR** — `updateChecklistItem` и `deleteChecklistItem` не фильтруют по `noteId` | `where: { id: itemId, noteId }` в update и delete |
| B6 | `app.ts:128` | **Memory leak в `chatTypingLastSentAt`** — Map никогда не очищается | Добавить `setInterval` каждые 5 мин, удалять записи старше 1 минуты |
| B7 | `chats/service.ts:23,147` | **Пагинация по UUID** вместо `createdAt` — UUID не сортируются хронологически | Пагинация по `createdAt` cursor: `{ createdAt: { lt: beforeDate } }` |

---

## II. БЭКЕНД — находки агента (реализовать все критичные/high)

| # | Файл | Severity | Проблема | Фикс |
|---|------|----------|---------|------|
| BE1 | `update/service.ts:95` | Critical | Хардкод `semvanic` как admin | Добавить поле `isAdmin: Boolean @default(false)` в модель User + миграция |
| BE2 | `chats/service.ts:236` | Critical | `getPersonalConversations` загружает 1000 сообщений | SQL aggregation: отдельный `COUNT + lastMessage` через Prisma groupBy или raw |
| BE3 | `chats/routes.ts` | High | Нет Zod-валидации body для чат-роутов | Создать `sendGroupMessageSchema` и `sendPersonalMessageSchema` |
| BE4 | `chats/service.ts` | High | `imageUrl` записывается без проверки (SSRF/XSS) | Валидировать что `imageUrl` начинается с `/uploads/` |
| BE5 | `server.ts` | Medium | Нет graceful shutdown | Добавить `SIGTERM`/`SIGINT` handler → `app.close()` |
| BE6 | `config/env.ts:9` | Medium | `JWT_REFRESH_SECRET` объявлен но не используется | Удалить из env-схемы |
| BE7 | `app.ts:49` | Medium | CORS `*` по умолчанию | Убрать default `*`, сделать обязательным в production |
| BE8 | `auth/service.ts` | Medium | Нет cleanup expired refresh tokens | Добавить cron-задачу или лимит 10 токенов на пользователя |
| BE9 | Schema | Medium | `role`, `status`, `platform` — string вместо enum | Создать Prisma enum-ы: `GroupRole`, `InvitationStatus`, `Platform` + миграция |
| BE10 | `app.ts:138` | Medium | WS JWT проверяется только при подключении | Разрывать соединение после истечения TTL access token (15 мин) |
| BE11 | Три файла | Low | Дублирование `ALLOWED_MIME_TYPES`, `MAGIC_BYTES`, `ensureDir` | Вынести в `utils/upload-helpers.ts` |
| BE12 | `uploads/service.ts:2` | Low | Неиспользуемый импорт `pipeline` | Удалить |
| BE13 | `notes/service.ts:64` | Medium | `getNotes` без пагинации | Добавить `limit`/`cursor` параметры |

---

## III. UX — выбранные улучшения

### A. Заметки

| # | Улучшение | Детали реализации |
|---|-----------|------------------|
| A2 | **Бейджи с количеством на фильтр-чипах** | На каждом AppChip показывать количество заметок в скобках (Все: 12, Личное: 5) |
| A4 | **Markdown-рендер для content** | При просмотре заметки — рендерить `**bold**`, `*italic*`, `# heading`, `- list`. В редакторе — plain text. Использовать пакет `flutter_markdown` |
| A5 | **Inline добавление пунктов чеклиста** | Заменить bottom sheet на inline TextField «Новый пункт...» в конце каждой секции. Enter → создать пункт, фокус на следующее поле |
| A6 | **Удаление в корзину + undo** | Вместо жёсткого удаления — SnackBar с кнопкой «Отменить» (5 секунд). Если пользователь не нажал — отправить `DELETE`. Либо экран «Корзина» |
| A7 | **Опции сортировки** | Dropdown/кнопка рядом с view toggle: «По изменению», «По созданию», «По названию», «По цвету» |
| A8 | **Highlight matching text + поиск по чеклистам** | При поиске — выделять совпадение в заголовке и content в карточке. Добавить поиск по `checklistItems.text` на бэкенде |
| A9 | **Grid: высота по содержимому** | В masonry grid не растягивать до самого высокого в ряду — оставлять высоту по контенту, следующий ряд начинается с отступа от самого высокого в текущем. Это стандартное masonry-поведение — проверить конфиг `MasonryGridView` |
| A13 | **Diff при конфликте редактирования** | В диалоге конфликта показывать «Кто изменил + когда» + preview нового содержимого (первые 100 символов diff) |
| A14 | **Drag-to-reorder заметок** | В list view — добавить drag handle, ReorderableListView для ручного упорядочивания. Позиция сохраняется локально (SharedPreferences) или через новое поле `position` на бэкенде |

### B. Чаты

| # | Улучшение | Детали реализации |
|---|-----------|------------------|
| B15 | **Объединённый список чатов** | Один список (как Telegram): личные + групповые перемешаны, сортировка по времени последнего сообщения. TabBar убрать |
| B16 | **Fix FutureBuilder в GroupsTab** | `buildGroupPayload` уже возвращает `lastMessage`. Убрать FutureBuilder, использовать данные из `groupsProvider` напрямую |
| B17 | **Unread badge для групповых чатов** | Бэкенд: добавить `unreadCount` в `buildGroupPayload` (COUNT непрочитанных). Фронт: показывать `_ConversationCounter` |
| B18 | **Reply/цитирование** | Swipe right на bubble → quote preview над composer. `replyTo: { id, body, senderName }` в payload сообщения. Бэкенд: добавить `replyToId String?` в `GroupChatMessage` и `PersonalMessage` |
| B19 | **Удаление сообщений** | Long press на bubble → «Удалить» (только свои, только в течение 15 мин). Бэкенд: soft delete `deletedAt`, WS broadcast `message_deleted`. Фронт: bubble заменяется на «Сообщение удалено» |
| B20 | **Дата-разделители** | DateSeparator виджет между сообщениями разных дней: «Сегодня» / «Вчера» / «29 мая» |
| B22 | **Scroll-to-bottom button** | FAB со стрелкой вниз появляется при скролле вверх. Badge с кол-вом новых сообщений |
| B23 | **Link preview** | При наличии URL в тексте — парсить и показывать карточку: favicon + title + domain. Пакет `url_launcher` + HTTP GET meta tags. Кешировать |
| B24 | **"Прочитано: ..." под сообщением** | Под последним своим сообщением в группе — показывать avatars/имена тех кто прочитал. Тап → список |
| B25 | **Haptic feedback** | `HapticFeedback.selectionClick()` при: отправке сообщения, свайпе к порогу, pin/unpin, pull-to-refresh. Без звука |
| B26 | **Поиск пользователей по displayName** | Бэкенд: `users/search` искать по `displayName ILIKE %query%` + `username ILIKE %query%`. Фронт: показывать оба поля |
| B27 | **Mic/Send кнопка** | Если текст пуст — иконка микрофона справа от поля ввода (пока без записи, просто заглушка). Если текст введён — только стрелка отправки. Иконка галереи остаётся слева всегда |
| B28 | **Pinch-to-zoom в ChatImageViewer** | Заменить `Image.network` в `ChatImageViewerScreen` на `InteractiveViewer` с `maxScale: 4.0`. Double tap to zoom |
| B30 | **Emoji reactions** | Long press на bubble → quick reaction picker (6 эмодзи: ❤️ 👍 😂 😮 😢 🔥). Тап на реакцию под bubble → добавить/убрать. Бэкенд: новая таблица `MessageReaction` |

### C. Группы

| # | Улучшение | Детали реализации |
|---|-----------|------------------|
| C31 | **Полноценный экран группы** | `/groups/:id` — аватарка, название, список участников с ролями, кнопки «Пригласить / Покинуть / Удалить группу», переход в чат группы, список заметок группы |
| C33 | **Ссылка-инвайт / QR-код** | Бэкенд: endpoint `POST /invitations/link` → возвращает одноразовый токен. `GET /invitations/join/:token` → auto-accept. Фронт: кнопка «Поделиться ссылкой» в экране группы + QR |
| C34 | **Media tab в экране группы** | Вкладка «Медиа» в `/groups/:id` — все изображения из чатов группы + заметок, grid view, тап → fullscreen |
| C35 | **Transfer ownership** | В управлении участниками: owner может тапнуть на member → «Назначить владельцем». Подтверждение диалогом |
| C36 | **Per-group mute** | Toggle «Уведомления» в экране группы. Бэкенд: добавить `GroupMember.mutedUntil DateTime?`. Фронт: учитывать при показе push |

### D. Навигация и общее

| # | Улучшение | Детали реализации |
|---|-----------|------------------|
| D37 | **Badge на tab «Чаты»** | Суммарный unread count (личные + групповые) на иконке «Чаты» в bottom navbar. Provider для unread totals |
| D38 | **Smooth animation для navbar** | Скрытие/появление bottom navbar при входе/выходе в note editor — AnimatedContainer + SlideTransition |
| D41 | **Friendly error messages** | `DioException` → читаемые сообщения: `connection refused` → «Нет связи с сервером», `timeout` → «Сервер не отвечает», 401 → «Необходимо войти снова». Создать `ErrorMessageMapper` |
| D43 | **Skeleton для chat list** | `_ChatListSkeleton` — shimmer с формой conversation card (avatar circle + text lines + time). Использовать вместо `AppLoader` в ChatsListScreen |
| D45 | **Full light theme** | Аудит всех hardcoded цветов: `Color(0xFF1A1A1A)`, `AppColors.bg2/bg3` в NoteCard, чатах → заменить на `Theme.of(context).colorScheme.*`. Проверить light theme визуально |

---

## IV. НОВАЯ ФУНКЦИОНАЛЬНОСТЬ — Telegram OAuth

### Описание
Добавить кнопку «Войти через Telegram» на экран авторизации.

### Технический план

**Бэкенд:**
1. `POST /auth/telegram` — принимает `{ id, first_name, last_name?, username?, photo_url?, hash, auth_date }` (Telegram Login Widget данные)
2. Верификация HMAC-SHA256 подписи (`hash`) через `TELEGRAM_BOT_TOKEN`
3. Upsert пользователя: если есть `telegramId` — логин, иначе создать новый аккаунт
4. Новые поля в `User`: `telegramId String? @unique`, `photoUrl String?`
5. Env: `TELEGRAM_BOT_TOKEN`

**Фронт (Flutter):**
1. Пакет `flutter_telegram_login` или `webview_flutter` для Telegram Login Widget
2. На экране авторизации кнопка «🔵 Войти через Telegram» под формой
3. При успехе — те же `accessToken` + `refreshToken`, что и при обычном логине

**Схема Prisma:**
```prisma
model User {
  // ...existing fields...
  telegramId   String?  @unique @map("telegram_id")
}
```

---

## V. Дополнительные UX (из агента — выбраны все)

| Проблема | Фикс |
|---------|------|
| **Offline indicator** — нет баннера при потере сети | `connectivity_plus` пакет → `MaterialBanner` «Нет подключения» |
| **Нет pull-to-refresh в GroupsTab** | Обернуть в `RefreshIndicator` |
| **Нет Semantics для accessibility** | `Semantics` на checklist progress, delivery status, online dot, color dot |
| **`_ResilientNoteImage` дублирован** | → `shared/widgets/resilient_image.dart` |
| **Raw exceptions в UI** | `ErrorMessageMapper` (входит в D41) |

---

## VI. Порядок реализации (фазы)

### Фаза 1: Критичные баги + безопасность (можно деплоить сразу)
1. B4 — authenticate return
2. B5 — checklist IDOR  
3. B1 — PopScope потеря данных
4. B2 — image viewer в редакторе
5. BE1 — admin hardcode (isAdmin field)
6. BE4 — imageUrl validation
7. B6 — typing map memory leak

### Фаза 2: Бэкенд улучшения
8. BE2 — getPersonalConversations performance
9. BE3 — Zod validation для чатов
10. BE5 — graceful shutdown
11. BE8 — refresh token cleanup
12. BE9 — Prisma enums
13. BE13 — getNotes pagination
14. B7 — chat pagination cursor fix
15. BE11 — utils/upload-helpers.ts
16. BE12 — unused import

### Фаза 3: Telegram OAuth
17. Бэкенд: `/auth/telegram` + миграция
18. Фронт: кнопка Telegram на auth screen

### Фаза 4: Чаты (высокий приоритет)
19. B16 — Fix FutureBuilder (quick win)
20. B20 — Date separators
21. B28 — Pinch-to-zoom
22. D43 — Chat list skeleton
23. B15 — Объединённый список
24. B17 + D37 — Unread badges
25. B22 — Scroll-to-bottom
26. B27 — Mic/Send button logic
27. B25 — Haptic feedback
28. B19 — Удаление сообщений
29. B18 — Reply/цитирование

### Фаза 5: Заметки
30. B3 — _ResilientNoteImage extraction
31. A5 — Inline checklist
32. A8 — Search highlight + checklist search
33. A4 — Markdown render
34. A7 — Sort options
35. A2 — Count badges on chips
36. A6 — Undo delete
37. A9 — Masonry grid fix
38. A13 — Conflict diff
39. A14 — Drag reorder

### Фаза 6: Группы
40. C31 — Group screen
41. C35 — Transfer ownership
42. C33 — Invite link/QR
43. C34 — Media tab
44. C36 — Per-group mute

### Фаза 7: Полировка
45. D41 — Error messages
46. D38 — Navbar animation
47. D45 — Light theme audit
48. B23 — Link preview
49. B24 — Seen by
50. B26 — Search by displayName
51. B30 — Emoji reactions
52. C36 — Offline indicator
53. Accessibility semantics

---

## VII. Технические зависимости

**Новые Flutter пакеты:**
- `flutter_markdown` — рендер markdown
- `connectivity_plus` — offline detection
- `url_launcher` (уже есть) — для link preview
- `webview_flutter` или `flutter_telegram_login` — Telegram OAuth

**Новые бэкенд зависимости:**
- `node-telegram-bot-api` или нативная crypto верификация — Telegram auth

**Новые поля БД (миграции):**
- `User.telegramId String? @unique`
- `User.isAdmin Boolean @default(false)`
- `GroupChatMessage.replyToId String?`
- `PersonalMessage.replyToId String?`
- `GroupChatMessage.deletedAt DateTime?`
- `PersonalMessage.deletedAt DateTime?`
- `GroupMember.mutedUntil DateTime?`
- Новая таблица `MessageReaction`
- Prisma enums: `GroupRole`, `InvitationStatus`, `Platform`

