# Багфиксы: заметки (текст+изображения) + приглашения

> Дата: 2026-05-28 (после Stage 6).
> Версия: `1.4.1+6`.

## Что было сломано

| # | Баг | Причина |
|---|---|---|
| 1 | Текст заметки появляется с задержкой | `_buildEditor` ждал `noteDetailProvider` (API call); полноэкранный `AppLoader` блокировал UI |
| 2 | Изображение не грузится (томбстоун) | `NoteImage.url` использовал пустой `_baseUrl` (`setBaseUrl()` нигде не вызывался) → запрос шёл на относительный `/uploads/notes/<file>` без хоста |
| 3 | Изображение нельзя удалить | Не было backend-эндпоинта DELETE, не было UI-кнопки, не было метода в сервисе/провайдере |
| 4 | Нет fullscreen-просмотра с зумом | Не было экрана; `Image.network` без обёртки |
| 5 | Нет свайпа между изображениями | То же — не было `PageView` |
| 6 | Приглашения accept/decline не работают | `onPressed: () => ref.read(...).accept(id)` — Future терялся, ошибки молча игнорировались (Dart разрешает возвращать Future из VoidCallback, но результат отбрасывается) |

## Что исправлено

### Backend (`backend/src/modules/uploads/`)

- **routes.ts**: добавлен `DELETE /uploads/note-image/:imageId` с `authenticate` preHandler.
- **service.ts**: добавлена функция `deleteNoteImage(app, userId, imageId)`:
  - проверяет существование и `note.deletedAt`
  - проверяет членство в группе (`requireGroupMember`)
  - удаляет файл с диска (best-effort, ошибка не блокирует БД)
  - удаляет запись `noteImage` из БД
- `tsc` зелёный, `dist/` пересобран.

### Flutter

| Файл | Что |
|---|---|
| `core/config/app_config.dart` | + `apiOrigin` getter (`https://api.achiemvemer.ru/api/v1` → `https://api.achiemvemer.ru`) |
| `features/notes/models/note_model.dart` | `NoteImage.url` использует `AppConfig.apiOrigin`; убран мёртвый `setBaseUrl()` |
| `core/config/api_endpoints.dart` | + `deleteNoteImage(imageId)` → `/uploads/note-image/:id` |
| `features/notes/services/notes_service.dart` | + `deleteImage(imageId)` через `dio.delete` |
| `features/notes/providers/notes_provider.dart` | + `deleteImage(imageId)` в `NoteDetailNotifier`, оптимистично удаляет из `state.images` |
| `features/notes/screens/image_viewer_screen.dart` | **Новый файл**: PageView (зацикленный через × 1000 + modulo) + InteractiveViewer (pinch zoom до 5×) + удаление с подтверждением |
| `features/notes/screens/note_editor_screen.dart` | • Bug 1: pre-fill controllers из `notesProvider` cache в `initState` → текст виден мгновенно <br>• Bug 2: `Image.network` → `CachedNetworkImage` <br>• Bug 3: `_NoteImageTile` с long-press + ❌ chip overlay + диалог подтверждения <br>• Bug 4-5: tap на картинку → `Navigator.push(ImageViewerScreen)` |
| `features/invitations/screens/invitations_screen.dart` | • Отдельный stateful `_InvitationCard` per-item<br>• Bug 6: try/catch + SnackBar + `_busy` блокировка обеих кнопок во время запроса<br>• Spinner на active button через `AppButton.isLoading`<br>• Дружелюбные сообщения об ошибках (сеть/404) |

## Архитектурные заметки

- **Bug 1 fix** — двухстадийная отрисовка. Первая фаза рендерит из кеша списка (`notesProvider`). Когда `noteDetailProvider` возвращает свежие данные, обновляем поля только если `!_isDirty` (чтобы не затереть ввод пользователя). Это даёт ощущение мгновенного открытия + автоматическое подтягивание актуальных checklist/images.
- **Bug 6 fix** — главный анти-паттерн: `() => future` в `VoidCallback`. Future выполняется, но любой `throw` теряется. Решение: явный `async` метод в State + try/catch + UI-feedback.
- **Зацикленный PageView** — без отдельного пакета: `itemCount = images.length × 1000`, `initialPage = length × 500 + initialIndex`, реальный индекс = `page % length`. Бесшовно прокручивается в обе стороны.
- **Static uploads без auth** — backend сервит `/uploads/*` через `@fastify/static` без middleware, поэтому в `CachedNetworkImage` не нужны headers.

## Результаты

| Проверка | Результат |
|---|---|
| Backend `tsc --noEmit` | OK |
| Flutter `analyze` | 0 issues |
| Flutter `test` | 1/1 passed |
| APK release | (в сборке) |
| EXE Windows release | (в сборке) |

## Что осталось вне scope

- **Деплой backend** — изменения в `dist/` готовы, но раскатывать на сервер — отдельный шаг.
- **Drag-to-reorder изображений** — пользователь не просил.
- **Кэширование изображений на диск надолго** — `cached_network_image` использует дефолтную политику (~30 дней).
