# Phase A Action Log (2026-05-30)

## Session Start
- Получен старт реализации с требованием логировать все действия.
- Выбрана фаза A: пункты 1, 5, 6, 22, 23.
- Выполнен baseline-reading ключевых файлов: main.dart, main_shell.dart, note_editor_screen.dart, note_card.dart, router.dart.

## Planned In-Progress Changes
- [P1] Double-back exit guard: глобально, сообщение "Еще раз, чтобы выйти", окно 3 сек.
- [P5] Ослабление swipe карточек в list mode через повышенные dismiss thresholds.
- [P6/P22] Скрытие bottom navbar на экранах редактирования заметки + стабилизация показа FAB на корне /notes.
- [P23] Защита локального ввода в редакторе от rollback при автосохранении/перерисовках.

## Action Trace
1. Создан лог-файл фазы A и зафиксирован старт.
2. main.dart:
	- Добавлен AppExitGuard на уровне MaterialApp и MaterialApp.router через builder.
	- Реализована логика double-back exit с окном 3 секунды.
	- Добавлен snackbar "Еще раз, чтобы выйти".
3. main_shell.dart:
	- Переключен route source на state.uri.path + state.matchedLocation.
	- Добавлено скрытие bottom navbar на роутах редактора заметки.
	- Оставлена логика FAB для корня /notes и режима архива.
4. note_card.dart:
	- Добавлены dismissThresholds 0.4/0.4 для ослабления случайных свайпов.
5. note_editor_screen.dart:
	- Добавлены FocusNode для title/content.
	- Добавлена безопасная гидрация контроллеров только при отсутствии локального ввода.
	- После сохранения добавлен локальный апдейт noteDetailProvider через applyLocalTextEdits.
6. notes_provider.dart:
	- Добавлен метод applyLocalTextEdits для синхронного локального состояния editor-detail.
7. main.dart (edge-case fix):
	- Скорректирован AppExitGuard: если есть back-stack, но текущий экран временно блокирует pop (например, во время save), приложение не показывает exit-confirm и не выходит.
8. Валидация:
	- Выполнен `flutter analyze` в `collab_notes_app`.
	- Результат: `No issues found`.
9. notes_list_screen.dart (архив UX):
	- Добавлен одноразовый hint при входе в архив с action "Выйти".
	- Добавлена явная кнопка в шапке "Выйти из архива".
	- В snackbar после архивации добавлен action "Перейти" в архив текущего контекста.
10. notes_list_screen.dart (cleanup):
	- Удалены дубли archive-кнопок в AppBar, оставлен единый UX-поток: либо "Показать архив", либо "Выйти из архива".
11. Повторная валидация:
	- Выполнен повторный `flutter analyze` после архивных изменений.
	- Результат: `No issues found`.
12. notes_provider.dart:
	- Добавлен метод `applyRemoteSnapshot` для безопасного применения серверной версии заметки в `noteDetailProvider`.
13. notes_list_screen.dart (P14 + P17):
	- Реализован restore-flow при разархивации: перед восстановлением открывается выбор контекста.
	- Добавлен предвыбор исходного контекста заметки (личный/групповой).
	- Отмена в restore-sheet теперь оставляет заметку в архиве без изменений.
	- Если выбран другой контекст, выполняется `moveNote`, затем unarchive.
	- В loading-state списка заметок заменен `AppLoader` на gradient/shimmer skeleton (`_NotesListSkeleton`).
14. note_editor_screen.dart (P15 + P16):
	- Presence: добавлен локальный viewer редактора и сортировка viewers с приоритетом редактора (self-first), затем по имени.
	- Добавлен periodic remote-check (polling) для заметки в редакторе.
	- Добавлен pull-to-refresh в редакторе (`RefreshIndicator`).
	- При обнаружении свежих серверных изменений во время локального ввода показывается banner "Есть новые изменения".
	- Добавлен конфликт-диалог: "Оставить мое" / "Применить" для входящих обновлений.
	- При отсутствии локального ввода серверная версия применяется автоматически через `applyRemoteSnapshot`.
15. Валидация блока 14–17:
	- Выполнен `flutter analyze` из `collab_notes_app` после правок.
	- Итог: `No issues found`.
16. notes_provider.dart + note_editor_screen.dart (P18 + P21):
	- Добавлен `updateChecklistItemText` в `noteDetailProvider` для inline-редактирования пунктов.
	- В редакторе заметки добавлен режим мультизагрузки изображений:
	  - выбор режима "Со сжатием / Без сжатия" перед выбором файлов,
	  - выбор нескольких изображений из галереи,
	  - лимит 10 изображений за операцию (с snackbar-подсказкой),
	  - последовательная загрузка с итоговым статусом `успех/ошибки`.
	- Для drag&drop чеклиста:
	  - скрыта явная иконка drag-handle,
	  - перетаскивание запускается long-press по всему контейнеру,
	  - задержка long-press установлена на 250мс,
	  - во время inline-редактирования drag отключается.
	- Для пунктов чеклиста добавлен inline edit по double-tap (фактически закрывает и пункт 12 досрочно).
17. main_shell.dart (P19 + UX toast bridge):
	- Добавлена глобальная подписка на `PushNotificationEvent` (WS) внутри MainShell.
	- Реализованы in-app toast/snackbar-сценарии:
	  - входящее приглашение,
	  - принято/отклонено отправленное приглашение,
	  - изменение доступа к группе (исключение/удаление группы).
	- При релевантных событиях выполняется invalidate `invitationsProvider`, `groupsProvider`, `notesProvider`.
18. backend notifications + groups + invitations (P19 + P20):
	- `notifications/service.ts`:
	  - добавлены `notifyInvitationDeclined`,
	  - добавлены `notifyGroupMemberRemoved`,
	  - добавлены `notifyGroupDeleted`.
	- `invitations/service.ts`:
	  - при `decline` теперь отправляется уведомление отправителю приглашения (`invitation_declined`).
	- `groups/service.ts`:
	  - при исключении участника отправляется push/WS `group_member_removed` исключенному пользователю,
	  - при удалении группы отправляется push/WS `group_deleted` всем участникам кроме инициатора.
19. Валидация блока 18–21:
	- Выполнен `flutter analyze` в `collab_notes_app`.
	- Результат: `No issues found`.
	- Дополнительно выполнен `npm run build` в `backend`.
	- Результат: успешная сборка TypeScript (`tsc`).
20. notes_provider.dart + notes_list_screen.dart + note_card.dart (P2 + P8 + P11):
	- Добавлена realtime-обработка WS push-событий заметок (`new_note`, `note_updated`, `checklist_updated`, `checklist_completed`) в `NotesNotifier`.
	- Для узких контекстов (поиск/фильтр/архив/контекст) изменения не применяются молча: показывается banner "Есть новые изменения в заметках" с действиями "Обновить/Позже".
	- Для широкого контекста без фильтров включено автообновление списка с debounce.
	- Добавлены таймерные highlight-маркеры обновлений:
	  - текстовые обновления подсвечивают контент карточки,
	  - checklist-обновления подсвечивают блок прогресса чеклиста,
	  - подсветка гаснет по таймеру,
	  - при открытии заметки подсветка для нее снимается ("после просмотра").
	- Для chips фильтров выставлен фон неактивного состояния как фон карточек заметок (сохранены active/hover состояния).
21. notes/service.ts + notifications/service.ts + note_editor_screen.dart (P9 + P10):
	- Backend: добавлен `notifyChecklistCompleted` с cooldown 5 минут на заметку.
	- Backend: триггер completion-push реализован только на переходе `неполный -> полный` (при update checklist item).
	- Frontend: в редакторе заметки добавлен обработчик `checklist_completed` push-события для запуска confetti у участников, у которых открыт редактор этой заметки.
22. image_viewer_screen.dart (P13):
	- Проверен full-screen индикатор `N/M` в AppBar viewer-а: функциональность уже присутствовала и сохранена.
23. Валидация блока 2/8/9/10/11/13:
	- Выполнен `flutter analyze` в `collab_notes_app`.
	- Результат: `No issues found`.
	- Выполнен `npm run build` в `backend`.
	- Результат: успешная сборка TypeScript (`tsc`).
24. Регрессионные фиксы по отчету пользователя (desktop 401 + navbar + note images):
	- `collab_notes_app/lib/core/api/api_client.dart`:
	  - переработан interceptor 401: добавлен единый refresh-future вместо флага,
	  - устранены гонки при параллельных 401 (все запросы ждут один refresh),
	  - добавлен session invalidation сигнал (`sessionInvalidated` + `sessionEpoch`) при провале refresh.
	- `collab_notes_app/lib/router.dart`:
	  - router refresh теперь слушает `sessionEpoch`,
	  - redirect принудительно ведет на `/login`, если сессия инвалидирована после refresh-fail.
	- `collab_notes_app/lib/features/auth/providers/auth_provider.dart`:
	  - при успешном restore/login/register сбрасывается флаг инвалидированной сессии через `ApiClient.markSessionActive()`.
	- `collab_notes_app/lib/shared/widgets/main_shell.dart`:
	  - логика скрытия navbar/FAB на editor-route переведена на `state.uri.path` (`/notes/new` и `/notes/:id` по префиксу),
	  - устранена зависимость от хрупкого `matchedLocation` шаблона.
	- `collab_notes_app/lib/features/notes/models/note_model.dart`:
	  - добавлены `urlCandidates` для изображений (поддержка absolute URL, `/uploads/...`, fallback через origin/baseUrl).
	- `collab_notes_app/lib/features/notes/screens/note_editor_screen.dart`,
	  `collab_notes_app/lib/features/notes/widgets/note_card.dart`,
	  `collab_notes_app/lib/features/notes/screens/image_viewer_screen.dart`:
	  - внедрен resilient image-loader с последовательным fallback по `urlCandidates`.
25. Валидация после регрессионных фиксов:
	- Выполнен `flutter analyze` в `collab_notes_app`.
	- Результат: `No issues found`.
	- Выполнен `npm run build` в `backend`.
	- Результат: успешная сборка TypeScript (`tsc`).

## Current Status
- Реализовано в коде: пункты 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23.
- Дополнительно закрыт регрессионный блок: desktop 401/route-navbar/note-images.
- Следующий целевой блок: адресные UX-polish и повторная ручная smoke-проверка пользовательских сценариев.

## Regression Batch (2026-05-31)
26. Chats + realtime UX фиксы:
	- Добавлены chat-typing события через WS (backend/frontend):
	  - backend: `chat_typing` broadcast для group/personal, throttling 900ms,
	  - frontend: отображение "user печатает..." / "user, user печатают...".
	- Для личных чатов добавлены read-receipts по WS (`read_receipt`) при `mark read`.
	- В client provider реализовано применение read-receipt к сообщениям и refresh списка диалогов.
27. Chats input/compose desktop UX:
	- Автофокус поля ввода при входе в чат.
	- После отправки сообщения сохраняется активный фокус input.
	- Добавлен дебаунс-эмит typing при наборе в чате.
	- Добавлена поддержка вставки изображения из буфера обмена (desktop) через `pasteboard` и `Ctrl+V`.
28. Chats image upload UX:
	- Реализованы локальные pending-bubbles для изображений из галереи/clipboard во время отправки.
	- При успешной отправке pending-bubble заменяется серверным сообщением.
	- При ошибке pending очищается и показывается snackbar.
29. Message status indicators:
	- Для исходящих сообщений в личных чатах добавлены чек-галочки статуса:
	  - `Отправлено` (одна галочка),
	  - `Прочитано` (двойная галочка).
30. Notes UX фиксы по отчету:
	- В `NotePresenceBar` убраны аватарки, плашка теперь показывает имена/никнеймы.
	- Исправлен false-positive confetti при входящем `checklist_completed`: confetti играет только если checklist фактически полностью закрыт в текущем состоянии.
	- Исправлено выравнивание блоков preview note-card (text/checklist).
31. 429 mitigation:
	- Увеличен глобальный backend rate limit с 100 до 300 запросов в минуту.

### Validation (2026-05-31)
- `flutter pub get` в `collab_notes_app` (добавлен `pasteboard`).
- `flutter analyze` в `collab_notes_app` → `No issues found`.
- `npm run build` в `backend` → успешная сборка `tsc`.

## Interview Log Batch (2026-05-31, v1.19-v1.21)
32. Groups/Profile UX block (`v1.19`):
	- backend `groups` responses расширены полем `lastMessage` для preview в списке групп.
	- `GroupsListScreen`: long-press actions, preview последнего сообщения, rename/avatar/invite/delete-or-leave.
	- `GroupDetailScreen`: full-screen info layout, pending invitations, long-press member actions.
	- `ChatUserProfileScreen`: online label, CTA `Написать сообщение` и `Пригласить в группу`.
33. Online + notification block (`v1.20`):
	- backend: добавлены user-level notification prefs (`notePushEnabled`, `checklistPushEnabled`, `releasePushEnabled`).
	- backend: personal chat previews и group members теперь несут `lastSeenAt`; note/checklist/release push уведомления учитывают prefs.
	- backend: publish release теперь триггерит `app_release` notification event с `downloadUrl`.
	- frontend: в настройках добавлены тумблеры пушей, в списке чатов и участниках группы добавлены online dots и `last seen`, MainShell показывает snackbar с кнопкой скачивания при новом релизе.
34. UX polish block (`v1.21`):
	- `SearchScreen`: при пустом поиске показываются `Недавние` из личных диалогов.
	- `ActivityFeedScreen`: добавлены chips-фильтры по пользователям и группам.
	- `AppLoader`: заменён на shimmer skeleton list.
	- `NotesListScreen`: переключение list/grid анимировано через `AnimatedSwitcher`.

### Validation (2026-05-31, continued)
- `npx prisma generate` в `backend` → успешно.
- `npm run build` в `backend` → успешно после изменений v1.20.
- `flutter analyze` в `collab_notes_app` → `No issues found` после блоков v1.20 и v1.21.
